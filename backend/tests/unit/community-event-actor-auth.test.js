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
const base = '/api/community-events';
const payload = {
  title: 'Family walk', location: 'Park', city: 'Berlin',
  eventDate: '2099-10-24T12:00:00Z', organizer: 'Parents',
};
const routes = [
  ['POST', base, payload],
  ['DELETE', `${base}/:id`, {}],
  ['POST', `${base}/:id/interest`, { displayName: 'Parent', message: 'Joining' }],
];

function fixture({ configured = true, failure, dailyCount = 0 } = {}) {
  const handlers = new Map(), accesses = [], writes = [];
  const events = new Map([
    ['own', { id: 'own', creatorId: 'a', ...payload }],
    ['foreign', { id: 'foreign', creatorId: 'b', ...payload }],
    ['ownerless', { id: 'ownerless', creatorId: null, ...payload }],
  ]);
  const interests = new Map([['b', { eventId: 'own', userId: 'b', message: 'Original' }]]);
  function access(kind, args) {
    accesses.push([kind, args]);
    if (failure === kind || failure === 'database') throw new Error('Private DB detail');
  }
  function write(kind, args) {
    access(kind, args);
    if (failure === 'write') throw new Error('Private DB detail');
    writes.push([kind, args]);
  }
  const prisma = {
    communityEvent: {
      count: async args => { access('count', args); return dailyCount; },
      create: async ({ data }) => {
        write('create', data);
        const row = { id: 'created', ...data };
        events.set(row.id, row);
        return row;
      },
      findUnique: async ({ where }) => {
        access('read', where);
        return events.get(where.id) || null;
      },
      delete: async ({ where }) => {
        write('delete', where);
        events.delete(where.id);
        return { id: where.id };
      },
      update: async ({ where, data }) => {
        write('update', { where, data });
        return Object.assign(events.get(where.id), data);
      },
      findMany: async () => [...events.values()],
    },
    communityEventInterest: {
      upsert: async ({ where, create, update }) => {
        write('interest', { where, create, update });
        const existing = interests.get(create.userId);
        const row = existing ? Object.assign(existing, update) : create;
        interests.set(create.userId, row);
        return row;
      },
      count: async () => interests.size,
      findMany: async () => [...interests.values()],
    },
  };
  const context = vm.createContext({
    prisma, console: { error() {} },
    firebaseAdmin: configured ? { auth: () => ({
      verifyIdToken: async token => {
        if (token === 'unavailable') throw Object.assign(new Error('Unavailable'), { code: 'app/network-error' });
        if (!['a', 'b', 'a'.repeat(128)].includes(token)) throw new Error('Invalid token');
        return { uid: token };
      },
    }) } : null,
    app: Object.fromEntries(['get', 'post', 'delete'].map(method => [
      method, (route, ...chain) => handlers.set(`${method.toUpperCase()} ${route}`, chain),
    ])),
  });
  vm.runInContext([
    block('async function verifyFirebaseIdToken(', 'function resolveVerifiedUserId('),
    block('function requireActorClaims(', 'function respondChatPersistenceError('),
    block("app.get('/api/community-events',", '// TREASURE ITEMS API'),
  ].join('\n'), context);
  async function request(method, route, { token = 'a', body = {}, query = {}, id = 'own' } = {}) {
    let status = 200, response;
    const req = { body, query, params: { id },
      headers: token === null ? {} : { authorization: `Bearer ${token}` } };
    const res = { status(value) { status = value; return res; },
      json(value) { response = value; return res; } };
    const chain = handlers.get(`${method} ${route}`);
    const run = i => chain[i](req, res, () => run(i + 1));
    await run(0);
    return { status, body: response };
  }
  return { request, handlers, accesses, writes, events, interests };
}

