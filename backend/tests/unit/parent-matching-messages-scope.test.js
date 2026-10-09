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

// PR D: Legacy-Parent-Matching-Nachrichtenrouten verlangen jetzt eine
// verifizierte Identität (requireVerifiedUser) und leiten die handelnde UID aus
// dem Token ab — nicht mehr aus frei behaupteter query/body.userId.
const messageRoutes = [
  ['GET', '/parent-matching/messages/stream'],
  ['GET', '/parent-matching/messages'],
  ['POST', '/parent-matching/messages'],
];

function fixture({ app, configured = true } = {}) {
  const handlers = new Map();
  const context = vm.createContext({
    DEMO_FAMILY_ID: 'demo-family-001',
    // Nachrichten-Helfer werden gemockt: ein Mutual-Match für userId 'a' auf
    // profileId 'p-match', sonst nichts.
    getMyParentMatchingProfile: async uid => (uid === 'a' ? { id: 'own-a' } : null),
    getMutualConnectionProfileIds: async (familyId, uid) =>
      uid === 'a' ? ['p-match'] : [],
    getMyParentMatchingProfileInMemory: uid => (uid === 'a' ? { id: 'own-a' } : null),
    getMutualConnectionProfileIdsInMemory: (familyId, uid) =>
      uid === 'a' ? ['p-match'] : [],
    parentMatchingStreamKey: (familyId, profileId) => `${familyId}::${profileId}`,
    parentMatchingMessageSubscribers: new Map(),
    parentMatchingMessages: [],
    ensureParentMatchingSchemaReady: async () => {},
    publishParentMatchingMessage: () => {},
    respondWithStrictPersistenceError: () => false,
    generateId: prefix => `${prefix}-new`,
    prisma: {
      $queryRaw: async () => [],
      $executeRaw: async () => 1,
    },
    firebaseAdmin: configured ? { auth: () => ({
      verifyIdToken: async token => {
        if (!['a', 'b'].includes(token)) throw new Error('Invalid');
        return { uid: token };
      },
    }) } : null,
    console: { error: () => {}, log: () => {} },
    process: { env: { NODE_ENV: 'production', FIREBASE_REQUIRE_AUTH: '1' } },
    setInterval: () => 0,
    clearInterval: () => {},
    app: app || Object.fromEntries(['get', 'post', 'put', 'delete'].map(method => [
      method, (route, ...chain) => handlers.set(`${method.toUpperCase()} ${route}`, chain),
    ])),
  });
  vm.runInContext(slice('async function verifyFirebaseIdToken(', 'function resolveVerifiedUserId('), context);
  vm.runInContext(slice('class FamilyContextError', 'async function ensurePaymentContext('), context);
  vm.runInContext(slice('const firebaseRequireAuth =', '\n// Middleware'), context);
  vm.runInContext(
    slice("app.get('/parent-matching/messages/stream'", '// ─── Durable friend list'),
    context,
  );

  async function request(method, route, { token = 'a', query = {}, body = {} } = {}) {
    let status = 200, response, headers = {}, writes = [];
    const req = {
      method, path: route,
      headers: token === null ? {} : { authorization: `Bearer ${token}` },
      query, body,
      on: () => {},
    };
    const res = {
      status(value) { status = value; return res; },
      json(value) { response = value; return res; },
      send() { return res; },
      setHeader(k, v) { headers[k] = v; },
      flushHeaders() {},
      write(chunk) { writes.push(chunk); return true; },
    };
    const chain = handlers.get(`${method} ${route}`);
    const run = i => chain[i](req, res, () => run(i + 1));
    await run(0);
    return { status, body: response, headers, writes };
  }
  return { context, request, handlers };
}

for (const [method, route] of messageRoutes) {
  for (const token of [null, 'invalid', 'expired', 'shared']) {
    test(`${method} ${route} rejects ${token ?? 'missing'} token`, async () => {
      const f = fixture();
      const result = await f.request(method, route, {
        token, query: { profileId: 'p-match' }, body: { profileId: 'p-match', content: 'hi' },
      });
      assert.equal(result.status, 401);
    });
  }

  test(`${method} ${route} rejects missing Admin configuration`, async () => {
    const f = fixture({ configured: false });
    const result = await f.request(method, route, {
      query: { profileId: 'p-match' }, body: { profileId: 'p-match', content: 'hi' },
    });
    assert.equal(result.status, 401);
  });

  for (const field of ['query', 'body']) {
    test(`${method} ${route} rejects foreign ${field} userId claim`, async () => {
      const f = fixture();
      const result = await f.request(method, route, {
        token: 'a',
        [field]: { profileId: 'p-match', content: 'hi', userId: 'b' },
      });
      assert.equal(result.status, 403);
    });
  }
}

// Nutzer ohne Mutual-Match darf nicht lesen/schreiben.
test('GET messages without a mutual match is 403', async () => {
  const f = fixture();
  const result = await f.request('GET', '/parent-matching/messages', {
    token: 'a', query: { profileId: 'p-other' },
  });
  assert.equal(result.status, 403);
});

test('POST message without a mutual match is 403', async () => {
  const f = fixture();
  const result = await f.request('POST', '/parent-matching/messages', {
    token: 'a', body: { profileId: 'p-other', content: 'hi' },
  });
  assert.equal(result.status, 403);
});

// Verifizierter Nutzer mit Mutual-Match darf (handelnde UID aus Token).
test('verified user with mutual match can read own matched conversation', async () => {
  const f = fixture();
  const result = await f.request('GET', '/parent-matching/messages', {
    token: 'a', query: { profileId: 'p-match' },
  });
  assert.equal(result.status, 200);
  assert.ok(Array.isArray(result.body.items));
});

test('verified user with mutual match can post (author from token)', async () => {
  const f = fixture();
  const result = await f.request('POST', '/parent-matching/messages', {
    token: 'a', body: { profileId: 'p-match', content: 'Hallo' },
  });
  assert.equal(result.status, 201);
  assert.equal(result.body.item.authorUserId, 'a');
});

// Echte Express-Kette: GET-Stream ohne Token nicht erreichbar.
test('real Express chain protects the SSE stream', async t => {
  const app = express(); app.use(express.json());
  fixture({ app });
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => new Promise(resolve => { server.close(resolve); server.closeAllConnections(); }));
  const base = `http://127.0.0.1:${server.address().port}`;
  assert.equal((await fetch(`${base}/parent-matching/messages/stream?profileId=p-match`)).status, 401);
});
