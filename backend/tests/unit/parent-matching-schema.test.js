const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const {
  assertWriteMatchesSchema, withSchemaGuard, schemaOrigin, parseSchemaModels,
} = require('./helpers/prisma-schema-guard');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
function extract(name, async = false) {
  const start = source.indexOf(`${async ? 'async ' : ''}function ${name}(`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}
function route(method, url) {
  const start = source.indexOf(`app.${method}('${url}',`);
  assert.ok(start >= 0, url);
  return source.slice(start, source.indexOf('\n});', start) + 4);
}

// Real write paths from server.js; only the Prisma delegate is mocked, and every
// write is checked against the generated schema like the real client would do.
function fixture({ existingProfile = null } = {}) {
  const routes = new Map();
  const writes = [];
  const errors = [];
  const prismaMock = {
    parentMatchingProfile: {
      findFirst: async () => existingProfile,
      upsert: async args => {
        writes.push(['upsert', args]);
        return { id: 'p-1', ...args.create };
      },
      updateMany: async args => {
        writes.push(['updateMany', args]);
        return { count: 1 };
      },
    },
  };
  const context = {
    crypto,
    console: { error: (...args) => errors.push(args.join(' ')) },
    process: { env: {} },
    app: Object.fromEntries(['get', 'post'].map(method => [method,
      (url, handler) => routes.set(`${method} ${url}`, handler)])),
    prisma: withSchemaGuard(prismaMock),
    disableInMemoryFallbacks: true,
    ensureParentMatchingSchemaReady: async () => {},
    verifyFirebaseIdToken: async () => ({ verified: false, uid: null }),
    mapParentMatchingProfileForClient: profile => profile,
    parentMatchingOtpStore: new Map(),
    otpMaxAttempts: 5,
    upsertMyParentMatchingProfileInMemory: () => { throw new Error('in-memory fallback must stay off'); },
    ensureParentMatchingProfileForUserInMemory: () => { throw new Error('in-memory fallback must stay off'); },
    getMyParentMatchingProfileInMemory: () => { throw new Error('in-memory fallback must stay off'); },
  };
  vm.createContext(context);
  vm.runInContext('const runtimeOtpHashSecret = "test-secret";', context);
  for (const [name, async] of [
    ['respondWithStrictPersistenceError', false],
    ['parseOptionalParentAge', false], ['parseOptionalParentCoordinate', false],
    ['inferCityForUser', false], ['inferCoordinatesForCity', false],
    ['ensureParentMatchingProfileForUser', true], ['hashOtpForUser', false],
  ]) vm.runInContext(extract(name, async), context);
  vm.runInContext(route('post', '/parent-matching/my-profile'), context);
  vm.runInContext(route('post', '/parent-matching/verification/confirm-otp'), context);
  return {
    context, writes, errors,
    async post(url, req) {
      let status = 200;
      let body;
      const res = {
        status(code) { status = code; return res; },
        json(value) { body = value; return res; },
      };
      await routes.get(`post ${url}`)(req, res);
      return { status, body };
    },
  };
}

test('schema guard rejects unknown fields and null in required fields, accepts valid writes', t => {
  t.diagnostic(`schema source: ${schemaOrigin}`);
  const profile = parseSchemaModels(path.join(__dirname, '../../prisma/schema.prisma')).get('ParentMatchingProfile');
  assert.deepEqual(profile.get('familyForm'), { type: 'String', isRequired: true });
  assert.deepEqual(profile.get('bio'), { type: 'String', isRequired: false });
  assert.deepEqual(profile.get('languages'), { type: 'String', isRequired: false });
  assert.deepEqual(profile.get('actions'), { type: 'ParentMatchingAction', isRequired: false });
  assert.throws(
    () => assertWriteMatchesSchema('parentMatchingProfile', 'create', { data: { name: 'A', notAField: true } }),
    /Unknown argument `notAField`/,
  );
  assert.throws(
    () => assertWriteMatchesSchema('parentMatchingProfile', 'upsert', {
      create: { name: 'A', city: 'B', familyForm: 'kernfamilie' }, update: { familyForm: null },
    }),
    /`familyForm` must not be null/,
  );
  assert.throws(
    () => assertWriteMatchesSchema('parentMatchingProfile', 'createMany', { data: [{ name: 'A' }, { bogus: 1 }] }),
    /data\[1\]: Unknown argument `bogus`/,
  );
  assert.doesNotThrow(() => assertWriteMatchesSchema('parentMatchingProfile', 'updateMany', {
    where: { ownerUserId: 'u' }, data: { bio: null, age: null, isActive: false },
  }));
});

test('POST /parent-matching/my-profile create branch matches the Prisma schema', async () => {
  const f = fixture();
  const result = await f.post('/parent-matching/my-profile', {
    firebaseUid: 'owner',
    body: {
      userId: 'owner', name: 'Mara', city: 'Berlin', familyForm: 'kernfamilie',
      childAges: ['4'], languages: ['de', 'ar'], latitude: null, longitude: null,
    },
  });
  assert.deepEqual(f.errors, []);
  assert.equal(result.status, 201, JSON.stringify(result.body));
  const [method, args] = f.writes[0];
  assert.equal(method, 'upsert');
  assert.equal(args.create.phoneVerified, false);
  assert.equal(args.create.identityVerified, false);
  assert.equal(args.create.moderationChecked, false);
});

test('ensureParentMatchingProfileForUser creates a schema-valid own profile', async () => {
  const f = fixture();
  await f.context.ensureParentMatchingProfileForUser('owner-hamburg');
  const [method, args] = f.writes[0];
  assert.equal(method, 'upsert');
  assert.equal(args.create.ownerUserId, 'owner-hamburg');
  assert.equal(args.create.phoneVerified, false);
});

test('OTP confirmation writes phoneVerified through a schema-valid updateMany', async () => {
  const f = fixture();
  f.context.parentMatchingOtpStore.set('owner', {
    codeHash: f.context.hashOtpForUser('owner', '123456'),
    expiresAt: Date.now() + 60_000,
    attempts: 0,
  });
  const result = await f.post('/parent-matching/verification/confirm-otp', {
    body: { userId: 'owner', code: '123456' },
  });
  assert.deepEqual(f.errors, []);
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.deepEqual(f.writes.map(([method]) => method), ['upsert', 'updateMany']);
  assert.equal(f.writes[1][1].data.phoneVerified, true);
});
