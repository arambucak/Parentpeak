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
const routes = ['todos', 'shopping'].flatMap(name => [
  ['GET', `/${name}`], ['POST', `/${name}`],
  ['PUT', `/${name}/:id`], ['DELETE', `/${name}/:id`],
]);
const clone = value => JSON.parse(JSON.stringify(value));

function fixture({ app, configured = true, failure, production = true,
  fallback = false, owner = 'a', members = ['a'], preProvisioned = true,
  emailConflict = false, retries = 0, retryCode = 'P2034', firebaseAccount = {} } = {}) {
  const handlers = new Map(), calls = [], logs = [];
  const users = new Map(preProvisioned ? ['a', 'b'].map(id => [id, { id }]) : []);
  const families = new Map(preProvisioned ? [
    [familyId('a'), { id: familyId('a'), createdById: owner,
      memberUsers: members.map(id => ({ id })) }],
    [familyId('b'), { id: familyId('b'), createdById: 'b', memberUsers: [{ id: 'b' }] }],
  ] : []);
  const initial = name => ['a', 'b', 'demo'].map(uid => ({
    id: `${name}-${uid}`, familyId: uid === 'demo' ? 'demo-family-001' : familyId(uid),
    title: uid, name: uid, done: false, bought: false, description: '{}',
  }));
  const data = { todo: initial('todo'), shoppingItem: initial('shop') };
  const memory = { todos: initial('memtodo'), shoppingItems: initial('memshop') };
  let queue = Promise.resolve(), transactionAttempts = 0;
  const p2025 = () => Object.assign(new Error('Not found'), { code: 'P2025' });
  const prisma = {
    user: {
      findUnique: async ({ where }) => {
        calls.push(['user-read', where.id]);
        if (failure === 'user') throw new Error('DB unavailable');
        return users.get(where.id) || null;
      },
      upsert: async ({ where, create }) => {
        calls.push(['user-upsert', where.id]);
        if (emailConflict) throw Object.assign(new Error('Email collision'), { code: 'P2002' });
        if (!users.has(where.id)) users.set(where.id, clone(create));
        return users.get(where.id);
      },
      count: async ({ where }) => Number(users.has(where.id)),
      deleteMany: async ({ where }) => {
        calls.push(['user-delete', where.id]);
        const count = Number(users.delete(where.id));
        for (const [id, family] of families) {
          if (family.createdById !== where.id) continue;
          families.delete(id);
          for (const table of Object.values(data)) {
            for (let i = table.length - 1; i >= 0; i--) if (table[i].familyId === id) table.splice(i, 1);
          }
        }
        return { count };
      },
    },
    family: {
      upsert: async ({ where, create, update }) => {
        calls.push(['family-upsert', where.id]);
        assert.deepEqual(Object.keys(update), []);
        if (failure === 'family') throw new Error('DB unavailable');
        if (transactionAttempts++ < retries) {
          throw Object.assign(new Error('Serialization conflict'), { code: retryCode });
        }
        if (!families.has(where.id)) families.set(where.id, {
          id: create.id, createdById: create.createdById,
          memberUsers: clone(create.memberUsers.connect),
        });
        return clone(families.get(where.id));
      },
      findUnique: async ({ where }) => {
        if (failure === 'family') throw new Error('DB unavailable');
        return families.get(where.id) || null;
      },
      findMany: async ({ where }) => [...families.values()].filter(f => f.createdById === where.createdById),
    },
  };
  for (const [model, table] of Object.entries(data)) {
    const matching = where => table.find(row => row.id === where.id && row.familyId === where.familyId);
    prisma[model] = {
      findMany: async ({ where }) => {
        calls.push([`${model}-list`, where?.familyId]);
        assert.ok(where?.familyId, 'Unrestricted read forbidden');
        if (failure === 'data') throw new Error('DB unavailable');
        return table.filter(row => row.familyId === where.familyId).map(clone);
      },
      findUnique: async ({ where }) => {
        calls.push([`${model}-read`, where.id, where.familyId]);
        assert.ok(where.familyId);
        if (failure === 'data') throw new Error('DB unavailable');
        return matching(where) ? clone(matching(where)) : null;
      },
      create: async ({ data: create }) => {
        if (failure === 'data') throw new Error('DB unavailable');
        calls.push([`${model}-create`, create.familyId]);
        const row = { id: `${model}-new`, ...clone(create) };
        table.push(row);
        return row;
      },
      update: async ({ where, data: update }) => {
        calls.push([`${model}-update`, where.id, where.familyId]);
        assert.ok(where.familyId);
        if (failure === 'data') throw new Error('DB unavailable');
        const row = matching(where);
        if (!row) throw p2025();
        Object.assign(row, clone(update));
        return row;
      },
      delete: async ({ where }) => {
        calls.push([`${model}-delete`, where.id, where.familyId]);
        assert.ok(where.familyId);
        if (failure === 'data') throw new Error('DB unavailable');
        const row = matching(where);
        if (!row) throw p2025();
        table.splice(table.indexOf(row), 1);
        return row;
      },
    };
  }
  prisma.$transaction = (operation, options) => {
    assert.equal(options.isolationLevel, 'Serializable');
    const result = queue.then(async () => {
      const snapshot = clone([...families]);
      try { return await operation(prisma); }
      catch (error) {
        families.clear();
        for (const [id, family] of snapshot) families.set(id, family);
        throw error;
      }
    });
    queue = result.catch(() => {});
    return result;
  };
  const context = vm.createContext({
    crypto, prisma, ...memory,
    firebaseAdmin: configured ? { auth: () => ({
      verifyIdToken: async token => {
        if (failure === 'verification') {
          throw Object.assign(new Error('Firebase unavailable'), { code: 'app/network-error' });
        }
        if (!['a', 'b'].includes(token)) throw new Error('Invalid');
        return { uid: token };
      },
      getUser: async uid => {
        if (failure === 'firebase') throw new Error('Firebase unavailable');
        return { uid, email: `${uid}@example.test`, emailVerified: true, displayName: 'Parent', ...firebaseAccount };
      },
    }) } : null,
    console: { error: (...args) => logs.push(args) },
    process: { env: { NODE_ENV: production ? 'production' : 'development', FIREBASE_REQUIRE_AUTH: '1' } },
    disableInMemoryFallbacks: !fallback,
    backendApiToken: 'shared', requireAuthForWrites: true,
    WRITE_METHODS: new Set(['POST', 'PUT', 'PATCH', 'DELETE']),
    isWriteRequest: req => ['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method),
    generateId: prefix => `${prefix}-new`,
    app: app || Object.fromEntries(['get', 'post', 'put', 'delete'].map(method => [
      method, (route, ...chain) => handlers.set(`${method.toUpperCase()} ${route}`, chain),
    ])),
  });
  vm.runInContext(slice('async function verifyFirebaseIdToken(', 'function resolveVerifiedUserId('), context);
  vm.runInContext(slice('class FamilyContextError', 'async function ensurePaymentContext('), context);
  vm.runInContext(slice('function parseTodoDescription(', 'function buildLocalEmail('), context);
  vm.runInContext(slice('const firebaseRequireAuth =', '\n// Middleware'), context);
  if (app) {
    app.use(context.firebaseAuthMiddleware);
    const start = source.lastIndexOf('app.use(async (req, res, next) => {',
      source.indexOf('  if (!requireAuthForWrites)'));
    vm.runInContext(source.slice(start, source.indexOf('\nconst allowedGeminiModels', start)), context);
  }
  vm.runInContext(slice('// 8. Todos', '// 10. Calendar events'), context);
  Object.assign(context, {
    isProduction: production,
    respondWithStrictPersistenceError: () => false,
    deleteAccountDataByUserIdPrisma: async uid => {
      calls.push(['delete-account', uid]);
      return { removed: 0, hostedEventIds: [], mediaUrls: [] };
    },
    exportAccountDataByUserIdPrisma: uid => context.exportOwnFamilyItems(uid),
    countAccountDataByUserIdInMemory: () => 0,
    deleteAccountDataByUserIdInMemory: uid => { calls.push(['delete-memory', uid]); return 0; },
    deleteUnreferencedAccountMedia: async () => ({}),
  });
  vm.runInContext(slice('async function authorizeAccountOwner(', 'async function authorizeProfileOwner('), context);
  vm.runInContext(slice("app.post('/account/delete-data'", "app.get('/entitlements/:userId/status'"), context);
  async function request(method, route, { token = 'a', query = {}, body = {}, id } = {}) {
    let status = 200, response;
    const req = {
      method, path: route,
      headers: token === null ? {} : { authorization: `Bearer ${token}` },
      query, body: { title: 'New', name: 'New', completed: true, checked: true, ...body },
      params: { id: id || (route.includes('todos') ? 'todo-a' : 'shop-a') },
    };
    const res = { status(value) { status = value; return res; },
      json(value) { response = value; return res; }, send() { return res; } };
    const chain = handlers.get(`${method} ${route}`);
    const run = i => chain[i](req, res, () => run(i + 1));
    await run(0);
    return { status, body: response };
  }
  return { context, request, calls, logs, data, memory, families, users, prisma };
}

for (const [method, route] of routes) {
  for (const token of [null, 'invalid', 'expired', 'shared']) {
    test(`${method} ${route} rejects ${token ?? 'missing'} token`, async () => {
      const f = fixture();
      assert.equal((await f.request(method, route, { token })).status, 401);
      assert.deepEqual(f.calls, []);
    });
  }
  test(`${method} ${route} rejects missing Admin configuration`, async () => {
    const f = fixture({ configured: false });
    assert.equal((await f.request(method, route)).status, 401);
    assert.deepEqual(f.calls, []);
  });
  for (const field of ['query', 'body']) {
    test(`${method} ${route} rejects foreign ${field} family before provisioning`, async () => {
      const f = fixture();
      assert.equal((await f.request(method, route, {
        [field]: { familyId: familyId('b') },
      })).status, 403);
      assert.deepEqual(f.calls, []);
    });
  }
  test(`${method} ${route} production failure cannot use enabled fallback`, async () => {
    const f = fixture({ failure: 'data', fallback: true });
    assert.equal((await f.request(method, route)).status, 503);
    assert.equal(f.memory.todos.length, 3);
    assert.equal(f.memory.shoppingItems.length, 3);
  });
}

for (const name of ['todos', 'shopping']) {
  const model = name === 'todos' ? 'todo' : 'shoppingItem';
  test(`${name} missing family resolves only current account; demo stays hidden`, async () => {
    const f = fixture();
    for (const uid of ['a', 'b']) {
      const result = await f.request('GET', `/${name}`, { token: uid });
      assert.equal(result.status, 200);
      assert.equal(result.body.items.length, 1);
      assert.equal(result.body.items[0].familyId, familyId(uid));
    }
    assert.equal((await f.request('GET', `/${name}`, {
      query: { familyId: 'demo-family-001' },
    })).status, 403);
  });
  test(`${name} create binds token family with no claim`, async () => {
    const f = fixture();
    assert.equal((await f.request('POST', `/${name}`, { token: 'b' })).status, 201);
    assert.equal(f.data[model].at(-1).familyId, familyId('b'));
  });
  for (const method of ['PUT', 'DELETE']) {
    test(`${method} ${name} foreign and missing IDs are indistinguishable and unchanged`, async () => {
      const f = fixture();
      const before = clone(f.data);
      for (const id of [name === 'todos' ? 'todo-b' : 'shop-b', 'missing']) {
        assert.equal((await f.request(method, `/${name}/:id`, { id })).status, 404);
      }
      assert.deepEqual(f.data, before);
    });
    test(`${method} ${name} own ID mutates only own row`, async () => {
      const f = fixture();
      assert.equal((await f.request(method, `/${name}/:id`)).status, method === 'DELETE' ? 204 : 200);
      assert.equal(f.data[model].some(row => row.familyId === familyId('b')), true);
      assert.equal(f.data[model].some(row => row.familyId === 'demo-family-001'), true);
    });
  }
  test(`${name} development fallback is scoped after verified family resolution`, async () => {
    const f = fixture({ production: false, fallback: true, failure: 'data' });
    const result = await f.request('GET', `/${name}`);
    assert.equal(result.status, 200);
    assert.equal(result.body.items.length, 1);
    assert.equal(result.body.items[0].familyId, familyId('a'));
    const foreign = name === 'todos' ? 'memtodo-b' : 'memshop-b';
    assert.equal((await f.request('DELETE', `/${name}/:id`, { id: foreign })).status, 404);
    assert.equal((await f.request('POST', `/${name}`)).body.item.familyId, familyId('a'));
  });
}

for (const failure of ['user', 'family', 'firebase']) {
  test(`failed ${failure} context cannot fall back even in development`, async () => {
    const f = fixture({ failure, preProvisioned: false, production: false, fallback: true });
    assert.equal((await f.request('GET', '/todos')).status, 503);
    assert.equal(f.calls.some(([kind]) => kind === 'todo-list'), false);
  });
}
for (const conflict of [{ owner: 'b' }, { members: [] }, { members: ['a', 'b'] }]) {
  test(`reserved family conflict ${JSON.stringify(conflict)} is 409 without access`, async () => {
    const f = fixture(conflict);
    const before = clone([...f.families]);
    assert.equal((await f.request('GET', '/todos')).status, 409);
    assert.deepEqual([...f.families], before);
    assert.equal(f.calls.some(([kind]) => kind === 'todo-list'), false);
  });
}
test('email conflict cannot adopt a legacy user', async () => {
  const f = fixture({ preProvisioned: false, emailConflict: true });
  assert.equal((await f.request('GET', '/todos')).status, 409);
  assert.equal(f.families.size, 0);
});
test('concurrent first provisions produce one stable private family per UID', async () => {
  const f = fixture({ preProvisioned: false });
  await Promise.all(Array.from({ length: 6 }, () => f.context.resolveOwnFamily('a')));
  assert.equal(f.users.size, 1);
  assert.equal(f.families.size, 1);
  const user = f.users.get('a');
  assert.notEqual(user.passwordHash, 'demo');
  assert.notEqual(user.passwordSalt, 'demo');
  assert.equal(f.families.get(familyId('a')).createdById, 'a');
  await f.context.resolveOwnFamily('b');
  assert.equal(f.families.size, 2);
});
test('serialization retry is bounded and never exposes a fallback family', async () => {
  const succeeds = fixture({ retries: 2 });
  assert.equal((await succeeds.request('GET', '/todos')).status, 200);
  const fails = fixture({ retries: 3 });
  assert.equal((await fails.request('GET', '/todos')).status, 503);
  assert.equal(fails.calls.filter(([kind]) => kind === 'family-upsert').length, 3);
});
test('invalid identity has no implicit fallback', async () => {
  const f = fixture();
  for (const uid of [undefined, '', ' a ']) {
    await assert.rejects(f.context.resolveOwnFamily(uid), error => error.status === 401);
  }
  assert.deepEqual(f.calls, []);
});
test('real Express GET and tokenoptional writes still require local Firebase auth', async t => {
  const app = express(); app.use(express.json());
  fixture({ app });
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => new Promise(resolve => { server.close(resolve); server.closeAllConnections(); }));
  const base = `http://127.0.0.1:${server.address().port}`;
  for (const [method, path] of routes) {
    assert.equal((await fetch(`${base}${path.replace(':id', 'todo-a')}`, { method })).status, 401);
  }
  assert.equal((await fetch(`${base}/todos`, { headers: { Authorization: 'Bearer a' } })).status, 200);
  assert.equal((await fetch(`${base}/todos?familyId=${familyId('b')}`,
    { headers: { Authorization: 'Bearer a' } })).status, 403);
});

