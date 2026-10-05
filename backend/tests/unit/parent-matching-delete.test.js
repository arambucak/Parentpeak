const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
const start = source.indexOf("app.delete('/parent-matching/my-profile',");
assert.ok(start >= 0);
const route = source.slice(start, source.indexOf('\n});', start) + 4);

function fixture({ fails = false, count = 2 } = {}) {
  let handler;
  const calls = [];
  const parentProfiles = [
    { ownerUserId: 'owner' }, { ownerUserId: 'other' }, { ownerUserId: 'owner' },
  ];
  vm.runInNewContext(route, {
    app: { delete: (_path, callback) => { handler = callback; } },
    ensureParentMatchingSchemaReady: async () => {},
    prisma: { parentMatchingProfile: {
      deleteMany: async options => {
        calls.push(JSON.parse(JSON.stringify(options)));
        if (fails) throw new Error('database unavailable');
        return { count };
      },
    } },
    parentProfiles,
    console: { error: () => {} },
  });
  return {
    calls,
    parentProfiles,
    async request(firebaseUid, userId = 'owner') {
      let status = 200;
      let body;
      const res = {
        status(code) { status = code; return res; },
        json(value) { body = value; return res; },
      };
      await handler({ firebaseUid, query: { userId } }, res);
      return { status, body };
    },
  };
}

test('deletion requires an authenticated owner', async () => {
  for (const [uid, expected] of [[undefined, 401], ['stranger', 403]]) {
    const app = fixture();
    assert.equal((await app.request(uid)).status, expected);
    assert.deepEqual(app.calls, []);
    assert.equal(app.parentProfiles.length, 3);
  }
});

test('deletes all matching profiles owned by the user, not other profiles', async () => {
  const app = fixture();
  const result = await app.request('owner');
  assert.equal(result.status, 200);
  assert.equal(result.body.success, true);
  assert.deepEqual(app.calls, [{ where: { ownerUserId: 'owner' } }]);
  assert.deepEqual(app.parentProfiles, [{ ownerUserId: 'other' }]);
});

test('repeated deletion is acknowledged when the profile is already absent', async () => {
  const app = fixture({ count: 0 });
  const result = await app.request('owner');
  assert.equal(result.status, 200);
  assert.equal(result.body.success, true);
});

test('persistence failure is not disguised as successful local-only deletion', async () => {
  const app = fixture({ fails: true });
  const result = await app.request('owner');
  assert.equal(result.status, 503);
  assert.notEqual(result.body.success, true);
  assert.equal(app.parentProfiles.length, 3);
});
