const assert = require('node:assert/strict');
const crypto = require('node:crypto');
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
const familyId = uid => `account-family-v1-${crypto.createHash('sha256').update(uid).digest('hex')}`;
const clone = value => JSON.parse(JSON.stringify(value));

// Meal-Routen des aktuellen main-Stands.
const mealRoutes = [
  ['GET', '/api/meal-plans/:familyId'],
  ['GET', '/api/meal-plans/:familyId/week'],
  ['POST', '/api/meal-plans/:familyId'],
  ['POST', '/api/meals/:mealPlanId'],
  ['PUT', '/api/meals/:mealId'],
  ['DELETE', '/api/meals/:mealId'],
];

function fixture({ app, configured = true, failure, production = true } = {}) {
  const handlers = new Map(), calls = [], logs = [];
  const users = new Map(['a', 'b'].map(id => [id, { id }]));
  const families = new Map([
    [familyId('a'), { id: familyId('a'), createdById: 'a', memberUsers: [{ id: 'a' }] }],
    [familyId('b'), { id: familyId('b'), createdById: 'b', memberUsers: [{ id: 'b' }] }],
  ]);
  // MealPlans gehören zu A, B und einem Legacy-/Demo-Kontext.
  const mealPlans = [
    { id: 'plan-a', familyId: familyId('a'), date: '2026-01-01' },
    { id: 'plan-b', familyId: familyId('b'), date: '2026-01-01' },
    { id: 'plan-demo', familyId: 'demo-family-001', date: '2026-01-01' },
  ];
  const meals = [
    { id: 'meal-a', mealPlanId: 'plan-a', title: 'A', type: 'breakfast' },
    { id: 'meal-b', mealPlanId: 'plan-b', title: 'B', type: 'breakfast' },
  ];
  const planFamily = id => (mealPlans.find(p => p.id === id) || {}).familyId;
  let queue = Promise.resolve();

  const mealModel = {
    deleteMany: async ({ where }) => {
      if (failure === 'data') throw new Error('DB unavailable');
      const fam = where.mealPlan?.familyId;
      let count = 0;
      for (let i = meals.length - 1; i >= 0; i--) {
        if (planFamily(meals[i].mealPlanId) === fam) { meals.splice(i, 1); count++; }
      }
      return { count };
    },
    create: async ({ data }) => {
      if (failure === 'create') throw new Error('DB unavailable');
      calls.push(['meal-create', data.mealPlanId]);
      const row = { id: `meal-new-${meals.length}`, ...clone(data) };
      meals.push(row);
      return row;
    },
    findUnique: async ({ where, select }) => {
      calls.push(['meal-read', where.id]);
      if (failure === 'data') throw new Error('DB unavailable');
      const row = meals.find(m => m.id === where.id);
      if (!row) return null;
      if (select && select.mealPlan) {
        return { id: row.id, mealPlan: { familyId: planFamily(row.mealPlanId) } };
      }
      return clone(row);
    },
    update: async ({ where, data }) => {
      calls.push(['meal-update', where.id]);
      const row = meals.find(m => m.id === where.id);
      Object.assign(row, clone(data));
      return clone(row);
    },
    delete: async ({ where }) => {
      calls.push(['meal-delete', where.id]);
      meals.splice(meals.findIndex(m => m.id === where.id), 1);
      return { id: where.id };
    },
    findMany: async ({ where }) => meals.filter(m => planFamily(m.mealPlanId) === where?.mealPlanId).map(clone),
  };

  const mealPlanModel = {
    findUnique: async ({ where, include, select }) => {
      calls.push(['plan-read', where.id || JSON.stringify(where)]);
      if (failure === 'data') throw new Error('DB unavailable');
      let row;
      if (where.id) row = mealPlans.find(p => p.id === where.id);
      else if (where.familyId_date) {
        row = mealPlans.find(p => p.familyId === where.familyId_date.familyId);
      }
      if (!row) return null;
      if (select) return { id: row.id, familyId: row.familyId };
      const out = clone(row);
      if (include?.meals) out.meals = meals.filter(m => m.mealPlanId === row.id).map(clone);
      return out;
    },
    upsert: async ({ where, create }) => {
      calls.push(['plan-upsert', where.familyId_date.familyId]);
      if (failure === 'upsert') throw new Error('DB unavailable');
      let row = mealPlans.find(p => p.familyId === where.familyId_date.familyId);
      if (!row) { row = { id: `plan-new`, ...clone(create) }; mealPlans.push(row); }
      return clone(row);
    },
    findMany: async ({ where }) => {
      calls.push(['plan-list', where.familyId]);
      assert.ok(where.familyId, 'Unrestricted meal-plan read forbidden');
      if (failure === 'data') throw new Error('DB unavailable');
      return mealPlans.filter(p => p.familyId === where.familyId).map(p => {
        const out = clone(p);
        out.meals = meals.filter(m => m.mealPlanId === p.id).map(clone);
        return out;
      });
    },
    deleteMany: async ({ where }) => {
      calls.push(['plan-deletemany', where.familyId]);
      let count = 0;
      for (let i = mealPlans.length - 1; i >= 0; i--) {
        if (mealPlans[i].familyId === where.familyId) { mealPlans.splice(i, 1); count++; }
      }
      return { count };
    },
  };

  const prisma = {
    user: {
      findUnique: async ({ where }) => users.get(where.id) || null,
      upsert: async ({ where, create }) => {
        if (!users.has(where.id)) users.set(where.id, clone(create));
        return users.get(where.id);
      },
    },
    family: {
      upsert: async ({ where, create, update }) => {
        assert.deepEqual(Object.keys(update), []);
        if (failure === 'family') throw new Error('DB unavailable');
        if (!families.has(where.id)) families.set(where.id, {
          id: create.id, createdById: create.createdById,
          memberUsers: clone(create.memberUsers.connect),
        });
        return clone(families.get(where.id));
      },
      findUnique: async ({ where }) => families.get(where.id) || null,
    },
    mealPlan: mealPlanModel,
    meal: mealModel,
    todo: { findMany: async () => [] },
    shoppingItem: { findMany: async () => [] },
  };
  prisma.$transaction = (operation, options) => {
    const snapshotPlans = clone(mealPlans), snapshotMeals = clone(meals);
    const result = queue.then(() => operation(prisma)).catch(error => {
      mealPlans.length = 0; mealPlans.push(...snapshotPlans);
      meals.length = 0; meals.push(...snapshotMeals);
      throw error;
    });
    queue = result.catch(() => {});
    return result;
  };

  const context = vm.createContext({
    crypto, prisma,
    firebaseAdmin: configured ? { auth: () => ({
      verifyIdToken: async token => {
        if (!['a', 'b'].includes(token)) throw new Error('Invalid');
        return { uid: token };
      },
      getUser: async uid => ({ uid, email: `${uid}@example.test`, emailVerified: true, displayName: 'Parent' }),
    }) } : null,
    console: { error: (...args) => logs.push(args) },
    process: { env: { NODE_ENV: production ? 'production' : 'development', FIREBASE_REQUIRE_AUTH: '1' } },
    disableInMemoryFallbacks: true,
    backendApiToken: 'shared', requireAuthForWrites: true,
    generateId: prefix => `${prefix}-new`,
    app: app || Object.fromEntries(['get', 'post', 'put', 'delete'].map(method => [
      method, (route, ...chain) => handlers.set(`${method.toUpperCase()} ${route}`, chain),
    ])),
  });
  vm.runInContext(slice('async function verifyFirebaseIdToken(', 'function resolveVerifiedUserId('), context);
  vm.runInContext(slice('class FamilyContextError', 'async function ensurePaymentContext('), context);
  vm.runInContext(slice('const firebaseRequireAuth =', '\n// Middleware'), context);
  vm.runInContext(slice("app.get('/api/meal-plans/:familyId'", '// PARENT MATCHING - Modern'), context);

  async function request(method, route, { token = 'a', query = {}, body = {}, params = {} } = {}) {
    let status = 200, response;
    const req = {
      method, path: route,
      headers: token === null ? {} : { authorization: `Bearer ${token}` },
      query, body,
      params,
    };
    const res = { status(value) { status = value; return res; },
      json(value) { response = value; return res; }, send() { return res; } };
    const chain = handlers.get(`${method} ${route}`);
    const run = i => chain[i](req, res, () => run(i + 1));
    await run(0);
    return { status, body: response };
  }
  return { context, request, calls, logs, mealPlans, meals, families, users };
}

