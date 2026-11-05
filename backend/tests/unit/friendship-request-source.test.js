const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
function slice(start, end) {
  const a = source.indexOf(start), b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `Missing source block: ${start}`);
  return source.slice(a, b);
}

function fixture({ isPrivate = true, profileExists = true, blocked = false } = {}) {
  const routes = new Map(), writes = [];
  const context = {
    featureQuotas: { ...require('../../feature_quota_store'), limitsEnabled: () => false },
    requireContactQuota: async (_req, _res, _uid, operation) => {
      await operation(context.prisma);
      return true;
    },
    app: Object.fromEntries(['get', 'post', 'delete'].map(method => [
      method, (route, ...handlers) => routes.set(`${method.toUpperCase()} ${route}`, handlers),
    ])),
    firebaseAdmin: { auth: () => ({ verifyIdToken: async token => {
      if (!['a', 'b'].includes(token)) throw new Error('Invalid token');
      return { uid: token };
    } }) },
    console: { error: () => {} },
    process: { env: { FIREBASE_REQUIRE_AUTH: '1' } },
    WRITE_METHODS: new Set(['POST', 'PUT', 'PATCH', 'DELETE']),
    backendApiToken: 'shared',
    requireAuthForWrites: true,
    isWriteRequest: req => ['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method),
    safetyBlocks: new Map(), userProfiles: new Map(),
    isUserSuspended: async () => false,
    respondSuspended: res => res.status(403).json({ code: 'account_suspended' }),
    generateId: prefix => `${prefix}-new`,
    sendPushToUser: async () => {},
    resolveDisplayName: async () => 'Name',
    ensureSocialSchemaReady: async () => {},
    prisma: {
      $queryRawUnsafe: async sql => {
        if (sql.includes('"SafetyBlock"')) return blocked ? [{}] : [];
        if (sql.includes('FROM "UserProfile"')) return profileExists ? [{ isPrivate }] : [];
        throw new Error(`Unhandled fixture query: ${sql}`);
      },
      $executeRawUnsafe: async (sql, ...params) => {
        writes.push([sql, ...params]);
        return 1;
      },
    },
  };
  vm.createContext(context);
  vm.runInContext(slice('async function verifyFirebaseIdToken(', 'function resolveVerifiedUserId('), context);
  vm.runInContext(slice('const firebaseRequireAuth =', '\n// Middleware'), context);
  vm.runInContext(slice('const friendships = new Map()', '// ─── Phase 3a:'), context);

  async function request(body = {}) {
    let status = 200, response;
    const req = {
      method: 'POST', path: '/api/friendships/request',
      headers: { authorization: 'Bearer a' },
      body: { toUid: 'b', ...body }, query: {}, params: {},
    };
    const res = { status(code) { status = code; return res; },
      json(value) { response = value; return res; } };
    const handlers = routes.get('POST /api/friendships/request');
    assert.ok(handlers);
    async function run(index) { await handlers[index](req, res, () => run(index + 1)); }
    await run(0);
    return { status, body: response };
  }
  const insertedStatus = () => {
    const insert = writes.find(([sql]) => sql.includes('INSERT INTO "Friendship"'));
    return insert && insert[3];
  };
  return { request, writes, insertedStatus };
}

test('discovery request to a public account stays pending', async () => {
  const f = fixture({ isPrivate: false });
  const res = await f.request({ source: 'discovery' });
  assert.equal(res.status, 200);
  assert.equal(res.body.status, 'pending');
  assert.equal(f.insertedStatus(), 'pending');
});

test('discovery request to a private account stays pending', async () => {
  const f = fixture({ isPrivate: true });
  const res = await f.request({ source: 'discovery' });
  assert.equal(res.body.status, 'pending');
  assert.equal(f.insertedStatus(), 'pending');
});

test('missing source keeps legacy behavior (public -> accepted, private -> pending)', async () => {
  const pub = fixture({ isPrivate: false });
  const pubRes = await pub.request();
  assert.equal(pubRes.status, 200);
  assert.equal(pubRes.body.status, 'accepted');
  assert.equal(pub.insertedStatus(), 'accepted');

  const priv = fixture({ isPrivate: true });
  const privRes = await priv.request();
  assert.equal(privRes.body.status, 'pending');
  assert.equal(priv.insertedStatus(), 'pending');

  const missing = fixture({ profileExists: false });
  assert.equal((await missing.request()).body.status, 'pending');
});

test('empty or whitespace source keeps legacy behavior', async () => {
  for (const value of ['', '   ', null]) {
    const f = fixture({ isPrivate: false });
    const res = await f.request({ source: value });
    assert.equal(res.body.status, 'accepted', JSON.stringify(value));
  }
});

test('unknown non-empty source falls back to pending', async () => {
  for (const value of ['invite', 'something-else', ' Discovery ']) {
    const f = fixture({ isPrivate: false });
    const res = await f.request({ source: value });
    assert.equal(res.status, 200);
    assert.equal(res.body.status, 'pending', value);
    assert.equal(f.insertedStatus(), 'pending');
  }
});

test('blocked users are still rejected with 403 regardless of source', async () => {
  for (const body of [{}, { source: 'discovery' }, { source: 'other' }]) {
    const f = fixture({ isPrivate: false, blocked: true });
    const res = await f.request(body);
    assert.equal(res.status, 403);
    assert.equal(res.body.code, 'blocked');
    assert.deepEqual(f.writes, []);
  }
});
