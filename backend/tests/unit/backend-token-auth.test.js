const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');

function block(startMarker, endMarker) {
  const start = source.indexOf(startMarker);
  const end = source.indexOf(endMarker, start);
  assert.ok(start >= 0 && end > start, `Missing source block: ${startMarker}`);
  return source.slice(start, end);
}

function routeBlock(startMarker) {
  const start = source.indexOf(startMarker);
  const end = source.indexOf('\napp.', start + startMarker.length);
  assert.ok(start >= 0 && end > start, `Missing route block: ${startMarker}`);
  return source.slice(start, end);
}

function createFirebaseAdmin() {
  return {
    auth: () => ({
      verifyIdToken: async token => {
        if (!['admin-token', 'user-token', 'user-a-token'].includes(token)) {
          throw new Error('Invalid Firebase token');
        }
        return { uid: token === 'admin-token' ? 'admin' : token === 'user-a-token' ? 'user-a' : 'user' };
      },
    }),
  };
}

function createAdminRoutes({ admins = ['admin'] } = {}) {
  const routes = new Map();
  const calls = [];
  const app = Object.fromEntries(['get', 'post'].map(method => [
    method,
    (route, ...handlers) => routes.set(`${method.toUpperCase()} ${route}`, handlers),
  ]));
  const context = vm.createContext({
    ...require('../../moderation'),
    app,
    adminUserIds: new Set(admins),
    firebaseAdmin: createFirebaseAdmin(),
    console: { error() {} },
    prisma: {
      recipeReport: {
        findMany: async () => { calls.push('food-list'); return []; },
        findUnique: async () => { calls.push('food-find'); return { id: 'food-report', recipeId: 'recipe' }; },
        update: async ({ data }) => { calls.push('food-resolve'); return { id: 'food-report', ...data }; },
      },
      treasureReport: {
        findUnique: async () => { calls.push('treasure-find'); return { id: 'treasure-report', treasureId: 'treasure' }; },
        update: async ({ data }) => { calls.push('treasure-resolve'); return { id: 'treasure-report', ...data }; },
      },
      treasureItem: {
        updateMany: async () => { calls.push('treasure-archive'); return { count: 1 }; },
      },
    },
  });
  vm.runInContext(
    [
      block('async function verifyFirebaseIdToken(', '\nasync function requireVerifiedUser('),
      block('async function requireAdmin(', '\n// Liste aller Meldungen'),
      block("app.get('/api/food-feed/reports',", '\n/**\n * EVENTS & AKTIVITÄTEN'),
      block("app.post('/api/treasures/reports/:reportId/resolve'", '\n/**\n * GET /api/treasures/:id'),
    ].join('\n'),
    context,
  );

  async function request(route, { token = 'admin-token', body = {}, query = {}, params = {} } = {}) {
    let status = 200;
    let payload;
    const handlers = routes.get(route);
    assert.ok(handlers, `Missing route: ${route}`);
    const req = {
      headers: token === null ? {} : { authorization: `Bearer ${token}` },
      body: { action: 'resolved', ...body },
      query,
      params: { reportId: route.includes('food-feed') ? 'food-report' : 'treasure-report', ...params },
    };
    const res = {
      status(code) { status = code; return res; },
      json(value) { payload = value; return res; },
    };
    async function run(index) {
      if (handlers[index]) await handlers[index](req, res, () => run(index + 1));
    }
    await run(0);
    return { status, body: payload };
  }

  return { request, calls };
}

const adminRoutes = [
  'GET /api/food-feed/reports',
  'POST /api/food-feed/reports/:reportId/resolve',
  'POST /api/treasures/reports/:reportId/resolve',
];

test('Firebase allowlisted admins can access food-feed and treasure moderation', async () => {
  const fixture = createAdminRoutes();
  for (const route of adminRoutes) {
    assert.equal((await fixture.request(route)).status, 200, route);
  }
  assert.deepEqual(fixture.calls, [
    'food-list', 'food-find', 'food-resolve',
    'treasure-find', 'treasure-resolve', 'treasure-archive',
  ]);
});

test('moderation rejects non-admin, missing, invalid, and legacy static tokens', async () => {
  for (const route of adminRoutes) {
    for (const token of ['user-token', null, 'invalid-token', 'static-backend-token']) {
      const fixture = createAdminRoutes();
      const result = await fixture.request(route, { token });
      assert.equal(result.status, token === 'user-token' ? 403 : 401, `${route} token=${token}`);
      assert.deepEqual(fixture.calls, [], `${route} token=${token} must not reach persistence`);
    }
    const noAdmins = createAdminRoutes({ admins: [] });
    assert.equal((await noAdmins.request(route)).status, 403, route);
    assert.deepEqual(noAdmins.calls, [], `${route} with empty admin list must not reach persistence`);
  }
});

