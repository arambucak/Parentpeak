const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const express = require('express');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
function block(start, end) {
  const a = source.indexOf(start), b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, start);
  return source.slice(a, b);
}
const route = '/api/events/series/:seriesId/follow';

function fixture({ configured = true, failure, suspended = false } = {}) {
  const handlers = new Map(), accesses = [], writes = [], checks = [];
  const followers = new Set(['b']);
  function access(kind, args) {
    accesses.push([kind, args]);
    if (failure === kind || failure === 'database') throw new Error('Private DB detail');
  }
  const prisma = { eventSeriesFollower: {
    upsert: async ({ where, create }) => {
      access('upsert', { where, create });
      writes.push(['upsert', create.userId]);
      followers.add(create.userId);
      return create;
    },
    deleteMany: async ({ where }) => {
      access('delete', where);
      writes.push(['delete', where.userId]);
      followers.delete(where.userId);
      return { count: 1 };
    },
    findUnique: async ({ where }) => {
      access('read', where);
      return followers.has(where.seriesId_userId.userId) ? { ...where.seriesId_userId } : null;
    },
    count: async ({ where }) => {
      access('count', where);
      return followers.size;
    },
  } };
  const context = vm.createContext({
    prisma, console: { error() {} },
    firebaseAdmin: configured ? { auth: () => ({
      verifyIdToken: async token => {
        if (token === 'unavailable') throw Object.assign(new Error('Unavailable'), { code: 'app/network-error' });
        if (!['a', 'b'].includes(token)) throw new Error('Invalid token');
        return { uid: token };
      },
    }) } : null,
    isUserSuspended: async (uid, options) => {
      checks.push({ uid, strict: options?.strict });
      if (failure === 'suspension') throw new Error('Private suspension detail');
      return suspended;
    },
    respondSuspended: res => res.status(403).json({ code: 'account_suspended' }),
    app: Object.fromEntries(['get', 'post', 'delete'].map(method => [
      method, (path, ...chain) => handlers.set(method.toUpperCase(), chain),
    ])),
  });
  vm.runInContext([
    block('async function verifyFirebaseIdToken(', 'function resolveVerifiedUserId('),
    block("app.post('/api/events/series/:seriesId/follow',", '// COMMUNITY EVENTS API'),
  ].join('\n'), context);
  async function request(method, { token = 'a', body = {}, query = {}, seriesId = 'series' } = {}) {
    let status = 200, response;
    const req = { body, query, params: { seriesId },
      headers: token === null ? {} : { authorization: `Bearer ${token}` } };
    const res = { status(value) { status = value; return res; },
      json(value) { response = value; return res; } };
    const chain = handlers.get(method);
    const run = i => chain[i](req, res, () => run(i + 1));
    await run(0);
    return { status, body: response };
  }
  return { request, handlers, accesses, writes, checks, followers };
}

for (const method of ['POST', 'DELETE', 'GET']) {
  for (const token of [null, 'shared', 'invalid']) {
    test(`${method}: missing/shared/invalid token ${token} cannot access personal state`, async () => {
      const f = fixture();
      assert.equal((await f.request(method, { token, query: { userId: 'a' } })).status, 401);
      assert.deepEqual(f.accesses, []);
      assert.deepEqual(f.checks, []);
    });
  }
  for (const location of ['body', 'query']) {
    test(`${method}: foreign/malformed ${location}.userId rejected before any state access`, async () => {
      for (const userId of ['b', '', null, ['a'], { uid: 'a' }]) {
        const f = fixture();
        assert.equal((await f.request(method, { [location]: { userId } })).status, 403);
        assert.deepEqual(f.accesses, []);
        assert.deepEqual(f.checks, []);
      }
    });
  }
  test(`${method}: matching claims never mask a foreign claim in the other location`, async () => {
    for (const [body, query] of [[{ userId: 'a' }, { userId: 'b' }], [{ userId: 'b' }, { userId: 'a' }]]) {
      const f = fixture();
      assert.equal((await f.request(method, { body, query })).status, 403);
      assert.deepEqual(f.accesses, []);
    }
  });
  test(`${method}: missing verifier and Firebase outage fail closed`, async () => {
    for (const [config, token, status] of [[{ configured: false }, 'a', 401], [{}, 'unavailable', 503]]) {
      const f = fixture(config);
      assert.equal((await f.request(method, { token })).status, status);
      assert.deepEqual(f.accesses, []);
    }
  });
  test(`${method}: authenticated identity works with absent or matching claims`, async () => {
    for (const claims of [{}, { userId: 'a' }]) {
      const f = fixture();
      const response = await f.request(method, { body: claims, query: claims });
      assert.equal(response.status, method === 'POST' ? 201 : 200);
      assert.equal(response.body.following, method === 'POST');
      assert.ok(f.followers.has('b'));
      if (method === 'POST') {
        assert.ok(f.followers.has('a'));
        assert.deepEqual(f.checks, [{ uid: 'a', strict: true }]);
      }
      if (method === 'GET') assert.equal(f.accesses[0][1].seriesId_userId.userId, 'a');
    }
  });
  test(`${method}: database errors never return success or internal details`, async () => {
    const f = fixture({ failure: 'database' });
    const response = await f.request(method);
    assert.equal(response.status, 500);
    assert.equal(response.body.following, undefined);
    assert.equal(JSON.stringify(response.body).includes('Private DB detail'), false);
    assert.deepEqual(f.writes, []);
  });
  test(`${method}: invalid series remains explicit`, async () => {
    const f = fixture();
    assert.equal((await f.request(method, { seriesId: ' ' })).status, 400);
    assert.deepEqual(f.accesses, []);
  });
}

