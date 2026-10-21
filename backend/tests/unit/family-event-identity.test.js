const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
const routes = [
  ['get', '/family/requests'],
  ['post', '/family/requests'],
  ['put', '/family/requests/:id'],
  ['delete', '/family/requests/:id'],
  ['delete', '/events/item/:id'],
  ['get', '/events/hosted-invite-only'],
  ['get', '/events/:id/invitations/accepted'],
  ['get', '/events/:id/chat/messages'],
  ['post', '/events/:id/chat/messages'],
  ['delete', '/events/:eventId/chat/messages/:messageId'],
  ['post', '/events/:id/chat/reports'],
  ['get', '/events/:id/chat/reports'],
  ['get', '/events/:id/chat/access'],
];

function section(start, end) {
  const index = source.indexOf(start);
  assert.notEqual(index, -1, start);
  const stop = source.indexOf(end, index + start.length);
  assert.notEqual(stop, -1, end);
  return source.slice(index, stop);
}

function matches(item, where = {}) {
  return Object.entries(where).every(([key, value]) => {
    if (key === 'OR') return value.some(clause => matches(item, clause));
    if (key === 'AND') return value.every(clause => matches(item, clause));
    if (value && typeof value === 'object') {
      if (value.in) return value.in.includes(item[key]);
    }
    return item[key] === value;
  });
}

function fixture({ uid = 'member', databaseFailure = false, memoryFallback = false, participationStatus = 'approved' } = {}) {
  const handlers = new Map();
  const requests = [
    { id: 'request', fromUserId: 'sender', toUserId: 'member', status: 'pending' },
    { id: 'foreign', fromUserId: 'other', toUserId: 'stranger', status: 'pending' },
  ];
  const event = { id: 'event', hosterId: 'host', visibility: 'inviteOnly', status: 'active', inviteCode: 'private' };
  const message = { id: 'message', authorId: 'member', chatId: 'chat', chat: { eventId: 'event' }, author: { firstName: 'Member' }, content: 'Hello' };
  const writes = [];
  let confirmed = true;
  const prisma = {
    familyRequest: {
      findMany: async ({ where }) => requests.filter(item => matches(item, where)),
      findFirst: async ({ where }) => requests.find(item => matches(item, where)),
      findUnique: async ({ where }) => requests.find(item => item.id === where.id),
      create: async ({ data }) => { writes.push(data); return { id: 'new-request', ...data }; },
      update: async ({ where, data }) => { writes.push(data); return { ...requests.find(item => item.id === where.id), ...data }; },
      delete: async ({ where }) => { writes.push({ deleted: where.id }); },
    },
    event: {
      findUnique: async ({ where }) => where.id === event.id ? event : null,
      findMany: async ({ where }) => matches(event, where) ? [event] : [],
      delete: async ({ where }) => { writes.push({ deleted: where.id }); },
    },
    eventParticipation: {
      findMany: async () => [{ id: 'invite', eventId: 'event', userId: 'member', status: 'accepted' }],
      findFirst: async ({ where }) => confirmed && where.userId === 'member' && where.eventId === 'event'
        && where.status.in.includes(participationStatus)
        ? { userId: 'member', status: participationStatus } : null,
    },
    eventChat: {
      findUnique: async () => ({ id: 'chat', event, messages: [message] }),
    },
    message: {
      findUnique: async ({ where }) => where.id === 'message' ? message : null,
      create: async ({ data }) => { writes.push(data); return { ...message, ...data }; },
      delete: async ({ where }) => { writes.push({ deleted: where.id }); },
    },
    chatReport: {
      create: async ({ data }) => { writes.push(data); return { id: 'report', ...data }; },
      findMany: async () => [{ id: 'report', reportedById: 'member' }],
    },
  };
  if (databaseFailure) {
    for (const model of Object.values(prisma)) {
      for (const method of Object.keys(model)) model[method] = async () => { throw new Error('offline'); };
    }
  }
  const context = vm.createContext({
    console: { error() {} },
    Set, Date,
    prisma, familyRequests: requests, events: [event],
    eventParticipations: [], eventInvitations: [
      { id: 'invite', eventId: 'event', invitedUserId: 'member', status: 'accepted' },
    ],
    eventChatMessages: {}, eventChatReports: [], eventInviteCodes: {}, eventInviteExpiresAt: {},
    CONFIRMED: ['approved', 'accepted', 'attended'],
    adminUserIds: new Set(['admin']),
    verifyFirebaseIdToken: async () => ({ uid, verified: Boolean(uid) }),
    ensureAuthenticatedEventUser: async req => req.firebaseUid,
    ensureEventChatRecord: async () => ({ id: 'chat' }),
    resilientEventFindMany: options => prisma.event.findMany(options),
    buildParticipantCountMap: async () => new Map(),
    mapEventRecordToApiItem: item => item,
    mapInvitationRecordToApiItem: item => item,
    generateId: () => 'generated',
    respondWithStrictPersistenceError: (res) => {
      if (memoryFallback) return false;
      res.status(503).json({ error: 'Persistence unavailable' });
      return true;
    },
    app: Object.fromEntries(['get', 'post', 'put', 'delete'].map(method => [
      method, (route, ...chain) => handlers.set(`${method} ${route}`, chain),
    ])),
  });
  vm.runInContext(section('async function requireVerifiedUser(', 'function resolveVerifiedUserId('), context);
  vm.runInContext(section('function requireActorClaims(', 'async function authorizeChatParticipant('), context);
  vm.runInContext(section('async function authorizeEventChat(', "app.get('/events/:id/chat/messages'"), context);
  for (const [method, route] of routes) {
    const start = `app.${method}('${route}',`;
    vm.runInContext(`${section(start, '\n});')}\n});`, context);
  }
  async function call(method, route, { body = {}, query = {}, params = {} } = {}) {
    const req = { body, query, params: { id: 'event', eventId: 'event', messageId: 'message', ...params }, headers: {} };
    const res = {
      statusCode: 200,
      status(code) { this.statusCode = code; return this; },
      json(data) { this.body = data; return this; },
      send() { return this; },
    };
    const chain = handlers.get(`${method} ${route}`);
    let index = 0;
    const next = async () => chain[index++]?.(req, res, next);
    await next();
    return res;
  }
  return { call, writes, event, message, requests, setConfirmed: value => { confirmed = value; } };
}

