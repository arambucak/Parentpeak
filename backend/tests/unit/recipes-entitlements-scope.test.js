const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const express = require('express');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
function slice(start, end) {
  const a = source.indexOf(start), b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `Missing block: ${start}`);
  return source.slice(a, b);
}

function baseContext({ app, configured = true, extra = {} } = {}) {
  const handlers = new Map();
  const ctx = {
    console: { error: () => {}, log: () => {} },
    process: { env: { NODE_ENV: 'production', FIREBASE_REQUIRE_AUTH: '1' } },
    firebaseAdmin: configured ? { auth: () => ({
      verifyIdToken: async token => {
        if (!['a', 'b'].includes(token)) throw new Error('Invalid');
        return { uid: token };
      },
    }) } : null,
    app: app || Object.fromEntries(['get', 'post', 'put', 'delete'].map(method => [
      method, (route, ...chain) => handlers.set(`${method.toUpperCase()} ${route}`, chain),
    ])),
    ...extra,
  };
  const context = vm.createContext(ctx);
  vm.runInContext(slice('async function verifyFirebaseIdToken(', 'function resolveVerifiedUserId('), context);
  vm.runInContext(slice('class FamilyContextError', 'async function ensurePaymentContext('), context);
  vm.runInContext(slice('const firebaseRequireAuth =', '\n// Middleware'), context);
  return { context, handlers };
}

async function callRoute(handlers, method, route, { token = 'a', query = {}, body = {}, params = {} } = {}) {
  let status = 200, response;
  const req = {
    method, path: route,
    headers: token === null ? {} : { authorization: `Bearer ${token}` },
    query, body, params,
  };
  const res = { status(v) { status = v; return res; }, json(v) { response = v; return res; }, send() { return res; } };
  const chain = handlers.get(`${method} ${route}`);
  const run = i => chain[i](req, res, () => run(i + 1));
  await run(0);
  return { status, body: response };
}

// ========== MEDIUM 1: private Rezepte ==========
function recipeFixture({ app, configured = true } = {}) {
  // Recipe-Tabelle: eigenes privates (A), fremdes privates (B), oeffentliches (B).
  const recipeRows = [
    { id: 'r-a-private', authorUserId: 'a', visibility: 'private', title: 'A privat', ingredients: '[]', tags: '[]' },
    { id: 'r-b-private', authorUserId: 'b', visibility: 'private', title: 'B privat', ingredients: '[]', tags: '[]' },
    { id: 'r-b-public', authorUserId: 'b', visibility: 'public', title: 'B public', ingredients: '[]', tags: '[]' },
  ];
  const { context, handlers } = baseContext({
    app, configured,
    extra: {
      prisma: {
        $queryRawUnsafe: async (sql, arg) => {
          if (sql.includes('FROM "Recipe" WHERE "id"')) {
            return recipeRows.filter(r => r.id === arg);
          }
          if (sql.includes('FROM "Recipe"')) return recipeRows.slice();
          if (sql.includes('Friendship')) return []; // keine Freundschaften
          return [];
        },
      },
      ensureSocialSchemaReady: async () => {},
      parseJsonArray: () => [],
      buildRecipeForClient: async r => ({ id: r.id, title: r.title }),
      areFriends: async () => false,
      respondWithStrictPersistenceError: () => false,
      recipes: new Map(),
      recipeReactions: new Map(),
    },
  });
  vm.runInContext(slice('// ueber Titel/Beschreibung/Zutaten', '// Rezept loeschen'), context);
  return { handlers };
}

for (const route of ['/api/recipes', '/api/recipes/:id']) {
  for (const token of [null, 'invalid', 'shared']) {
    test(`GET ${route} rejects ${token ?? 'missing'} token`, async () => {
      const { handlers } = recipeFixture();
      const result = await callRoute(handlers, 'GET', route, { token, params: { id: 'r-a-private' } });
      assert.equal(result.status, 401);
    });
  }
  test(`GET ${route} rejects missing Admin configuration`, async () => {
    const { handlers } = recipeFixture({ configured: false });
    const result = await callRoute(handlers, 'GET', route, { params: { id: 'r-a-private' } });
    assert.equal(result.status, 401);
  });
  for (const field of ['query']) {
    test(`GET ${route} rejects foreign ${field} userId claim`, async () => {
      const { handlers } = recipeFixture();
      const result = await callRoute(handlers, 'GET', route, {
        token: 'a', [field]: { userId: 'b' }, params: { id: 'r-a-private' },
      });
      assert.equal(result.status, 403);
    });
  }
}

