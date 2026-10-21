const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
const base = '/api/weekly-impulse/community';
const impulseId = 'imp_test_gfk_w1';
const protectedRoutes = [
  ['POST', `${base}/posts`],
  ['GET', `${base}/verification-status`],
  ['POST', `${base}/verification-requests`],
  ['POST', `${base}/posts/:postId/like`],
  ['POST', `${base}/posts/:postId/comments`],
  ['POST', `${base}/posts/:postId/report`],
];
const moderatorRoutes = [
  ['GET', `${base}/verification-requests`],
  ['POST', `${base}/verification-requests/:requestId/approve`],
  ['GET', `${base}/reports`],
  ['POST', `${base}/reports/:reportId/resolve`],
  ['POST', `${base}/posts/:postId/moderation-visibility`],
];

function block(start, end) {
  const a = source.indexOf(start);
  const b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `Missing source block: ${start}`);
  return source.slice(a, b);
}

function fixture({ firebaseAvailable = true, verificationError } = {}) {
  const routes = new Map();
  const state = new Map();
  const requests = [];
  const experts = new Map();
  let verifications = 0;
  const parent = { uid: 'parent', email: 'parent@example.org', email_verified: true };
  const tokens = {
    parent,
    moderator: { uid: 'mod', email: ' MOD@ParentPeak.de ', email_verified: true },
    allowlisted: { uid: 'external-mod', email: 'reviewer@example.org', email_verified: true },
    unverified: { ...parent, uid: 'unverified', email: 'mod@parentpeak.de', email_verified: false },
    missingEmail: { uid: 'no-email', email_verified: true },
    missingVerification: { uid: 'no-verification', email: 'mod@parentpeak.de' },
    stringVerification: { uid: 'bad-verification', email: 'mod@parentpeak.de', email_verified: 'true' },
    deceptiveDomain: { ...parent, email: 'mod@parentpeak.de.attacker.org' },
    expert: { uid: 'expert', email: 'expert@example.org', email_verified: true },
  };
  const context = vm.createContext({
    crypto,
    console: { error() {} },
    internalModeratorEmails: ['reviewer@example.org'],
    internalModeratorDomains: ['parentpeak.de', 'parentpeak.com'],
    weeklyImpulseCommunityState: state,
    weeklyImpulseVerificationRequests: requests,
    weeklyImpulseVerifiedExperts: experts,
    firebaseAdmin: firebaseAvailable ? { auth: () => ({
      verifyIdToken: async token => {
        verifications++;
        if (verificationError) throw Object.assign(new Error('Unavailable'), { code: verificationError });
        if (!tokens[token]) throw new Error('Invalid token');
        return tokens[token];
      },
    }) } : null,
    app: Object.fromEntries(['get', 'post'].map(method => [
      method, (url, ...chain) => routes.set(`${method.toUpperCase()} ${url}`, chain),
    ])),
    getWeeklyImpulseSchema: () => ({ id: 'test' }),
    findWeeklyImpulseCommunityPost: ({ postId }) =>
      postId === 'post1' ? { id: 'post1', seed_comments: [], seed_like_count: 0 } : null,
    buildWeeklyImpulseReportItems: () => [...state.values()]
      .flatMap(entry => Object.values(entry.reportsByPostId).flat()),
  });
  vm.runInContext([
    block('function getWeeklyImpulseCommunityEntry(', '// Pool of 28 daily impulse topics'),
    block('async function verifyFirebaseIdToken(', 'function resolveVerifiedUserId('),
    block("app.post('/api/weekly-impulse/community/posts'", '// 1. Alle Anbieter abrufen'),
  ].join('\n'), context);

  async function call(method, route, {
    token = 'parent', body = {}, query = {}, params = {},
  } = {}) {
    let status = 200;
    let response;
    const req = {
      headers: { authorization: token ? `Bearer ${token}` : '' },
      body, query, params,
      // Simulate an earlier global middleware/static-token bypass.
      firebaseUid: 'untrusted-prefilled-uid',
    };
    const res = {
      status(code) { status = code; return res; },
      json(value) { response = value; return res; },
    };
    const chain = routes.get(`${method} ${route}`);
    assert.ok(chain, `Unregistered route: ${method} ${route}`);
    const run = async i => { if (chain[i]) await chain[i](req, res, () => run(i + 1)); };
    await run(0);
    return { status, body: response };
  }
  return { call, requests, experts, state, get verifications() { return verifications; } };
}

