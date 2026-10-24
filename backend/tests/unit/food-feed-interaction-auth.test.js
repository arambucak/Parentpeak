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
const prefix = '/api/food-feed/recipes/:id';
const writes = [
  ['POST', 'rate', { rating: 4, comment: 'Tasty' }],
  ['POST', 'comments', { text: 'Thank you' }],
  ['POST', 'reserve', { portions: 2 }],
  ['DELETE', 'reserve', {}],
  ['POST', 'complete', {}],
  ['POST', 'report', { reason: 'incorrect', details: 'Wrong description' }],
];

function fixture({ configured = true, failure } = {}) {
  const handlers = new Map(), accesses = [], mutations = [];
  const recipes = new Map([['recipe', { id: 'recipe', creatorUserId: 'owner', isPublished: true }]]);
  const reservations = new Map(['a', 'b'].map(userId => [userId, {
    id: `reservation-${userId}`, recipeId: 'recipe', userId, portions: 1, completedAt: null,
  }]));
  const ratings = new Map(), comments = [], reports = [];
  function access(kind, args) {
    accesses.push([kind, args]);
    if (failure === 'database') throw new Error('Private database error');
  }
  function mutate(kind, args) {
    access(kind, args);
    if (failure === 'write') throw new Error('Private database error');
    mutations.push([kind, args]);
  }
  const prisma = {
    sharedRecipe: {
      findUnique: async ({ where }) => {
        access('recipe.read', where);
        return recipes.get(where.id) || null;
      },
      update: async ({ where, data }) => {
        mutate('recipe.update', { where, data });
        return Object.assign(recipes.get(where.id), data);
      },
    },
    recipeRating: {
      upsert: async ({ where, create, update }) => {
        mutate('rating.upsert', { where, create, update });
        const row = ratings.get(create.userId);
        const result = row ? Object.assign(row, update) : { id: 'rating', ...create };
        ratings.set(create.userId, result);
        return result;
      },
      findMany: async () => [...ratings.values()],
    },
    recipeReport: {
      findFirst: async ({ where }) => {
        access('report.read', where);
        return reports.find(row => row.recipeId === where.recipeId &&
          row.reportedById === where.reportedById && where.status.in.includes(row.status)) || null;
      },
      create: async ({ data }) => {
        mutate('report.create', data);
        const row = { id: `report-${reports.length}`, ...data };
        reports.push(row);
        return row;
      },
      count: async () => reports.length,
      updateMany: async ({ data }) => {
        mutate('report.updateMany', data);
        for (const row of reports) Object.assign(row, data);
        return { count: reports.length };
      },
    },
    $transaction: async work => Promise.all(work),
    $queryRawUnsafe: async (sql, ...args) => {
      access('sql.read', args);
      if (sql.includes('FoodOfferComment')) return comments;
      if (sql.includes('SUM("portions")')) {
        const active = [...reservations.values()].filter(row => row.recipeId === args[0] && !row.completedAt);
        return [{ reservedPortions: active.reduce((sum, row) => sum + row.portions, 0), reservationsCount: active.length }];
      }
      const mine = reservations.get(args[1]);
      return mine && mine.recipeId === args[0] && !mine.completedAt ? [mine] : [];
    },
    $executeRawUnsafe: async (sql, ...args) => {
      mutate('sql.write', args);
      if (sql.includes('INSERT INTO "FoodOfferComment"')) {
        comments.push({ id: args[0], recipeId: args[1], userId: args[2], text: args[3], createdAt: args[4] });
      } else if (sql.includes('INSERT INTO "FoodOfferReservation"')) {
        reservations.set(args[2], {
          id: args[0], recipeId: args[1], userId: args[2], portions: args[3], completedAt: null,
        });
      } else if (sql.includes('DELETE FROM "FoodOfferReservation"')) {
        const row = reservations.get(args[1]);
        if (row?.recipeId === args[0] && !row.completedAt) reservations.delete(args[1]);
      } else if (sql.includes('UPDATE "FoodOfferReservation"')) {
        const row = reservations.get(args[1]);
        if (row?.recipeId === args[0] && !row.completedAt) row.completedAt = new Date();
      } else {
        assert.fail(`Unexpected SQL: ${sql}`);
      }
      return 1;
    },
  };
  const context = vm.createContext({
    prisma, console: { error() {} }, generateId: scope => `${scope}-id`,
    firebaseAdmin: configured ? { auth: () => ({
      verifyIdToken: async token => {
        if (token === 'unavailable') throw Object.assign(new Error('Unavailable'), { code: 'app/network-error' });
        if (!['a', 'b', 'owner'].includes(token)) throw new Error('Invalid token');
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
    block('function normalizeRecipeReportReason(', 'function isTreasureContentSevere('),
    block("app.post('/api/food-feed/recipes/:id/rate',", "app.get('/api/food-feed/reports',"),
  ].join('\n'), context);

  async function request(method, suffix, { token = 'a', body = {}, query = {}, id = 'recipe' } = {}) {
    let status = 200, response;
    const req = { body, query, params: { id },
      headers: token === null ? {} : { authorization: `Bearer ${token}` } };
    const res = { status(value) { status = value; return res; },
      json(value) { response = value; return res; } };
    const chain = handlers.get(`${method} ${prefix}/${suffix}`);
    const run = i => chain[i](req, res, () => run(i + 1));
    await run(0);
    return { status, body: response };
  }
  return { request, handlers, accesses, mutations, recipes, reservations, ratings, comments, reports };
}

for (const [method, suffix, payload] of writes) {
  for (const token of [null, 'invalid', 'shared']) {
    test(`${method} ${suffix}: absent/invalid/shared token ${token} never reaches persistence`, async () => {
      const f = fixture();
      assert.equal((await f.request(method, suffix, { token, body: { ...payload, userId: 'a' } })).status, 401);
      assert.deepEqual(f.accesses, []);
    });
  }
  for (const location of ['body', 'query']) {
    test(`${method} ${suffix}: foreign or malformed ${location}.userId rejected before persistence`, async () => {
      for (const userId of ['b', '', null, ['a'], { uid: 'a' }]) {
        const f = fixture();
        const options = { body: { ...payload }, [location]: { ...payload, userId } };
        assert.equal((await f.request(method, suffix, options)).status, 403);
        assert.deepEqual(f.accesses, []);
      }
    });
  }
  test(`${method} ${suffix}: missing verifier and verification outage fail closed`, async () => {
    for (const [options, token, status] of [[{ configured: false }, 'a', 401], [{}, 'unavailable', 503]]) {
      const f = fixture(options);
      assert.equal((await f.request(method, suffix, { token, body: payload })).status, status);
      assert.deepEqual(f.accesses, []);
    }
  });
  test(`${method} ${suffix}: own actor derived from token with absent or matching claims`, async () => {
    for (const claims of [{}, { userId: 'a' }]) {
      const f = fixture();
      const result = await f.request(method, suffix, { body: { ...payload, ...claims } });
      assert.ok([200, 201].includes(result.status), `${result.status}`);
      assert.ok(f.mutations.length > 0);
      assert.equal(f.reservations.get('b').completedAt, null);
      assert.equal(f.reservations.get('b').portions, 1);
      if (suffix === 'rate') assert.equal(f.ratings.get('a').userId, 'a');
      if (suffix === 'comments') assert.equal(f.comments[0].userId, 'a');
      if (suffix === 'report') assert.equal(f.reports[0].reportedById, 'a');
      if (suffix === 'reserve' && method === 'POST') assert.equal(f.reservations.get('a').portions, 2);
      if (suffix === 'reserve' && method === 'DELETE') assert.equal(f.reservations.has('a'), false);
      if (suffix === 'complete') assert.ok(f.reservations.get('a').completedAt);
    }
  });
  test(`${method} ${suffix}: database/write failures never report success`, async () => {
    for (const failure of ['database', 'write']) {
      const f = fixture({ failure });
      const response = await f.request(method, suffix, { body: payload });
      assert.equal(response.status, 500);
      assert.equal(response.body.success, undefined);
      assert.equal(JSON.stringify(response.body).includes('Private database error'), false);
      assert.deepEqual(f.mutations, []);
    }
  });
}

test('report rejects all foreign reportedById aliases even alongside matching userId', async () => {
  for (const location of ['body', 'query']) {
    for (const reportedById of ['b', null, ['a'], '']) {
      const f = fixture();
      const options = { body: { reason: 'incorrect', userId: 'a' } };
      options[location] = { ...options[location], reportedById };
      assert.equal((await f.request('POST', 'report', options)).status, 403);
      assert.deepEqual(f.accesses, []);
    }
  }
});

test('report duplicate protection and severe auto-moderation stay intact', async () => {
  const f = fixture();
  const options = { body: { reportedById: 'a', reason: 'scam' } };
  const result = await f.request('POST', 'report', options);
  assert.equal(result.status, 201);
  assert.equal(result.body.autoModeration.action, 'unpublished_severe');
  assert.equal(f.recipes.get('recipe').isPublished, false);
  assert.equal((await f.request('POST', 'report', options)).status, 409);
  assert.equal(f.reports.length, 1);
});

test('only an existing own open reservation can be completed', async () => {
  const f = fixture();
  f.reservations.delete('a');
  assert.equal((await f.request('POST', 'complete')).status, 404);
  assert.deepEqual(f.mutations, []);
  assert.equal(f.reservations.get('b').completedAt, null);
});

test('anonymous reservation aggregate remains public without individual records', async () => {
  const f = fixture();
  const result = await f.request('GET', 'reservations', { token: null });
  assert.equal(result.status, 200);
  assert.equal(result.body.reservedPortions, 2);
  assert.equal(result.body.reservationsCount, 2);
  assert.equal(result.body.myReservation, null);
  assert.equal(f.accesses.filter(([kind]) => kind === 'sql.read').length, 1);
});

test('personal reservation reads require Firebase, reject foreign claims and derive identity from token', async () => {
  for (const token of [null, 'shared', 'invalid', 'unavailable']) {
    const f = fixture();
    assert.equal((await f.request('GET', 'reservations', { token, query: { userId: 'a' } })).status,
      token === 'unavailable' ? 503 : 401);
    assert.deepEqual(f.accesses, []);
  }
  for (const location of ['query', 'body']) {
    const f = fixture();
    assert.equal((await f.request('GET', 'reservations', { [location]: { userId: 'b' } })).status, 403);
    assert.deepEqual(f.accesses, []);
  }
  for (const query of [{}, { userId: 'a' }]) {
    const f = fixture();
    const result = await f.request('GET', 'reservations', { query });
    assert.equal(result.status, 200);
    assert.equal(result.body.myReservation.userId, 'a');
    assert.equal(result.body.myReservation.id, 'reservation-a');
    assert.equal(result.body.reservedPortions, 2);
  }
  const f = fixture({ failure: 'database' });
  assert.equal((await f.request('GET', 'reservations')).status, 500);
});

test('public comments stay readable and missing recipes/validation stay explicit', async () => {
  const f = fixture();
  assert.equal((await f.request('GET', 'comments', { token: null })).status, 200);
  assert.equal((await f.request('POST', 'comments', { body: { text: '' } })).status, 400);
  assert.equal((await f.request('POST', 'rate', { body: { rating: 6 } })).status, 400);
  assert.equal((await f.request('POST', 'report', { body: { reason: 'x' } })).status, 400);
  for (const suffix of ['comments', 'reserve', 'complete', 'report']) {
    const payload = writes.find(row => row[1] === suffix)[2];
    assert.equal((await f.request('POST', suffix, { id: 'missing', body: payload })).status, 404);
  }
  assert.deepEqual(f.mutations, []);
});

test('real Express chains enforce guards without global auth and keep public aggregates', async t => {
  const f = fixture(), app = express();
  app.use(express.json());
  for (const [key, chain] of f.handlers) {
    const [method, route] = key.split(' ');
    app[method.toLowerCase()](route, ...chain);
  }
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => new Promise(resolve => { server.close(resolve); server.closeAllConnections(); }));
  const base = `http://127.0.0.1:${server.address().port}/api/food-feed/recipes/recipe`;
  for (const [method, suffix, payload] of writes) {
    for (const token of [null, 'shared']) {
      const response = await fetch(`${base}/${suffix}`, { method,
        headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
        body: JSON.stringify(payload),
      });
      assert.equal(response.status, 401);
    }
    const response = await fetch(`${base}/${suffix}?userId=b`, { method,
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer a' },
      body: JSON.stringify({ ...payload, userId: 'a' }),
    });
    assert.equal(response.status, 403);
  }
  assert.equal((await fetch(`${base}/reservations`)).status, 200);
  assert.equal((await fetch(`${base}/reservations?userId=b`)).status, 401);
  assert.equal((await fetch(`${base}/reservations?userId=b`, { headers: { Authorization: 'Bearer a' } })).status, 403);
  assert.deepEqual(f.mutations, []);
});