test('export helper is own-scoped, non-provisioning and rejects foreign ownership', async () => {
  const f = fixture();
  const result = await f.context.exportOwnFamilyItems('a');
  assert.equal(result.todos.length, 1);
  assert.equal(result.shoppingItems.length, 1);
  assert.equal(result.todos[0].familyId, familyId('a'));
  assert.equal(f.calls.some(([kind]) => kind.includes('upsert')), false);
  const empty = fixture({ preProvisioned: false });
  assert.equal((await empty.context.exportOwnFamilyItems('a')).todos.length, 0);
  assert.equal(empty.families.size, 0);
  await assert.rejects(fixture({ owner: 'b' }).context.exportOwnFamilyItems('a'),
    error => error.status === 409);
});

test('Prisma and migration enforce actual User-Family-Todo/Shopping cascades', () => {
  const schema = fs.readFileSync(path.join(__dirname, '../../prisma/schema.prisma'), 'utf8');
  for (const model of ['Family', 'Todo', 'ShoppingItem']) {
    const block = schema.slice(schema.indexOf(`model ${model} {`),
      schema.indexOf('\n}', schema.indexOf(`model ${model} {`)));
    assert.match(block, /onDelete: Cascade/);
  }
  const migrationRoot = path.join(__dirname, '../../prisma/migrations');
  const sql = fs.readdirSync(migrationRoot).filter(name =>
    fs.existsSync(path.join(migrationRoot, name, 'migration.sql')))
    .map(name => fs.readFileSync(path.join(migrationRoot, name, 'migration.sql'), 'utf8')).join('\n');
  for (const key of ['Family_createdById_fkey', 'Todo_familyId_fkey', 'ShoppingItem_familyId_fkey']) {
    assert.match(sql, new RegExp(`"${key}"[^;]+ON DELETE CASCADE`));
  }
});

