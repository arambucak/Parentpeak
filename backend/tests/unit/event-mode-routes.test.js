const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const crypto = require('node:crypto');
const policy = require('../../event_participation_policy');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
function routeBlock(method, route) {
  const start = source.indexOf(`app.${method}('${route}',`);
  assert.ok(start >= 0, route);
  return source.slice(start, source.indexOf('\n});', start) + 4);
}
function fixture(overrides = {}, initial = []) {
  const event = { id: 'event', hosterId: 'host', title: 'Meetup',
    startDate: new Date('2099-01-01'), status: 'upcoming', participationMode: 'direct',
    visibility: 'publicNearby', maxParticipants: 1, externalUrl: null, ...overrides };
  let rows = initial.map(item => ({ eventId: 'event', createdAt: new Date(), updatedAt: new Date(), ...item }));
  const handlers = {};
  const calls = [];
  let queue = Promise.resolve();
  const participation = {
    findUnique: async ({ where }) => where.id ? rows.find(item => item.id === where.id) || null
      : rows.find(item => item.userId === where.eventId_userId.userId) || null,
    count: async ({ where }) => rows.filter(item => where.status.in.includes(item.status)).length,
    findMany: async ({ where }) => rows.filter(item => !where?.status ||
      (typeof where.status === 'string' ? item.status === where.status : where.status.in.includes(item.status))),
    upsert: async ({ create, update }) => {
      calls.push('write');
      if (event.writeFailure) throw new Error('Database write failed');
      const existing = rows.find(item => item.userId === create.userId);
      if (existing) return Object.assign(existing, update);
      const item = { id: create.userId, createdAt: new Date(), updatedAt: new Date(), ...create };
      rows.push(item); return item;
    },
    update: async ({ where, data }) => Object.assign(rows.find(item => item.id === where.id), data),
  };
  const prisma = {
    event: {
      findUnique: async () => ({ ...event, participants: rows }),
      findMany: async () => [{ ...event, participants: rows }],
      create: async ({ data }) => { calls.push('create'); Object.assign(event, data); return { ...event, participants: [] }; },
      update: async ({ data }) => { calls.push('update'); Object.assign(event, data); return { ...event, participants: rows }; },
    },
    eventParticipation: participation,
    familyRequest: { findFirst: async () => null },
    $transaction: operation => {
      const result = queue.then(async () => {
        const snapshot = rows.map(item => ({ ...item }));
        try { return await operation({ ...prisma,
          $queryRaw: async strings => { calls.push('lock'); assert.match(strings.join(''), /FOR UPDATE/); },
        }); } catch (error) { rows = snapshot; throw error; }
      });
      queue = result.catch(() => {}); return result;
    },
  };
  const context = vm.createContext({
    ...policy, prisma, crypto, console: { error() {} },
    resilientEventFindMany: args => prisma.event.findMany(args),
    ensureAuthenticatedEventUser: async (_req, userId) => userId,
    verifyFirebaseIdToken: async req => req.headers.authorization === 'Bearer verified-token'
      ? { verified: true, uid: 'parent' } : { verified: false, uid: null },
    isUserSuspended: async () => false,
    mapParticipationRecordToApiItem: item => ({ ...item, requestedAt: item.createdAt }),
    app: Object.fromEntries(['get', 'post', 'put'].map(method => [method,
      (route, handler) => { handlers[`${method} ${route}`] = handler; }])),
  });
  const start = source.indexOf('async function authorizeEventParticipation(');
  vm.runInContext(source.slice(start, source.indexOf("\napp.put('/events/participations/withdraw'", start)), context);
  const identityStart = source.indexOf('async function eventIdentityMiddleware(');
  vm.runInContext(source.slice(identityStart, source.indexOf('\napp.use(', identityStart)), context);
  for (const [method, route] of [
    ['post', '/events/participations'], ['put', '/events/participations/withdraw'],
    ['put', '/events/participations/:id/respond'], ['post', '/api/events'],
    ['get', '/api/events'], ['get', '/api/events/:id'], ['put', '/api/events/:id'],
  ]) vm.runInContext(routeBlock(method, route), context);
  async function request(method, route, body = {}, uid = 'parent', query = {}) {
    let status = 200; let payload;
    const res = { status(code) { status = code; return res; }, json(value) { payload = value; return res; } };
    await handlers[`${method} ${route}`]({ firebaseUid: uid, body, query, params: { id: route.includes('participations') ? 'parent' : 'event' } }, res);
    return { status, body: payload };
  }
  return { request, rows: () => rows, calls, event,
    authenticate: async authorization => {
      const req = { method: 'GET', headers: { authorization } };
      let status = 200; let nextCalled = false;
      const res = { status(code) { status = code; return res; }, json() { return res; } };
      await context.eventIdentityMiddleware(req, res, () => { nextCalled = true; });
      return { status, uid: req.firebaseUid, nextCalled };
    },
    join: (userId = 'parent', uid = userId) => request('post', '/events/participations', { eventId: 'event', userId }, uid) };
}

