const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const {
  normalizeReportReason, reasonSeverity, reasonLabelDe, withReportSeverity, criticalFirst,
  createModerationService, buildModerationOverview,
} = require('../../moderation');

function database() {
  const reports = new Map();
  const claims = new Map();
  const writes = [];
  let now = 0;
  const prisma = {
    async $executeRawUnsafe(sql, ...args) {
      writes.push({ sql, args });
      if (sql.includes('INSERT INTO "ModerationReport"')) {
        const [id, source, targetId, reporterUserId, reason] = args;
        if (!reports.has(id)) reports.set(id, { id, source, targetId, reporterUserId, reason });
      }
      if (sql.includes('UPDATE "ModerationNotificationClaim"')) {
        const [key, token, cooldown] = args;
        if (claims.get(key)?.token === token) claims.set(key, { token: null, expires: cooldown ? now + 900000 : null });
      }
      if (sql.includes('DELETE FROM "ModerationNotificationClaim"')) {
        const [key, token] = args;
        if (claims.get(key)?.token === token) claims.delete(key);
      }
      return 1;
    },
    async $queryRawUnsafe(sql, ...args) {
      if (sql.includes('INSERT INTO "ModerationNotificationClaim"')) {
        const [key, token] = args;
        if (claims.has(key) && (claims.get(key).expires === null || claims.get(key).expires > now)) return [];
        claims.set(key, { token, expires: now + 60000 });
        return [{ key }];
      }
      if (sql.includes('COUNT(DISTINCT reporter)')) {
        const [source, targetId] = args;
        return [{ n: new Set([...reports.values()]
          .filter(row => row.source === source && row.targetId === targetId)
          .map(row => row.reporterUserId)).size }];
      }
      return [];
    },
  };
  return { prisma, reports, claims, writes, advance: ms => { now += ms; } };
}

function fixture({ db = database(), env = {}, failEmail = false, failPush = false, admins = ['a', 'b'],
  emailResult = true, pushResult, hangEmail = false, hangPush = false } = {}) {
  const emails = [];
  const pushes = [];
  const errors = [];
  const service = createModerationService({
    prisma: db.prisma, env, adminUserIds: new Set(admins),
    logger: { error: (...args) => errors.push(args) },
    sendEmail: async email => {
      emails.push(email);
      if (hangEmail) return new Promise(() => {});
      if (failEmail) throw new Error('mail unavailable');
      return emailResult;
    },
    sendPushToUser: async (uid, push) => {
      pushes.push({ uid, ...push });
      if (hangPush) return new Promise(() => {});
      if (failPush) throw new Error('push unavailable');
      return pushResult;
    },
  });
  return { ...service, db, emails, pushes, errors };
}

function report(overrides = {}) {
  return { id: 'one', source: 'safety', targetId: 'target', reporterUserId: 'r1', reason: 'spam', ...overrides };
}

test('canonical mappings, normal ambiguous unsafe, and event-only expired compatibility', () => {
  const mappings = {
    insult: 'harassment', hostile: 'harassment', fake: 'fraud',
    false_info: 'misinformation', unsafe: 'inappropriate',
  };
  for (const [legacy, canonical] of Object.entries(mappings)) {
    assert.equal(normalizeReportReason(` ${legacy.toUpperCase()} `), canonical);
    assert.equal(reasonSeverity(legacy), 'normal');
  }
  for (const reason of ['child_safety', 'sexual_content', 'violence_threat', 'self_harm']) {
    assert.equal(normalizeReportReason(reason), reason);
    assert.equal(reasonSeverity(reason), 'critical');
  }
  for (const reason of ['harassment', 'spam', 'fraud', 'inappropriate', 'misinformation', 'other']) {
    assert.equal(normalizeReportReason(reason), reason);
    assert.equal(reasonSeverity(reason), 'normal');
  }
  assert.equal(normalizeReportReason('unknown'), 'other');
  assert.equal(normalizeReportReason('__proto__'), 'other');
  assert.equal(normalizeReportReason('expired'), 'other');
  assert.equal(normalizeReportReason('expired', { event: true }), 'expired');
  assert.equal(reasonSeverity('expired'), 'normal');
});

