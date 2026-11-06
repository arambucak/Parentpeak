const assert = require('node:assert/strict');
const test = require('node:test');
const { createModerationService } = require('../../moderation');

// Minimaler prisma-Mock: beantwortet die Digest-Aggregat-Query mit konfigurierten
// offenen Meldungen. CREATE TABLE/INDEX/ALTER werden geschluckt.
function fixture({ pending = [], env = {}, emailResult = true, failEmail = false } = {}) {
  const emails = [];
  const errors = [];
  const prisma = {
    async $executeRawUnsafe() { return 1; },
    async $queryRawUnsafe(sql) {
      if (sql.includes('FROM "ModerationReport"') && sql.includes("'pending'")
        && sql.includes('GROUP BY')) {
        return pending;
      }
      return [];
    },
  };
  const service = createModerationService({
    prisma, env, adminUserIds: new Set(['a']),
    logger: { error: (...a) => errors.push(a) },
    sendEmail: async email => {
      emails.push(email);
      if (failEmail) throw new Error('mail unavailable');
      return emailResult;
    },
    sendPushToUser: async () => true,
  });
  return { service, emails, errors };
}

const row = (over = {}) => ({
  source: 'safety', targetId: 't1', reportCount: 1, distinctReporters: 1,
  critical: false, oldestAt: '2026-11-06T08:00:00.000Z',
  newestAt: '2026-11-06T08:00:00.000Z', ...over,
});

test('digest skips when nothing actionable is pending', async () => {
  const { service, emails } = fixture({ pending: [] });
  const result = await service.sendPendingDigest();
  assert.equal(result.sent, false);
  assert.equal(result.pendingCount, 0);
  assert.equal(emails.length, 0);
});

test('a single normal report below threshold is NOT included', async () => {
  const { service, emails } = fixture({
    pending: [row({ critical: false, distinctReporters: 1 })],
  });
  const result = await service.sendPendingDigest();
  assert.equal(result.sent, false);
  assert.equal(emails.length, 0);
});

test('a critical report is always included, even with one reporter', async () => {
  const { service, emails } = fixture({
    pending: [row({ critical: true, distinctReporters: 1 })],
  });
  const result = await service.sendPendingDigest();
  assert.equal(result.sent, true);
  assert.equal(result.pendingCount, 1);
  assert.equal(result.criticalCount, 1);
  assert.equal(emails.length, 1);
  assert.match(emails[0].subject, /kritisch/);
  assert.match(emails[0].text, /\[KRITISCH\]/);
});

test('normal reports are included once the reporter threshold is reached', async () => {
  const { service, emails } = fixture({
    env: { PARENT_MATCHING_REPORT_HIDE_THRESHOLD: '3' },
    pending: [row({ critical: false, distinctReporters: 3 })],
  });
  const result = await service.sendPendingDigest();
  assert.equal(result.sent, true);
  assert.equal(result.criticalCount, 0);
  assert.equal(emails.length, 1);
});

test('one digest email summarizes several pending targets', async () => {
  const { service, emails } = fixture({
    pending: [
      row({ source: 'safety', targetId: 't1', critical: true, distinctReporters: 1 }),
      row({ source: 'event_chat', targetId: 'm9', critical: false, distinctReporters: 4 }),
    ],
  });
  const result = await service.sendPendingDigest();
  assert.equal(result.sent, true);
  assert.equal(result.pendingCount, 2);
  assert.equal(emails.length, 1, 'genau EINE Sammel-Mail');
});

test('digest surfaces email delivery failure to the caller', async () => {
  const { service, emails } = fixture({
    failEmail: true,
    pending: [row({ critical: true })],
  });
  await assert.rejects(() => service.sendPendingDigest(), /nicht versendet|mail unavailable/);
  assert.equal(emails.length, 1, 'Versand wurde versucht');
});

test('digest treats a false email result as failure', async () => {
  const { service } = fixture({
    emailResult: false,
    pending: [row({ critical: true })],
  });
  await assert.rejects(() => service.sendPendingDigest(), /nicht versendet/);
});
