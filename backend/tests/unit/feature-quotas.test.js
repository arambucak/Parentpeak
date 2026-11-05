const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const quotas = require('../../feature_quota_store');
const { buildFeatureAiRequest } = require('../../feature_ai_request');
const { storeDiscoveredEvents } = require('../../discovered_event_store');

function databaseFixture() {
  const clock = { now: new Date('2026-11-05T12:00:00Z') };
  let state = { buckets: new Map(), receipts: new Map(), entitlements: new Map(),
    discovered: new Map(), friendships: new Map() };
  let tail = Promise.resolve();
  let failWrite = false;
  const key = (uid, feature, period) => `${uid}/${feature}/${period.toISOString()}`;
  function client(getState) {
    return {
      userEntitlement: {
        upsert: async ({ where, create }) => {
          const s = getState();
          if (!s.entitlements.has(where.userId)) s.entitlements.set(where.userId, create);
          return s.entitlements.get(where.userId);
        },
        updateMany: async ({ where, data }) => {
          const s = getState();
          s.entitlements.set(where.userId, { ...s.entitlements.get(where.userId), ...data });
          return { count: 1 };
        },
      },
      event: { findUnique: async ({ where }) => ({ id: where.id, visibility: 'publicNearby' }) },
      eventParticipation: { findUnique: async () => null },
      $queryRawUnsafe: async (sql, ...args) => {
        const s = getState();
        if (sql.startsWith('SELECT CURRENT_TIMESTAMP')) return [{ now: new Date(clock.now) }];
        if (sql.includes('FROM "FeatureQuota"')) {
          const count = s.buckets.get(key(...args));
          return count === undefined ? [] : [{ count }];
        }
        if (sql.includes('FROM "FeatureQuotaItem"') && sql.includes('"itemKey" = $4')) {
          return [...s.receipts.values()].filter(item => item.userId === args[0] &&
            item.feature === args[1] && item.periodStart.getTime() === args[2].getTime() &&
            item.itemKey === args[3]);
        }
        if (sql.includes('SELECT "result"')) {
          return [...s.receipts.values()].filter(item => item.userId === args[0] &&
            item.feature === 'recipes' && item.periodStart.getTime() === args[1].getTime() &&
            item.result != null).slice(0, 1);
        }
        if (sql.includes('FROM "Friendship"')) {
          const friendship = s.friendships.get(args.join('/'));
          return friendship ? [friendship] : [];
        }
        if (sql.includes('FROM "UserProfile"')) return [{ isPrivate: true }];
        if (sql.includes('FROM "DiscoveredEventDetail"')) {
          return s.discovered.has(args[0]) ? [{ id: args[0] }] : [];
        }
        throw new Error(`Unexpected query: ${sql}`);
      },
      $executeRawUnsafe: async (sql, ...args) => {
        if (failWrite) throw new Error('Simulated DB write failure');
        const s = getState();
        if (sql.includes('INSERT INTO "FeatureQuota"')) {
          const id = key(...args);
          if (!s.buckets.has(id)) s.buckets.set(id, 0);
        } else if (sql.includes('INSERT INTO "FeatureQuotaItem"')) {
          const [id, userId, feature, periodStart, itemKey, expiresAt] = args;
          s.receipts.set(id, { id, userId, feature, periodStart, itemKey, expiresAt,
            aiUsed: false, result: null });
        } else if (sql.includes('UPDATE "FeatureQuota"')) {
          const id = key(...args);
          s.buckets.set(id, s.buckets.get(id) + 1);
        } else if (sql.includes('UPDATE "FeatureQuotaItem"')) {
          const item = s.receipts.get(args[0]);
          if (!item || item.userId !== args[1] || item.feature !== 'recipes' ||
              item.expiresAt <= clock.now || item.result != null ||
              (sql.includes('"aiUsed" = true') && item.aiUsed)) return 0;
          if (sql.includes('"aiUsed" = true')) item.aiUsed = true;
          else item.result = JSON.parse(args[2]);
        } else if (sql.includes('INSERT INTO "Friendship"')) {
          s.friendships.set(args.slice(0, 2).join('/'), { status: args[2] });
        } else if (sql.includes('INSERT INTO "DiscoveredEventDetail"')) {
          s.discovered.set(args[0], JSON.parse(args[1]));
        } else throw new Error(`Unexpected statement: ${sql}`);
        return 1;
      },
    };
  }
  const db = client(() => state);
  db.$transaction = operation => {
    const run = tail.then(async () => {
      const next = structuredClone(state);
      const value = await operation(client(() => next));
      state = next;
      return value;
    });
    tail = run.catch(() => {});
    return run;
  };
  return { db, clock, fail() { failWrite = true; }, premium(uid, access = 'active') {
    state.entitlements.set(uid, { userId: uid, tier: 'premium', access,
      validFrom: new Date('2026-01-01'), validUntil: new Date('2027-01-01'),
      verifiedAt: clock.now, revokedAt: null, adsEligibleByEntitlement: false });
  } };
}