test('all German weekly/food legacy labels normalize exactly, including colon-appended notes', () => {
  const aliases = {
    'Unpassender Ton': 'harassment', 'Nicht hilfreich': 'other',
    'Nicht elternfreundlich': 'inappropriate', 'Fachlich fragwuerdig': 'misinformation',
    'Fachlich fragwürdig': 'misinformation', 'Spam oder Irrefuehrung': 'spam',
    'Spam oder Irreführung': 'spam', 'Unpassender Inhalt': 'inappropriate',
    'Betrug oder Unsicherheit': 'fraud', 'Andere Sorge': 'other',
  };
  for (const [label, expected] of Object.entries(aliases)) {
    for (const value of [label, ` ${label.toUpperCase()} `, `${label}: private note: more`]) {
      assert.equal(normalizeReportReason(value), expected);
      assert.equal(reasonSeverity(value), 'normal');
      assert.equal(withReportSeverity({ reason: value }).reason, expected);
    }
  }
  assert.equal(normalizeReportReason('fake: old note'), 'fraud');
  for (const value of ['self_harm: note', 'child_safety: note', 'sexual_content: note',
    'violence_threat: note', 'Unpassender Ton extra: note', `${'self_harm'.padEnd(120)}suffix`]) {
    assert.equal(normalizeReportReason(value), 'other');
    assert.equal(reasonSeverity(value), 'normal');
  }
});

test('legacy German reason labels reach admin groups and email as canonical normal reasons', async () => {
  const legacy = 'Fachlich fragwürdig: private note';
  const f = fixture({ env: { PARENT_MATCHING_REPORT_HIDE_THRESHOLD: '1' } });
  await f.notifyModeration(report({ reason: legacy }));
  assert.match(f.emails[0].text, /Grund: Falsche Information/);
  assert.doesNotMatch(JSON.stringify(f.emails), /misinformation/);
  assert.doesNotMatch(f.emails[0].text, /private note/);
  const overview = buildModerationOverview([
    { reportedUserId: 'target', lastReason: legacy },
  ], [{ reportedUserId: 'target', reason: legacy }], []);
  assert.equal(overview.groups[0].lastReason, 'misinformation');
  assert.equal(overview.groups[0].severity, 'normal');
  assert.equal(overview.reports[0].reason, 'misinformation');
});

test('critical reports email immediately, ignore client severity, and push every report to every admin', async () => {
  const f = fixture();
  await f.notifyModeration(report({ reason: 'child_safety', severity: 'normal', content: 'PRIVATE', reporterName: 'PRIVATE' }));
  await f.notifyModeration(report({ id: 'two', reason: 'child_safety', severity: 'normal' }));
  assert.equal(f.emails.length, 1);
  assert.equal(f.emails[0].to, 'support@parentpeak.com');
  assert.match(f.emails[0].text, /Europe\/Berlin/);
  assert.match(f.emails[0].text, /Moderations-Dashboard/);
  assert.doesNotMatch(JSON.stringify(f.emails), /PRIVATE|reporterUserId/);
  assert.deepEqual(f.pushes.map(push => push.uid), ['a', 'b', 'a', 'b']);
  assert.ok(f.pushes.every(push => push.data.type === 'moderation_report' && push.data.severity === 'critical'));
});

test('normal reports email once at distinct-reporter threshold, not raw report count', async () => {
  const f = fixture({ env: { MODERATION_EMAIL: 'team@example.test' } });
  await f.notifyModeration(report());
  await f.notifyModeration(report({ id: 'two' }));
  await f.notifyModeration(report({ id: 'three', reporterUserId: 'r2' }));
  assert.equal(f.emails.length, 0);
  await f.notifyModeration(report({ id: 'four', reporterUserId: 'r3', severity: 'critical' }));
  await f.notifyModeration(report({ id: 'five', reporterUserId: 'r4' }));
  assert.equal(f.emails.length, 1);
  assert.equal(f.emails[0].to, 'team@example.test');
  assert.match(f.emails[0].subject, /Meldeschwelle/);
  assert.equal(f.pushes.length, 10);
});

