const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const express = require('express');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
const start = source.indexOf('function respondLegacyReferralRetired(');
const end = source.indexOf("app.post('/account/delete-data',", start);
assert.ok(start >= 0 && end > start);
const retiredRoutes = [
  ['POST', '/referrals/record'],
  ['GET', '/referrals/pending/:code'],
  ['DELETE', '/referrals/claim/:code'],
];

function fixture() {
  const handlers = new Map(), accesses = [];
  const forbidden = name => () => {
    accesses.push(name);
    throw new Error(`Retired route must not use ${name}`);
  };
  const context = vm.createContext({
    prisma: new Proxy({}, { get: (_target, name) => forbidden(`prisma.${String(name)}`) }),
    ensureSocialSchemaReady: forbidden('schema'),
    generateId: forbidden('id'),
    respondWithStrictPersistenceError: forbidden('fallback'),
    console: { log: forbidden('log'), error: forbidden('error') },
    app: Object.fromEntries(['get', 'post', 'delete'].map(method => [
      method, (route, ...chain) => handlers.set(`${method.toUpperCase()} ${route}`, chain),
    ])),
  });
  vm.runInContext(source.slice(start, end), context);
  return { handlers, accesses };
}

for (const [method, route] of retiredRoutes) {
  for (const identity of [null, 'shared', 'firebase-a', 'firebase-b']) {
    test(`${method} ${route} is gone for identity ${identity} without data access`, () => {
      const f = fixture();
      let status, body;
      const headers = {};
      const req = {
        body: { referralCode: 'SECRET-CODE', inviteeId: 'private-user', inviteeName: 'Private Name' },
        params: { code: 'SECRET-CODE' }, query: { userId: 'private-user' },
        firebaseUid: identity, headers: identity ? { authorization: `Bearer ${identity}` } : {},
      };
      const res = {
        setHeader(name, value) { headers[name] = value; },
        status(value) { status = value; return res; },
        json(value) { body = value; return res; },
      };
      const chain = f.handlers.get(`${method} ${route}`);
      assert.equal(chain.length, 1);
      chain[0](req, res);
      assert.equal(status, 410);
      assert.equal(body.code, 'referral_retired');
      assert.equal(headers['Cache-Control'], 'no-store');
      for (const key of ['success', 'claimed', 'referrals', 'inviteeId', 'inviteeName', 'ts']) {
        assert.equal(body[key], undefined);
      }
      assert.equal(JSON.stringify(body).includes('SECRET-CODE'), false);
      assert.equal(JSON.stringify(body).includes('private-user'), false);
      assert.equal(JSON.stringify(body).includes('Private Name'), false);
      assert.deepEqual(f.accesses, []);
    });
  }
}

test('real Express routes retire malformed and valid requests identically; pending HEAD is also gone', async t => {
  const f = fixture(), app = express();
  app.use(express.json());
  for (const [key, chain] of f.handlers) {
    const [method, route] = key.split(' ');
    app[method.toLowerCase()](route, ...chain);
  }
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => new Promise(resolve => { server.close(resolve); server.closeAllConnections(); }));
  const base = `http://127.0.0.1:${server.address().port}`;
  for (const [method, route] of retiredRoutes) {
    for (const body of [{}, { referralCode: 'TEST-CODE', inviteeId: 'other', inviteeName: 'Private Name' }]) {
      const response = await fetch(base + route.replace(':code', 'TEST-CODE'), {
        method,
        headers: { 'Content-Type': 'application/json' },
        ...(method === 'GET' ? {} : { body: JSON.stringify(body) }),
      });
      assert.equal(response.status, 410);
      assert.equal(response.headers.get('cache-control'), 'no-store');
      assert.equal((await response.json()).code, 'referral_retired');
    }
  }
  const head = await fetch(`${base}/referrals/pending/TEST-CODE`, { method: 'HEAD' });
  assert.equal(head.status, 410);
  assert.equal(await head.text(), '');
  assert.deepEqual(f.accesses, []);
});

test('no legacy memory fallback or referral route storage operations remain', () => {
  assert.equal(source.includes('_pendingReferrals'), false);
  const retired = source.slice(start, end);
  for (const name of ['prisma', 'PendingReferral', 'ensureSocialSchemaReady', 'console.', 'inviteeId']) {
    assert.equal(retired.includes(name), false, name);
  }
  assert.equal(fixture().handlers.size, 3);
});