// --- Auth-Grundtests für alle 6 Routen ---
for (const [method, route] of mealRoutes) {
  for (const token of [null, 'invalid', 'expired', 'shared']) {
    test(`${method} ${route} rejects ${token ?? 'missing'} token`, async () => {
      const f = fixture();
      const result = await f.request(method, route, { token, params: { familyId: 'own', mealPlanId: 'plan-a', mealId: 'meal-a' } });
      assert.equal(result.status, 401);
      assert.deepEqual(f.calls, []);
    });
  }
  test(`${method} ${route} rejects missing Admin configuration`, async () => {
    const f = fixture({ configured: false });
    const result = await f.request(method, route, { params: { familyId: 'own', mealPlanId: 'plan-a', mealId: 'meal-a' } });
    assert.equal(result.status, 401);
    assert.deepEqual(f.calls, []);
  });
}

// --- Familien-/Owner-Trennung ---
test('GET meal-plan accepts own selector and resolves token family', async () => {
  const f = fixture();
  const result = await f.request('GET', '/api/meal-plans/:familyId', {
    token: 'a', params: { familyId: 'own' }, query: { date: '2026-01-01' },
  });
  assert.equal(result.status, 200);
  assert.equal(result.body.familyId, familyId('a'));
});

test('GET meal-plan accepts exact own family id but rejects foreign/demo', async () => {
  const f = fixture();
  const ok = await f.request('GET', '/api/meal-plans/:familyId', {
    token: 'a', params: { familyId: familyId('a') }, query: { date: '2026-01-01' },
  });
  assert.equal(ok.status, 200);
  for (const foreign of [familyId('b'), 'demo-family-001']) {
    const denied = await f.request('GET', '/api/meal-plans/:familyId', {
      token: 'a', params: { familyId: foreign }, query: { date: '2026-01-01' },
    });
    assert.equal(denied.status, 403);
  }
});