for (const [method, route, body] of routes) {
  for (const token of [null, 'invalid', 'shared']) {
    test(`${method} ${route}: token ${token} rejected before database access`, async () => {
      const f = fixture();
      assert.equal((await f.request(method, route, { token, body })).status, 401);
      assert.deepEqual(f.accesses, []);
    });
  }
  for (const location of ['body', 'query']) {
    const fields = route.endsWith('/interest') ? ['userId'] : ['userId', 'creatorId'];
    for (const field of fields) {
      test(`${method} ${route}: foreign/malformed ${location}.${field} rejected`, async () => {
        for (const claim of ['b', '', null, ['a'], { uid: 'a' }]) {
          const f = fixture();
          const options = { body: { ...body } };
          options[location] = { ...options[location], [field]: claim };
          assert.equal((await f.request(method, route, options)).status, 403);
          assert.deepEqual(f.accesses, []);
        }
      });
    }
  }
  test(`${method} ${route}: missing Firebase and verification outage fail closed`, async () => {
    for (const [config, token, status] of [[{ configured: false }, 'a', 401], [{}, 'unavailable', 503]]) {
      const f = fixture(config);
      assert.equal((await f.request(method, route, { token, body })).status, status);
      assert.deepEqual(f.accesses, []);
    }
  });
  test(`${method} ${route}: matching claims and absent claims both work`, async () => {
    for (const claims of [{}, { userId: 'a', ...(route.endsWith('/interest') ? {} : { creatorId: 'a' }) }]) {
      const f = fixture();
      const result = await f.request(method, route, { body: { ...body, ...claims }, query: claims });
      assert.ok([200, 201].includes(result.status));
      assert.ok(f.writes.length);
    }
  });
  test(`${method} ${route}: database/write failure never returns success or internal detail`, async () => {
    for (const failure of ['database', 'write']) {
      const f = fixture({ failure });
      const result = await f.request(method, route, { body });
      assert.equal(result.status, 500);
      assert.equal(result.body.success, undefined);
      assert.equal(JSON.stringify(result.body).includes('Private DB detail'), false);
      assert.deepEqual(f.writes, []);
    }
  });
}

test('create binds persisted creator and daily limit to complete verified UID', async () => {
  const token = 'a'.repeat(128);
  const f = fixture();
  const result = await f.request('POST', base, { token, body: payload });
  assert.equal(result.status, 201);
  assert.equal(result.body.creatorId, token);
  assert.equal(f.accesses[0][1].where.creatorId, token);
  assert.equal(result.body.title, payload.title);
  assert.equal(result.body.source, 'community');
  assert.equal(result.body.isFree, true);
});

test('daily maximum stays three and count failure is explicitly handled', async () => {
  const f = fixture({ dailyCount: 3 });
  assert.equal((await f.request('POST', base, { body: payload })).status, 429);
  assert.deepEqual(f.writes, []);
  const failed = fixture({ failure: 'count' });
  assert.equal((await failed.request('POST', base, { body: payload })).status, 500);
  assert.deepEqual(failed.writes, []);
});

test('only stored creator may delete, never a foreign or ownerless row', async () => {
  for (const id of ['foreign', 'ownerless']) {
    const f = fixture();
    assert.equal((await f.request('DELETE', `${base}/:id`, { id })).status, 403);
    assert.ok(f.events.has(id));
    assert.deepEqual(f.writes, []);
  }
  const f = fixture();
  assert.equal((await f.request('DELETE', `${base}/:id`, { id: 'missing' })).status, 404);
  assert.equal((await f.request('DELETE', `${base}/:id`)).status, 200);
  assert.equal(f.events.has('own'), false);
});

test('interest updates only the verified account and keeps another user untouched', async () => {
  const f = fixture();
  for (const message of ['Joining', 'New message']) {
    const result = await f.request('POST', `${base}/:id/interest`, {
      body: { displayName: 'Parent', message },
    });
    assert.equal(result.status, 200);
    assert.equal(result.body.interestCount, 2);
    assert.equal(f.interests.get('a').message, message);
    assert.equal(f.interests.get('b').message, 'Original');
  }
  assert.equal((await f.request('POST', `${base}/:id/interest`, { id: 'missing' })).status, 404);
});

test('public discovery/attendees and protected flag route keep their auth boundaries', async () => {
  const f = fixture();
  assert.equal((await f.request('GET', base, { token: null })).status, 200);
  assert.equal((await f.request('GET', `${base}/:id/attendees`, { token: null })).status, 200);
  assert.equal((await f.request('POST', `${base}/:id/flag`, { token: null })).status, 401);
});

test('real Express route chains reject absent/shared tokens and conflicting claims', async t => {
  const f = fixture(), app = express();
  app.use(express.json());
  for (const [key, chain] of f.handlers) {
    const [method, route] = key.split(' ');
    app[method.toLowerCase()](route, ...chain);
  }
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => new Promise(resolve => { server.close(resolve); server.closeAllConnections(); }));
  const host = `http://127.0.0.1:${server.address().port}`;
  for (const [method, route, body] of routes) {
    const url = host + route.replace(':id', 'own');
    for (const token of [null, 'shared']) {
      const response = await fetch(url, { method,
        headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
        body: JSON.stringify(body),
      });
      assert.equal(response.status, 401);
    }
    const field = route.endsWith('/interest') ? 'userId' : 'creatorId';
    const response = await fetch(`${url}?${field}=b`, { method,
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer a' },
      body: JSON.stringify({ ...body, [field]: 'a' }),
    });
    assert.equal(response.status, 403);
  }
  assert.deepEqual(f.accesses, []);
});
