const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const express = require('express');
const {
  buildEntitlementSnapshot,
  readEntitlementSnapshot,
} = require('../../entitlement_store');

const serverSource = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
const fixedNow = new Date('2026-10-24T10:00:00.000Z');

function entitlementDb(records = new Map(), failure = false) {
  return {
    records,
    userEntitlement: {
      upsert: async ({ where, create }) => {
        if (failure) throw new Error('database unavailable');
        if (!records.has(where.userId)) records.set(where.userId, { ...create });
        return { ...records.get(where.userId) };
      },
      updateMany: async ({ where, data }) => {
        if (failure) throw new Error('database unavailable');
        const record = records.get(where.userId);
        if (!record || record.tier !== where.tier ||
            record.access !== where.access ||
            record.validUntil !== where.validUntil ||
            record.revokedAt !== where.revokedAt) {
          return { count: 0 };
        }
        Object.assign(record, data);
        return { count: 1 };
      },
      findUnique: async ({ where }) => {
        if (failure) throw new Error('database unavailable');
        return records.has(where.userId) ? { ...records.get(where.userId) } : null;
      },
    },
  };
}

async function withEntitlementServer(t, { db, ensureUser = async () => {} }) {
  const app = express();
  app.use(express.json());
  const firebaseAdmin = {
    auth: () => ({
      verifyIdToken: async token => {
        if (token !== 'valid-user-token') throw new Error('invalid token');
        return { uid: 'firebase-user-1', email_verified: true };
      },
    }),
  };
  const context = vm.createContext({
    app,
    console: { error() {} },
    firebaseAdmin,
    process: { env: {} },
    prisma: db,
    ensureVerifiedBackendUser: ensureUser,
    readEntitlementSnapshot,
    respondFamilyPersistenceError: (res, _label, _error) =>
      res.status(503).json({
        error: 'Entitlement derzeit nicht verfuegbar',
        code: 'persistence_unavailable',
      }),
  });
  const middlewareStart = serverSource.indexOf('async function verifyFirebaseIdToken(');
  const middlewareEnd = serverSource.indexOf('function resolveVerifiedUserId(', middlewareStart);
  vm.runInContext(serverSource.slice(middlewareStart, middlewareEnd), context);

  const routeStart = serverSource.indexOf("app.get('/entitlements/me'");
  const routeEnd = serverSource.indexOf('// 0. Weekly Impulse abrufen', routeStart);
  assert.ok(routeStart >= 0 && routeEnd > routeStart);
  vm.runInContext(serverSource.slice(routeStart, routeEnd), context);

  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => new Promise(resolve => {
    server.close(resolve);
    server.closeAllConnections();
  }));
  return `http://127.0.0.1:${server.address().port}`;
}

function premiumRecord(overrides = {}) {
  return {
    userId: 'firebase-user-1',
    tier: 'premium',
    access: 'active',
    validFrom: new Date('2026-10-01T00:00:00.000Z'),
    validUntil: new Date('2026-11-01T00:00:00.000Z'),
    verifiedAt: new Date('2026-10-01T00:00:00.000Z'),
    adsEligibleByEntitlement: false,
    revokedAt: null,
    ...overrides,
  };
}

test('expired premium is downgraded and persisted as free', async () => {
  const db = entitlementDb(new Map([['firebase-user-1', premiumRecord({
    validUntil: new Date('2026-10-24T09:59:59.000Z'),
  })]]));

  const snapshot = await readEntitlementSnapshot(db, 'firebase-user-1', fixedNow);

  assert.equal(snapshot.state, 'verified');
  assert.equal(snapshot.tier, 'free');
  assert.equal(snapshot.access, 'expired');
  assert.equal(db.records.get('firebase-user-1').tier, 'free');
  assert.equal(db.records.get('firebase-user-1').access, 'expired');
});

test('revoked premium is downgraded and persisted as free', async () => {
  const db = entitlementDb(new Map([['firebase-user-1', premiumRecord({
    revokedAt: new Date('2026-10-24T09:00:00.000Z'),
  })]]));

  const snapshot = await readEntitlementSnapshot(db, 'firebase-user-1', fixedNow);

  assert.equal(snapshot.tier, 'free');
  assert.equal(snapshot.access, 'revoked');
  assert.equal(db.records.get('firebase-user-1').tier, 'free');
});

test('verified active premium snapshot remains premium before expiry', async () => {
  const db = entitlementDb(new Map([['firebase-user-1', premiumRecord()]]));

  const snapshot = await readEntitlementSnapshot(db, 'firebase-user-1', fixedNow);

  assert.equal(snapshot.state, 'verified');
  assert.equal(snapshot.tier, 'premium');
  assert.equal(snapshot.access, 'active');
  assert.equal(snapshot.validUntil, '2026-11-01T00:00:00.000Z');
});

