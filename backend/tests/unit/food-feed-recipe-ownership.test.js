const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const express = require('express');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
function block(start, end) {
  const a = source.indexOf(start), b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, start);
  return source.slice(a, b);
}
const familyId = uid => `account-family-v1-${crypto.createHash('sha256').update(uid).digest('hex')}`;
const validRecipe = {
  title: 'Family lunch', category: 'dinner', difficulty: 'leicht', servings: 4,
  ingredients: [{ name: 'Rice', quantity: '200', unit: 'g' }],
  instructions: ['Cook rice'], tags: ['lunch'],
};
const routes = [
  ['POST', '/api/food-feed/recipes'],
  ['PUT', '/api/food-feed/recipes/:id'],
  ['DELETE', '/api/food-feed/recipes/:id'],
];

function fixture({ configured = true, failure } = {}) {
  const handlers = new Map(), writes = [], reads = [], familyWrites = [];
  const recipes = new Map([
    ['a-recipe', { id: 'a-recipe', creatorUserId: 'a', familyId: 'legacy-family', isPublished: true, ...validRecipe }],
    ['b-recipe', { id: 'b-recipe', creatorUserId: 'b', familyId: familyId('b'), isPublished: true, ...validRecipe }],
    ['ownerless', { id: 'ownerless', creatorUserId: null, isPublished: true, ...validRecipe }],
  ]);
  const families = new Map();
  const prisma = {
    user: { findUnique: async ({ where }) => ({ id: where.id }) },
    family: { upsert: async ({ create }) => {
      if (failure === 'family') throw new Error('Family store unavailable');
      familyWrites.push(create.id);
      const row = failure === 'conflict'
        ? { id: create.id, createdById: 'b', memberUsers: [{ id: 'b' }] }
        : { id: create.id, createdById: create.createdById, memberUsers: create.memberUsers.connect };
      families.set(create.id, row);
      return row;
    } },
    $transaction: async work => work(prisma),
    sharedRecipe: {
      findUnique: async ({ where }) => {
        reads.push(where.id);
        if (failure === 'read') throw new Error('Recipe store unavailable');
        return recipes.get(where.id) || null;
      },
      findMany: async ({ where }) => [...recipes.values()].filter(row => row.isPublished === where.isPublished),
      count: async () => recipes.size,
      create: async ({ data }) => {
        if (failure === 'write') throw new Error('Recipe write unavailable');
        writes.push(['create', data]);
        const row = { id: 'new-recipe', isPublished: true, ...data };
        recipes.set(row.id, row);
        return row;
      },
      update: async ({ where, data }) => {
        if (failure === 'write') throw new Error('Recipe write unavailable');
        writes.push(['update', where.id]);
        const row = recipes.get(where.id);
        for (const [key, value] of Object.entries(data)) if (value !== undefined) row[key] = value;
        return row;
      },
      delete: async ({ where }) => {
        if (failure === 'write') throw new Error('Recipe write unavailable');
        writes.push(['delete', where.id]);
        recipes.delete(where.id);
        return { id: where.id };
      },
    },
  };
  const context = vm.createContext({
    crypto, prisma, console: { error() {} },
    process: { env: { NODE_ENV: 'production', REQUIRE_AUTH_FOR_WRITES: '0', FIREBASE_REQUIRE_AUTH: '0' } },
    firebaseAdmin: configured ? { auth: () => ({
      verifyIdToken: async token => {
        if (token === 'unavailable') throw Object.assign(new Error('Unavailable'), { code: 'app/network-error' });
        if (!['a', 'b'].includes(token)) throw new Error('Invalid token');
        return { uid: token };
      },
    }) } : null,
    buildAuthorTrustMapForRecipes: async () => new Map(),
    app: Object.fromEntries(['get', 'post', 'put', 'delete'].map(method => [
      method, (route, ...chain) => handlers.set(`${method.toUpperCase()} ${route}`, chain),
    ])),
  });
  vm.runInContext([
    block('async function verifyFirebaseIdToken(', 'function resolveVerifiedUserId('),
    block('class FamilyContextError', 'async function ensurePaymentContext('),
    block('function requireActorClaims(', 'function respondChatPersistenceError('),
    block("app.get('/api/food-feed/recipes',", "app.post('/api/food-feed/recipes/:id/rate',"),
  ].join('\n'), context);

  async function request(method, route, { token = 'a', body = {}, query = {}, id = 'a-recipe' } = {}) {
    let status = 200, response;
    const req = { body, query, params: { id },
      headers: token == null ? {} : { authorization: `Bearer ${token}` } };
    const res = { status(value) { status = value; return res; },
      json(value) { response = value; return res; } };
    const chain = handlers.get(`${method} ${route}`);
    const run = i => chain[i](req, res, () => run(i + 1));
    await run(0);
    return { status, body: response };
  }
  return { handlers, request, recipes, writes, reads, familyWrites };
}

