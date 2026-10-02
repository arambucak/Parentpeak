const assert = require('node:assert/strict');
const test = require('node:test');
const { changeParticipation, validateEventMode } = require('../../event_participation_policy');

function fixture(overrides = {}, initial = []) {
  const event = { id: 'event', hosterId: 'host', participationMode: 'direct',
    status: 'upcoming', startDate: '2099-01-01', maxParticipants: 1, ...overrides };
  let rows = initial.map(item => ({ ...item }));
  let queue = Promise.resolve();
  const prisma = { $transaction: operation => {
    const pending = queue.then(async () => {
      const snapshot = rows.map(item => ({ ...item }));
      const transaction = {
        $queryRaw: async (strings) => { assert.match(strings.join(''), /FOR UPDATE/); },
        event: { findUnique: async () => event },
        eventParticipation: {
          findUnique: async ({ where }) => rows.find(item => item.userId === where.eventId_userId.userId) || null,
          count: async ({ where }) => rows.filter(item => where.status.in.includes(item.status)).length,
          update: async ({ where, data }) => Object.assign(rows.find(item => item.id === where.id), data),
          upsert: async ({ create, update }) => {
            if (event.writeFailure) throw new Error('write failed');
            const current = rows.find(item => item.userId === create.userId);
            if (current) return Object.assign(current, update);
            const item = { id: create.userId, ...create }; rows.push(item); return item;
          },
        },
      };
      try { return await operation(transaction); } catch (error) { rows = snapshot; throw error; }
    });
    queue = pending.catch(() => {});
    return pending;
  } };
  return { rows: () => rows, change: (userId, action, authorize) =>
    changeParticipation(prisma, { eventId: 'event', userId, action, authorize }) };
}

test('concurrent duplicate last-slot joins are idempotent; other parent gets 409', async () => {
  const route = fixture();
  const results = await Promise.allSettled([route.change('parent'), route.change('parent'), route.change('other')]);
  assert.equal(results[0].value.status, 'approved');
  assert.equal(results[1].value.id, results[0].value.id);
  assert.equal(results[2].reason.httpStatus, 409);
  assert.equal(route.rows().length, 1);
});
test('withdraw is idempotent, frees capacity and allows rejoining', async () => {
  const route = fixture();
  await route.change('parent');
  await route.change('parent', 'withdraw');
  await route.change('parent', 'withdraw');
  assert.equal((await route.change('parent')).status, 'approved');
  assert.equal(route.rows().length, 1);
});
test('interest is not confirmed attendance and ignores capacity', async () => {
  const route = fixture({ participationMode: 'interest', maxParticipants: 0 });
  assert.equal((await route.change('parent')).status, 'interested');
  assert.equal((await route.change('other')).status, 'interested');
  assert.equal(route.rows().filter(item => item.status === 'approved').length, 0);
});
test('existing pending is never automatically approved even in direct mode', async () => {
  const route = fixture({}, [{ id: 'pending', userId: 'parent', status: 'pending' }]);
  assert.equal((await route.change('parent')).status, 'pending');
});
test('legacy defaults to pending', async () => {
  assert.equal((await fixture({ participationMode: null }).change('parent')).status, 'pending');
});
test('host cannot join and closed events cannot accept joins', async () => {
  await assert.rejects(fixture().change('host'), { httpStatus: 403 });
  for (const status of ['cancelled', 'completed']) {
    await assert.rejects(fixture({ status }).change('parent'), { httpStatus: 409 });
  }
  await assert.rejects(fixture({ startDate: '2000-01-01' }).change('parent'), { httpStatus: 409 });
});
test('rollback on write failure and unauthorized action keeps rows unchanged', async () => {
  const route = fixture({ writeFailure: true });
  await assert.rejects(route.change('parent'), /write failed/);
  assert.equal(route.rows().length, 0);
  await assert.rejects(fixture().change('parent', 'withdraw', () => {
    const error = new Error('Forbidden'); error.httpStatus = 403; throw error;
  }), { httpStatus: 403 });
});
test('legacy host approval uses capacity; interests cannot be approved', async () => {
  const pending = [{ id: 'one', userId: 'parent', status: 'pending' }];
  assert.equal((await fixture({ participationMode: 'legacyApproval' }, pending).change('parent', 'approve')).status, 'approved');
  await assert.rejects(fixture({ participationMode: 'interest' }, pending).change('parent', 'approve'), { httpStatus: 409 });
  await assert.rejects(fixture({ maxParticipants: 0 }, pending).change('parent', 'approve'), { httpStatus: 409 });
});
test('invitation acceptance shares last-slot locking and remains idempotent', async () => {
  const route = fixture({ participationMode: 'legacyApproval' });
  const result = await Promise.allSettled([
    route.change('parent', 'acceptInvite'), route.change('parent', 'acceptInvite'),
    route.change('other', 'acceptInvite'),
  ]);
  assert.equal(result[0].value.status, 'accepted');
  assert.equal(result[1].value.id, result[0].value.id);
  assert.equal(result[2].reason.httpStatus, 409);
});
test('invitation cannot automatically approve pending or turn interest into attendance', async () => {
  const route = fixture({}, [{ id: 'pending', userId: 'parent', status: 'pending' }]);
  assert.equal((await route.change('parent', 'acceptInvite')).status, 'pending');
  await assert.rejects(fixture({ participationMode: 'interest' }).change('parent', 'acceptInvite'), { httpStatus: 409 });
});
test('mode and structured URL contracts reject malformed input', () => {
  validateEventMode('direct', null);
  validateEventMode('legacyApproval', null);
  validateEventMode('interest', 'https://organizer.example/events/one');
  for (const [mode, url] of [['bogus', null], ['interest', null], ['interest', 'javascript:alert(1)'],
    ['interest', 'https://user:pass@example.org'], ['interest', 'not a url'], ['direct', 'https://example.org'],
    ['interest', ['https://example.org']], ['interest', ' https://example.org'], ['interest', 'https://example.org/' + 'a'.repeat(2048)]]) {
    assert.throws(() => validateEventMode(mode, url), { httpStatus: 400 });
  }
});