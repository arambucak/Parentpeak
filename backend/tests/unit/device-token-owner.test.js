const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
const helperStart = source.indexOf('async function authorizeProfileOwner(');
const helperEnd = source.indexOf('\n}', helperStart) + 2;
const start = source.indexOf('const deviceTokens = new Map()');
const end = source.indexOf('// Internal helper to send an FCM push', start);
assert.ok(helperStart >= 0 && start >= 0 && end > start);

function fixture() {
  const routes = new Map();
  let persistenceCalls = 0;
  const context = {
    app: {
      post: (url, fn) => routes.set(`POST ${url}`, fn),
      delete: (url, fn) => routes.set(`DELETE ${url}`, fn),
    },
    verifyFirebaseIdToken: async req => ({
      verified: ['a', 'b'].includes(req.tokenUid), uid: req.tokenUid,
    }),
    ensureBackendUser: async () => { persistenceCalls++; },
    console,
  };
  vm.createContext(context);
  vm.runInContext(source.slice(helperStart, helperEnd), context);
  vm.runInContext(source.slice(start, end), context);
  return {
    get persistenceCalls() { return persistenceCalls; },
    async request(method, tokenUid, userId = 'a', token = 'device-token') {
      let status = 200, body;
      const res = {
        status(code) { status = code; return res; },
        json(value) { body = value; return res; },
      };
      await routes.get(`${method} /devices/register-token`)(
        { tokenUid, body: { userId, token } }, res,
      );
      return { status, body };
    },
  };
}

for (const method of ['POST', 'DELETE']) {
  for (const [uid, status] of [[undefined, 401], ['invalid', 401], ['b', 403]]) {
    test(`${method} device token rejects ${uid ?? 'missing'} owner`, async () => {
      const app = fixture();
      const result = await app.request(method, uid);
      assert.equal(result.status, status);
      assert.equal(app.persistenceCalls, 0);
    });
  }
  test(`${method} device token accepts matching owner`, async () => {
    const app = fixture();
    assert.equal((await app.request('POST', 'a')).status, 200);
    assert.equal((await app.request(method, 'a')).status, 200);
  });
}

test('token cannot be rebound to another owner until deregistered', async () => {
  const app = fixture();
  assert.equal((await app.request('POST', 'a')).status, 200);
  assert.equal((await app.request('POST', 'b', 'b')).status, 409);
  assert.equal((await app.request('DELETE', 'b', 'a')).status, 403);
  assert.equal((await app.request('POST', 'b', 'b')).status, 409);
  assert.equal((await app.request('DELETE', 'a')).status, 200);
  assert.equal((await app.request('POST', 'b', 'b')).status, 200);
});

test('own repeated registration is idempotent and foreign DELETE leaves it intact', async () => {
  const app = fixture();
  await app.request('POST', 'a');
  assert.equal((await app.request('POST', 'a')).body.tokenCount, 1);
  assert.equal((await app.request('DELETE', 'b', 'a')).status, 403);
  assert.equal((await app.request('POST', 'b', 'b')).status, 409);
});