for (const [feature, maximum] of Object.entries(quotas.LIMITS)) {
  test(`${feature}: Free allows exactly ${maximum}, blocks the next operation`, async () => {
    const { db } = databaseFixture();
    for (let i = 0; i < maximum; i++) {
      const result = await quotas.consumeQuota(db, 'a', feature, `item-${i}`, true);
      assert.equal(result.remaining, maximum - i - 1);
    }
    await assert.rejects(quotas.consumeQuota(db, 'a', feature, 'extra', true),
      error => error.code === 'feature_limit_reached' && error.status === 429);
    assert.equal((await quotas.quotaStatus(db, 'a', true)).items[feature].used, maximum);
    assert.equal((await quotas.consumeQuota(db, 'b', feature, 'other-account', true)).used, 1);
  });

  test(`${feature}: simultaneous requests cannot overspend the allowance`, async () => {
    const { db } = databaseFixture();
    const results = await Promise.allSettled(Array.from({ length: 20 }, (_, i) =>
      quotas.consumeQuota(db, 'a', feature, `parallel-${i}`, true)));
    assert.equal(results.filter(item => item.status === 'fulfilled').length, maximum);
    assert.equal((await quotas.quotaStatus(db, 'a', true)).items[feature].used, maximum);
  });

  test(`${feature}: verified Premium has no product allowance and does not burn Free usage`, async () => {
    const fixture = databaseFixture();
    fixture.premium('premium-user');
    for (let i = 0; i < maximum + 5; i++) {
      const result = await quotas.consumeQuota(fixture.db, 'premium-user', feature, `premium-${i}`, true);
      assert.equal(result.remaining, null);
      assert.equal(result.used, 0);
    }
  });
}

test('contact write failure rolls back the allowance in the same transaction', async () => {
  const { db } = databaseFixture();
  await assert.rejects(quotas.consumeQuota(db, 'a', 'contacts', 'b', true,
    async () => { throw new Error('Contact write failed'); }), /Contact write failed/);
  assert.equal((await quotas.quotaStatus(db, 'a', true)).items.contacts.used, 0);
  let operationDb;
  await quotas.consumeQuota(db, 'a', 'contacts', 'b', true, async tx => {
    operationDb = tx;
  });
  assert.notEqual(operationDb, db);
  assert.equal((await quotas.quotaStatus(db, 'a', true)).items.contacts.used, 1);
});