for (const [method, route] of routes) {
  for (const token of [null, 'invalid', 'shared']) {
    test(`${method} recipe rejects ${token || 'absent'} token even without global guards`, async () => {
      const f = fixture();
      assert.equal((await f.request(method, route, { token, body: validRecipe })).status, 401);
      assert.deepEqual(f.writes, []);
      assert.deepEqual(f.reads, []);
    });
  }
  test(`${method} recipe fails closed with missing Firebase configuration or verification outage`, async () => {
    assert.equal((await fixture({ configured: false }).request(method, route, { body: validRecipe })).status, 401);
    const f = fixture();
    assert.equal((await f.request(method, route, { token: 'unavailable', body: validRecipe })).status, 503);
    assert.deepEqual(f.writes, []);
  });
  for (const location of ['body', 'query']) {
    for (const field of ['userId', 'creatorUserId', 'familyId']) {
      test(`${method} recipe rejects foreign ${location}.${field} before persistence`, async () => {
        const f = fixture();
        const options = { body: { ...validRecipe } };
        options[location] = { ...options[location], [field]: field === 'familyId' ? familyId('b') : 'b' };
        assert.equal((await f.request(method, route, options)).status, 403);
        assert.deepEqual(f.writes, []);
        assert.deepEqual(f.reads, []);
        assert.deepEqual(f.familyWrites, []);
      });
    }
  }
}

test('create derives creator from token; optional family is absent/null unless verified', async () => {
  for (const extra of [{}, { familyId: null }, { userId: 'a', creatorUserId: 'a' }]) {
    const f = fixture();
    const result = await f.request('POST', routes[0][1], { body: { ...validRecipe, ...extra } });
    assert.equal(result.status, 201);
    assert.equal(result.body.recipe.creatorUserId, 'a');
    assert.equal(result.body.recipe.familyId, null);
    assert.equal(result.body.recipe.title, validRecipe.title);
    assert.equal(result.body.recipe.ingredients, JSON.stringify(validRecipe.ingredients));
    assert.deepEqual(f.familyWrites, []);
  }
  const f = fixture();
  const result = await f.request('POST', routes[0][1], {
    body: { ...validRecipe, familyId: familyId('a') },
  });
  assert.equal(result.status, 201);
  assert.equal(result.body.recipe.familyId, familyId('a'));
  assert.deepEqual(f.familyWrites, [familyId('a')]);
});

for (const method of ['PUT', 'DELETE']) {
  const route = routes[1][1];
  test(`${method} checks stored creator, never family membership or absent owner`, async () => {
    for (const id of ['b-recipe', 'ownerless']) {
      const f = fixture();
      const result = await f.request(method, route, {
        id, body: { userId: 'a', familyId: familyId('a'), title: 'Changed' },
      });
      assert.equal(result.status, 403);
      assert.deepEqual(f.writes, []);
    }
  });
  test(`${method} allows only stored creator and preserves 404 semantics`, async () => {
    const f = fixture();
    assert.equal((await f.request(method, route, { id: 'missing' })).status, 404);
    const result = await f.request(method, route, { body: { title: 'Changed' } });
    assert.equal(result.status, 200);
    if (method === 'PUT') {
      assert.equal(result.body.recipe.creatorUserId, 'a');
      assert.equal(result.body.recipe.familyId, 'legacy-family');
      assert.equal(result.body.recipe.title, 'Changed');
    } else {
      assert.equal(result.body.success, true);
      assert.equal(f.recipes.has('a-recipe'), false);
    }
    assert.equal(f.recipes.has('b-recipe'), true);
  });
}

