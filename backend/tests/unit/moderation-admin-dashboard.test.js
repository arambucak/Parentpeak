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

// Liefert eine isolierte Umgebung, in der requireAdmin, die /admin/reports-Query
// (m1) und die /admin/profiles/:userId/deactivate-Route (m2) laufen. Die Handler
// werden ueber den app.post/app.get-Mock eingesammelt und per call() ausgefuehrt.
function fixture({ adminUids = ['admin-1'], groupRows = [], updateManyResult = { count: 0 } } = {}) {
  const routes = new Map();
  const updates = [];
  const context = {
    ...require('../../moderation'),
    loadAdditionalReports: async () => [],
    console: { error: () => {}, log: () => {}, warn: () => {} },
    Set, Map, Array, Number, Date,
    app: {
      get: (url, ...chain) => routes.set(`GET ${url}`, chain),
      post: (url, ...chain) => routes.set(`POST ${url}`, chain),
    },
    adminUserIds: new Set(adminUids),
    verifyFirebaseIdToken: async req => ({
      verified: typeof req.tokenUid === 'string', uid: req.tokenUid,
    }),
    ensureSocialSchemaReady: async () => {},
    ensureParentMatchingSchemaReady: async () => {},
    respondWithStrictPersistenceError: () => false,
    safetyReports: [],
    safetySuspensions: new Map(),
    prisma: {
      $queryRawUnsafe: async (sql) => {
        if (sql.includes('GROUP BY r."reportedUserId"')) return groupRows;
        return [];
      },
      parentMatchingProfile: {
        updateMany: async args => { updates.push(args); return updateManyResult; },
      },
    },
  };
  vm.createContext(context);
  vm.runInContext(slice('async function requireAdmin(', '// Liste aller Meldungen'), context);
  vm.runInContext(slice("app.get('/admin/reports'", '// Meldung(en) als geprueft'), context);
  vm.runInContext(
    slice("app.post('/admin/profiles/:userId/deactivate'", '// ─── Admin: Cleanup kaputter'),
    context,
  );

  async function call(route, tokenUid, { body = {}, params = {}, query = {} } = {}) {
    let status = 200;
    let payload;
    const req = { tokenUid, body, params, query, headers: {} };
    const res = {
      status(code) { status = code; return res; },
      json(value) { payload = value; return res; },
    };
    const chain = routes.get(route);
    assert.ok(chain, `Route not registered: ${route}`);
    const run = async i => { if (chain[i]) await chain[i](req, res, () => run(i + 1)); };
    await run(0);
    return { status, body: payload };
  }
  return { call, updates };
}

// ── m1: /admin/reports ──────────────────────────────────────────────────────

test('GET /admin/reports query exposes the matching profile fields (m1)', () => {
  const block = slice("app.get('/admin/reports'", '// Meldung(en) als geprueft');
  for (const col of ['"distinctReporters"', '"profileName"', '"profileCity"', '"profileBio"', '"profileActive"']) {
    assert.ok(block.includes(col), `Query is missing ${col}`);
  }
  assert.ok(block.includes('COUNT(DISTINCT r."reporterUserId")'), 'distinctReporters must count distinct reporters');
  assert.ok(block.includes('"ParentMatchingProfile" pm'), 'Query must join the matching profile');
  assert.ok(block.includes('ORDER BY BOOL_OR(LOWER(BTRIM(r."reason")) IN'), 'Critical groups must precede the database limit');
});

test('GET /admin/reports returns the enriched group rows to the client (m1)', async () => {
  const group = {
    reportedUserId: 'owner-b',
    reportCount: 4,
    distinctReporters: 3,
    profileName: 'Mara',
    profileCity: 'Köln',
    profileBio: 'Mama von zwei',
    profileActive: true,
  };
  const { call } = fixture({ groupRows: [group] });
  const result = await call('GET /admin/reports', 'admin-1', { query: { status: 'pending' } });
  assert.equal(result.status, 200);
  const payload = JSON.parse(JSON.stringify(result.body));
  assert.equal(payload.groups.length, 1);
  assert.deepEqual(payload.groups[0], { ...group, lastReason: 'other', severity: 'normal' });
});

test('GET /admin/reports requires an admin token (m1)', async () => {
  const { call } = fixture({ groupRows: [] });
  const anon = await call('GET /admin/reports', undefined, {});
  assert.equal(anon.status, 401);
  const nonAdmin = await call('GET /admin/reports', 'random-user', {});
  assert.equal(nonAdmin.status, 403);
});

// ── m2: /admin/profiles/:userId/deactivate ───────────────────────────────────

test('POST /admin/profiles/:userId/deactivate flips isActive to false (m2)', async () => {
  const { call, updates } = fixture({ updateManyResult: { count: 2 } });
  const result = await call('POST /admin/profiles/:userId/deactivate', 'admin-1', {
    params: { userId: 'owner-b' },
  });
  assert.equal(result.status, 200);
  assert.equal(result.body.ok, true);
  assert.equal(result.body.deactivated, 2);
  assert.equal(updates.length, 1);
  assert.deepEqual(JSON.parse(JSON.stringify(updates[0])), {
    where: { ownerUserId: 'owner-b' },
    data: { isActive: false },
  });
});

test('POST /admin/profiles/:userId/deactivate rejects non-admins and never writes (m2)', async () => {
  const { call, updates } = fixture({});
  const anon = await call('POST /admin/profiles/:userId/deactivate', undefined, {
    params: { userId: 'owner-b' },
  });
  assert.equal(anon.status, 401);
  const nonAdmin = await call('POST /admin/profiles/:userId/deactivate', 'random-user', {
    params: { userId: 'owner-b' },
  });
  assert.equal(nonAdmin.status, 403);
  assert.equal(updates.length, 0);
});

test('POST /admin/profiles/:userId/deactivate needs a userId (m2)', async () => {
  const { call, updates } = fixture({});
  const result = await call('POST /admin/profiles/:userId/deactivate', 'admin-1', {
    params: { userId: '  ' },
  });
  assert.equal(result.status, 400);
  assert.equal(updates.length, 0);
});