test('atomic claims survive service restarts and concurrent instances; critical cooldown is target + reason scoped', async () => {
  const db = database();
  const a = fixture({ db });
  const b = fixture({ db });
  await Promise.all([
    a.notifyModeration(report({ reason: 'violence_threat' })),
    b.notifyModeration(report({ id: 'two', reason: 'violence_threat' })),
  ]);
  assert.equal(a.emails.length + b.emails.length, 1);
  await b.notifyModeration(report({ id: 'three', reason: 'self_harm' }));
  await b.notifyModeration(report({ id: 'four', reason: 'violence_threat', targetId: 'other' }));
  assert.equal(a.emails.length + b.emails.length, 3);
  db.advance(15 * 60 * 1000);
  const restarted = fixture({ db });
  await restarted.notifyModeration(report({ id: 'five', reason: 'violence_threat' }));
  assert.equal(restarted.emails.length, 1);
  const implementation = fs.readFileSync(path.join(__dirname, '../../moderation.js'), 'utf8');
  assert.match(implementation, /ON CONFLICT \("key"\) DO UPDATE/);
  assert.match(implementation, /"expiresAt" <= NOW\(\)/);
  assert.match(implementation, /RETURNING "key"/);
});

test('threshold claim remains once after restarts, invalid threshold falls back to three', async () => {
  const db = database();
  const f = fixture({ db, env: { PARENT_MATCHING_REPORT_HIDE_THRESHOLD: 'invalid' } });
  for (let i = 0; i < 3; i++) await f.notifyModeration(report({ id: `r${i}`, reporterUserId: `r${i}` }));
  const restarted = fixture({ db });
  await restarted.notifyModeration(report({ id: 'r4', reporterUserId: 'r4' }));
  assert.equal(f.emails.length, 1);
  assert.equal(restarted.emails.length, 0);
});

test('one email covers a simultaneous critical and threshold claim', async () => {
  const f = fixture({ env: { PARENT_MATCHING_REPORT_HIDE_THRESHOLD: '1' } });
  await f.notifyModeration(report({ reason: 'sexual_content' }));
  await f.notifyModeration(report({ id: 'two', reason: 'spam', reporterUserId: 'r2' }));
  assert.equal(f.emails.length, 1);
  assert.equal(f.db.claims.size, 2);
});

test('delivery failures log and never reject; absent admin tokens/admins do not suppress email', async () => {
  const f = fixture({ failEmail: true, failPush: true });
  await assert.doesNotReject(f.notifyModeration(report({ reason: 'child_safety' })));
  assert.equal(f.pushes.length, 2);
  assert.equal(f.emails.length, 1);
  assert.equal(f.db.reports.size, 1);
  assert.equal(f.errors.length, 3);
  const noAdmins = fixture({ admins: [] });
  await noAdmins.notifyModeration(report({ reason: 'child_safety' }));
  assert.equal(noAdmins.emails.length, 1);
});

for (const options of [{ failEmail: true }, { emailResult: false }, { hangEmail: true }]) {
  test(`failed email releases both claims for next report: ${JSON.stringify(options)}`, async () => {
    const db = database();
    const env = { PARENT_MATCHING_REPORT_HIDE_THRESHOLD: '1', MODERATION_SEND_TIMEOUT_MS: '5' };
    const failing = fixture({ db, env, ...options });
    await failing.notifyModeration(report({ reason: 'child_safety' }));
    assert.equal(db.claims.size, 0);
    const healthy = fixture({ db, env });
    await healthy.notifyModeration(report({ id: 'retry', reason: 'child_safety' }));
    assert.equal(healthy.emails.length, 1);
    assert.equal(db.claims.size, 2);
    await healthy.notifyModeration(report({ id: 'again', reason: 'child_safety' }));
    assert.equal(healthy.emails.length, 1);
  });
}

test('false and hanging pushes log without suppressing independent email', async () => {
  for (const options of [{ pushResult: false }, { hangPush: true }]) {
    const f = fixture({ ...options, env: { MODERATION_SEND_TIMEOUT_MS: '5' } });
    await f.notifyModeration(report({ reason: 'self_harm' }));
    assert.equal(f.emails.length, 1);
    assert.equal(f.errors.length, 2);
  }
});

test('expired crash lease can be reclaimed; stale owner cannot delete another lease', async () => {
  const db = database();
  const key = JSON.stringify(['critical', 'safety', 'target', 'child_safety']);
  db.claims.set(key, { token: 'crashed', expires: 60000 });
  const f = fixture({ db });
  await f.notifyModeration(report({ reason: 'child_safety' }));
  assert.equal(f.emails.length, 0);
  db.advance(60000);
  await f.notifyModeration(report({ id: 'retry', reason: 'child_safety' }));
  assert.equal(f.emails.length, 1);
  await db.prisma.$executeRawUnsafe('DELETE FROM "ModerationNotificationClaim"', key, 'crashed');
  assert.equal(db.claims.size, 1);
});