test('own family claims cannot hide a foreign claim in the other request location', async () => {
  const f = fixture();
  const result = await f.request('POST', routes[0][1], {
    body: { ...validRecipe, familyId: familyId('a') }, query: { familyId: familyId('b') },
  });
  assert.equal(result.status, 403);
  assert.deepEqual(f.writes, []);
});

test('malformed actor and family claims are rejected, never coerced to an owner', async () => {
  for (const [method, route] of routes) {
    for (const claim of [{ creatorUserId: ['a'] }, { userId: 1 },
      { familyId: '' }, { familyId: ['other'] }, { familyId: 'demo-family-001' }]) {
      const f = fixture();
      assert.equal((await f.request(method, route, { body: { ...validRecipe, ...claim } })).status, 403);
      assert.deepEqual(f.writes, []);
      assert.deepEqual(f.reads, []);
      assert.deepEqual(f.familyWrites, []);
    }
  }
});

test('database lookup errors do not allow update or delete', async () => {
  for (const method of ['PUT', 'DELETE']) {
    const f = fixture({ failure: 'read' });
    const response = await f.request(method, routes[1][1]);
    assert.equal(response.status, 500);
    assert.equal('recipe' in response.body, false);
    assert.equal('success' in response.body, false);
    assert.deepEqual(f.writes, []);
  }
});

test('family errors and conflicting ownership never create a recipe', async () => {
  for (const [failure, status] of [['family', 503], ['conflict', 409]]) {
    const f = fixture({ failure });
    const response = await f.request('POST', routes[0][1], {
      body: { ...validRecipe, familyId: familyId('a') },
    });
    assert.equal(response.status, status);
    assert.deepEqual(f.writes, []);
  }
});

test('database errors never return successful CRUD payloads', async () => {
  for (const [method, route] of routes) {
    const f = fixture({ failure: 'write' });
    const response = await f.request(method, route, { body: validRecipe });
    assert.equal(response.status, 500);
    assert.equal('recipe' in response.body, false);
    assert.equal('success' in response.body, false);
    assert.deepEqual(f.writes, []);
  }
});

test('create validation and public recipe reads remain available without new login gates', async () => {
  const f = fixture();
  assert.equal((await f.request('POST', routes[0][1], { body: { ...validRecipe, title: 'x' } })).status, 400);
  assert.deepEqual(f.writes, []);
  const list = await f.request('GET', '/api/food-feed/recipes', { token: null });
  assert.equal(list.status, 200);
  assert.ok(list.body.recipes.length > 0);
  assert.equal((await f.request('GET', '/api/food-feed/recipes/:id', { token: null })).status, 200);
});

test('real Express route chains reject shared tokens and forged owners', async t => {
  const f = fixture();
  const app = express();
  app.use(express.json());
  for (const [method, route] of routes) app[method.toLowerCase()](route, ...f.handlers.get(`${method} ${route}`));
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => new Promise(resolve => { server.close(resolve); server.closeAllConnections(); }));
  const base = `http://127.0.0.1:${server.address().port}`;
  for (const [method] of routes) {
    const url = base + '/api/food-feed/recipes' + (method === 'POST' ? '' : '/b-recipe');
    const shared = await fetch(url, { method, headers: { Authorization: 'Bearer shared' } });
    assert.equal(shared.status, 401);
    const forged = await fetch(url, { method,
      headers: { Authorization: 'Bearer a', 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...validRecipe, userId: 'b' }),
    });
    assert.equal(forged.status, 403);
  }
  assert.deepEqual(f.writes, []);
});