test('account export includes own Todos/Shopping and never B or demo rows', async () => {
  const f = fixture();
  const names = ['eventParticipation', 'message', 'chatReport', 'treasureItem', 'treasureRating',
    'treasureHandover', 'treasureReport', 'paymentTransaction', 'parentMatchingProfile',
    'parentMatchingAction', 'sharedRecipe', 'foodOfferComment', 'foodOfferReservation',
    'recipeRating', 'recipeFavorite', 'recipeReport', 'communityEvent', 'communityEventFlag',
    'communityEventInterest'];
  for (const name of names) f.prisma[name] = { findMany: async () => [] };
  f.context.resilientEventFindMany = async () => [];
  vm.runInContext(slice('async function exportAccountDataByUserIdPrisma(', '// ============================================================================\n// REFERRAL'), f.context);
  const result = await f.context.exportAccountDataByUserIdPrisma('a');
  assert.equal(result.todos[0].id, 'todo-a');
  assert.equal(result.shoppingItems[0].id, 'shop-a');
});

test('account deletion cascades only own family items; dry-run preserves all data', async () => {
  const f = fixture();
  const names = ['event', 'aiChildProfile', 'aiMemoryItem', 'aiMemorySettings', 'treasureItem',
    'treasureReport', 'parentMatchingProfile', 'sharedRecipe', 'foodOfferComment',
    'foodOfferReservation', 'recipeRating', 'recipeFavorite', 'recipeReport', 'communityEvent',
    'communityEventFlag', 'communityEventInterest', 'familyRequest', 'paymentTransaction',
    'parentMatchingAction'];
  for (const name of names) f.prisma[name] = {
    count: async () => 0, findMany: async () => [], deleteMany: async () => ({ count: 0 }),
  };
  vm.runInContext(slice('async function deleteAccountDataByUserIdPrisma(', 'async function exportAccountDataByUserIdPrisma('), f.context);
  const before = clone(f.data);
  const dry = await f.context.deleteAccountDataByUserIdPrisma('a', { dryRun: true });
  assert.equal(dry.removed, 3);
  assert.deepEqual(f.data, before);
  await f.context.deleteAccountDataByUserIdPrisma('a');
  assert.equal(f.families.has(familyId('a')), false);
  assert.equal(f.families.has(familyId('b')), true);
  for (const table of Object.values(f.data)) {
    assert.deepEqual(table.map(row => row.familyId), [familyId('b'), 'demo-family-001']);
  }
});

