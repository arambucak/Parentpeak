const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const { changeParticipation } = require('../../event_participation_policy');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
function block(startMarker, endMarker) {
  const start = source.indexOf(startMarker);
  const end = source.indexOf(endMarker, start);
  assert.ok(start >= 0 && end > start, `Missing source block: ${startMarker}`);
  return source.slice(start, end);
}

function fixture(options = {}) {
  const calls = [];
  const users = new Map((options.users || []).map(user => [user.id, { ...user }]));
  const participations = new Map();
  const account = options.account || {
    uid: 'firebase-owner', email: 'Owner@Example.org', emailVerified: true,
    displayName: 'Trusted Parent',
  };
  let handler;
  const context = vm.createContext({
    crypto,
    changeParticipation,
    authorizeEventParticipation: async () => {},
    console: { error() {} },
    allowDemoBootstrap: false,
    disableInMemoryFallbacks: true,
    DEMO_USER_ID: 'demo',
    firebaseRequireAuth: true,
    backendApiToken: 'server-token',
    WRITE_METHODS: new Set(['POST']),
    isNoTokenWritePath: () => false,
    firebaseAdmin: { auth: () => ({
      verifyIdToken: async token => {
        if (token !== 'verified-token') throw new Error('Invalid token');
        return { uid: 'firebase-owner' };
      },
      getUser: async uid => {
        calls.push(['firebase.getUser', uid]);
        if (options.firebaseFailure) throw new Error('Firebase unavailable');
        return account;
      },
    }) },
    prisma: {
      event: { findUnique: async () => {
        calls.push(['event.findUnique']);
        return options.missingEvent ? null : { id: 'event1' };
      } },
      user: {
        findUnique: async ({ where }) => {
          calls.push(['user.findUnique', where.id]);
          if (options.lookupFailure) throw new Error('Database unavailable');
          return users.get(where.id) || null;
        },
        upsert: async args => {
          calls.push(['user.upsert', args]);
          if (options.databaseFailure) throw new Error('Database unavailable');
          if (options.racingUser) users.set(args.where.id, options.racingUser);
          if (!users.has(args.where.id)) {
            if ([...users.values()].some(user => user.email === args.create.email)) {
              throw new Error('Unique email constraint');
            }
            users.set(args.where.id, { ...args.create });
          }
          return users.get(args.where.id);
        },
      },
      eventParticipation: { upsert: async args => {
        calls.push(['participation.upsert', args]);
        if (options.participationFailure) throw new Error('Participation write failed');
        const key = `${args.create.eventId}/${args.create.userId}`;
        const item = participations.has(key)
          ? { ...participations.get(key), ...args.update }
          : { id: 'participation1', ...args.create };
        participations.set(key, item);
        return item;
      } },
    },
    mapParticipationRecordToApiItem: item => item,
    app: { post: (route, routeHandler) => { handler = routeHandler; } },
  });
  vm.runInContext([
    block('async function verifyFirebaseIdToken(', '\nfunction resolveVerifiedUserId('),
    block('async function firebaseAuthMiddleware(', '\n// Middleware'),
    block('function respondWithStrictPersistenceError(', '\nfunction getWeeklyImpulseCommunityEntry('),
    block('async function ensureBackendUser(', '\nasync function ensurePaymentContext('),
    block("app.post('/events/participations',", "\nasync function authorizeEventParticipation("),
  ].join('\n'), context);
  context.prisma.$transaction = async operation => operation({
    $queryRaw: async () => [],
    event: { findUnique: async () => ({ id: 'event1', startDate: '2099-01-01', participationMode: 'legacyApproval' }) },
    eventParticipation: {
      ...context.prisma.eventParticipation,
      findUnique: async ({ where }) => participations.get(`${where.eventId_userId.eventId}/${where.eventId_userId.userId}`) || null,
      count: async () => 0,
    },
  });
  async function request({ userId = 'firebase-owner', token = 'verified-token', body = {} } = {}) {
    let status = 200;
    let response;
    const req = {
      method: 'POST', path: '/events/participations',
      headers: { authorization: token ? `Bearer ${token}` : '' },
      body: { eventId: 'event1', userId, userName: 'Untrusted Body Name', ...body },
    };
    const res = {
      status: code => { status = code; return res; },
      json: value => { response = value; return res; },
    };
    await context.firebaseAuthMiddleware(req, res, () => handler(req, res));
    return { status, body: response };
  }
  return { calls, users, participations, request };
}

test('verified missing account syncs trusted identity and persists participation with 201', async () => {
  const route = fixture();
  const result = await route.request({ body: { email: 'forged@example.org' } });
  assert.equal(result.status, 201);
  assert.equal(result.body.item.userId, 'firebase-owner');
  assert.equal(result.body.item.status, 'pending');
  const user = route.users.get('firebase-owner');
  assert.equal(user.email, 'owner@example.org');
  assert.equal(user.firstName, 'Trusted');
  assert.equal(user.lastName, 'Parent');
  assert.match(user.passwordHash, /^[a-f0-9]{128}$/);
  assert.match(user.passwordSalt, /^[a-f0-9]{64}$/);
  assert.deepEqual(Object.keys(route.calls.find(call => call[0] === 'user.upsert')[1].update), []);
  assert.deepEqual(route.calls.map(call => call[0]), [
    'event.findUnique', 'user.findUnique', 'firebase.getUser', 'user.upsert', 'participation.upsert',
  ]);
  assert.equal(route.participations.size, 1);
});

