const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const express = require('express');
const { ADS_CONSENT_VERSION, readAdsConsent, setAdsConsent } = require('../../ads_consent_store');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
function database() {
  const rows = new Map();
  let failed = false;
  const project = row => Object.fromEntries(Object.entries(row)
    .filter(([key]) => key !== 'userId'));
  return {
    rows,
    fail() { failed = true; },
    adsConsent: {
      upsert: async ({ where, create }) => {
        if (failed) throw new Error('DB unavailable');
        if (!rows.has(where.userId)) rows.set(where.userId, {
          decision: 'unknown', consentVersion: ADS_CONSENT_VERSION,
          consentedAt: null, withdrawnAt: null,
          createdAt: new Date(), updatedAt: new Date(), ...create,
        });
        return project(rows.get(where.userId));
      },
      updateMany: async ({ where, data }) => {
        if (failed) throw new Error('DB unavailable');
        const row = rows.get(where.userId);
        if (!row || row.consentRevision !== where.consentRevision) return { count: 0 };
        Object.assign(row, data);
        return { count: 1 };
      },
      findUnique: async ({ where }) => {
        if (failed) throw new Error('DB unavailable');
        return project(rows.get(where.userId));
      },
    },
  };
}
const choice = (snapshot, decision) => ({
  decision, consentVersion: ADS_CONSENT_VERSION,
  consentRevision: snapshot.consentRevision,
});

test('missing consent defaults unknown; grant, deny, withdraw and second instance sync', async () => {
  const db = database();
  const empty = await readAdsConsent(db, 'a');
  assert.equal(empty.decision, 'unknown');
  assert.equal(empty.consentedAt, null);
  const granted = await setAdsConsent(db, 'a', choice(empty, 'granted'));
  assert.equal(granted.decision, 'granted');
  assert.ok(granted.consentedAt);
  const denied = await setAdsConsent(db, 'a', choice(granted, 'denied'));
  assert.equal(denied.decision, 'denied');
  assert.ok(denied.withdrawnAt);
  assert.equal(denied.consentedAt, null);
  assert.notEqual(denied.consentRevision, granted.consentRevision);
  assert.deepEqual(await readAdsConsent({ adsConsent: db.adsConsent }, 'a'), denied);
  assert.equal((await readAdsConsent(db, 'b')).decision, 'unknown');
  assert.deepEqual(Object.keys(denied).sort(), [
    'consentRevision', 'consentVersion', 'consentedAt', 'createdAt',
    'decision', 'updatedAt', 'withdrawnAt',
  ]);
});

test('old versions and malformed input cannot grant; stale grants cannot undo withdrawal', async () => {
  const db = database();
  const original = await readAdsConsent(db, 'a');
  for (const input of [
    { ...choice(original, 'granted'), consentVersion: 'ads.consent.v0' },
    { ...choice(original, 'granted'), child: 'not allowed' },
    { ...choice(original, 'granted'), userId: 'b' },
    choice(original, 'unknown'), {}, null,
  ]) {
    await assert.rejects(setAdsConsent(db, 'a', input), { code: 'invalid_ads_consent' });
  }
  await setAdsConsent(db, 'a', choice(original, 'denied'));
  await assert.rejects(setAdsConsent(db, 'a', choice(original, 'granted')),
    { code: 'ads_consent_conflict' });
  Object.assign(db.rows.get('a'), { decision: 'granted', consentVersion: 'old' });
  assert.equal((await readAdsConsent(db, 'a')).decision, 'unknown');
});

async function server(t, db) {
  const app = express();
  app.use(express.json());
  const context = vm.createContext({
    app, prisma: db, readAdsConsent, setAdsConsent,
    console: { error() {} }, process: { env: {} },
    firebaseAdmin: { auth: () => ({
      verifyIdToken: async token => {
        if (!['a', 'b'].includes(token)) throw new Error('invalid token');
        return { uid: token };
      },
    }) },
    ensureVerifiedBackendUser: async () => {},
    respondFamilyPersistenceError: res => res.status(503).json({ code: 'persistence_unavailable' }),
  });
  const start = source.indexOf('async function verifyFirebaseIdToken(');
  vm.runInContext(source.slice(start, source.indexOf('function resolveVerifiedUserId(', start)), context);
  const route = source.indexOf("app.get('/ads/consent/me'");
  vm.runInContext(source.slice(route, source.indexOf("app.get('/entitlements/me'", route)), context);
  const instance = app.listen(0, '127.0.0.1');
  await new Promise(resolve => instance.once('listening', resolve));
  t.after(() => new Promise(resolve => {
    instance.close(resolve); instance.closeAllConnections();
  }));
  return `http://127.0.0.1:${instance.address().port}/ads/consent/me`;
}

test('GET/PUT require verified identity, scope by token and return only metadata', async t => {
  const db = database(), url = await server(t, db);
  for (const method of ['GET', 'PUT']) {
    for (const token of [null, 'shared']) {
      const response = await fetch(url, { method,
        headers: token ? { Authorization: `Bearer ${token}` } : {} });
      assert.equal(response.status, 401);
    }
  }
  assert.equal(db.rows.size, 0);
  const headers = { Authorization: 'Bearer a', 'Content-Type': 'application/json' };
  assert.equal((await fetch(`${url}?userId=b`, { headers })).status, 403);
  const response = await fetch(url, { headers });
  assert.equal(response.headers.get('cache-control'), 'no-store');
  const { item } = await response.json();
  assert.equal(item.decision, 'unknown');
  const update = await fetch(url, {
    method: 'PUT', headers, body: JSON.stringify(choice(item, 'granted')),
  });
  assert.equal(update.status, 200);
  assert.equal((await update.json()).item.decision, 'granted');
  assert.equal(db.rows.has('b'), false);
  const mismatch = await fetch(url, {
    method: 'PUT', headers, body: JSON.stringify({ ...choice(item, 'granted'), consentVersion: 'old' }),
  });
  assert.equal(mismatch.status, 400);
  const stale = await fetch(url, { method: 'PUT', headers, body: JSON.stringify(choice(item, 'denied')) });
  assert.equal(stale.status, 409);
  db.fail();
  for (const method of ['GET', 'PUT']) {
    const failed = await fetch(url, { method, headers,
      ...(method === 'PUT' ? { body: JSON.stringify(choice(item, 'denied')) } : {}) });
    assert.equal(failed.status, 503);
    assert.equal('item' in await failed.json(), false);
  }
});