test('development memory deletion and counts cannot touch B or demo family', () => {
  const f = fixture();
  Object.assign(f.context, {
    userEntitlements: new Map(), familyContacts: [], familyRequests: [], events: [],
    eventInvitations: [], eventParticipations: [], paymentTransactions: [],
    eventChatReports: [], eventChatMessages: {}, parentMatchingActions: [],
  });
  vm.runInContext(slice('function removeMatching(', 'function localUploadFilenameFromUrl('), f.context);
  assert.equal(f.context.countAccountDataByUserIdInMemory('a'), 2);
  assert.equal(f.context.deleteAccountDataByUserIdInMemory('a'), 2);
  for (const table of Object.values(f.memory)) {
    assert.deepEqual(table.map(row => row.familyId), [familyId('b'), 'demo-family-001']);
  }
});

  for (const [method, route] of [['GET', '/account/export-data'], ['POST', '/account/delete-data']]) {
    for (const token of [null, 'shared']) {
      test(`${method} ${route} lifecycle requires individual token even in dev`, async () => {
        const f = fixture({ production: false, fallback: true });
        assert.equal((await f.request(method, route, { token, query: { userId: 'a' }, body: { userId: 'a' } })).status, 401);
        assert.deepEqual(f.calls, []);
      });
    }
    test(`${method} ${route} A cannot export or delete B through lifecycle`, async () => {
      const f = fixture();
      const before = clone(f.data);
      assert.equal((await f.request(method, route, { query: { userId: 'b' }, body: { userId: 'b' } })).status, 403);
      assert.deepEqual(f.calls, []);
      assert.deepEqual(f.data, before);
    });
  }

  test('own account export route includes private items only', async () => {
    const f = fixture();
    const result = await f.request('GET', '/account/export-data', { query: { userId: 'a' } });
    assert.equal(result.status, 200);
    assert.equal(result.body.data.todos[0].id, 'todo-a');
    assert.equal(result.body.data.shoppingItems[0].id, 'shop-a');
  });

  for (const production of [false, true]) {
    test(`account deletion owner conflict cannot become memory success; production=${production}`, async () => {
      const f = fixture({ production, fallback: true, owner: 'b' });
      f.context.deleteAccountDataByUserIdPrisma = async uid => f.context.exportOwnFamilyItems(uid);
      const result = await f.request('POST', '/account/delete-data', { body: { userId: 'a' } });
      assert.equal(result.status, 409);
      assert.equal(f.calls.some(([kind]) => kind === 'delete-memory'), false);
    });
  }

  test('account deletion production DB failure cannot become memory success', async () => {
    const f = fixture({ fallback: true });
    f.context.deleteAccountDataByUserIdPrisma = async () => { throw new Error('DB unavailable'); };
    assert.equal((await f.request('POST', '/account/delete-data', { body: { userId: 'a' } })).status, 503);
    assert.equal(f.calls.some(([kind]) => kind === 'delete-memory'), false);
  });

