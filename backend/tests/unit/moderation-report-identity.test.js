const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');

function slice(start, end) {
  const a = source.indexOf(start);
  const b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `Missing block: ${start}`);
  return source.slice(a, b);
}

function fixture() {
  const routes = new Map();
  const inserts = [];
  const flags = [];
  const context = {
    console: { error: () => {}, log: () => {} },
    app: {
      post: (url, ...chain) => routes.set(`POST ${url}`, chain),
    },
    verifyFirebaseIdToken: async req => ({
      verified: ['a', 'b'].includes(req.tokenUid), uid: req.tokenUid,
    }),
    ensureSocialSchemaReady: async () => {},
    generateId: prefix => `${prefix}_1`,
    respondWithStrictPersistenceError: () => false,
    safetyReports: [],
    prisma: {
      $executeRawUnsafe: async (sql, ...args) => { inserts.push(args); },
      $queryRawUnsafe: async () => [{ n: 1 }],
      communityEvent: {
        findUnique: async () => ({ id: 'ev1' }),
        update: async () => ({}),
      },
      communityEventFlag: {
        upsert: async args => { flags.push(args.create.userId); },
        count: async () => 1,
      },
    },
  };
  vm.createContext(context);
  vm.runInContext(slice('async function requireVerifiedUser(', 'function resolveVerifiedUserId('), context);
  vm.runInContext(slice("app.post('/api/safety/report'", '// ─── Moderations-Dashboard'), context);
  vm.runInContext(slice("app.post('/api/community-events/:id/flag'", '/**\n * POST /api/community-events/:id/interest'), context);
  async function call(route, tokenUid, body, params = {}) {
    let status = 200;
    let payload;
    const req = { tokenUid, body, params, query: {}, headers: {} };
    const res = {
      status(code) { status = code; return res; },
      json(value) { payload = value; return res; },
    };
    const chain = routes.get(route);
    const run = async i => { if (chain[i]) await chain[i](req, res, () => run(i + 1)); };
    await run(0);
    return { status, body: payload };
  }
  return { call, inserts, flags };
}

test('POST /api/safety/report requires a verified token', async () => {
  const { call, inserts } = fixture();
  for (const uid of [undefined, 'invalid']) {
    const result = await call('POST /api/safety/report', uid, { reportedUserId: 'b', reason: 'spam' });
    assert.equal(result.status, 401);
  }
  assert.equal(inserts.length, 0);
});

test('POST /api/safety/report rejects a spoofed reporter and records the token uid', async () => {
  const { call, inserts } = fixture();
  const spoofed = await call('POST /api/safety/report', 'a', {
    reporterUserId: 'b', reportedUserId: 'c', reason: 'spam',
  });
  assert.equal(spoofed.status, 403);
  assert.equal(inserts.length, 0);
  const own = await call('POST /api/safety/report', 'a', { reportedUserId: 'c', reason: 'spam' });
  assert.equal(own.status, 200);
  assert.equal(inserts[0][1], 'a');
});

test('POST /api/community-events/:id/flag counts the token uid, not the body uid', async () => {
  const { call, flags } = fixture();
  const anonymous = await call('POST /api/community-events/:id/flag', undefined,
    { userId: 'x', reason: 'spam' }, { id: 'ev1' });
  assert.equal(anonymous.status, 401);
  const spoofed = await call('POST /api/community-events/:id/flag', 'a',
    { userId: 'fake-1', reason: 'spam' }, { id: 'ev1' });
  assert.equal(spoofed.status, 403);
  assert.equal(flags.length, 0);
  const own = await call('POST /api/community-events/:id/flag', 'a',
    { reason: 'spam' }, { id: 'ev1' });
  assert.equal(own.status, 200);
  assert.deepEqual(flags, ['a']);
});