for (const [method, route] of [...protectedRoutes, ...moderatorRoutes]) {
  test(`${method} ${route} requires Firebase even with forged admin claims`, async () => {
    const app = fixture();
    for (const token of [null, 'invalid', 'expired', 'static-backend-token']) {
      const result = await app.call(method, route, {
        token,
        body: { moderatorEmail: 'mod@parentpeak.de', reviewerEmail: 'mod@parentpeak.de' },
        query: { moderatorEmail: 'mod@parentpeak.de', reviewerEmail: 'mod@parentpeak.de' },
      });
      assert.equal(result.status, 401);
    }
    assert.equal(app.state.size, 0);
    assert.equal(app.requests.length, 0);
    assert.equal(app.experts.size, 0);
  });

  test(`${method} ${route} fails closed when Firebase is absent or unavailable`, async () => {
    for (const options of [
      { firebaseAvailable: false },
      { verificationError: 'auth/certificate-fetch-failed' },
    ]) {
      const app = fixture(options);
      const result = await app.call(method, route, { token: 'moderator' });
      assert.equal(result.status, options.firebaseAvailable === false ? 401 : 503);
      assert.equal(app.state.size, 0);
    }
  });
}

for (const [method, route] of moderatorRoutes) {
  test(`${method} ${route} cannot elevate an ordinary or unverified account`, async () => {
    const app = fixture();
    for (const token of [
      'parent', 'unverified', 'missingEmail', 'missingVerification',
      'stringVerification', 'deceptiveDomain',
    ]) {
      const result = await app.call(method, route, {
        token,
        body: { moderatorEmail: 'mod@parentpeak.de', reviewerEmail: 'mod@parentpeak.de' },
        query: { moderatorEmail: 'mod@parentpeak.de', reviewerEmail: 'mod@parentpeak.de' },
      });
      assert.equal(result.status, 403);
    }
    assert.equal(app.state.size, 0);
    assert.equal(app.requests.length, 0);
  });
}

test('verified moderator domain and explicit email allowlist both work without claimed email', async () => {
  const app = fixture();
  for (const token of ['moderator', 'allowlisted']) {
    assert.equal((await app.call('GET', `${base}/reports`, { token })).status, 200);
    assert.equal((await app.call('GET', `${base}/verification-requests`, { token })).status, 200);
  }
  assert.equal(app.verifications, 4);
});

test('verification requests and status are bound to the token account, not supplied email', async () => {
  const app = fixture();
  const result = await app.call('POST', `${base}/verification-requests`, {
    body: {
      email: 'victim@example.org', displayName: 'Parent', roleTitle: 'Educator',
    },
  });
  assert.equal(result.status, 201);
  assert.equal(result.body.item.userId, 'parent');
  assert.equal(result.body.item.email, 'parent@example.org');
  const other = await app.call('GET', `${base}/verification-status`, {
    token: 'expert', query: { email: 'parent@example.org' },
  });
  assert.equal(other.body.latestRequest, null);
  const own = await app.call('GET', `${base}/verification-status`);
  assert.equal(own.body.pendingRequest, true);
  const mismatch = await app.call('GET', `${base}/verification-status`, {
    query: { userId: 'expert' },
  });
  assert.equal(mismatch.status, 403);
  const duplicate = await app.call('POST', `${base}/verification-requests`, {
    body: { email: 'changed@example.org', displayName: 'Parent', roleTitle: 'Educator' },
  });
  assert.equal(duplicate.status, 409);
  assert.equal(app.requests.length, 1);
});

