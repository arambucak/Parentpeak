const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
function extract(name) {
  const start = source.indexOf(`async function ${name}(`);
  assert.ok(start >= 0);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

function fixture({ result = { matches: [] }, fails = false } = {}) {
  const calls = [];
  const context = {
    verifyFirebaseIdToken: async req => ({
      verified: req.tokenUid != null, uid: req.tokenUid,
    }),
    discoverParentMatchingProfiles: async args => {
      calls.push(JSON.parse(JSON.stringify(args)));
      if (fails) throw new Error('database unavailable');
      return result;
    },
    console: { error: () => {} },
  };
  vm.createContext(context);
  vm.runInContext(extract('respondWithParentMatchingDiscovery'), context);
  return {
    calls,
    async request(tokenUid, userId = 'owner', params = {}) {
      let status = 200;
      let body;
      const res = {
        status(code) { status = code; return res; },
        json(value) { body = value; return res; },
      };
      await context.respondWithParentMatchingDiscovery({
        tokenUid, query: { userId, ...params },
      }, res);
      return { status, body };
    },
  };
}

test('discovery requires a verified token and matching account', async () => {
  for (const [uid, expected] of [[undefined, 401], ['other', 403]]) {
    const app = fixture();
    assert.equal((await app.request(uid)).status, expected);
    assert.deepEqual(app.calls, []);
  }
});

test('successful empty result stays a valid empty result with query values', async () => {
  const app = fixture();
  const response = await app.request('owner', 'owner', { limit: '20', maxDistanceKm: '50' });
  assert.equal(response.status, 200);
  assert.deepEqual(response.body.matches, []);
  assert.deepEqual(app.calls, [{ userId: 'owner', limit: '20', maxDistanceKm: '50' }]);
});

test('missing own profile and server failures are not empty discovery results', async () => {
  const missing = await fixture({ result: null }).request('owner');
  assert.equal(missing.status, 404);
  assert.equal(missing.body.matches, undefined);
  const failed = await fixture({ fails: true }).request('owner');
  assert.equal(failed.status, 503);
  assert.equal(failed.body.matches, undefined);
});

test('both discovery URLs use the same authenticated handler', () => {
  assert.ok(source.includes("app.get('/parent-matching/discover', respondWithParentMatchingDiscovery);"));
  assert.ok(source.includes("app.get('/api/parent-matching/find', respondWithParentMatchingDiscovery);"));
});

test('discovery loads persistent block and suspension filters before scoring', async () => {
  let scored;
  const candidates = [{ ownerUserId: 'blocked' }, { ownerUserId: 'allowed' }];
  const context = {
    getMyParentMatchingProfile: async () => ({ id: 'own', ownerUserId: 'owner' }),
    prisma: {
      parentMatchingProfile: { findMany: async () => candidates },
      $queryRawUnsafe: async sql => sql.includes('SafetyBlock')
        ? [{ blockedUserId: 'blocked' }] : [{ userId: 'suspended' }],
    },
    ensureSocialSchemaReady: async () => {},
    scoreParentMatchingCandidates: args => { scored = args; return { matches: [] }; },
  };
  vm.createContext(context);
  vm.runInContext(extract('discoverParentMatchingProfiles'), context);
  await context.discoverParentMatchingProfiles({ userId: 'owner', limit: '10', maxDistanceKm: '25' });
  assert.equal(scored.blockedIds.has('blocked'), true);
  assert.equal(scored.suspendedIds.has('suspended'), true);
  assert.equal(scored.candidates, candidates);
});

test('failed safety-filter query stops discovery instead of using incomplete filters', async () => {
  const context = {
    getMyParentMatchingProfile: async () => ({ id: 'own' }),
    prisma: {
      parentMatchingProfile: { findMany: async () => [] },
      $queryRawUnsafe: async () => { throw new Error('safety unavailable'); },
    },
    ensureSocialSchemaReady: async () => {},
    scoreParentMatchingCandidates: () => { throw new Error('must not score'); },
  };
  vm.createContext(context);
  vm.runInContext(extract('discoverParentMatchingProfiles'), context);
  await assert.rejects(context.discoverParentMatchingProfiles({ userId: 'owner' }),
    /safety unavailable/);
});