test('anonymous count remains public and never queries an individual follower', async () => {
  const f = fixture();
  const result = await f.request('GET', { token: null });
  assert.equal(result.status, 200);
  assert.equal(result.body.followerCount, 1);
  assert.equal(result.body.following, false);
  assert.equal(f.accesses.length, 1);
  assert.equal(f.accesses[0][0], 'count');
  assert.equal(f.accesses[0][1].seriesId, 'series');
  assert.deepEqual(f.checks, []);
});

test('own follow/unfollow idempotency and read isolation leave other followers unchanged', async () => {
  const f = fixture();
  assert.equal((await f.request('GET')).body.following, false);
  for (let i = 0; i < 2; i++) {
    assert.equal((await f.request('POST')).body.followerCount, 2);
  }
  assert.equal((await f.request('GET')).body.following, true);
  for (let i = 0; i < 2; i++) {
    const result = await f.request('DELETE');
    assert.equal(result.body.following, false);
    assert.equal(result.body.followerCount, 1);
  }
  assert.equal((await f.request('GET', { token: 'b' })).body.following, true);
  assert.deepEqual([...f.followers], ['b']);
});

test('suspended account cannot opt in; suspension-store outage fails closed; opt-out stays possible', async () => {
  const f = fixture({ suspended: true });
  assert.equal((await f.request('POST')).status, 403);
  assert.deepEqual(f.accesses, []);
  f.followers.add('a');
  assert.equal((await f.request('DELETE')).status, 200);
  assert.equal(f.followers.has('a'), false);
  const failed = fixture({ failure: 'suspension' });
  assert.equal((await failed.request('POST')).status, 500);
  assert.deepEqual(failed.accesses, []);
  assert.deepEqual(failed.writes, []);
});

test('post-write count outage is an explicit error, not a fabricated success', async () => {
  for (const method of ['POST', 'DELETE']) {
    const f = fixture({ failure: 'count' });
    const result = await f.request(method);
    assert.equal(result.status, 500);
    assert.equal(result.body.following, undefined);
  }
});

test('real Express chains enforce local guards and preserve anonymous count', async t => {
  const f = fixture(), app = express();
  app.use(express.json());
  for (const [method, chain] of f.handlers) app[method.toLowerCase()](route, ...chain);
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => new Promise(resolve => { server.close(resolve); server.closeAllConnections(); }));
  const url = `http://127.0.0.1:${server.address().port}/api/events/series/series/follow`;
  for (const method of ['POST', 'DELETE', 'GET']) {
    for (const token of [null, 'shared']) {
      const result = await fetch(`${url}?userId=b`, { method,
        headers: token ? { Authorization: `Bearer ${token}` } : {},
      });
      assert.equal(result.status, 401);
    }
    const result = await fetch(`${url}?userId=b`, { method,
      headers: { Authorization: 'Bearer a' },
    });
    assert.equal(result.status, 403);
  }
  assert.deepEqual(f.accesses, []);
  const result = await fetch(url);
  assert.equal(result.status, 200);
  assert.equal((await result.json()).followerCount, 1);
});