test('existing account remains untouched without contacting Firebase', async () => {
  const user = { id: 'firebase-owner', email: 'saved@example.org', firstName: 'Saved',
    passwordHash: 'saved-hash', passwordSalt: 'saved-salt', isPremium: true };
  const route = fixture({ users: [user], firebaseFailure: true });
  assert.equal((await route.request()).status, 201);
  assert.deepEqual(route.users.get(user.id), user);
  assert.deepEqual(route.calls.map(call => call[0]), [
    'event.findUnique', 'user.findUnique', 'participation.upsert',
  ]);
});

test('verified UID mismatch returns 403 before any database or Firebase query', async () => {
  const route = fixture();
  assert.equal((await route.request({ userId: 'someone-else' })).status, 403);
  assert.deepEqual(route.calls, []);
});

for (const token of ['', 'forged-token']) {
  test(`unverified token ${JSON.stringify(token)} cannot forge UID in body`, async () => {
    const route = fixture();
    assert.equal((await route.request({ token, body: { firebaseUid: 'firebase-owner' } })).status, 401);
    assert.deepEqual(route.calls, []);
  });
}

test('server-token without verified UID cannot create participation', async () => {
  const route = fixture();
  assert.equal((await route.request({ token: 'server-token', body: { firebaseUid: 'firebase-owner' } })).status, 401);
  assert.deepEqual(route.calls, []);
  assert.equal(route.users.size, 0);
});

for (const failure of ['firebaseFailure', 'lookupFailure', 'databaseFailure', 'participationFailure']) {
  test(`${failure} returns strict 503 without successful participation`, async () => {
    const route = fixture({ [failure]: true });
    const result = await route.request();
    assert.equal(result.status, 503);
    assert.equal(result.body.route, 'POST /events/participations');
    assert.equal(route.participations.size, 0);
  });
}

test('repeat participation is idempotent and does not resync the account', async () => {
  const route = fixture();
  assert.equal((await route.request()).status, 201);
  const user = { ...route.users.get('firebase-owner') };
  assert.equal((await route.request()).status, 201);
  assert.deepEqual(route.users.get('firebase-owner'), user);
  assert.equal(route.participations.size, 1);
  assert.equal(route.calls.filter(call => call[0] === 'user.upsert').length, 1);
  assert.equal(route.calls.filter(call => call[0] === 'firebase.getUser').length, 1);
});

for (const email of [undefined, 'unverified@example.org']) {
  test(`missing/unverified email ${JSON.stringify(email)} uses UID-specific reserved placeholder`, async () => {
    const route = fixture({ account: { uid: 'firebase-owner', email, emailVerified: false } });
    assert.equal((await route.request()).status, 201);
    assert.equal(route.users.get('firebase-owner').email,
      `firebase-${crypto.createHash('sha256').update('firebase-owner').digest('hex')}@firebase.local.invalid`);
    assert.equal(route.users.get('firebase-owner').firstName, null);
  });
}

test('email collision never takes over an account under another UID', async () => {
  const user = { id: 'other-uid', email: 'owner@example.org', firstName: 'Other' };
  const route = fixture({ users: [user] });
  assert.equal((await route.request()).status, 503);
  assert.deepEqual(route.users.get(user.id), user);
  assert.equal(route.users.size, 1);
  assert.equal(route.participations.size, 0);
});

for (const account of [{ uid: 'different-uid' }, { uid: 'firebase-owner', disabled: true }]) {
  test(`invalid Admin account ${JSON.stringify(account)} cannot sync`, async () => {
    const route = fixture({ account });
    assert.equal((await route.request()).status, 503);
    assert.equal(route.users.size, 0);
    assert.equal(route.participations.size, 0);
    assert.equal(route.calls.some(call => call[0] === 'user.upsert'), false);
  });
}

test('concurrently created UID keeps its saved profile through empty upsert update', async () => {
  const user = { id: 'firebase-owner', email: 'saved@example.org', firstName: 'Saved', isPremium: true };
  const route = fixture({ racingUser: user });
  assert.equal((await route.request()).status, 201);
  assert.deepEqual(route.users.get(user.id), user);
  assert.deepEqual(Object.keys(route.calls.find(call => call[0] === 'user.upsert')[1].update), []);
});

test('missing event remains 404 without creating an account', async () => {
  const route = fixture({ missingEvent: true });
  assert.equal((await route.request()).status, 404);
  assert.deepEqual(route.calls, [['event.findUnique']]);
});