for (const feature of ['chat', 'recipes']) {
  test(`${feature}: UTC midnight reset, independent of client date`, async () => {
    const { db, clock } = databaseFixture();
    clock.now = new Date('2026-11-05T23:59:59.999Z');
    for (let i = 0; i < quotas.LIMITS[feature]; i++) {
      await quotas.consumeQuota(db, 'a', feature, `before-${i}`, true);
    }
    clock.now = new Date('2026-11-06T00:00:00Z');
    const result = await quotas.consumeQuota(db, 'a', feature, 'after', true);
    assert.equal(result.used, 1);
    assert.equal(result.periodStart, '2026-11-06T00:00:00.000Z');
    assert.equal(result.resetsAt, '2026-11-07T00:00:00.000Z');
  });
}

test('weekly allowance renews at Monday UTC, including year boundary', async () => {
  const { db, clock } = databaseFixture();
  clock.now = new Date('2026-12-27T23:59:59.999Z');
  for (let i = 0; i < 3; i++) await quotas.consumeQuota(db, 'a', 'events', `e${i}`, true);
  clock.now = new Date('2026-12-28T00:00:00Z');
  assert.equal((await quotas.consumeQuota(db, 'a', 'events', 'new', true)).used, 1);
  const period = quotas.quotaPeriod('events', new Date('2027-01-01T03:00:00+03:00'));
  assert.equal(period.start.toISOString(), '2026-12-28T00:00:00.000Z');
  assert.equal(period.end.toISOString(), '2027-01-04T00:00:00.000Z');
});

test('contacts renew at first of month UTC, including leap day and December', async () => {
  const { db, clock } = databaseFixture();
  clock.now = new Date('2028-02-29T23:59:59.999Z');
  for (let i = 0; i < 3; i++) await quotas.consumeQuota(db, 'a', 'contacts', `u${i}`, true);
  clock.now = new Date('2028-03-01T00:00:00Z');
  assert.equal((await quotas.consumeQuota(db, 'a', 'contacts', 'u0', true)).used, 1);
  assert.equal(quotas.quotaPeriod('contacts', new Date('2026-12-31T23:59:59Z'))
    .end.toISOString(), '2027-01-01T00:00:00.000Z');
});

test('reopening an event or repeating the same contact does not consume twice', async () => {
  for (const feature of ['events', 'contacts']) {
    const { db } = databaseFixture();
    const first = await quotas.consumeQuota(db, 'a', feature, 'same-target', true);
    const second = await quotas.consumeQuota(db, 'a', feature, 'same-target', true);
    assert.equal(second.receipt, first.receipt);
    assert.equal(second.used, 1);
    assert.equal(second.repeated, true);
  }
});

test('recipe and chat allowances are separate; a saved local fallback consumes the recipe slot', async () => {
  const { db } = databaseFixture();
  const recipe = await quotas.consumeQuota(db, 'a', 'recipes', 'local', true);
  await quotas.saveRecipeResult(db, 'a', recipe.receipt,
    { title: 'Rice', ingredients: ['Rice'], steps: ['Cook'] });
  assert.equal((await quotas.todayRecipe(db, 'a')).item.title, 'Rice');
  await assert.rejects(quotas.consumeQuota(db, 'a', 'recipes', 'another-local', true));
  assert.equal((await quotas.consumeQuota(db, 'a', 'chat', 'question', true)).remaining, 2);
  await assert.rejects(quotas.useRecipeReceipt(db, 'a', recipe.receipt));
  await assert.rejects(quotas.saveRecipeResult(db, 'a', recipe.receipt,
    { title: 'Changed', ingredients: [], steps: [] }));
});

test('recipe receipt is UID-bound, single-use and expires at UTC midnight', async () => {
  const { db, clock } = databaseFixture();
  const receipt = (await quotas.consumeQuota(db, 'a', 'recipes', 'r', true)).receipt;
  await assert.rejects(quotas.useRecipeReceipt(db, 'b', receipt));
  await quotas.useRecipeReceipt(db, 'a', receipt);
  await assert.rejects(quotas.useRecipeReceipt(db, 'a', receipt));
  clock.now = new Date('2026-11-06T00:00:00Z');
  await assert.rejects(quotas.saveRecipeResult(db, 'a', receipt,
    { title: 'Late', ingredients: [], steps: [] }));
});