function createOwnerRoutes() {
  const routes = new Map();
  const databaseCalls = [];
  const app = {
    delete: (route, ...handlers) => routes.set(`DELETE ${route}`, handlers),
    get: (route, ...handlers) => routes.set(`GET ${route}`, handlers),
  };
  const context = vm.createContext({
    app,
    firebaseAdmin: createFirebaseAdmin(),
    console: { error() {} },
    ensureSocialSchemaReady: async () => databaseCalls.push('schema'),
    prisma: {
      $queryRawUnsafe: async () => { databaseCalls.push('query'); return []; },
      $executeRawUnsafe: async () => { databaseCalls.push('execute'); return 0; },
      treasureItem: { findMany: async () => { databaseCalls.push('treasure-read'); return []; } },
      treasureHandover: { findMany: async () => { databaseCalls.push('handover-read'); return []; } },
    },
  });
  vm.runInContext(
    [
      block('async function verifyFirebaseIdToken(', '\nasync function requireVerifiedUser('),
      block('async function authorizeAccountOwner(', '\nasync function authorizeProfileOwner('),
      routeBlock("app.delete('/api/account/:userId',"),
      routeBlock("app.get('/api/treasures/mine',"),
    ].join('\n'),
    context,
  );

  async function request(route, { token = 'user-a-token', userId = 'user-b' } = {}) {
    let status = 200;
    let payload;
    const handlers = routes.get(route);
    const req = {
      headers: token === null ? {} : { authorization: `Bearer ${token}` },
      params: { userId },
      query: { userId },
    };
    const res = {
      status(code) { status = code; return res; },
      json(value) { payload = value; return res; },
    };
    await handlers[0](req, res, () => {});
    return { status, body: payload };
  }

  return { request, databaseCalls };
}

test('account deletion and treasure mine enforce verified owner identity', async () => {
  const routes = [
    'DELETE /api/account/:userId',
    'GET /api/treasures/mine',
  ];
  for (const route of routes) {
    const fixture = createOwnerRoutes();
    assert.equal((await fixture.request(route, { token: 'user-a-token', userId: 'user-b' })).status, 403, route);
    assert.equal((await fixture.request(route, { token: 'static-backend-token', userId: 'user-b' })).status, 401, route);
    assert.equal((await fixture.request(route, { token: null, userId: 'user-b' })).status, 401, route);
    assert.deepEqual(fixture.databaseCalls, [], `${route} must reject before data access`);
  }

  const ownerContext = vm.createContext({
    firebaseAdmin: createFirebaseAdmin(),
  });
  vm.runInContext(
    block('async function verifyFirebaseIdToken(', '\nasync function requireVerifiedUser(') +
    block('async function authorizeAccountOwner(', '\nasync function authorizeProfileOwner('),
    ownerContext,
  );
  const ownerReq = { headers: { authorization: 'Bearer user-a-token' } };
  const ownerRes = { status() { return this; }, json() { return this; } };
  assert.equal(await ownerContext.authorizeAccountOwner(ownerReq, ownerRes, 'user-a'), true);
  assert.equal(ownerReq.firebaseUid, 'user-a');
});

