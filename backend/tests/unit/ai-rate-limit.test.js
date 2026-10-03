const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

// checkRateLimit aus server.js extrahieren (reine Funktion, kein Netzwerk).
const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
const start = source.indexOf('function checkRateLimit(');
const fnSrc = source.slice(start, source.indexOf('\n}', start) + 2);
const ctx = {};
vm.runInNewContext(fnSrc + '\nthis.checkRateLimit = checkRateLimit;', ctx);
const checkRateLimit = ctx.checkRateLimit;

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
