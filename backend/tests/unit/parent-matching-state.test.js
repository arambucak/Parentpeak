const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
const start = source.indexOf("app.get('/parent-matching/my-profile',");
assert.ok(start >= 0);
const route = source.slice(start, source.indexOf('\n});', start) + 4);

function fixture({ profile = { id: 'p', ownerUserId: 'owner' }, fails = false } = {}) {
  let handler;
  const calls = [];
  vm.runInNewContext(route, {
    app: { get: (_path, callback) => { handler = callback; } },
    verifyFirebaseIdToken: async req => ({
      verified: req.tokenUid != null, uid: req.tokenUid,
    }),
    getMyParentMatchingProfile: async uid => {
      calls.push(uid);
      if (fails) throw new Error('database unavailable');
      return profile;
    },
    mapParentMatchingProfileForClient: p => p,
    console: { error: () => {} },
  });
  return {
    calls,
    async request(tokenUid, userId = 'owner') {
      let status = 200;
      let body;
      const res = {
        status(code) { status = code; return res; },
        json(value) { body = value; return res; },
      };
      await handler({ tokenUid, query: { userId } }, res);
      return { status, body };
    },
  };
}

test('GET verifies the Firebase token and reads only the authenticated owner', async () => {
  const app = fixture();
  const result = await app.request('owner');
  assert.equal(result.status, 200);
  assert.equal(result.body.item.ownerUserId, 'owner');
  assert.deepEqual(app.calls, ['owner']);
});

test('unauthenticated and mismatched GET requests never query profile data', async () => {
  for (const [uid, expected] of [[undefined, 401], ['other', 403]]) {
    const app = fixture();
    assert.equal((await app.request(uid)).status, expected);
    assert.deepEqual(app.calls, []);
  }
});

test('a missing active profile is distinct from failed verification', async () => {
  assert.equal((await fixture({ profile: null }).request('owner')).status, 404);
  const result = await fixture({ fails: true }).request('owner');
  assert.equal(result.status, 503);
  assert.equal(result.body.item, undefined);
});

test('missing account ID is rejected', async () => {
  const app = fixture();
  assert.equal((await app.request('owner', '')).status, 400);
  assert.deepEqual(app.calls, []);
});

test('publication cannot write a profile for a different authenticated account', async () => {
  const postStart = source.indexOf("app.post('/parent-matching/my-profile',");
  const postRoute = source.slice(postStart, source.indexOf('\n});', postStart) + 4);
  let handler;
  vm.runInNewContext(postRoute, {
    app: { post: (_path, callback) => { handler = callback; } },
    verifyFirebaseIdToken: async () => ({ verified: false, uid: null }),
  });
  for (const [firebaseUid, expected] of [[undefined, 401], ['other', 403]]) {
    let status = 200;
    const res = {
      status(code) { status = code; return res; },
      json() { return res; },
    };
    await handler({ firebaseUid, body: { userId: 'owner' } }, res);
    assert.equal(status, expected);
  }
});