test('finance requires verified Premium, but disabled rollout leaves access free', async () => {
  const fixture = databaseFixture();
  await assert.rejects(quotas.requireFinancePremium(fixture.db, 'a', true),
    error => error.status === 403 && error.code === 'feature_premium_required');
  await quotas.requireFinancePremium(fixture.db, 'a', false);
  fixture.premium('a', 'trial');
  await quotas.requireFinancePremium(fixture.db, 'a', true);
  fixture.clock.now = new Date('2027-01-01');
  await assert.rejects(quotas.requireFinancePremium(fixture.db, 'a', true));
});

test('DB failure does not grant access or increment a partially committed bucket', async () => {
  const fixture = databaseFixture();
  fixture.fail();
  await assert.rejects(quotas.consumeQuota(fixture.db, 'a', 'chat', 'q', true),
    /Simulated DB write failure/);
  assert.equal((await quotas.quotaStatus(fixture.db, 'a', true)).items.chat.used, 0);
});

test('rollout defaults off and rejects misspelled configuration', () => {
  const original = process.env.PP_ABO_LIMITS_ENABLED;
  try {
    delete process.env.PP_ABO_LIMITS_ENABLED;
    assert.equal(quotas.limitsEnabled(), false);
    process.env.PP_ABO_LIMITS_ENABLED = 'true';
    assert.equal(quotas.limitsEnabled(), true);
    process.env.PP_ABO_LIMITS_ENABLED = 'yes';
    assert.throws(quotas.limitsEnabled, /must be true or false/);
  } finally {
    if (original === undefined) delete process.env.PP_ABO_LIMITS_ENABLED;
    else process.env.PP_ABO_LIMITS_ENABLED = original;
  }
});

test('client cannot select an unlimited AI feature or put an arbitrary prompt in discovery/scan', () => {
  assert.throws(() => buildFeatureAiRequest({ feature: 'unlimited', prompt: 'q' }, new Date()));
  const event = buildFeatureAiRequest({ feature: 'events', prompt: 'UNTRUSTED CHAT',
    systemInstruction: 'UNTRUSTED SYSTEM', featureInput: { city: 'Berlin' } }, new Date());
  assert.ok(!event.prompt.includes('UNTRUSTED CHAT'));
  assert.ok(!event.systemInstruction.includes('UNTRUSTED SYSTEM'));
  const scan = buildFeatureAiRequest({ feature: 'fridge_scan', prompt: 'UNTRUSTED CHAT',
    featureInput: {} }, new Date());
  assert.ok(!scan.prompt.includes('UNTRUSTED CHAT'));
});

test('discovered events have stable server identities, independent of supplied IDs', async () => {
  const { db } = databaseFixture();
  const input = { title: 'Family museum', url: 'https://events.example.test/museum',
    eventDate: null, id: 'caller-id' };
  const first = JSON.parse(await storeDiscoveredEvents(db, JSON.stringify([input])));
  const again = JSON.parse(await storeDiscoveredEvents(db, JSON.stringify([{ ...input, id: 'other' }])));
  assert.equal(first[0].id, again[0].id);
  assert.notEqual(first[0].id, input.id);
});

