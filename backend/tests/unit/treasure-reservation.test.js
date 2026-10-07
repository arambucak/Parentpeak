const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');

function fixture({ status = 'available', requester = 'requester', handovers = [],
  mismatch = false, missingUser = false, raceOwner, failRetryLookup = false } = {}) {
  const item = { id: 'item', userId: 'giver', title: 'A book', status };
  const reservations = handovers.map(value => ({ treasureId: 'item', ...value }));
  let handler, transactions = 0, creates = 0, pushes = 0, reads = 0;
  const context = {
    app: { post: (_, callback) => { handler = callback; } },
    resolveVerifiedUserId: () => requester,
    hasExplicitUserMismatch: () => mismatch,
    sendPushToUser: async () => { pushes++; },
    console: { error: () => {} },
    prisma: {
      treasureItem: {
        findUnique: async () => {
          if (++reads > 1 && failRetryLookup) throw new Error('lookup unavailable');
          return { ...item };
        },
      },
      user: { findUnique: async () => missingUser ? null : { id: requester } },
      treasureHandover: {
        findFirst: async ({ where }) => reservations.find(value =>
          value.treasureId === where.treasureId &&
          value.requesterId === where.requesterId &&
          where.status.in.includes(value.status)) ?? null,
      },
      $transaction: async operation => {
        transactions++;
        if (raceOwner) {
          item.status = 'reserved';
          reservations.push({ id: 'raced', treasureId: 'item',
            requesterId: raceOwner, status: 'reserved' });
        }
        return operation({
          treasureItem: { updateMany: async ({ where, data }) => {
            if (item.status !== where.status) return { count: 0 };
            Object.assign(item, data);
            return { count: 1 };
          } },
          treasureHandover: { create: async ({ data }) => {
            creates++;
            const value = { id: 'created', ...data };
            reservations.push(value);
            return value;
          } },
        });
      },
    },
  };
  const start = source.indexOf("app.post('/api/treasures/:id/reserve',");
  const end = source.indexOf('\n});', start) + 4;
  assert.ok(start >= 0 && end > start);
  vm.runInNewContext(source.slice(start, end), context);
  return {
    get creates() { return creates; },
    get transactions() { return transactions; },
    get pushes() { return pushes; },
    async request() {
      let status = 200, body;
      const res = {
        status(value) { status = value; return res; },
        json(value) { body = value; return res; },
      };
      await handler({ params: { id: 'item' }, body: {
        requesterUserId: requester, preferredSlot: 'sunday_morning', handoverMode: 'coffee',
      } }, res);
      return { status, body };
    },
  };
}

test('first reserve and sequential retry return same handover, only one write and push', async () => {
  const app = fixture();
  const first = await app.request();
  const repeat = await app.request();
  assert.equal(first.status, 201);
  assert.equal(first.body.alreadyReserved, false);
  assert.equal(repeat.status, 200);
  assert.equal(repeat.body.alreadyReserved, true);
  assert.equal(repeat.body.handover.id, first.body.handover.id);
  assert.equal(app.transactions, 1);
  assert.equal(app.creates, 1);
  assert.equal(app.pushes, 1);
});

for (const status of ['pending', 'reserved']) {
  test(`own existing ${status} reservation is idempotent`, async () => {
    const app = fixture({ status: 'reserved',
      handovers: [{ id: 'mine', requesterId: 'requester', status }] });
    const result = await app.request();
    assert.equal(result.status, 200);
    assert.equal(result.body.handover.id, 'mine');
    assert.equal(app.transactions, 0);
    assert.equal(app.pushes, 0);
  });
}

for (const status of ['archived', 'claimed', 'deleted']) {
  test(`${status} cannot be bypassed by an old handover`, async () => {
    const app = fixture({ status,
      handovers: [{ id: 'old', requesterId: 'requester', status: 'reserved' }] });
    assert.equal((await app.request()).status, 410);
    assert.equal(app.transactions, 0);
  });
}

test('other account reservation is not returned and cannot be claimed', async () => {
  const app = fixture({ status: 'reserved',
    handovers: [{ id: 'private', requesterId: 'someone-else', status: 'reserved' }] });
  const result = await app.request();
  assert.equal(result.status, 410);
  assert.equal(result.body.handover, undefined);
  assert.equal(app.transactions, 0);
});

test('cancelled or completed handovers are not successful retries', async () => {
  for (const status of ['cancelled', 'completed', 'confirmed']) {
    const app = fixture({ status: 'reserved',
      handovers: [{ id: 'old', requesterId: 'requester', status }] });
    assert.equal((await app.request()).status, 410);
    assert.equal(app.creates, 0);
  }
});

test('auth mismatch, missing registered requester and self reservation remain rejected', async () => {
  for (const [options, expected] of [
    [{ mismatch: true }, 403], [{ missingUser: true }, 404],
    [{ requester: 'giver' }, 400],
  ]) {
    const app = fixture(options);
    assert.equal((await app.request()).status, expected);
    assert.equal(app.transactions, 0);
  }
});

test('same-account race returns committed handover, competing race stays unavailable', async () => {
  const mine = fixture({ raceOwner: 'requester' });
  const result = await mine.request();
  assert.equal(result.status, 200);
  assert.equal(result.body.handover.id, 'raced');
  assert.equal(mine.creates, 0);
  assert.equal(mine.pushes, 0);
  const other = fixture({ raceOwner: 'someone-else' });
  assert.equal((await other.request()).status, 410);
});

test('failed race lookup is an explicit server error, never successful fallback', async () => {
  const app = fixture({ raceOwner: 'requester', failRetryLookup: true });
  assert.equal((await app.request()).status, 500);
  assert.equal(app.creates, 0);
  assert.equal(app.pushes, 0);
});