test('route-level concurrent duplicate and last-place race confirms exactly one parent', async () => {
  const route = fixture();
  const result = await Promise.all([route.join(), route.join(), route.join('other')]);
  assert.deepEqual(result.map(item => item.status), [201, 201, 409]);
  assert.equal(route.rows().length, 1);
  assert.equal(route.rows()[0].status, 'approved');
  assert.equal(route.calls.filter(item => item === 'lock').length, 3);
});
test('join UID mismatch and anonymous calls never acquire a lock or write', async () => {
  const route = fixture();
  assert.equal((await route.join('other', 'parent')).status, 403);
  assert.equal((await route.join('parent', null)).status, 401);
  assert.deepEqual(route.calls, []);
});
test('withdraw own UID is idempotent and cannot withdraw another parent', async () => {
  const route = fixture(); await route.join();
  const body = { eventId: 'event', userId: 'parent' };
  assert.equal((await route.request('put', '/events/participations/withdraw', body, 'other')).status, 403);
  for (let attempt = 0; attempt < 2; attempt++) {
    assert.equal((await route.request('put', '/events/participations/withdraw', body)).body.success, true);
  }
  assert.equal((await route.join('other')).status, 201);
});
test('legacy remains pending and selecting direct mode never approves old pending', async () => {
  const route = fixture({ participationMode: 'legacyApproval', maxParticipants: 2 });
  assert.equal((await route.join()).body.item.status, 'pending');
  assert.equal((await route.request('put', '/api/events/:id', { hosterId: 'host', participationMode: 'direct' }, 'host')).status, 200);
  assert.equal(route.rows()[0].status, 'pending');
  assert.equal((await route.join()).body.item.status, 'pending');
  assert.equal((await route.join('other')).body.item.status, 'approved');
});
test('host review requires stored owner, pending request, and available capacity', async () => {
  const route = fixture({ participationMode: 'legacyApproval' }, [{ id: 'parent', userId: 'parent', status: 'pending' }]);
  assert.equal((await route.request('put', '/events/participations/:id/respond', { accept: true })).status, 403);
  assert.equal((await route.request('put', '/events/participations/:id/respond', { accept: 'true' }, 'host')).status, 400);
  assert.equal((await route.request('put', '/events/participations/:id/respond', { accept: true }, 'host')).body.item.status, 'approved');
});
test('interested is persisted but list and detail report zero confirmed places', async () => {
  const route = fixture({ participationMode: 'interest', externalUrl: 'https://organizer.example/event', maxParticipants: null });
  assert.equal((await route.join()).body.item.status, 'interested');
  const list = await route.request('get', '/api/events');
  assert.equal(list.body.events[0].currentParticipants, 0);
  assert.equal(list.body.events[0].participationMode, 'interest');
  assert.equal(list.body.events[0].externalUrl, 'https://organizer.example/event');
  assert.equal((await route.request('get', '/api/events/:id')).body.event.currentParticipants, 0);
});
test('only confirmed statuses count; pending, cancelled and interested do not', async () => {
  const route = fixture({ maxParticipants: 10 }, ['approved', 'accepted', 'attended', 'pending', 'interested', 'cancelled', 'invited'].map(status => ({ id: status, userId: status, status })));
  assert.equal((await route.request('get', '/api/events')).body.events[0].currentParticipants, 3);
  assert.equal((await route.request('get', '/api/events/:id')).body.event.spotsAvailable, 7);
});
for (const visibility of ['privateOnly', 'inviteOnly', 'familyCircle']) {
  test(`${visibility}: unauthorized joins, detail IDs and discovery cannot reveal event`, async () => {
    const route = fixture({ visibility });
    assert.equal((await route.join()).status, 403);
    assert.equal((await route.request('get', '/api/events/:id')).status, 403);
    assert.equal((await route.request('get', '/api/events', {}, 'parent', { visibility })).body.events.length, 0);
    assert.equal((await route.request('get', '/api/events/:id', {}, 'host')).status, 200);
  });
}
test('invited user can join direct meetup, but host cannot join their own', async () => {
  const route = fixture({ visibility: 'inviteOnly' }, [{ id: 'parent', userId: 'parent', status: 'invited' }]);
  assert.equal((await route.join()).body.item.status, 'approved');
  assert.equal((await route.join('host')).status, 403);
});
test('cancelled event and write failure are honest failures, never local success', async () => {
  assert.equal((await fixture({ status: 'cancelled' }).join()).status, 409);
  const route = fixture({ writeFailure: true });
  assert.equal((await route.join()).status, 503);
  assert.equal(route.rows().length, 0);
});
test('creation rejects invalid mode, URL and forged host without any write', async () => {
  const body = { hosterId: 'host', title: 'Public offer', location: 'Park', latitude: 52, longitude: 13,
    startDate: '2099-01-01', participationMode: 'interest', externalUrl: 'https://organizer.example' };
  const route = fixture();
  assert.equal((await route.request('post', '/api/events', body)).status, 403);
  for (const changes of [{ participationMode: 'unknown' }, { externalUrl: 'javascript:alert(1)' },
    { externalUrl: null }, { visibility: 'inviteOnly' }]) {
    assert.equal((await route.request('post', '/api/events', { ...body, ...changes }, 'host')).status, 400);
  }
  assert.deepEqual(route.calls, []);
  const result = await route.request('post', '/api/events', body, 'host');
  assert.equal(result.status, 201);
  assert.equal(result.body.event.participationMode, 'interest');
  assert.equal(result.body.event.maxParticipants, null);
});
test('capacity edits and new-mode conversion cannot invalidate confirmed attendance', async () => {
  const route = fixture({ maxParticipants: 2 }, [{ id: 'parent', userId: 'parent', status: 'approved' }]);
  assert.equal((await route.request('put', '/api/events/:id', { hosterId: 'host', maxParticipants: 0 }, 'host')).status, 400);
  assert.equal((await route.request('put', '/api/events/:id', { hosterId: 'host', participationMode: 'interest', externalUrl: 'https://example.org' }, 'host')).status, 409);
});