test('re-enabling notifications leaves unsent thresholds eligible and legacy reasons remain normal', async () => {
  const db = database();
  const disabled = fixture({ db, env: { MODERATION_NOTIFY_ENABLED: 'false' } });
  await disabled.persistModerationReport(report({ reason: 'unsupported-old-value' }));
  await disabled.notifyModeration(report());
  assert.equal(db.claims.size, 0);
  const enabled = fixture({ db, env: { PARENT_MATCHING_REPORT_HIDE_THRESHOLD: '1' } });
  await enabled.notifyModeration(report({ id: 'retry', reason: 'unsupported-old-value' }));
  assert.equal(enabled.emails.length, 1);
  assert.match(enabled.emails[0].text, /Grund: Sonstiges/);
});

test('disabled notifications leave durable persistence available', async () => {
  for (const disabled of ['false', '0']) {
    const f = fixture({ env: { MODERATION_NOTIFY_ENABLED: disabled } });
    await f.persistModerationReport(report());
    await f.notifyModeration(report({ reason: 'child_safety' }));
    assert.equal(f.db.reports.size, 1);
    assert.equal(f.emails.length + f.pushes.length, 0);
  }
});

test('database notification failures do not reject and do not suppress admin push', async () => {
  const f = fixture();
  f.db.prisma.$executeRawUnsafe = async () => { throw new Error('db unavailable'); };
  await assert.doesNotReject(f.notifyModeration(report({ reason: 'child_safety' })));
  assert.equal(f.pushes.length, 2);
  assert.equal(f.errors.length, 1);
});

test('admin overview retains API shape, normalizes legacy rows, and puts critical groups across sources first', () => {
  const sources = ['weekly', 'event_chat', 'community_event', 'food_feed', 'treasure'];
  const extra = sources.map((source, i) => withReportSeverity({
    id: `${i}`, source, targetId: 't', reportedUserId: `${source}:t`, reporterUserId: 'r',
    reason: i === 4 ? 'self_harm' : 'fake', status: 'pending', createdAt: '2020-01-01',
  }));
  const result = buildModerationOverview([
    { reportedUserId: 'u', lastReason: 'spam', lastReportedAt: '2026-01-01' },
  ], [{ id: 's', reportedUserId: 'u', reason: 'insult', createdAt: '2026-01-01' }], extra);
  assert.equal(result.groups.length, 6);
  assert.equal(result.reports.length, 6);
  assert.equal(result.groups[0].source, 'treasure');
  assert.equal(result.reports[0].severity, 'critical');
  assert.equal(result.reports.find(row => row.id === 's').reason, 'harassment');
  assert.ok(result.groups.every(group => ['normal', 'critical'].includes(group.severity)));
  const legacyCritical = buildModerationOverview([
    { reportedUserId: 'legacy', lastReason: 'spam', severity: 'normal' },
  ], [{ reportedUserId: 'legacy', reason: ' SELF_HARM ' }], []);
  assert.equal(legacyCritical.groups[0].severity, 'critical');
});

test('admin loader includes all legacy data sources and durable weekly history, with status filtering', async () => {
  const f = fixture();
  const queries = [];
  f.db.prisma.$queryRawUnsafe = async sql => {
    queries.push(sql);
    return [
      { id: 'legacy', source: 'treasure', targetId: 'target', reason: 'insult', status: 'pending' },
      { id: 'weekly:r', source: 'weekly', targetId: 'imp:post', reason: 'self_harm', status: 'pending' },
      { id: 'old', source: 'food_feed', targetId: 'recipe', reason: 'fake', status: 'resolved' },
    ];
  };
  const pending = await f.loadAdditionalReports('pending');
  assert.equal(pending.length, 2);
  assert.equal(pending.find(row => row.id === 'weekly:r').severity, 'critical');
  assert.equal(pending.find(row => row.id === 'legacy').reason, 'harassment');
  const all = await f.loadAdditionalReports('all');
  assert.equal(all.length, 3);
  for (const table of ['TreasureReport', 'RecipeReport', 'ChatReport', 'CommunityEventFlag', 'ModerationReport']) {
    assert.ok(queries[0].includes(`"${table}"`));
  }
  assert.match(queries[0], /COALESCE\(m\."status", 'pending'\)/);
});