test('persisted snapshot is shared by independent backend instances', async () => {
  const records = new Map();
  const firstInstance = entitlementDb(records);
  const secondInstance = entitlementDb(records);

  const created = await readEntitlementSnapshot(firstInstance, 'firebase-user-1', fixedNow);
  const afterRestart = await readEntitlementSnapshot(secondInstance, 'firebase-user-1', fixedNow);

  assert.deepEqual(afterRestart, created);
  assert.equal(records.size, 1);
  assert.equal(records.get('firebase-user-1').tier, 'free');
});

test('invalid or unbounded premium records fail closed to free', () => {
  const unbounded = buildEntitlementSnapshot(premiumRecord({ validUntil: null }), fixedNow);
  const future = buildEntitlementSnapshot(premiumRecord({
    validFrom: new Date('2026-10-25T00:00:00.000Z'),
  }), fixedNow);

  assert.equal(unbounded.tier, 'free');
  assert.equal(future.tier, 'free');
  assert.equal(unbounded.adsEligibleByEntitlement, false);
});

test('a concurrent verified renewal is not overwritten by an expiry downgrade', async () => {
  const records = new Map([['firebase-user-1', premiumRecord({
    validUntil: new Date('2026-10-24T09:59:59.000Z'),
  })]]);
  const db = entitlementDb(records);
  db.userEntitlement.updateMany = async () => {
    records.set('firebase-user-1', premiumRecord());
    return { count: 0 };
  };

  const snapshot = await readEntitlementSnapshot(db, 'firebase-user-1', fixedNow);

  assert.equal(snapshot.tier, 'premium');
  assert.equal(records.get('firebase-user-1').tier, 'premium');
});

test('authenticated GET ignores client premium claims and persists a verified free snapshot', async t => {
  const db = entitlementDb();
  const userIds = [];
  const base = await withEntitlementServer(t, {
    db,
    ensureUser: async userId => userIds.push(userId),
  });

  const response = await fetch(
    `${base}/entitlements/me?isPremium=true&registeredAt=1900-01-01`,
    { headers: { authorization: 'Bearer valid-user-token' } },
  );
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.item.state, 'verified');
  assert.equal(body.item.tier, 'free');
  assert.equal(body.item.adsEligibleByEntitlement, false);
  assert.deepEqual(userIds, ['firebase-user-1']);
  assert.equal(db.records.size, 1);
  assert.deepEqual(Object.keys(body.item).sort(), [
    'access',
    'adsEligibleByEntitlement',
    'state',
    'tier',
    'validFrom',
    'validUntil',
    'verifiedAt',
  ]);
});

test('database failure returns non-2xx instead of a free entitlement', async t => {
  const base = await withEntitlementServer(t, { db: entitlementDb(new Map(), true) });
  const response = await fetch(`${base}/entitlements/me`, {
    headers: { authorization: 'Bearer valid-user-token' },
  });
  const body = await response.json();

  assert.equal(response.status, 503);
  assert.equal(body.code, 'persistence_unavailable');
  assert.equal('item' in body, false);
});

test('entitlement endpoint rejects requests without a verified token', async t => {
  const db = entitlementDb();
  const base = await withEntitlementServer(t, { db });
  const response = await fetch(`${base}/entitlements/me`);

  assert.equal(response.status, 401);
  assert.equal(db.records.size, 0);
});

test('legacy self-service activation cannot create a verified premium snapshot', async t => {
  const db = entitlementDb();
  const base = await withEntitlementServer(t, { db });
  const response = await fetch(
    `${base}/entitlements/firebase-user-1/activate-premium`,
    {
      method: 'POST',
      headers: {
        authorization: 'Bearer valid-user-token',
        'content-type': 'application/json',
      },
      body: JSON.stringify({ isPremium: true }),
    },
  );
  const body = await response.json();

  assert.equal(response.status, 410);
  assert.equal(body.code, 'store_verification_required');
  assert.equal(db.records.size, 0);
});

test('entitlement routes remain authenticated and the in-memory/self-service authority is gone', () => {
  assert.match(serverSource, /app\.get\('\/entitlements\/me', requireVerifiedUser/);
  assert.doesNotMatch(serverSource, /const userEntitlements = new Map/);
  assert.doesNotMatch(serverSource, /ALLOW_SELF_SERVICE_PREMIUM/);
  assert.doesNotMatch(serverSource, /ensureEntitlement\([^)]*isPremium/);
});