for (const [method, route] of routes) {
  test(`${method.toUpperCase()} ${route} rejects missing Firebase identity`, async () => {
    const f = fixture({ uid: null });
    assert.equal((await f.call(method, route)).statusCode, 401);
    assert.equal(f.writes.length, 0);
  });
  test(`${method.toUpperCase()} ${route} rejects conflicting userId claims`, async () => {
    for (const claims of [{ body: { userId: 'victim' } }, { query: { userId: 'victim' } }]) {
      const f = fixture();
      assert.equal((await f.call(method, route, claims)).statusCode, 403);
      assert.equal(f.writes.length, 0);
    }
  });
}

test('family reads are participant-scoped even without filters', async () => {
  const f = fixture();
  const res = await f.call('get', '/family/requests');
  assert.equal(res.statusCode, 200);
  assert.deepEqual(Array.from(res.body.requests, item => item.id), ['request']);
  assert.equal((await f.call('get', '/family/requests', { query: { fromUserId: 'other' } })).statusCode, 403);
  assert.equal((await f.call('get', '/family/requests', { query: { fromUserId: 'sender', toUserId: 'member' } })).body.requests.length, 1);
});

test('family creation binds sender and cannot manufacture accepted relationships', async () => {
  const f = fixture();
  for (const body of [
    { fromUserId: 'victim', toUserId: 'target' },
    { actingUserId: 'victim', toUserId: 'target' },
    { toUserId: 'target', status: 'accepted' },
  ]) assert.equal((await f.call('post', '/family/requests', { body })).statusCode, 403);
  const created = await f.call('post', '/family/requests', { body: { toUserId: 'target' } });
  assert.equal(created.statusCode, 201);
  assert.equal(created.body.item.fromUserId, 'member');
  assert.equal(created.body.item.status, 'pending');
});

test('only the recipient accepts and participants delete a family relationship', async () => {
  for (const [uid, expected] of [['member', 200], ['sender', 403], ['stranger', 403]]) {
    const f = fixture({ uid });
    assert.equal((await f.call('put', '/family/requests/:id', { params: { id: 'request' }, body: { status: 'accepted' } })).statusCode, expected);
  }
  const f = fixture();
  assert.equal((await f.call('put', '/family/requests/:id', { params: { id: 'request' }, body: { status: 'accepted', actingUserId: 'sender' } })).statusCode, 403);
  assert.equal((await f.call('delete', '/family/requests/:id', { params: { id: 'foreign' } })).statusCode, 403);
  assert.equal((await f.call('delete', '/family/requests/:id', { params: { id: 'request' }, query: { actingUserId: 'sender' } })).statusCode, 403);
  assert.equal((await f.call('delete', '/family/requests/:id', { params: { id: 'request' } })).statusCode, 204);
});

test('event deletion and private invitation reads require the actual host', async () => {
  for (const [uid, expected] of [['host', 204], ['member', 403]]) {
    const f = fixture({ uid });
    assert.equal((await f.call('delete', '/events/item/:id')).statusCode, expected);
  }
  const host = fixture({ uid: 'host' });
  assert.equal((await host.call('delete', '/events/item/:id', { query: { requestingUserId: 'member' } })).statusCode, 403);
  assert.equal((await host.call('get', '/events/hosted-invite-only')).body.items.length, 1);
  assert.equal((await fixture().call('get', '/events/hosted-invite-only')).body.items.length, 0);
  assert.equal((await host.call('get', '/events/hosted-invite-only', { query: { hostUserId: 'member' } })).statusCode, 403);
  assert.equal((await host.call('get', '/events/:id/invitations/accepted')).statusCode, 200);
  assert.equal((await fixture().call('get', '/events/:id/invitations/accepted')).statusCode, 403);
});