test('threshold counting unions legacy reporters with new history rather than double counting reports', async () => {
  const f = fixture();
  const queries = [];
  f.db.prisma.$queryRawUnsafe = async (sql, ...args) => {
    queries.push(sql);
    if (sql.includes('COUNT(DISTINCT reporter)')) return [{ n: 3 }];
    return [{ key: args[0] }];
  };
  await f.notifyModeration(report());
  assert.equal(f.emails.length, 1);
  assert.match(queries[0], /COUNT\(DISTINCT reporter\)/);
  assert.match(queries[0], /UNION SELECT "reporterUserId" AS reporter FROM "SafetyReport"/);
});

test('additional report resolution updates source rows and creates durable overlays for legacy event flags', async () => {
  const f = fixture();
  await f.resolveAdditionalReport({ reportId: 'legacy-id' });
  for (const table of ['TreasureReport', 'RecipeReport', 'ChatReport']) {
    assert.ok(f.db.writes.some(write => write.sql.includes(`UPDATE "${table}"`)));
  }
  assert.ok(f.db.writes.some(write => write.sql.includes('FROM "CommunityEventFlag" WHERE "id" = $1')
    && write.sql.includes('ON CONFLICT ("id") DO UPDATE')));
  await f.resolveAdditionalReport({ reportedUserId: 'community_event:event:with:colon' });
  const byTarget = f.db.writes.find(write => write.sql.includes('FROM "CommunityEventFlag" WHERE "eventId"'));
  assert.equal(byTarget.args[0], 'event:with:colon');
});

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
const reportRoutes = [
  ['/api/safety/report', 'safety'],
  ['/api/weekly-impulse/community/posts/:postId/report', 'weekly'],
  ['/events/:id/chat/reports', 'event_chat'],
  ['/api/food-feed/recipes/:id/report', 'food_feed'],
  ['/api/treasures/:id/report', 'treasure'],
  ['/api/community-events/:id/flag', 'community_event'],
];

