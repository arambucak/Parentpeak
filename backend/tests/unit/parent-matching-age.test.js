const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
const parserStart = source.indexOf('function parseOptionalParentAge(');
const parser = source.slice(parserStart, source.indexOf('\n}', parserStart) + 2);

function fixture(routePath, persistenceFails = false) {
  const start = source.indexOf(`app.post('${routePath}',`);
  const route = source.slice(start, source.indexOf('\n});', start) + 4);
  let handler;
  const writes = [];
  const fallbackWrites = [];
  vm.runInNewContext(`${parser}\n${route}`, {
    app: { post: (_path, callback) => { handler = callback; } },
    prisma: {
      parentMatchingProfile: {
        upsert: async options => {
          writes.push(options);
          if (persistenceFails) throw new Error('unavailable');
          return { id: 'self-viewer', ...options.create };
        },
      },
    },
    ensureParentMatchingSchemaReady: async () => {},
    mapParentMatchingProfileForClient: profile => profile,
    respondWithStrictPersistenceError: () => false,
    upsertMyParentMatchingProfileInMemory: profile => {
      fallbackWrites.push(profile);
      return profile;
    },
    isUserSuspended: async () => false,
    console,
  });
  return {
    writes,
    fallbackWrites,
    async request(overrides = {}) {
      let code = 200;
      let payload;
      const res = {
        status(value) { code = value; return res; },
        json(value) { payload = value; return res; },
      };
      await handler({
        body: {
          userId: 'viewer',
          name: 'Test family',
          city: 'Berlin',
          familyForm: 'kernfamilie',
          ...overrides,
        },
      }, res);
      return { code, payload };
    },
  };
}

for (const route of ['/parent-matching/my-profile', '/api/parent-matching/profiles']) {
  test(`${route}: missing, null and empty age persist as null`, async () => {
    for (const overrides of [{}, { age: null }, { age: '' }]) {
      const app = fixture(route);
      const result = await app.request(overrides);
      assert.ok(result.code >= 200 && result.code < 300);
      assert.equal(app.writes[0].create.age, null);
      assert.equal(app.writes[0].update.age, null);
    }
  });

  test(`${route}: valid adult age is preserved`, async () => {
    for (const age of [34, '34']) {
      const app = fixture(route);
      await app.request({ age });
      assert.equal(app.writes[0].create.age, 34);
      assert.equal(app.writes[0].update.age, 34);
    }
  });

  test(`${route}: invalid supplied age is rejected before persistence`, async () => {
    for (const age of [0, -1, 15, 121, 34.5, '34years', ' ', true, [], {}]) {
      const app = fixture(route);
      const result = await app.request({ age });
      assert.equal(result.code, 400, `age: ${JSON.stringify(age)}`);
      assert.equal(app.writes.length, 0);
    }
  });
}

test('my-profile: in-memory fallback also preserves absent age as null', async () => {
  const app = fixture('/parent-matching/my-profile', true);
  const result = await app.request();
  assert.equal(result.code, 201);
  assert.equal(app.fallbackWrites[0].age, null);
});

test('schema, migration and runtime schema allow null adult age', () => {
  const schema = fs.readFileSync(path.join(__dirname, '../../prisma/schema.prisma'), 'utf8');
  const model = schema.slice(schema.indexOf('model ParentMatchingProfile {'));
  assert.match(model.slice(0, model.indexOf('\n}')), /\bage\s+Int\?/);
  const migration = fs.readFileSync(path.join(__dirname,
    '../../prisma/migrations/20261006000000_optional_parent_matching_age/migration.sql'), 'utf8');
  assert.match(migration, /ALTER COLUMN "age" DROP NOT NULL/);
  const runtimeStart = source.indexOf('async function ensureParentMatchingSchemaReady()');
  const runtime = source.slice(runtimeStart, source.indexOf('\n}', runtimeStart));
  assert.match(runtime, /"age" INTEGER,/);
  assert.match(runtime, /ALTER COLUMN "age" DROP NOT NULL/);
});