test('GET week reads only token family', async () => {
  const f = fixture();
  for (const uid of ['a', 'b']) {
    const result = await f.request('GET', '/api/meal-plans/:familyId/week', {
      token: uid, params: { familyId: 'own' }, query: { startDate: '2026-01-01' },
    });
    assert.equal(result.status, 200);
    assert.ok(result.body.every(p => p.familyId === familyId(uid)));
  }
});

test('POST meal-plan writes to own family only, replace is transactional', async () => {
  const f = fixture();
  const result = await f.request('POST', '/api/meal-plans/:familyId', {
    token: 'a', params: { familyId: 'own' },
    body: { date: '2026-01-01', meals: [{ title: 'Neu', type: 'lunch' }] },
  });
  assert.equal(result.status, 201);
  // Nur A-Meals ersetzt; B bleibt unberührt.
  assert.ok(f.meals.some(m => m.mealPlanId === 'plan-b'));
});

test('POST meal-plan replace rolls back fully on error', async () => {
  const f = fixture({ failure: 'create' });
  const before = clone(f.meals);
  const result = await f.request('POST', '/api/meal-plans/:familyId', {
    token: 'a', params: { familyId: 'own' },
    body: { date: '2026-01-01', meals: [{ title: 'Neu', type: 'lunch' }] },
  });
  assert.equal(result.status, 503);
  assert.deepEqual(f.meals, before); // kein halb geleerter Plan
});

test('POST meal cannot target a foreign meal plan', async () => {
  const f = fixture();
  const denied = await f.request('POST', '/api/meals/:mealPlanId', {
    token: 'a', params: { mealPlanId: 'plan-b' }, body: { title: 'X', type: 'lunch' },
  });
  assert.equal(denied.status, 404);
  const ok = await f.request('POST', '/api/meals/:mealPlanId', {
    token: 'a', params: { mealPlanId: 'plan-a' }, body: { title: 'X', type: 'lunch' },
  });
  assert.equal(ok.status, 201);
});

for (const method of ['PUT', 'DELETE']) {
  test(`${method} meal foreign/missing is 404 and unchanged`, async () => {
    const f = fixture();
    const before = clone(f.meals);
    for (const mealId of ['meal-b', 'missing']) {
      const result = await f.request(method, `/api/meals/:mealId`, {
        token: 'a', params: { mealId }, body: { title: 'X', type: 'lunch' },
      });
      assert.equal(result.status, 404);
    }
    assert.deepEqual(f.meals, before);
  });
  test(`${method} meal own id succeeds`, async () => {
    const f = fixture();
    const result = await f.request(method, `/api/meals/:mealId`, {
      token: 'a', params: { mealId: 'meal-a' }, body: { title: 'X', type: 'lunch' },
    });
    assert.equal(result.status, 200);
  });
}

// --- DB-Fehler => 503, kein Datenleck ---
test('persistence failure returns 503 without exposing data', async () => {
  const f = fixture({ failure: 'data' });
  const result = await f.request('GET', '/api/meal-plans/:familyId/week', {
    token: 'a', params: { familyId: 'own' }, query: { startDate: '2026-01-01' },
  });
  assert.equal(result.status, 503);
});

// --- Lifecycle: Export deckt Meal-Plans owner-scoped ab ---
test('export helper includes own meal plans only, non-provisioning', async () => {
  const f = fixture();
  const result = await f.context.exportOwnFamilyItems('a');
  assert.equal(result.mealPlans.length, 1);
  assert.equal(result.mealPlans[0].familyId, familyId('a'));
  assert.ok(Array.isArray(result.mealPlans[0].meals));
});

// --- Echte Express-Kette: GET nicht ungeschützt ---
test('real Express chain protects meal routes', async t => {
  const app = express(); app.use(express.json());
  fixture({ app });
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => new Promise(resolve => { server.close(resolve); server.closeAllConnections(); }));
  const base = `http://127.0.0.1:${server.address().port}`;
  assert.equal((await fetch(`${base}/api/meal-plans/own?date=2026-01-01`)).status, 401);
  assert.equal((await fetch(`${base}/api/meal-plans/own?date=2026-01-01`,
    { headers: { Authorization: 'Bearer a' } })).status, 200);
  assert.equal((await fetch(`${base}/api/meal-plans/${familyId('b')}?date=2026-01-01`,
    { headers: { Authorization: 'Bearer a' } })).status, 403);
});