test('verification request requires a verified email and rejects mismatched uid', async () => {
  const app = fixture();
  for (const token of ['unverified', 'missingEmail', 'missingVerification']) {
    const result = await app.call('POST', `${base}/verification-requests`, {
      token, body: { email: 'forged@example.org', displayName: 'P', roleTitle: 'E' },
    });
    assert.equal(result.status, 403);
  }
  assert.equal((await app.call('POST', `${base}/verification-requests`, {
    body: { userId: 'victim', displayName: 'P', roleTitle: 'E' },
  })).status, 403);
  assert.equal(app.requests.length, 0);
});

test('approval records the token moderator and badge cannot be borrowed from another account', async () => {
  const app = fixture();
  const created = await app.call('POST', `${base}/verification-requests`, {
    token: 'expert',
    body: { displayName: 'Expert', roleTitle: 'Educator' },
  });
  const approved = await app.call('POST', `${base}/verification-requests/:requestId/approve`, {
    token: 'moderator', params: { requestId: created.body.item.id },
    body: { reviewerName: 'Forged Person', reviewerEmail: 'forged@example.org' },
  });
  assert.equal(approved.status, 200);
  assert.equal(approved.body.item.reviewedBy, 'mod@parentpeak.de');
  const body = {
    impulseId, title: 'Advice', body: 'Helpful advice', authorName: 'Display name',
    role: 'Paedagog:in', authorUserId: 'expert', authorEmail: 'expert@example.org',
  };
  const borrowed = await app.call('POST', `${base}/posts`, { body });
  assert.equal(borrowed.status, 201);
  assert.equal(borrowed.body.item.verified_expert, false);
  const own = await app.call('POST', `${base}/posts`, { token: 'expert', body });
  assert.equal(own.body.item.verified_expert, true);
});

test('report, hide, resolve and restore work with trusted moderator attribution', async () => {
  const app = fixture();
  const result = await app.call('POST', `${base}/posts/:postId/report`, {
    params: { postId: 'post1' },
    body: { impulseId, reporterUserId: 'victim', reporterName: 'Parent', reason: 'Spam' },
  });
  assert.equal(result.status, 201);
  const report = result.body.item;
  assert.equal(report.reporterUserId, 'parent');
  const reports = await app.call('GET', `${base}/reports`, { token: 'moderator' });
  assert.equal(reports.body.items.length, 1);
  const hidden = await app.call('POST', `${base}/posts/:postId/moderation-visibility`, {
    token: 'moderator', params: { postId: 'post1' },
    body: { impulseId, hidden: true, moderatorName: 'Forged Person', reportId: report.id },
  });
  assert.equal(hidden.status, 200);
  assert.equal(hidden.body.hiddenBy, 'mod@parentpeak.de');
  assert.equal(report.lastAction, 'hidden');
  const resolved = await app.call('POST', `${base}/reports/:reportId/resolve`, {
    token: 'allowlisted', params: { reportId: report.id },
    body: { impulseId, moderatorName: 'Forged Person', moderatorNote: 'Done' },
  });
  assert.equal(resolved.status, 200);
  assert.equal(resolved.body.item.resolvedBy, 'reviewer@example.org');
  const restored = await app.call('POST', `${base}/posts/:postId/moderation-visibility`, {
    token: 'moderator', params: { postId: 'post1' }, body: { impulseId, hidden: false },
  });
  assert.equal(restored.status, 200);
  assert.equal(restored.body.hidden, false);
  assert.equal(app.state.get(impulseId).hiddenPostIds.post1, undefined);
});

test('like identity is token-bound and normal authenticated comments still work', async () => {
  const app = fixture();
  const spoofed = await app.call('POST', `${base}/posts/:postId/like`, {
    params: { postId: 'post1' }, body: { impulseId, userId: 'victim', isLiked: true },
  });
  assert.equal(spoofed.status, 403);
  const liked = await app.call('POST', `${base}/posts/:postId/like`, {
    params: { postId: 'post1' }, body: { impulseId, isLiked: true },
  });
  assert.equal(liked.status, 200);
  assert.deepEqual([...app.state.get(impulseId).likedByPostId.post1], ['parent']);
  const comment = await app.call('POST', `${base}/posts/:postId/comments`, {
    params: { postId: 'post1' },
    body: { impulseId, authorName: 'Parent', role: 'Elternteil', comment: 'Thanks' },
  });
  assert.equal(comment.status, 201);
});