test('dev account deletion DB failure cannot become memory success', async () => {
  const f = fixture({ production: false, fallback: true });
  f.context.deleteAccountDataByUserIdPrisma = async () => { throw new Error('DB unavailable'); };
  assert.equal((await f.request('POST', '/account/delete-data', { body: { userId: 'a' } })).status, 503);
  assert.equal(f.calls.some(([kind]) => kind === 'delete-memory'), false);
});

for (const claimed of ['', ['other'], { id: 'other' }, null]) {
  test(`malformed family claim ${JSON.stringify(claimed)} fails before provisioning`, async () => {
    const f = fixture({ preProvisioned: false });
    assert.equal((await f.request('GET', '/todos', { query: { familyId: claimed } })).status, 403);
    assert.deepEqual(f.calls, []);
  });
}

for (const account of [{ disabled: true }, { uid: 'other' }]) {
  test(`invalid Firebase provisioning identity ${JSON.stringify(account)} is rejected`, async () => {
    const f = fixture({ preProvisioned: false, firebaseAccount: account });
    assert.equal((await f.request('GET', '/todos')).status, 401);
    assert.equal(f.families.size, 0);
    assert.equal(f.users.size, 0);
  });
}

test('unique family-create collision retries the reserved upsert idempotently', async () => {
  const f = fixture({ preProvisioned: false, retries: 1, retryCode: 'P2002' });
  assert.equal((await f.request('GET', '/todos')).status, 200);
  assert.equal(f.families.size, 1);
});

