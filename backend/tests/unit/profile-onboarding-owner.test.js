const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
const helperStart = source.indexOf('async function authorizeProfileOwner(');
const helperEnd = source.indexOf('\n}', helperStart) + 2;
const start = source.indexOf('const onboardingProfiles = new Map()');
const end = source.indexOf('// ─── Freundschaft (UID-zu-UID', start);
assert.ok(helperStart >= 0 && start >= 0 && end > start);

function fixture({ fails = false, strict = false } = {}) {
  const routes = new Map();
  const calls = [];
  const context = {
    app: {
      get: (url, fn) => routes.set(`GET ${url}`, fn),
      post: (url, fn) => routes.set(`POST ${url}`, fn),
    },
    verifyFirebaseIdToken: async req => ({
      verified: ['a', 'b'].includes(req.tokenUid), uid: req.tokenUid,
    }),
    ensureSocialSchemaReady: async () => { calls.push('schema'); },
    respondWithStrictPersistenceError: (res, route, error) => {
      if (!strict) return false;
      res.status(503).json({ error: 'Persistence unavailable' });
      return true;
    },
    prisma: {
      $queryRawUnsafe: async (sql, uid) => {
        calls.push({ sql, uid });
        if (fails) throw new Error('database unavailable');
        return sql.includes('"OnboardingProfile"')
          ? [{ completed: true, familyName: 'Own family', parentRole: 'baby', priorities: 'tips' }]
          : [{ displayName: 'Public name', avatarUrl: 'https://images.example/avatar',
              searchable: true, isPrivate: false }];
      },
      $executeRawUnsafe: async (sql, ...args) => {
        calls.push({ sql, args });
        if (fails) throw new Error('database unavailable');
      },
    },
  };
  vm.createContext(context);
  vm.runInContext(source.slice(helperStart, helperEnd), context);
  vm.runInContext(source.slice(start, end), context);
  return {
    calls,
    async request(route, tokenUid, fields = {}) {
      let status = 200, body;
      const req = { tokenUid, params: { userId: fields.userId ?? 'a' },
        body: { userId: 'a', ...fields },
        headers: { authorization: 'Bearer test-backend-token' } };
      const res = {
        status(code) { status = code; return res; },
        json(value) { body = value; return res; },
      };
      await routes.get(route)(req, res);
      return { status, body, firebaseUid: req.firebaseUid };
    },
  };
}

for (const route of ['GET /api/onboarding/:userId', 'POST /api/onboarding', 'POST /api/profile']) {
  for (const [uid, status] of [[undefined, 401], ['invalid', 401], ['b', 403]]) {
    test(`${route} rejects ${uid ?? 'missing'} token before persistence or fallback`, async () => {
      const app = fixture({ fails: true });
      const result = await app.request(route, uid);
      assert.equal(result.status, status);
      assert.equal(result.body.ok, undefined);
      assert.deepEqual(app.calls, []);
    });
  }
  test(`${route} accepts the matching verified owner`, async () => {
    const app = fixture();
    const result = await app.request(route, 'a', {
      completed: true, familyName: 'Family', parentRole: 'baby', priorities: ['tips'],
    });
    assert.equal(result.status, 200);
    assert.equal(result.firebaseUid, 'a');
    assert.ok(app.calls.length > 0);
  });
}

for (const fields of [
  { displayName: 'Name' }, { username: 'new-name' }, { searchable: true },
  { isPrivate: false }, { avatarUrl: '' }, { avatarUrl: 'https://images.example/new' },
]) {
  test(`profile ${Object.keys(fields)[0]} requires owner with or without avatar`, async () => {
    for (const [uid, status] of [[undefined, 401], ['invalid', 401], ['b', 403], ['a', 200]]) {
      const app = fixture();
      assert.equal((await app.request('POST /api/profile', uid, fields)).status, status);
      if (status !== 200) assert.deepEqual(app.calls, []);
    }
  });
}

test('name/avatar reads for another account remain available', async () => {
  const app = fixture();
  const result = await app.request('GET /api/profile/:userId', undefined, { userId: 'b' });
  assert.equal(result.status, 200);
  assert.equal(result.body.displayName, 'Public name');
  assert.equal(result.body.avatarUrl, 'https://images.example/avatar');
});

test('profile partial updates retain fields absent from the request', async () => {
  const app = fixture();
  await app.request('POST /api/profile', 'a', { displayName: 'New name' });
  const sql = app.calls[1].sql;
  for (const field of ['avatarUrl', 'username', 'searchable', 'isPrivate']) {
    assert.ok(sql.includes(`"${field}" = "UserProfile"."${field}"`), field);
  }
});

test('fallback is still owner-isolated and strict failure is not success', async () => {
  const app = fixture({ fails: true });
  assert.equal((await app.request('POST /api/onboarding', 'a', {
    completed: true, familyName: 'A',
  })).body.ok, true);
  assert.equal((await app.request('GET /api/onboarding/:userId', 'a')).body.familyName, 'A');
  assert.equal((await app.request('GET /api/onboarding/:userId', 'b', { userId: 'b' })).body.completed, false);
  assert.equal((await fixture({ fails: true, strict: true })
    .request('POST /api/onboarding', 'a')).status, 503);
});