function routeFixture(enabled = true) {
  const { db, clock, premium } = databaseFixture();
  const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
  const routes = new Map();
  const enabledQuotas = { ...quotas, limitsEnabled: () => enabled,
    consumeQuota: (db, uid, feature, key, _enabled, operation) =>
      quotas.consumeQuota(db, uid, feature, key, enabled, operation),
    quotaStatus: (db, uid) => quotas.quotaStatus(db, uid, enabled),
    requireFinancePremium: (db, uid) => quotas.requireFinancePremium(db, uid, enabled),
  };
  const ctx = vm.createContext({
    featureQuotas: enabledQuotas, prisma: db, console,
    app: Object.fromEntries(['get', 'post', 'put'].map(method => [method,
      (route, ...handlers) => routes.set(`${method} ${route}`, handlers)])),
    requireVerifiedUser: (req, res, next) => {
      if (!['a', 'b'].includes(req.headers.authorization)) {
        return res.status(401).json({ error: 'Invalid token' });
      }
      req.firebaseUid = req.headers.authorization;
      return next();
    },
    verifyFirebaseIdToken: async req => ({ uid: req.headers.authorization,
      verified: ['a', 'b'].includes(req.headers.authorization) }),
    ensureVerifiedBackendUser: async () => {},
    pairKey: (a, b) => [a, b].sort(),
    friendRoomId: (a, b) => [a, b].sort().join('__'),
    ensureSocialSchemaReady: async () => {},
    isBlockedBetween: async () => false,
    requireActorClaims: (req, res, claims) => {
      if (claims.some(value => value && value !== req.firebaseUid)) {
        res.status(403).json({ error: 'Foreign identity' });
        return false;
      }
      return true;
    },
    authorizeEventParticipation: async () => {},
    buildFeatureAiRequest, storeDiscoveredEvents,
    geminiApiKey: 'synthetic-key', allowedGeminiModels: new Set(['gemini-3.5-flash-lite']),
    aiRateBuckets: new Map(), aiRateWindowMs: 900000, aiRateMax: 30,
    aiDailyBudget: {}, aiDailyBudgetMax: 2000,
    checkRateLimit: () => true, checkDailyBudget: () => true,
    getClientIp: () => '127.0.0.1', normalizeAppLanguage: () => 'en',
    buildLanguageInstruction: () => 'Respond in English',
    fetch: async () => ({ ok: true, status: 200, json: async () => ({
      candidates: [{ content: { parts: [{ text: 'A helpful answer' }] } }],
    }) }),
    AbortSignal,
  });
  const start = source.indexOf('function respondFeatureQuotaError(');
  const end = source.indexOf('// Providers-Daten aus JSON laden', start);
  vm.runInContext(source.slice(start, end), ctx);
  const friendshipStart = source.indexOf("app.post('/api/friendships/request'");
  const friendshipEnd = source.indexOf("app.post('/api/friendships/accept'", friendshipStart);
  vm.runInContext(source.slice(friendshipStart, friendshipEnd), ctx);
  async function request(method, route, { uid = 'a', body = {}, params = {} } = {}) {
    let status = 200, response;
    const req = { headers: { authorization: uid },
      body: route === '/ai/generate' ? { feature: 'chat', ...body } : body, params };
    const res = { setHeader() {}, status(value) { status = value; return this; },
      json(value) { response = value; return this; } };
    const handlers = routes.get(`${method} ${route}`);
    const run = i => handlers[i](req, res, () => run(i + 1));
    await run(0);
    return { status, body: response };
  }
  return { request, clock, premium, ctx };
}

test('real proxy handler blocks fourth Free chat and Free finance, with no client clock authority', async () => {
  const { request } = routeFixture();
  for (let i = 0; i < 3; i++) {
    assert.equal((await request('post', '/ai/generate',
      { body: { prompt: 'Question', userId: 'spoofed', now: '2099-01-01' } })).status, 200);
  }
  const blocked = await request('post', '/ai/generate', { body: { prompt: 'Fourth' } });
  assert.equal(blocked.status, 429);
  assert.equal(blocked.body.code, 'feature_limit_reached');
  assert.equal((await request('post', '/ai/generate',
    { body: { prompt: 'Personal finance', feature: 'finance' } })).status, 403);
  assert.equal((await request('post', '/ai/generate',
    { uid: 'b', body: { prompt: 'Other account' } })).status, 200);
  assert.equal((await request('post', '/ai/generate',
    { uid: 'shared-token', body: { prompt: 'Invalid token' } })).status, 401);
});

