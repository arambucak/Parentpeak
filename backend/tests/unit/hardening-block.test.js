const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const express = require('express');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
function slice(start, end) {
  const a = source.indexOf(start), b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `Missing block: ${start}`);
  return source.slice(a, b);
}

// ========== Zentrale Error-Middleware ==========
// Lädt die reale Error-Middleware aus server.js in eine echte Express-App und
// prüft, dass unbehandelte Fehler als generische Antwort ohne Leak enden.
function loadErrorMiddleware() {
  const context = vm.createContext({ console: { error: () => {} } });
  const block = slice('app.use((err, req, res, next) => {', '// Server starten mit Prisma');
  // Minimal-App, die die Middleware registriert.
  const app = express();
  context.app = app;
  vm.runInContext(block, context);
  return app;
}

test('error middleware returns generic 500 without leaking err.message', async t => {
  const app = express();
  app.get('/boom', () => { throw new Error('SECRET DB STRING postgres://user:pass@host'); });
  // reale Middleware anhängen
  const context = vm.createContext({ console: { error: () => {} }, app });
  vm.runInContext(slice('app.use((err, req, res, next) => {', '// Server starten mit Prisma'), context);
  const server = app.listen(0, '127.0.0.1');
  await new Promise(r => server.once('listening', r));
  t.after(() => new Promise(r => { server.close(r); server.closeAllConnections(); }));
  const base = `http://127.0.0.1:${server.address().port}`;
  const res = await fetch(`${base}/boom`);
  assert.equal(res.status, 500);
  const body = await res.text();
  assert.ok(!body.includes('SECRET'), 'must not leak error message');
  assert.ok(!body.includes('postgres://'), 'must not leak connection string');
  const json = JSON.parse(body);
  assert.equal(json.code, 'request_failed');
});

test('error middleware maps JSON parse failures to 400', async t => {
  const app = express();
  app.use(express.json());
  app.post('/echo', (req, res) => res.json(req.body));
  const context = vm.createContext({ console: { error: () => {} }, app });
  vm.runInContext(slice('app.use((err, req, res, next) => {', '// Server starten mit Prisma'), context);
  const server = app.listen(0, '127.0.0.1');
  await new Promise(r => server.once('listening', r));
  t.after(() => new Promise(r => { server.close(r); server.closeAllConnections(); }));
  const base = `http://127.0.0.1:${server.address().port}`;
  const res = await fetch(`${base}/echo`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: '{ this is not valid json',
  });
  assert.equal(res.status, 400);
  const json = await res.json();
  assert.equal(json.code, 'request_failed');
});

test('error middleware respects a route-provided status', async t => {
  const app = express();
  app.get('/teapot', (req, res, next) => next(Object.assign(new Error('x'), { status: 418 })));
  const context = vm.createContext({ console: { error: () => {} }, app });
  vm.runInContext(slice('app.use((err, req, res, next) => {', '// Server starten mit Prisma'), context);
  const server = app.listen(0, '127.0.0.1');
  await new Promise(r => server.once('listening', r));
  t.after(() => new Promise(r => { server.close(r); server.closeAllConnections(); }));
  const base = `http://127.0.0.1:${server.address().port}`;
  const res = await fetch(`${base}/teapot`);
  assert.equal(res.status, 418);
});

// ========== HSTS-Header-Logik ==========
test('HSTS header is set only in production', async () => {
  // Header-Middleware-Block isoliert laden und beide Modi prüfen.
  const block = slice("app.use(async (req, res, next) => {\n  // Baseline hardening", '\napp.use(\n  cors(');
  for (const production of [true, false]) {
    const headers = {};
    const context = vm.createContext({
      isProduction: production,
      app: { use: fn => { context._mw = fn; } },
    });
    vm.runInContext(block, context);
    const res = { setHeader: (k, v) => { headers[k] = v; } };
    await new Promise(resolve => context._mw({}, res, resolve));
    assert.equal('X-Content-Type-Options' in headers, true);
    assert.equal('Strict-Transport-Security' in headers, production,
      `HSTS presence should match production=${production}`);
  }
});

// ========== DB-TLS-Konfiguration ==========
test('database SSL config: default is non-strict, env can enable strict + CA', () => {
  const block = slice('const databaseUrl =', 'const prismaPool =');
  function evalConfig(env) {
    const out = {};
    const context = vm.createContext({ process: { env }, out });
    // const-Deklarationen landen im VM nicht als Context-Property; daher
    // den Wert explizit herausgeben.
    vm.runInContext(block + '\nout.cfg = databaseSslConfig;', context);
    return out.cfg;
  }
  // Render-URL, keine strict-Flag -> rejectUnauthorized false (bisheriges Verhalten)
  const def = evalConfig({ DATABASE_URL: 'postgres://x@db.render.com/y' });
  assert.equal(def.rejectUnauthorized, false);
  assert.equal('ca' in def, false);
  // strict aktiviert
  const strict = evalConfig({ DATABASE_URL: 'postgres://x@db.render.com/y', DATABASE_SSL_STRICT: '1' });
  assert.equal(strict.rejectUnauthorized, true);
  // strict + CA
  const withCa = evalConfig({
    DATABASE_URL: 'postgres://x@db.render.com/y',
    DATABASE_SSL_STRICT: 'true',
    DATABASE_SSL_CA: '-----BEGIN CERTIFICATE-----abc',
  });
  assert.equal(withCa.rejectUnauthorized, true);
  assert.equal(withCa.ca, '-----BEGIN CERTIFICATE-----abc');
  // Nicht-Render-URL -> kein SSL-Objekt
  const noSsl = evalConfig({ DATABASE_URL: 'postgres://x@localhost/y' });
  assert.equal(noSsl, undefined);
});
