const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

// checkRateLimit aus server.js extrahieren (reine Funktion, kein Netzwerk).
const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
const start = source.indexOf('function checkRateLimit(');
const fnSrc = source.slice(start, source.indexOf('\n}', start) + 2);
const budgetStart = source.indexOf('function checkDailyBudget(');
const budgetSrc = source.slice(budgetStart, source.indexOf('\n}', budgetStart) + 2);
const ctx = {};
vm.runInNewContext(
  fnSrc + '\n' + budgetSrc +
      '\nthis.checkRateLimit = checkRateLimit;' +
      '\nthis.checkDailyBudget = checkDailyBudget;',
  ctx,
);
const checkRateLimit = ctx.checkRateLimit;
const checkDailyBudget = ctx.checkDailyBudget;

test('erlaubt bis zum Limit, blockt danach', () => {
  const buckets = new Map();
  const opts = { windowMs: 1000, max: 3, now: 0 };
  assert.equal(checkRateLimit(buckets, 'u1', opts), true); // 1
  assert.equal(checkRateLimit(buckets, 'u1', opts), true); // 2
  assert.equal(checkRateLimit(buckets, 'u1', opts), true); // 3
  assert.equal(checkRateLimit(buckets, 'u1', opts), false); // 4 -> blockiert
});

test('getrennte Schlüssel haben eigene Buckets', () => {
  const buckets = new Map();
  const opts = { windowMs: 1000, max: 1, now: 0 };
  assert.equal(checkRateLimit(buckets, 'userA', opts), true);
  assert.equal(checkRateLimit(buckets, 'userA', opts), false);
  // Anderer Nutzer ist unberührt.
  assert.equal(checkRateLimit(buckets, 'userB', opts), true);
});

test('Fenster setzt den Zähler zurück', () => {
  const buckets = new Map();
  assert.equal(
    checkRateLimit(buckets, 'u1', { windowMs: 1000, max: 1, now: 0 }),
    true,
  );
  assert.equal(
    checkRateLimit(buckets, 'u1', { windowMs: 1000, max: 1, now: 500 }),
    false,
  );
  // Nach Ablauf des Fensters wieder erlaubt.
  assert.equal(
    checkRateLimit(buckets, 'u1', { windowMs: 1000, max: 1, now: 1500 }),
    true,
  );
});

test('Tagesbudget: erlaubt bis max, blockt danach', () => {
  const state = { day: '', count: 0 };
  const day = new Date('2026-10-03T08:00:00Z');
  assert.equal(checkDailyBudget(state, 2, day), true); // 1
  assert.equal(checkDailyBudget(state, 2, day), true); // 2
  assert.equal(checkDailyBudget(state, 2, day), false); // 3 -> blockiert
});

test('Tagesbudget: setzt sich am nächsten UTC-Tag zurück', () => {
  const state = { day: '', count: 0 };
  assert.equal(
    checkDailyBudget(state, 1, new Date('2026-10-03T23:59:00Z')),
    true,
  );
  assert.equal(
    checkDailyBudget(state, 1, new Date('2026-10-03T23:59:30Z')),
    false,
  );
  // Neuer Tag -> wieder erlaubt.
  assert.equal(
    checkDailyBudget(state, 1, new Date('2026-10-04T00:01:00Z')),
    true,
  );
});

test('Tagesbudget: max <= 0 bedeutet kein Cap', () => {
  const state = { day: '', count: 0 };
  for (let i = 0; i < 10; i++) {
    assert.equal(checkDailyBudget(state, 0, new Date('2026-10-03T08:00:00Z')), true);
  }
});
