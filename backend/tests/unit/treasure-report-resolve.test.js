const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
const start = source.indexOf("app.post('/api/treasures/reports/:reportId/resolve'");
const end = source.indexOf('/**\n * GET /api/treasures/:id', start);
assert.ok(start >= 0 && end > start);

function fixture() {
  const routes = new Map();
  const treasureUpdates = [];
  const context = {
    console: { error: () => {} },
    app: { post: (url, ...chain) => routes.set(`POST ${url}`, chain) },
    requireAdmin: (req, res, next) => (
      req.isAdmin ? next() : res.status(401).json({ error: 'Anmeldung erforderlich' })
    ),
    prisma: {
      treasureReport: {
        findUnique: async () => ({ id: 'r1', treasureId: 't1' }),
        update: async ({ data }) => ({ id: 'r1', ...data }),
      },
      treasureItem: {
        updateMany: async args => { treasureUpdates.push(args); return { count: 1 }; },
      },
    },
  };
  vm.createContext(context);
  vm.runInContext(source.slice(start, end), context);
  async function call(body, isAdmin = true) {
    let status = 200;
    let payload;
    const req = { isAdmin, body, params: { reportId: 'r1' } };
    const res = {
      status(code) { status = code; return res; },
      json(value) { payload = value; return res; },
    };
    const chain = routes.get('POST /api/treasures/reports/:reportId/resolve');
    const run = async i => { if (chain[i]) await chain[i](req, res, () => run(i + 1)); };
    await run(0);
    return { status, body: payload };
  }
  return { call, treasureUpdates };
}

test('resolve requires admin access', async () => {
  const { call, treasureUpdates } = fixture();
  assert.equal((await call({ action: 'resolved' }, false)).status, 401);
  assert.equal(treasureUpdates.length, 0);
});

test('resolved report archives the reported listing', async () => {
  const { call, treasureUpdates } = fixture();
  const result = await call({ action: 'resolved' });
  assert.equal(result.status, 200);
  assert.equal(result.body.listingAction, 'archived');
  assert.equal(treasureUpdates[0].where.id, 't1');
  assert.equal(treasureUpdates[0].data.status, 'archived');
});

test('resolved report can opt out of archiving', async () => {
  const { call, treasureUpdates } = fixture();
  const result = await call({ action: 'resolved', archiveListing: false });
  assert.equal(result.body.listingAction, 'none');
  assert.equal(treasureUpdates.length, 0);
});

test('dismissed report only restores a listing on explicit request', async () => {
  const plain = fixture();
  assert.equal((await plain.call({ action: 'dismissed' })).body.listingAction, 'none');
  assert.equal(plain.treasureUpdates.length, 0);
  const restore = fixture();
  const result = await restore.call({ action: 'dismissed', restoreListing: true });
  assert.equal(result.body.listingAction, 'restored');
  assert.equal(restore.treasureUpdates[0].data.status, 'available');
  assert.equal(restore.treasureUpdates[0].where.status, 'archived');
});