test('event chat uses stored membership and host, never query host or pending participation', async () => {
  const f = fixture();
  assert.equal((await f.call('get', '/events/:id/chat/messages')).statusCode, 200);
  assert.equal((await f.call('get', '/events/:id/chat/access')).body.hasAccess, true);
  const stranger = fixture({ uid: 'stranger' });
  assert.equal((await stranger.call('get', '/events/:id/chat/access')).body.hasAccess, false);
  assert.equal((await stranger.call('get', '/events/:id/chat/access', { query: { hosterId: 'stranger' } })).statusCode, 403);
  f.setConfirmed(false);
  // An accepted in-memory invite must not override authoritative database membership.
  for (const [method, route] of routes.filter(([, route]) => route.includes('/chat/') && !route.endsWith('/access'))) {
    assert.equal((await f.call(method, route)).statusCode, 403);
  }
});

for (const participationStatus of ['approved', 'accepted', 'attended', 'pending', 'declined', 'cancelled', 'interested', 'invited']) {
  test(`chat participation policy for stored status ${participationStatus}`, async () => {
    const f = fixture({ participationStatus });
    const expected = ['approved', 'accepted', 'attended'].includes(participationStatus);
    assert.equal((await f.call('get', '/events/:id/chat/access')).body.hasAccess, expected);
    assert.equal((await f.call('get', '/events/:id/chat/messages')).statusCode, expected ? 200 : 403);
  });
}

test('event chat authors/reporters come from the token; only author or moderator deletes', async () => {
  const f = fixture();
  const sent = await f.call('post', '/events/:id/chat/messages', { body: { content: 'Hello', isHost: true } });
  assert.equal(sent.statusCode, 201);
  assert.equal(sent.body.item.userId, 'member');
  assert.equal(sent.body.item.isHost, false);
  assert.equal((await f.call('post', '/events/:id/chat/reports', { body: { reportedMessageId: 'message', reporterId: 'other' } })).statusCode, 403);
  const report = await f.call('post', '/events/:id/chat/reports', { body: { reportedMessageId: 'message' } });
  assert.equal(report.statusCode, 201);
  assert.equal(report.body.item.reporterId, 'member');
  assert.equal((await f.call('delete', '/events/:eventId/chat/messages/:messageId')).statusCode, 204);
  f.message.authorId = 'other';
  assert.equal((await f.call('delete', '/events/:eventId/chat/messages/:messageId')).statusCode, 403);
  for (const uid of ['host', 'admin']) {
    const moderator = fixture({ uid });
    assert.equal((await moderator.call('delete', '/events/:eventId/chat/messages/:messageId')).statusCode, 204);
    assert.equal((await moderator.call('get', '/events/:id/chat/reports')).statusCode, 200);
  }
  assert.equal((await f.call('get', '/events/:id/chat/reports')).statusCode, 403);
});

test('chat resource checks reject another event or a message from another chat', async () => {
  const f = fixture();
  for (const [method, route] of routes.filter(([, route]) => route.includes('/chat/'))) {
    assert.equal((await f.call(method, route, { params: { id: 'missing', eventId: 'missing' } })).statusCode, 404);
  }
  f.message.chat.eventId = 'different';
  assert.equal((await f.call('delete', '/events/:eventId/chat/messages/:messageId')).statusCode, 404);
  f.message.chatId = 'different';
  assert.equal((await f.call('post', '/events/:id/chat/reports', { body: { reportedMessageId: 'message' } })).statusCode, 404);
  assert.equal(f.writes.length, 0);
});

test('private event chat fails closed on database errors even if memory fallback is enabled', async () => {
  for (const [method, route] of routes.filter(([, route]) => route.includes('/chat/'))) {
    const f = fixture({ uid: 'host', databaseFailure: true, memoryFallback: true });
    assert.equal((await f.call(method, route)).statusCode, 503);
    assert.equal(f.writes.length, 0);
  }
});

test('family memory fallback still enforces actor and resource ownership', async () => {
  const f = fixture({ databaseFailure: true, memoryFallback: true });
  assert.equal((await f.call('get', '/family/requests')).body.requests.length, 1);
  assert.equal((await f.call('delete', '/family/requests/:id', { params: { id: 'foreign' } })).statusCode, 403);
  assert.equal((await f.call('put', '/family/requests/:id', { params: { id: 'foreign' }, body: { status: 'accepted' } })).statusCode, 403);
});

test('family and private invitation routes fail closed with production persistence defaults', async () => {
  for (const [method, route] of routes.filter(([, route]) => !route.includes('/chat/'))) {
    const f = fixture({ uid: 'host', databaseFailure: true });
    const body = route === '/family/requests' ? { toUserId: 'member' } : { status: 'accepted' };
    assert.equal((await f.call(method, route, { body })).statusCode, 503);
    assert.equal(f.writes.length, 0);
  }
});