test('real usage routes gate community details, UID scope, recipe fallback and finance', async () => {
  const { request } = routeFixture();
  for (let i = 0; i < 3; i++) {
    assert.equal((await request('post', '/usage/events/view',
      { body: { eventKey: `community:e${i}` } })).status, 200);
  }
  assert.equal((await request('post', '/usage/events/view',
    { body: { eventKey: 'community:e0' } })).status, 200);
  assert.equal((await request('post', '/usage/events/view',
    { body: { eventKey: 'community:e3' } })).status, 429);
  const reservation = await request('post', '/usage/recipes/reserve');
  assert.equal(reservation.status, 200);
  assert.equal((await request('put', '/usage/recipes/:receipt/result', {
    params: { receipt: reservation.body.receipt },
    body: { item: { title: 'Fallback', ingredients: ['Rice'], steps: ['Cook'] } },
  })).status, 200);
  assert.equal((await request('post', '/usage/recipes/reserve')).status, 429);
  assert.equal((await request('get', '/usage/recipes/today')).body.item.title, 'Fallback');
  assert.equal((await request('get', '/usage/recipes/today', { uid: 'b' })).body.item, null);
  assert.equal((await request('get', '/usage/finance/access')).status, 403);
});

module.exports = { databaseFixture };

test('actual contact request handler enforces monthly unique contacts across devices/accounts', async () => {
  const { request, clock } = routeFixture();
  for (const toUid of ['b', 'c', 'd']) {
    assert.equal((await request('post', '/api/friendships/request',
      { body: { toUid, source: 'discovery' } })).status, 200);
  }
  assert.equal((await request('post', '/api/friendships/request',
    { body: { toUid: 'e' } })).status, 429);
  assert.equal((await request('post', '/api/friendships/request',
    { body: { toUid: 'b' } })).status, 200);
  assert.equal((await request('post', '/api/friendships/request',
    { uid: 'b', body: { toUid: 'a' } })).status, 200);
  assert.equal((await request('get', '/usage/me', { uid: 'b' })).body.items.contacts.used, 0);
  assert.equal((await request('post', '/api/friendships/request',
    { body: { toUid: 'e', fromUid: 'spoofed' } })).status, 403);
  clock.now = new Date('2026-12-01T00:00:00Z');
  assert.equal((await request('post', '/api/friendships/request',
    { body: { toUid: 'e' } })).status, 200);
  assert.equal((await request('get', '/usage/me')).body.items.contacts.used, 1);
});

test('proxy and finance routes trust server Premium, not caller tier', async () => {
  const { request, premium } = routeFixture();
  assert.equal((await request('post', '/ai/generate', {
    body: { feature: 'finance', prompt: 'Personal check', tier: 'premium' },
  })).status, 403);
  premium('a');
  assert.equal((await request('get', '/usage/finance/access')).status, 200);
  assert.equal((await request('post', '/ai/generate', {
    body: { feature: 'finance', prompt: 'Personal check' },
  })).status, 200);
  for (let i = 0; i < 5; i++) {
    assert.equal((await request('post', '/ai/generate',
      { body: { prompt: 'Premium question' } })).status, 200);
  }
});

test('disabled rollout preserves legacy prompts and leaves Free fully usable', async () => {
  const { request } = routeFixture(false);
  for (let i = 0; i < 5; i++) {
    assert.equal((await request('post', '/ai/generate', {
      body: { prompt: 'Existing recipe prompt', feature: 'recipes', featureInput: {} },
    })).status, 200);
  }
  assert.equal((await request('get', '/usage/finance/access')).status, 200);
  assert.equal((await request('get', '/usage/me')).body.enabled, false);
});

test('enabled proxy rejects legacy requests without an explicit feature', async () => {
  const { request } = routeFixture();
  assert.equal((await request('post', '/ai/generate', {
    body: { feature: undefined, prompt: 'Legacy request' },
  })).status, 400);
});