function createWriteGuards() {
  const guards = [];
  const requireAuthStart = source.indexOf('  if (!requireAuthForWrites) {');
  const writeGuardStart = source.lastIndexOf('app.use(async (req, res, next) => {', requireAuthStart);
  const writeGuardEnd = source.indexOf('\nconst allowedGeminiModels', requireAuthStart);
  assert.ok(writeGuardStart >= 0 && writeGuardEnd > requireAuthStart);
  const context = vm.createContext({
    app: { use: handler => guards.push(handler) },
    firebaseAdmin: createFirebaseAdmin(),
    process: { env: { FIREBASE_REQUIRE_AUTH: '1' } },
    requireAuthForWrites: true,
    WRITE_METHODS: new Set(['POST', 'PUT', 'PATCH', 'DELETE']),
    isWriteRequest: req => ['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method),
  });
  vm.runInContext(
    [
      block('async function verifyFirebaseIdToken(', '\nasync function requireVerifiedUser('),
      block('const firebaseRequireAuth =', '\n// Middleware'),
      source.slice(writeGuardStart, writeGuardEnd),
    ].join('\n'),
    context,
  );
  guards.unshift(context.firebaseAuthMiddleware);
  return guards;
}

async function callGuard(guard, { token = 'user-token', method = 'POST', path = '/write' } = {}) {
  let status = 200;
  let continued = false;
  const req = {
    method, path,
    headers: token === null ? {} : { authorization: `Bearer ${token}` },
  };
  const res = {
    status(code) { status = code; return res; },
    json() { return res; },
  };
  await guard(req, res, () => { continued = true; });
  return { status, continued, req };
}

test('global write guards accept Firebase identity and reject the legacy token', async () => {
  const guards = createWriteGuards();
  assert.equal(guards.length, 2);
  for (const guard of guards) {
    const valid = await callGuard(guard);
    assert.equal(valid.continued, true);
    assert.equal(valid.req.firebaseUid, 'user');

    for (const token of ['static-backend-token', null, 'invalid-token']) {
      const rejected = await callGuard(guard, { token });
      assert.equal(rejected.continued, false);
      assert.equal(rejected.status, 401);
    }
  }
});

test('Stripe and social write exceptions remain route-local', async () => {
  const [firebaseGuard, writeGuard] = createWriteGuards();
  const stripe = await callGuard(firebaseGuard, {
    token: null, method: 'POST', path: '/payments/stripe/webhook',
  });
  assert.equal(stripe.continued, true);

  for (const guard of [firebaseGuard, writeGuard]) {
    const social = await callGuard(guard, {
      token: 'static-backend-token', path: '/api/account/user-b',
    });
    assert.equal(social.continued, true);
    assert.equal(social.req.firebaseUid, undefined);
  }
});

test('both global guards leave only the exact POST digest to its secret check', async () => {
  for (const guard of createWriteGuards()) {
    for (const token of [null, 'digest-secret']) {
      const result = await callGuard(guard, {
        token, path: '/internal/moderation/digest',
      });
      assert.equal(result.continued, true);
      assert.equal(result.req.firebaseUid, undefined);
    }
    for (const [method, requestPath] of [
      ['POST', '/internal/moderation/digest/extra'],
      ['POST', '/internal/moderation/other'],
      ['PUT', '/internal/moderation/digest'],
      ['DELETE', '/internal/moderation/digest'],
    ]) {
      const result = await callGuard(guard, { token: null, method, path: requestPath });
      assert.equal(result.continued, false, `${method} ${requestPath}`);
      assert.equal(result.status, 401);
    }
  }
});

function createDigestRoute({ secret = 'digest-secret', failDelivery = false } = {}) {
  let handler;
  let deliveries = 0;
  const context = vm.createContext({
    app: { post: (route, fn) => {
      assert.equal(route, '/internal/moderation/digest');
      handler = fn;
    } },
    crypto: require('node:crypto'),
    Buffer,
    process: { env: secret === null ? {} : { MODERATION_DIGEST_SECRET: secret } },
    sendPendingDigest: async () => {
      deliveries += 1;
      if (failDelivery) throw new Error('mail unavailable');
      return { sent: true, pendingCount: 1 };
    },
    console: { error() {} },
  });
  vm.runInContext(
    block('function timingSafeSecretMatch(', '\n// Liste aller Meldungen'),
    context,
  );
  const guards = createWriteGuards();
  async function request(headers = {}) {
    let status = 200;
    let body;
    const req = { method: 'POST', path: '/internal/moderation/digest', headers };
    const res = {
      status(code) { status = code; return res; },
      json(value) { body = value; return res; },
    };
    const chain = [...guards, handler];
    async function run(index) {
      if (chain[index]) await chain[index](req, res, () => run(index + 1));
    }
    await run(0);
    return { status, body };
  }
  return { request, deliveries: () => deliveries };
}

test('digest without configured secret stays disabled through both global guards', async () => {
  const fixture = createDigestRoute({ secret: null });
  assert.equal((await fixture.request()).status, 404);
  assert.equal(fixture.deliveries(), 0);
});

test('digest rejects missing, wrong and Firebase tokens before sending mail', async () => {
  const fixture = createDigestRoute();
  for (const headers of [
    {},
    { authorization: 'Bearer incorrect' },
    { authorization: 'Bearer user-token' },
    { 'x-digest-secret': 'incorrect' },
  ]) {
    assert.equal((await fixture.request(headers)).status, 401);
  }
  assert.equal(fixture.deliveries(), 0);
});

test('digest accepts its dedicated bearer or header with both auth flags enabled', async () => {
  for (const headers of [
    { authorization: 'Bearer digest-secret' },
    { 'x-digest-secret': 'digest-secret' },
  ]) {
    const fixture = createDigestRoute();
    const result = await fixture.request(headers);
    assert.equal(result.status, 200);
    assert.equal(result.body.ok, true);
    assert.equal(fixture.deliveries(), 1);
  }
});

test('authorized digest delivery failures remain explicit through global guards', async () => {
  const fixture = createDigestRoute({ failDelivery: true });
  const result = await fixture.request({ authorization: 'Bearer digest-secret' });
  assert.equal(result.status, 502);
  assert.equal(result.body.ok, false);
  assert.equal(fixture.deliveries(), 1);
});
