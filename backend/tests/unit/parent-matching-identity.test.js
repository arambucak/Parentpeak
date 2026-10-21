const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const crypto = require('node:crypto');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
function extract(name, async = false) {
  const start = source.indexOf(`${async ? 'async ' : ''}function ${name}(`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}
function route(method, url) {
  const start = source.indexOf(`app.${method}('${url}',`);
  assert.ok(start >= 0, url);
  const line = source.slice(start, source.indexOf('\n', start));
  return line.endsWith(');') ? line : source.slice(start, source.indexOf('\n});', start) + 4);
}
const urls = [
  ['get', '/parent-matching/profiles'],
  ['get', '/parent-matching/connections'],
  ['post', '/parent-matching/actions'],
  ['post', '/api/parent-matching/profiles'],
  ['post', '/api/parent-matching/record-action'],
];

function fixture({ persistenceFails = false, missingOwnProfile = false } = {}) {
  const routes = new Map();
  const writes = [];
  const reads = [];
  const profiles = [
    { id: 'p-owner', ownerUserId: 'owner', isActive: true },
    { id: 'p-other', ownerUserId: 'other', isActive: true },
  ];
  const actions = [];
  class FamilyContextError extends Error {
    constructor(status, code, message) { super(message); this.status = status; this.code = code; }
  }
  const context = {
    crypto, FamilyContextError, console: { error() {} },
    app: Object.fromEntries(['get', 'post'].map(method => [method,
      (url, ...handlers) => routes.set(`${method} ${url}`, handlers)])),
    verifyFirebaseIdToken: async req => ({
      uid: req.tokenUid, verified: Boolean(req.tokenUid),
    }),
    resolveOwnFamily: async uid => ({ id: context.ownFamilyId(uid) }),
    ensureParentMatchingSchemaReady: async () => {},
    getMyParentMatchingProfile: async uid => {
      if (persistenceFails) throw new Error('database unavailable');
      return missingOwnProfile ? null : profiles.find(p => p.ownerUserId === uid);
    },
    getMyParentMatchingProfileInMemory: uid =>
      missingOwnProfile ? null : profiles.find(p => p.ownerUserId === uid),
    discoverParentMatchingProfiles: async args => {
      reads.push(args);
      if (persistenceFails) throw new Error('discovery unavailable');
      return missingOwnProfile ? null : { matches: [{ profile: profiles[1] }] };
    },
    prisma: {
      parentMatchingProfile: {
        findMany: async ({ where }) => profiles.filter(p =>
          typeof where.ownerUserId === 'string' ? p.ownerUserId === where.ownerUserId :
            where.id?.in.includes(p.id)),
        findUnique: async ({ where }) => profiles.find(p => p.id === where.id),
        upsert: async options => { writes.push(options); return options.create; },
      },
      parentMatchingAction: {
        create: async ({ data }) => {
          writes.push(data);
          actions.unshift({ id: 'action', ...data });
          return data;
        },
        findMany: async ({ where }) => {
          reads.push(where);
          return actions.filter(a =>
            (!where.familyId || a.familyId === where.familyId) &&
            (!where.actorUserId || a.actorUserId === where.actorUserId) &&
            (!where.OR || where.OR.some(c =>
              a.actorUserId === c.actorUserId && a.familyId === c.familyId)) &&
            (!where.profileId || where.profileId.in.includes(a.profileId)));
        },
      },
    },
    isUserSuspended: async () => false,
    mapParentMatchingProfileForClient: profile => ({
      ...profile, latitude: 52.5, longitude: 13.4, approximateLocation: true,
    }),
    respondWithStrictPersistenceError: () => false,
    parentMatchingAllowedActions: new Set(['like', 'report', 'block', 'contact', 'pass', 'favorite']),
    parentProfiles: profiles, parentMatchingActions: actions,
    generateId: () => 'fallback-action',
  };
  vm.createContext(context);
  for (const [name, async] of [
    ['ownFamilyId', false], ['requireVerifiedUser', true], ['requireOwnFamily', true],
    ['respondFamilyPersistenceError', false], ['latestActionByProfile', false],
    ['getMutualConnectionProfileIds', true], ['getMutualConnectionProfileIdsInMemory', false],
    ['parseOptionalParentAge', false], ['parseOptionalParentCoordinate', false],
    ['recordParentMatchingAction', true],
  ]) vm.runInContext(extract(name, async), context);
  for (const [method, url] of urls) vm.runInContext(route(method, url), context);
  return {
    writes, reads, actions, family: uid => context.ownFamilyId(uid),
    async request(method, url, { uid = 'owner', body = {}, query = {}, firebaseUid } = {}) {
      let status = 200;
      let payload;
      const res = {
        status(value) { status = value; return res; },
        json(value) { payload = value; return res; },
      };
      const req = { tokenUid: uid, firebaseUid, body, query };
      const handlers = routes.get(`${method} ${url}`);
      const run = i => i < handlers.length ? handlers[i](req, res, () => run(i + 1)) : undefined;
      await run(0);
      return { status, payload };
    },
    mutual: uid => context.getMutualConnectionProfileIds(context.ownFamilyId(uid), uid),
    mutualMemory: uid => context.getMutualConnectionProfileIdsInMemory(context.ownFamilyId(uid), uid),
  };
}

for (const [method, url] of urls) {
  test(`${url}: token required even with a prefilled request identity`, async () => {
    const f = fixture();
    const result = await f.request(method, url, {
      uid: null, firebaseUid: 'owner', body: { userId: 'owner' }, query: { userId: 'owner' },
    });
    assert.equal(result.status, 401);
    assert.equal(f.writes.length, 0);
    assert.equal(f.reads.length, 0);
  });
  test(`${url}: body and query identity spoofing are rejected`, async () => {
    for (const claims of [{ body: { userId: 'other' } }, { query: { userId: 'other' } }]) {
      const f = fixture();
      assert.equal((await f.request(method, url, claims)).status, 403);
      assert.equal(f.writes.length, 0);
      assert.equal(f.reads.length, 0);
    }
  });
}

for (const [method, url] of urls.filter(([, url]) =>
  /connections|actions|record-action/.test(url))) {
  test(`${url}: foreign family is forbidden before access`, async () => {
    for (const claims of [{ body: { familyId: 'foreign' } }, { query: { familyId: 'foreign' } }]) {
      const f = fixture();
      assert.equal((await f.request(method, url, claims)).status, 403);
      assert.equal(f.writes.length, 0);
      assert.equal(f.reads.length, 0);
    }
  });
}

test('profiles reuse authenticated discovery and fail closed on unavailable safety filters', async () => {
  const f = fixture();
  const response = await f.request('get', '/parent-matching/profiles');
  assert.equal(response.status, 200);
  assert.equal(response.payload.profiles[0].ownerUserId, 'other');
  assert.equal(f.reads[0].userId, 'owner');
  assert.equal((await fixture({ persistenceFails: true })
    .request('get', '/parent-matching/profiles')).status, 503);
});

test('legacy profile saves only token owner using the canonical self key and coarse location', async () => {
  const f = fixture();
  const response = await f.request('post', '/api/parent-matching/profiles', {
    body: { name: 'Owner', city: 'Berlin', familyForm: 'Kernfamilie', latitude: 52.523, longitude: 13.412 },
  });
  assert.equal(response.status, 200);
  assert.equal(f.writes[0].where.externalId, 'self-owner');
  assert.equal(f.writes[0].create.ownerUserId, 'owner');
  assert.equal(response.payload.profile.latitude, 52.5);
});

for (const url of ['/parent-matching/actions', '/api/parent-matching/record-action']) {
  test(`${url}: action uses verified actor, resolved family, server timestamp and target owner`, async () => {
    const f = fixture();
    const response = await f.request('post', url, {
      body: { matchedProfileId: 'p-other', action: 'like', createdAt: '2099-01-01' },
    });
    assert.equal(response.status, 201);
    assert.equal(f.writes[0].actorUserId, 'owner');
    assert.equal(f.writes[0].familyId, f.family('owner'));
    assert.ok(f.writes[0].createdAt.getTime() < Date.parse('2099-01-01'));
    assert.equal(response.payload.connected, false);
    assert.equal(response.payload.action, response.payload.item);
    assert.equal((await f.request('post', url, {
      body: { matchedProfileId: 'p-owner', action: 'like' },
    })).status, 403);
  });
}

test('mutual consent requires the other verified owner in their own family, in both storage modes', async () => {
  const f = fixture();
  f.actions.push(
    { actorUserId: 'owner', userId: 'owner', familyId: f.family('owner'), profileId: 'p-other', action: 'like' },
    { actorUserId: 'other', userId: 'other', familyId: f.family('owner'), profileId: 'p-owner', action: 'like' },
  );
  assert.equal((await f.mutual('owner')).length, 0);
  assert.equal(f.mutualMemory('owner').length, 0);
  f.actions[1].familyId = f.family('other');
  assert.equal((await f.mutual('owner'))[0], 'p-other');
  assert.equal(f.mutualMemory('owner')[0], 'p-other');
  const response = await f.request('get', '/parent-matching/connections');
  assert.equal(response.status, 200);
  assert.equal(response.payload.profileIds[0], 'p-other');
});

test('legacy and canonical action endpoints produce a genuine mutual match across owner families', async () => {
  const f = fixture();
  await f.request('post', '/parent-matching/actions', {
    body: { profileId: 'p-other', action: 'like' },
  });
  const response = await f.request('post', '/api/parent-matching/record-action', {
    uid: 'other', body: { matchedProfileId: 'p-owner', action: 'like' },
  });
  assert.equal(response.status, 201);
  assert.equal(response.payload.connected, true);
  assert.equal(response.payload.matchState, 'matched');
});

test('fallback cannot invent an own profile and still derives its actor from the token', async () => {
  const missing = fixture({ persistenceFails: true, missingOwnProfile: true });
  assert.equal((await missing.request('post', '/parent-matching/actions', {
    body: { profileId: 'p-other', action: 'like' },
  })).status, 409);
  const f = fixture({ persistenceFails: true });
  const response = await f.request('post', '/parent-matching/actions', {
    body: { profileId: 'p-other', action: 'like' },
  });
  assert.equal(response.status, 201);
  assert.equal(response.payload.item.userId, 'owner');
  assert.equal(response.payload.item.familyId, f.family('owner'));
});