test('GET /api/recipes list hides foreign private, shows own and public', async () => {
  const { handlers } = recipeFixture();
  const result = await callRoute(handlers, 'GET', '/api/recipes', { token: 'a' });
  assert.equal(result.status, 200);
  const ids = result.body.recipes.map(r => r.id);
  assert.ok(ids.includes('r-a-private'));   // eigenes privat
  assert.ok(ids.includes('r-b-public'));    // oeffentlich
  assert.ok(!ids.includes('r-b-private'));  // fremdes privat NICHT
});

test('GET /api/recipes/:id forbids foreign private even with valid token', async () => {
  const { handlers } = recipeFixture();
  const denied = await callRoute(handlers, 'GET', '/api/recipes/:id', {
    token: 'a', params: { id: 'r-b-private' },
  });
  assert.equal(denied.status, 403);
  const ownOk = await callRoute(handlers, 'GET', '/api/recipes/:id', {
    token: 'a', params: { id: 'r-a-private' },
  });
  assert.equal(ownOk.status, 200);
  const publicOk = await callRoute(handlers, 'GET', '/api/recipes/:id', {
    token: 'a', params: { id: 'r-b-public' },
  });
  assert.equal(publicOk.status, 200);
});

// ========== MEDIUM 2: Entitlements ==========
function entitlementFixture({ app, configured = true } = {}) {
  const userEntitlements = new Map();
  const { context, handlers } = baseContext({
    app, configured,
    extra: {
      userEntitlements,
      ensureEntitlement: undefined, // wird aus Quelle geladen
      buildEntitlementStatus: undefined,
      asIsoDate: undefined,
    },
  });
  // Reale Helfer laden (ensureEntitlement, buildEntitlementStatus, asIsoDate).
  vm.runInContext(slice('function asIsoDate(', 'function removeMatching('), context);
  vm.runInContext(slice("app.get('/entitlements/:userId/status'", '// 0. Weekly Impulse abrufen'), context);
  return { handlers, userEntitlements };
}

for (const [method, route] of [
  ['GET', '/entitlements/:userId/status'],
  ['POST', '/entitlements/:userId/activate-premium'],
]) {
  for (const token of [null, 'invalid', 'shared']) {
    test(`${method} ${route} rejects ${token ?? 'missing'} token`, async () => {
      const { handlers } = entitlementFixture();
      const result = await callRoute(handlers, method, route, { token, params: { userId: 'a' } });
      assert.equal(result.status, 401);
    });
  }
  test(`${method} ${route} rejects foreign path userId`, async () => {
    const { handlers } = entitlementFixture();
    const result = await callRoute(handlers, method, route, { token: 'a', params: { userId: 'b' } });
    assert.equal(result.status, 403);
  });
  test(`${method} ${route} allows own path userId`, async () => {
    const { handlers } = entitlementFixture();
    const result = await callRoute(handlers, method, route, { token: 'a', params: { userId: 'a' } });
    assert.ok(result.status === 200 || result.status === 201);
  });
}

test('GET entitlement status does NOT set premium from query hint', async () => {
  const { handlers, userEntitlements } = entitlementFixture();
  await callRoute(handlers, 'GET', '/entitlements/:userId/status', {
    token: 'a', params: { userId: 'a' }, query: { isPremium: 'true' },
  });
  const record = userEntitlements.get('a');
  assert.equal(record.isPremium, false); // Query-Hint wird ignoriert
});

test('POST activate-premium sets premium only for own account', async () => {
  const { handlers, userEntitlements } = entitlementFixture();
  const result = await callRoute(handlers, 'POST', '/entitlements/:userId/activate-premium', {
    token: 'a', params: { userId: 'a' },
  });
  assert.equal(result.status, 201);
  assert.equal(userEntitlements.get('a').isPremium, true);
});

// Echte Express-Kette: GET /api/recipes nicht ungeschützt.
test('real Express chain protects recipes and entitlements', async t => {
  const app = express(); app.use(express.json());
  recipeFixture({ app });
  entitlementFixture({ app });
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => new Promise(resolve => { server.close(resolve); server.closeAllConnections(); }));
  const base = `http://127.0.0.1:${server.address().port}`;
  assert.equal((await fetch(`${base}/api/recipes`)).status, 401);
  assert.equal((await fetch(`${base}/entitlements/a/status`)).status, 401);
  assert.equal((await fetch(`${base}/entitlements/a/status`,
    { headers: { Authorization: 'Bearer b' } })).status, 403);
});