test('a same-UID user upsert collision rechecks UID, not email', async () => {
  const f = fixture({ preProvisioned: false });
  f.prisma.user.upsert = async ({ create }) => {
    f.users.set(create.id, create);
    throw Object.assign(new Error('Concurrent create'), { code: 'P2002' });
  };
  assert.equal((await f.request('GET', '/todos')).status, 200);
  assert.equal(f.users.size, 1);
  assert.equal(f.families.size, 1);
});

test('export owner conflict is explicit 409, never a successful empty export', async () => {
  const f = fixture({ owner: 'b' });
  assert.equal((await f.request('GET', '/account/export-data', { query: { userId: 'a' } })).status, 409);
});

test('export DB failure is explicit 503', async () => {
  const f = fixture({ failure: 'family', fallback: true, production: false });
  assert.equal((await f.request('GET', '/account/export-data', { query: { userId: 'a' } })).status, 503);
});

for (const [method, route] of [...routes, ['GET', '/account/export-data'], ['POST', '/account/delete-data']]) {
  test(`${method} ${route} Firebase verification outage is explicit 503 without persistence`, async () => {
    const f = fixture({ failure: 'verification', production: false, fallback: true });
    assert.equal((await f.request(method, route, { query: { userId: 'a' }, body: { userId: 'a' } })).status, 503);
    assert.deepEqual(f.calls, []);
  });
}