function routeFixture(route, reportSource, { failPersistence = false, hangNotification = false, failDelivery = true } = {}) {
  const f = fixture({ failEmail: failDelivery, failPush: failDelivery });
  const saved = [];
  const notifications = [];
  const pending = [];
  let handler;
  const create = async ({ data }) => {
    if (failPersistence) throw new Error('primary persistence failed');
    const row = { ...data, id: 'saved', createdAt: new Date() };
    saved.push(row);
    return row;
  };
  const state = { reportsByPostId: {} };
  const primary = {
    ...f.db.prisma,
    $executeRawUnsafe: async (sql, ...args) => {
      if (failPersistence) throw new Error('primary persistence failed');
      saved.push(args);
      return 1;
    },
    $queryRawUnsafe: async () => [{ n: 1 }],
    $transaction: async values => Promise.all(values),
    chatReport: { create },
    recipeReport: { create, findFirst: async () => null, count: async () => 1 },
    treasureReport: { create, findFirst: async () => null, count: async () => 1 },
    communityEventFlag: {
      upsert: async ({ create: data }) => create({ data }), count: async () => 1,
    },
    message: { findUnique: async () => ({ id: 'message', chatId: 'chat' }) },
    sharedRecipe: { findUnique: async () => ({ id: 'target' }), update: async () => ({}) },
    treasureItem: { findUnique: async () => ({ id: 'target' }) },
    communityEvent: { findUnique: async () => ({ id: 'target' }), update: async () => ({}) },
  };
  const context = {
    console: { error() {} }, crypto: require('node:crypto'),
    prisma: primary, requireVerifiedUser() {}, normalizeReportReason, reasonSeverity, withReportSeverity, criticalFirst,
    notifyModeration: data => {
      assert.ok(saved.length > 0, 'notification must follow durable persistence');
      notifications.push(data);
      if (hangNotification) return new Promise(() => {});
      const task = f.notifyModeration(data);
      pending.push(task);
      return task;
    },
    persistModerationReport: async data => {
      if (failPersistence) throw new Error('primary persistence failed');
      await f.persistModerationReport(data);
      saved.push(data);
    },
    app: { post: (_route, ...chain) => { handler = chain.at(-1); } },
    requireActorClaims: () => true, authorizeEventChat: async () => ({}),
    ensureEventChatRecord: async () => ({ id: 'chat' }),
    ensureAuthenticatedEventUser: async () => 'reporter',
    ensureSocialSchemaReady: async () => {}, generateId: () => `saved-${saved.length + 1}`,
    respondWithStrictPersistenceError: (res) => { res.status(503).json({ error: 'unavailable' }); return true; },
    respondChatPersistenceError: res => res.status(503).json({ error: 'unavailable' }),
    getWeeklyImpulseSchema: () => ({}), findWeeklyImpulseCommunityPost: () => ({}),
    getWeeklyImpulseCommunityEntry: () => state,
    isRecipeReportSevere: () => false, shouldAutoUnpublishRecipe: () => false,
    isTreasureReportSevere: () => false, shouldAutoArchiveTreasure: () => false,
  };
  const start = source.indexOf(`app.post('${route}'`);
  assert.ok(start >= 0);
  const block = source.slice(start, source.indexOf('\n});', start) + 4);
  assert.match(block, /void notifyModeration\(/);
  vm.runInNewContext(block, context);
  return {
    ...f, saved, notifications,
    async call(reason = 'child_safety', bodyOverrides = {}) {
      let status = 200, body;
      const req = {
        firebaseUid: 'reporter', params: { id: 'target', postId: 'post' }, query: {},
        body: { reportedUserId: 'target', reportedMessageId: 'message', reason,
          severity: 'normal', impulseId: 'impulse', reporterName: 'Name', ...bodyOverrides },
      };
      const res = { status(code) { status = code; return this; }, json(value) { body = value; return this; } };
      await handler(req, res);
      await Promise.all(pending);
      return { status, body };
    },
  };
}

for (const [route, reportSource] of reportRoutes) {
  test(`${route}: durable canonical save precedes helper; send failures retain ok:true`, async () => {
    const f = routeFixture(route, reportSource);
    const result = await f.call();
    assert.ok(result.status < 300);
    assert.equal(result.body.ok, true);
    assert.equal(f.notifications.length, 1);
    assert.equal(f.notifications[0].source, reportSource);
    assert.equal(f.notifications[0].reason, 'child_safety');
    assert.equal(f.emails.length, 1);
    assert.equal(f.pushes.length, 2);
    assert.ok(f.saved.length > 0);
  });
  test(`${route}: failed primary save sends no notification`, async () => {
    const f = routeFixture(route, reportSource, { failPersistence: true });
    const result = await f.call();
    assert.ok(result.status >= 500);
    assert.equal(f.notifications.length, 0);
    assert.equal(f.emails.length + f.pushes.length, 0);
  });
  test(`${route}: legacy client reason is normalized before saving and notifying`, async () => {
    const f = routeFixture(route, reportSource);
    const result = await f.call('fake');
    assert.ok(result.status < 300);
    assert.equal(f.notifications[0].reason, 'fraud');
    assert.ok(JSON.stringify(f.saved).includes('fraud'));
    assert.ok(!JSON.stringify(f.saved).includes('"fake"'));
    assert.equal(f.emails.length, 0);
  });
  test(`${route}: successful response does not wait for notification completion`, async () => {
    const f = routeFixture(route, reportSource, { hangNotification: true });
    const result = await f.call();
    assert.equal(result.body.ok, true);
    assert.equal(f.notifications.length, 1);
  });
}

test('AI-message safety reports retain contentType and deduplicate by distinct message target without leaking content', async () => {
  const f = routeFixture('/api/safety/report', 'safety', { failDelivery: false });
  const body = {
    contentType: 'ai_message', reportedUserId: 'ai_chat:thread:0',
    content: 'Private reported AI response',
  };
  const first = await f.call('self_harm', body);
  const repeated = await f.call('self_harm', body);
  const otherMessage = await f.call('self_harm', { ...body, reportedUserId: 'ai_chat:thread:1' });
  assert.ok([first, repeated, otherMessage].every(result => result.body.ok === true));
  assert.equal(f.saved[0][2], 'ai_chat:thread:0');
  assert.equal(f.saved[0][3], 'ai_message');
  assert.equal(f.saved[0][4], body.content);
  assert.equal(f.notifications[0].targetId, 'ai_chat:thread:0');
  assert.equal(f.notifications[2].targetId, 'ai_chat:thread:1');
  assert.equal(f.emails.length, 2);
  assert.equal(f.pushes.length, 6);
  assert.doesNotMatch(JSON.stringify(f.pushes), /Private reported AI response|ai_chat:thread/);
  assert.doesNotMatch(JSON.stringify(f.emails), /Private reported AI response/);
});

test('legacy safety event expired reason survives persistence, notification and admin normalization', async () => {
  const f = routeFixture('/api/safety/report', 'safety', { failDelivery: false });
  const result = await f.call('expired', { contentType: 'event' });
  assert.equal(result.body.ok, true);
  assert.equal(f.saved[0][5], 'expired');
  assert.equal(f.notifications[0].reason, 'expired');
  assert.equal([...f.db.reports.values()][0].reason, 'expired');
  const overview = buildModerationOverview([
    { reportedUserId: 'target', lastReason: 'expired', lastContentType: 'event' },
  ], [{ reportedUserId: 'target', reason: 'expired', contentType: 'event' }], []);
  assert.equal(overview.groups[0].lastReason, 'expired');
  assert.equal(overview.reports[0].reason, 'expired');
  assert.equal(overview.groups[0].severity, 'normal');
  assert.equal(overview.reports[0].severity, 'normal');
});

test('existing sendPushToUser tolerates missing tokens and fans out actual admin tokens', async () => {
  const start = source.indexOf('async function sendPushToUser(');
  const block = source.slice(start, source.indexOf('\n}', start) + 2);
  const calls = [];
  const context = {
    console: { error() {} },
    ensureDeviceTokenSchemaReady: async () => {},
    prisma: { $queryRawUnsafe: async (_sql, userId) => userId === 'a'
      ? [{ token: 'token1' }, { token: 'token2' }] : [] },
    firebaseAdmin: { messaging: () => ({
      sendEachForMulticast: async data => { calls.push(data); return { responses: [{ success: true }, { success: true }] }; },
    }) },
  };
  vm.runInNewContext(block, context);
  const f = fixture();
  const service = createModerationService({
    prisma: f.db.prisma, sendEmail: async () => true,
    sendPushToUser: context.sendPushToUser, adminUserIds: new Set(['a', 'no-token']), env: {},
  });
  await service.notifyModeration(report());
  assert.equal(calls.length, 1);
  assert.deepEqual([...calls[0].tokens], ['token1', 'token2']);
  assert.equal(calls[0].data.type, 'moderation_report');
  assert.equal(calls[0].data.accountUserId, 'a');
});

test('German reason labels cover all canonical reasons, expired and unknown fallback', () => {
  const labels = {
    child_safety: 'Gefährdung eines Kindes',
    sexual_content: 'Sexueller Inhalt / Missbrauch',
    violence_threat: 'Gewalt / Bedrohung',
    self_harm: 'Selbstgefährdung / Suizid',
    harassment: 'Belästigung / Hassrede',
    spam: 'Spam / Werbung',
    fraud: 'Betrug / Fake-Profil',
    inappropriate: 'Unangemessener Inhalt',
    misinformation: 'Falsche Information',
    other: 'Sonstiges',
    expired: 'Abgelaufen',
  };
  for (const [reason, label] of Object.entries(labels)) {
    assert.equal(reasonLabelDe(reason), label);
  }
  assert.equal(reasonLabelDe('future_reason'), 'future_reason');
  assert.equal(reasonLabelDe('__proto__'), '__proto__');
});

test('notification email uses only German display labels while storage and dedup keep keys', async () => {
  for (const reason of [
    'child_safety', 'sexual_content', 'violence_threat', 'self_harm',
    'harassment', 'spam', 'fraud', 'inappropriate', 'misinformation', 'other', 'expired',
  ]) {
    const f = fixture({ env: { PARENT_MATCHING_REPORT_HIDE_THRESHOLD: '1' } });
    await f.notifyModeration(report({ reason, contentType: 'event' }));
    assert.equal(f.emails.length, 1);
    assert.ok(f.emails[0].text.includes(`Grund: ${reasonLabelDe(reason)}`));
    assert.ok(f.emails[0].html.includes(`Grund: ${reasonLabelDe(reason)}`));
    assert.ok(!f.emails[0].text.includes(`Grund: ${reason}\n`));
    assert.equal([...f.db.reports.values()][0].reason, reason);
    if (reasonSeverity(reason) === 'critical') {
      assert.ok(f.db.claims.has(JSON.stringify(['critical', 'safety', 'target', reason])));
    }
  }
});
