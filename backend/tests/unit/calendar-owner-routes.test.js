const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const express = require('express');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
const helperStart = source.indexOf('async function verifyFirebaseIdToken(');
const helperEnd = source.indexOf('function resolveVerifiedUserId(', helperStart);
const middlewareStart = source.indexOf('const firebaseRequireAuth =');
const middlewareEnd = source.indexOf('\n// Middleware', middlewareStart);
const writeGuardStart = source.lastIndexOf('app.use(async (req, res, next) => {',
  source.indexOf('  if (!requireAuthForWrites)'));
const writeGuardEnd = source.indexOf('\nconst allowedGeminiModels', writeGuardStart);
const routeStart = source.indexOf('// 10. Calendar events');
const routeEnd = source.indexOf('// 11. Photos', routeStart);
assert.ok(helperStart >= 0 && helperEnd > helperStart);
assert.ok(middlewareStart >= 0 && middlewareEnd > middlewareStart);
assert.ok(writeGuardStart >= 0 && writeGuardEnd > writeGuardStart);
assert.ok(routeStart >= 0 && routeEnd > routeStart);

function fixture({ configured = true, dbFailure = false, strict = true,
  firebaseRequireAuth = '0', app } = {}) {
  const routes = new Map();
  const calls = [];
  const verifiedTokens = [];
  const logs = [];
  const db = [
    { id: 'event-a', userId: 'a', familyId: 'shared', title: 'A' },
    { id: 'event-b', userId: 'b', familyId: 'shared', title: 'B' },
  ];
  const memory = [...db.map(event => ({ ...event })),
    { id: 'legacy', familyId: 'a', title: 'Unassigned' }];
  const context = {
    app: app || Object.fromEntries(['get', 'post', 'delete'].map(method => [
      method, (url, ...handlers) => routes.set(`${method.toUpperCase()} ${url}`, handlers),
    ])),
    firebaseAdmin: configured ? { auth: () => ({
      verifyIdToken: async token => {
        verifiedTokens.push(token);
        if (!['a', 'b'].includes(token)) throw new Error('Invalid or expired token');
        return { uid: token };
      },
    }) } : null,
    process: { env: { FIREBASE_REQUIRE_AUTH: firebaseRequireAuth } },
    backendApiToken: 'shared-backend-token',
    WRITE_METHODS: new Set(['POST', 'PUT', 'PATCH', 'DELETE']),
    isWriteRequest: req => ['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method),
    requireAuthForWrites: true,
    disableInMemoryFallbacks: strict,
    console: { error: (...args) => logs.push(args) },
    calendarEvents: memory,
    generateId: () => 'new-event',
    ensureSocialSchemaReady: async () => {
      calls.push('schema');
      if (dbFailure) throw new Error('Database unavailable');
    },
    prisma: {
      $queryRawUnsafe: async (sql, uid) => {
        calls.push('read');
        assert.match(sql, /WHERE "userId" = \$1/);
        return db.filter(event => event.userId === uid);
      },
      $executeRawUnsafe: async (sql, ...params) => {
        if (sql.startsWith('INSERT')) {
          calls.push('create');
          db.push({ id: params[0], userId: params[1], familyId: params[2] });
          return 1;
        }
        calls.push('delete');
        assert.match(sql, /WHERE "id" = \$1 AND "userId" = \$2/);
        const index = db.findIndex(event => event.id === params[0] && event.userId === params[1]);
        if (index === -1) return 0;
        db.splice(index, 1);
        return 1;
      },
    },
  };
  const persistenceStart = source.indexOf('function respondWithStrictPersistenceError(');
  const persistenceEnd = source.indexOf('\nfunction ', persistenceStart + 1);
  vm.createContext(context);
  vm.runInContext(source.slice(persistenceStart, persistenceEnd), context);
  vm.runInContext(source.slice(helperStart, helperEnd), context);
  vm.runInContext(source.slice(middlewareStart, middlewareEnd), context);
  if (app) {
    app.use(context.firebaseAuthMiddleware);
    vm.runInContext(source.slice(writeGuardStart, writeGuardEnd), context);
  }
  vm.runInContext(source.slice(routeStart, routeEnd), context);

  async function request(method, { token = 'a', body = {}, query = {}, id = 'event-a',
    firebaseUid } = {}) {
    let status = 200, response;
    const req = {
      headers: token === null ? {} : { authorization: `Bearer ${token}` },
      body, query, params: { id }, firebaseUid,
    };
    const res = {
      status(code) { status = code; return res; },
      json(value) { response = value; return res; },
    };
    const url = method === 'DELETE' ? '/calendar/events/:id' : '/calendar/events';
    const handlers = routes.get(`${method} ${url}`);
    async function run(index) {
      await handlers[index](req, res, () => run(index + 1));
    }
    await run(0);
    return { status, body: response };
  }
  return { request, calls, db, memory, verifiedTokens, logs };
}

for (const method of ['GET', 'POST', 'DELETE']) {
  for (const token of [null, 'invalid', 'expired', 'shared-backend-token']) {
    test(`${method} calendar rejects ${token ?? 'missing'} token before persistence`, async () => {
      const f = fixture();
      assert.equal((await f.request(method, { token, firebaseUid: 'a' })).status, 401);
      assert.deepEqual(f.calls, []);
    });
  }
  for (const field of ['body', 'query']) {
    test(`${method} calendar rejects foreign ${field} UID`, async () => {
      const f = fixture();
      assert.equal((await f.request(method, { [field]: { userId: 'b' } })).status, 403);
      assert.deepEqual(f.calls, []);
    });
  }
  test(`${method} calendar fails closed without Firebase configuration`, async () => {
    const f = fixture({ configured: false });
    assert.equal((await f.request(method, { firebaseUid: 'a' })).status, 401);
    assert.deepEqual(f.calls, []);
  });
  test(`${method} calendar returns 503 on strict persistence failure`, async () => {
    const f = fixture({ dbFailure: true });
    assert.equal((await f.request(method)).status, 503);
    assert.equal(f.memory.length, 3);
    assert.equal(f.db.length, 2);
    assert.equal(f.logs.length, 1);
  });
}

test('calendar reads only token owner, not family/query scope', async () => {
  const f = fixture();
  const result = await f.request('GET', { query: { familyId: 'b' } });
  assert.equal(result.status, 200);
  assert.deepEqual(Array.from(result.body.items, event => event.id), ['event-a']);
  assert.equal((await f.request('GET', { token: 'b', query: { userId: 'b' } })).body.items[0].id, 'event-b');
});

test('calendar create takes its owner from verified token', async () => {
  const f = fixture();
  const result = await f.request('POST', { body: { familyId: 'b', title: 'New' } });
  assert.equal(result.status, 201);
  assert.equal(result.body.item.userId, 'a');
  assert.equal(f.db.at(-1).userId, 'a');
});

test('calendar foreign/missing delete returns 404 without changing data', async () => {
  const f = fixture();
  assert.equal((await f.request('DELETE', { id: 'event-b' })).status, 404);
  assert.equal((await f.request('DELETE', { id: 'missing' })).status, 404);
  assert.equal(f.db.length, 2);
});

test('calendar own delete removes only the owned event', async () => {
  const f = fixture();
  assert.equal((await f.request('DELETE')).status, 200);
  assert.deepEqual(f.db.map(event => event.id), ['event-b']);
});

test('development fallback reads only explicit owner, not legacy familyId', async () => {
  const f = fixture({ dbFailure: true, strict: false });
  const result = await f.request('GET');
  assert.deepEqual(Array.from(result.body.items, event => event.id), ['event-a']);
});

test('development fallback creates with verified owner', async () => {
  const f = fixture({ dbFailure: true, strict: false });
  const result = await f.request('POST', { body: { familyId: 'b' } });
  assert.equal(result.status, 201);
  assert.equal(f.memory[0].userId, 'a');
});

test('development fallback cannot delete foreign or unassigned events', async () => {
  const f = fixture({ dbFailure: true, strict: false });
  assert.equal((await f.request('DELETE', { id: 'event-b' })).status, 404);
  assert.equal((await f.request('DELETE', { id: 'legacy' })).status, 404);
  assert.equal(f.memory.length, 3);
  assert.equal((await f.request('DELETE')).status, 200);
  assert.deepEqual(f.memory.map(event => event.id), ['event-b', 'legacy']);
});

test('malformed, empty or conflicting UID claims are not accepted', async () => {
  for (const userId of ['', null, ['a'], { uid: 'a' }]) {
    const f = fixture();
    assert.equal((await f.request('GET', { query: { userId } })).status, 403);
    assert.deepEqual(f.calls, []);
  }
  assert.equal((await fixture().request('POST', {
    body: { userId: 'a' }, query: { userId: 'b' },
  })).status, 403);
});

test('real Express middleware chain protects GET and optional calendar writes', async t => {
  const app = express();
  app.use(express.json());
  const f = fixture({ app, firebaseRequireAuth: '1' });
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => new Promise((resolve, reject) => {
    server.close(error => error ? reject(error) : resolve());
    server.closeAllConnections();
  }));
  const base = `http://127.0.0.1:${server.address().port}`;
  for (const [method, route] of [
    ['GET', '/calendar/events'], ['POST', '/calendar/events'],
    ['DELETE', '/calendar/events/event-a'],
  ]) {
    const res = await fetch(base + route, { method });
    assert.equal(res.status, 401);
  }
  assert.deepEqual(f.calls, []);
  const denied = await fetch(`${base}/calendar/events?userId=b`, {
    headers: { Authorization: 'Bearer a' },
  });
  assert.equal(denied.status, 403);
  assert.deepEqual(f.calls, []);
  const allowed = await fetch(`${base}/calendar/events`, {
    headers: { Authorization: 'Bearer a' },
  });
  assert.equal(allowed.status, 200);
  assert.deepEqual((await allowed.json()).items.map(event => event.id), ['event-a']);
  assert.ok(f.verifiedTokens.includes('a'));
});