test('create preserves paid, free and unknown prices without invented coordinates', async () => {
  for (const price of [9.40, 0, null]) {
    const route = fixture();
    const result = await route.request('post', '/api/events', {
      hosterId: 'host', title: 'Public offer', location: 'Unresolved venue',
      latitude: null, longitude: null, startDate: '2099-01-01',
      participationMode: 'interest', externalUrl: 'https://organizer.example',
      costPerPerson: price,
    }, 'host');
    assert.equal(result.status, 201);
    assert.equal(result.body.event.costPerPerson, price);
    assert.equal(result.body.event.latitude, null);
    assert.equal(result.body.event.longitude, null);
  }
});

test('create rejects malformed coordinates and negative or invalid prices', async () => {
  const body = {
    hosterId: 'host', title: 'Public offer', location: 'Venue',
    latitude: 52, longitude: 13, startDate: '2099-01-01',
    participationMode: 'interest', externalUrl: 'https://organizer.example',
  };
  for (const change of [
    { latitude: null }, { latitude: '52' }, { longitude: Infinity },
    { costPerPerson: -1 }, { costPerPerson: '9,40' }, { costPerPerson: NaN },
  ]) {
    const route = fixture();
    assert.equal((await route.request('post', '/api/events', { ...body, ...change }, 'host')).status, 400);
    assert.deepEqual(route.calls, []);
  }
});
test('event GET identity is derived from a verified Firebase token, not URL claims', async () => {
  const route = fixture();
  assert.deepEqual(await route.authenticate('Bearer verified-token'), { status: 200, uid: 'parent', nextCalled: true });
  assert.deepEqual(await route.authenticate('Bearer forged-token'), { status: 401, uid: undefined, nextCalled: false });
  assert.deepEqual(await route.authenticate(undefined), { status: 200, uid: undefined, nextCalled: true });
});
test('owner edit rejects null or malformed mode, unsafe URLs, invalid dates and fractional capacity', async () => {
  const route = fixture();
  for (const change of [{ participationMode: null }, { participationMode: 'bogus' },
    { maxParticipants: 1.5 }, { maxParticipants: null }, { startDate: 'invalid' },
    { startDate: '2000-01-01' }, { externalUrl: 'javascript:alert(1)' }]) {
    assert.equal((await route.request('put', '/api/events/:id', { hosterId: 'host', ...change }, 'host')).status, 400);
  }
  assert.equal(route.calls.filter(item => item === 'update').length, 0);
});