const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
function fixture({ status = 'reserved', handovers = [
  { requesterId: 'requester', status: 'reserved' },
], failStatusWrite = false, mismatch = false } = {}) {
  let item = { id: 'item', status }, rows = handovers.map(row => ({ treasureId: 'item', ...row }));
  let handler, writes = 0;
  function matches(row, where) {
    return row.treasureId === where.treasureId &&
      (where.requesterId === undefined || row.requesterId === where.requesterId) &&
      where.status.in.includes(row.status);
  }
  const context = {
    app: { post: (_, callback) => { handler = callback; } },
    resolveVerifiedUserId: () => 'requester',
    hasExplicitUserMismatch: () => mismatch,
    console: { error: () => {} },
    prisma: { $transaction: async operation => {
      const pendingItem = { ...item }, pendingRows = rows.map(row => ({ ...row }));
      await operation({
        treasureHandover: {
          findFirst: async ({ where }) => pendingRows.find(row => matches(row, where)),
          updateMany: async ({ where, data }) => {
            const selected = pendingRows.filter(row => matches(row, where));
            selected.forEach(row => Object.assign(row, data));
            return { count: selected.length };
          },
          count: async ({ where }) => pendingRows.filter(row => matches(row, where)).length,
        },
        treasureItem: { updateMany: async ({ where, data }) => {
          writes++;
          if (failStatusWrite) throw new Error('database write unavailable');
          if (pendingItem.id !== where.id || pendingItem.status !== where.status) return { count: 0 };
          Object.assign(pendingItem, data);
          return { count: 1 };
        } },
      });
      item = pendingItem;
      rows = pendingRows;
    } },
  };
  const start = source.indexOf("app.post('/api/treasures/:id/cancel-reservation',");
  const end = source.indexOf('\n});', start) + 4;
  assert.ok(start >= 0 && end > start);
  vm.runInNewContext(source.slice(start, end), context);
  return {
    get item() { return item; }, get rows() { return rows; }, get writes() { return writes; },
    async request() {
      let status = 200, body;
      const res = {
        status(value) { status = value; return res; },
        json(value) { body = value; return res; },
      };
      await handler({ params: { id: 'item' }, body: { requesterUserId: 'requester' } }, res);
      return { status, body };
    },
  };
}

test('own last reservation cancels atomically and repeated cancellation is harmless', async () => {
  const app = fixture();
  assert.equal((await app.request()).status, 200);
  assert.equal(app.rows[0].status, 'cancelled');
  assert.equal(app.item.status, 'available');
  assert.equal((await app.request()).status, 200);
  assert.equal(app.writes, 1);
});

for (const status of ['archived', 'claimed', 'deleted']) {
  test(`${status} is never reactivated, including an old own open handover`, async () => {
    const app = fixture({ status });
    assert.equal((await app.request()).status, 200);
    assert.equal(app.item.status, status);
    const unowned = fixture({ status, handovers: [] });
    assert.equal((await unowned.request()).status, 200);
    assert.equal(unowned.item.status, status);
    assert.equal(unowned.writes, 0);
  });
}

test('another requester cannot cancel or release someone else reservation', async () => {
  const app = fixture({ handovers: [{ requesterId: 'someone-else', status: 'reserved' }] });
  assert.equal((await app.request()).status, 200);
  assert.equal(app.item.status, 'reserved');
  assert.equal(app.rows[0].status, 'reserved');
  assert.equal(app.writes, 0);
});

for (const status of ['pending', 'reserved', 'confirmed']) {
  test(`remaining ${status} handover prevents availability`, async () => {
    const app = fixture({ handovers: [
      { requesterId: 'requester', status: 'reserved' },
      { requesterId: 'someone-else', status },
    ] });
    assert.equal((await app.request()).status, 200);
    assert.equal(app.item.status, 'reserved');
    assert.equal(app.rows[0].status, 'cancelled');
    assert.equal(app.writes, 0);
  });
}

test('own confirmed/completed handover is rejected rather than falsely cancelled', async () => {
  for (const status of ['confirmed', 'completed']) {
    const app = fixture({ status: status === 'confirmed' ? 'claimed' : 'archived',
      handovers: [{ requesterId: 'requester', status }] });
    assert.equal((await app.request()).status, 409);
    assert.equal(app.rows[0].status, status);
    assert.equal(app.writes, 0);
  }
});

test('failed status write returns 500 and rolls back cancellation', async () => {
  const app = fixture({ failStatusWrite: true });
  const result = await app.request();
  assert.equal(result.status, 500);
  assert.equal(result.body.success, undefined);
  assert.equal(app.item.status, 'reserved');
  assert.equal(app.rows[0].status, 'reserved');
});

test('explicit account mismatch remains rejected', async () => {
  const app = fixture({ mismatch: true });
  assert.equal((await app.request()).status, 403);
  assert.equal(app.writes, 0);
});
