const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const express = require('express');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
function slice(start, end) {
  const a = source.indexOf(start), b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `Missing source block: ${start}`);
  return source.slice(a, b);
}
const chatRoutes = [
  ['GET', '/friend-chat/messages'],
  ['GET', '/friend-chat/overview'],
  ['POST', '/friend-chat/messages'],
  ['POST', '/friend-chat/read'],
  ['POST', '/friend-chat/clear-for-me'],
  ['POST', '/friend-chat/delete-for-all'],
];
const groupRoutes = [
  ['POST', '/chat-groups'], ['GET', '/chat-groups'],
  ['GET', '/chat-groups/:id/members'], ['POST', '/chat-groups/:id/members'],
  ['DELETE', '/chat-groups/:id/members/:userId'],
];
const relationRoutes = [
  ['POST', '/api/friendships/request'], ['POST', '/api/friendships/accept'],
  ['DELETE', '/api/friendships'], ['GET', '/api/friendships/:uid'],
  ['POST', '/api/friendships/invite'],
  ['POST', '/api/safety/block'], ['POST', '/api/safety/unblock'],
  ['GET', '/api/safety/blocks/:userId'],
];

function fixture({ app, failTable, failSchema = false, friends = true,
  blocks = [], member = true, suspended = false, requestedBy = 'b' } = {}) {
  const routes = new Map(), calls = [], pushes = [], logs = [];
  const messages = [{ id: 'm', roomId: 'a__b', authorUserId: 'b', content: 'Private' }];
  const markers = [], memberships = [], tokens = [];
  const friendship = { userLow: 'a', userHigh: 'b', requestedBy, status: 'pending' };
  const context = {
    app: app || Object.fromEntries(['get', 'post', 'delete'].map(method => [
      method, (route, ...handlers) => routes.set(`${method.toUpperCase()} ${route}`, handlers),
    ])),
    firebaseAdmin: { auth: () => ({ verifyIdToken: async token => {
      tokens.push(token);
      if (!['a', 'b', 'c'].includes(token)) throw new Error('Invalid token');
      return { uid: token };
    } }) },
    console: { error: (...args) => logs.push(args) },
    process: { env: { FIREBASE_REQUIRE_AUTH: '1' } },
    WRITE_METHODS: new Set(['POST', 'PUT', 'PATCH', 'DELETE']),
    backendApiToken: 'shared',
    requireAuthForWrites: true,
    isWriteRequest: req => ['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method),
    safetyBlocks: new Map(), userProfiles: new Map(),
    isUserSuspended: async uid => { calls.push(['suspension', uid]); return suspended; },
    respondSuspended: res => res.status(403).json({ code: 'account_suspended' }),
    generateId: prefix => `${prefix}-new`,
    sendPushToUser: async (uid, data) => pushes.push({ uid, data }),
    resolveDisplayName: async () => 'Name',
    respondWithStrictPersistenceError: (res, label, error) =>
      context.respondChatPersistenceError(res, label, error),
    ensureSocialSchemaReady: async () => {
      if (failSchema) throw new Error('Schema unavailable');
    },
    prisma: {
      $queryRawUnsafe: async (sql, ...params) => {
        calls.push(['read', sql, ...params]);
        if (failTable && sql.includes(`"${failTable}"`)) throw new Error('DB unavailable');
        if (sql.includes('"SafetyBlock"')) {
          const [a, b] = params;
          return blocks.some(([from, to]) =>
            sql.includes(' OR ') ? ((from === a && to === b) || (from === b && to === a))
              : (from === a && to === b)) ? [{}] : [];
        }
        if (sql.includes('FROM "Friendship"')) return friends ? [{}] : [];
        if (sql.includes('FROM "UserProfile"')) return [{ isPrivate: true }];
        if (sql.includes('SELECT DISTINCT "roomId"')) {
          assert.ok(!sql.includes('LIKE'));
          assert.match(sql, /split_part/);
          assert.equal(params[0], 'a');
          return ['a__b', 'a__c', 'aa__b', 'b__a', 'a__b__c', 'pp-aaaaaa-pp-bbbbbb']
            .map(roomId => ({ roomId }));
        }
        if (sql.includes('JOIN "ChatGroupMember"')) return member ? [{ id: 'g', name: 'Group' }] : [];
        if (sql.includes('FROM "ChatGroupMember"')) {
          if (sql.includes('SELECT 1')) return member && params[1] === 'a' ? [{}] : [];
          return member ? [{ userId: 'a', role: 'owner' }] : [];
        }
        if (sql.includes('FROM "ChatGroup"')) return [{ name: 'Group' }];
        if (sql.includes('COUNT(*)')) return [{ c: 1 }];
        if (sql.includes('"ChatRead"') || sql.includes('"ChatCleared"')) return [];
        if (sql.includes('"FriendChatMessage"')) {
          return [{ ...messages[0], roomId: params[0], createdAt: new Date().toISOString() }];
        }
        if (sql.includes('"FriendInvite"')) return [];
        throw new Error(`Unhandled fixture query: ${sql}`);
      },
      $executeRawUnsafe: async (sql, ...params) => {
        calls.push(['write', sql, ...params]);
        if (failTable && sql.includes(`"${failTable}"`)) throw new Error('DB unavailable');
        if (sql.startsWith('UPDATE "Friendship"')) {
          assert.match(sql, /"requestedBy" = \$3/);
          assert.match(sql, /"status" IN/);
          if (params[0] !== 'a' || params[1] !== 'b' || friendship.requestedBy !== params[2]) return 0;
          friendship.status = 'accepted';
          return 1;
        }
        if (sql.startsWith('INSERT INTO "FriendChatMessage"')) {
          messages.push({ id: params[0], roomId: params[1], authorUserId: params[2] });
        }
        if (sql.startsWith('DELETE FROM "FriendChatMessage"')) messages.length = 0;
        if (/INSERT INTO "Chat(Read|Cleared)"/.test(sql)) markers.push({ roomId: params[0], userId: params[1] });
        if (sql.includes('INSERT INTO "ChatGroupMember"')) memberships.push({ groupId: params[0], userId: params[1] });
        return 1;
      },
    },
  };
  vm.createContext(context);
  vm.runInContext(slice('async function verifyFirebaseIdToken(', 'function resolveVerifiedUserId('), context);
  vm.runInContext(slice('const firebaseRequireAuth =', '\n// Middleware'), context);
  if (app) {
    app.use(context.firebaseAuthMiddleware);
    const a = source.lastIndexOf('app.use(async (req, res, next) => {', source.indexOf('  if (!requireAuthForWrites)'));
    vm.runInContext(source.slice(a, source.indexOf('\nconst allowedGeminiModels', a)), context);
  }
  vm.runInContext(slice('const friendships = new Map()', '// ─── Phase 3a:'), context);
  vm.runInContext(slice("app.post('/api/safety/block'", "app.post('/api/safety/report'"), context);
  vm.runInContext(slice("app.get('/friend-chat/messages'", "app.get('/family/requests'"), context);
  async function request(method, route, { token = 'a', roomId = 'a__b',
    body = {}, query = {}, params = {} } = {}) {
    let status = 200, response;
    const req = {
      method, path: route, headers: token === null ? {} : { authorization: `Bearer ${token}` },
      body: { roomId, content: 'Hello', name: 'Group', toUid: 'b', otherUid: 'b', ...body },
      query: { roomId, ...query }, params: { id: 'g', userId: token, uid: token, ...params },
    };
    const res = { status(code) { status = code; return res; },
      json(value) { response = value; return res; } };
    const handlers = routes.get(`${method} ${route}`);
    assert.ok(handlers);
    async function run(index) { await handlers[index](req, res, () => run(index + 1)); }
    await run(0);
    return { status, body: response };
  }
  return { request, calls, messages, markers, memberships, friendship, pushes, logs, context };
}

for (const [method, route] of [...chatRoutes, ...groupRoutes, ...relationRoutes]) {
  test(`${method} ${route}: missing Firebase configuration fails closed`, async () => {
    const f = fixture();
    f.context.firebaseAdmin = null;
    assert.equal((await f.request(method, route)).status, 401);
    assert.deepEqual(f.calls, []);
  });
  for (const token of [null, 'invalid', 'expired', 'shared']) {
    test(`${method} ${route}: rejects ${token ?? 'missing'} token before access`, async () => {
      const f = fixture();
      assert.equal((await f.request(method, route, { token })).status, 401);
      assert.deepEqual(f.calls, []);
    });
  }
}

for (const [method, route] of chatRoutes.filter(([, route]) => !route.endsWith('overview'))) {
  test(`${method} ${route}: nonparticipant cannot access A-B`, async () => {
    const f = fixture();
    assert.equal((await f.request(method, route, { token: 'c' })).status, 403);
    assert.deepEqual(f.calls, []);
  });
  test(`${method} ${route}: spoofed UID fails before access`, async () => {
    const f = fixture();
    assert.equal((await f.request(method, route, {
      token: 'c', body: { userId: 'a' }, query: { userId: 'a' },
    })).status, 403);
    assert.deepEqual(f.calls, []);
  });
  test(`${method} ${route}: malformed and legacy rooms fail closed`, async () => {
    for (const roomId of ['', 'b__a', 'a__a', 'a____b', 'a__b__c', ' a__b',
      'a__b ', '__b', 'a__', 'pp-aaaaaa-pp-bbbbbb', [], 'group_']) {
      const f = fixture();
      assert.equal((await f.request(method, route, { roomId })).status, 403, String(roomId));
      assert.deepEqual(f.calls, []);
    }
  });
  test(`${method} ${route}: group nonmember and failed membership cannot access`, async () => {
    for (const [options, expected] of [[{ member: false }, 403],
      [{ failTable: 'ChatGroupMember' }, 503], [{ failSchema: true }, 503]]) {
      const f = fixture(options);
      assert.equal((await f.request(method, route, { roomId: 'group_g' })).status, expected);
      assert.ok(!f.calls.some(([kind]) => kind === 'write'));
      assert.equal(f.messages.length, 1);
      assert.deepEqual(f.pushes, []);
    }
  });
  test(`${method} ${route}: group member succeeds`, async () => {
    const f = fixture();
    assert.ok([200, 201].includes((await f.request(method, route, { roomId: 'group_g' })).status));
  });
}

test('unfriend retains archive reads but forbids writes', async () => {
  const f = fixture({ friends: false });
  assert.equal((await f.request('GET', '/friend-chat/messages')).status, 200);
  const send = await f.request('POST', '/friend-chat/messages');
  assert.equal(send.status, 403);
  assert.equal(send.body.code, 'not_friends');
  assert.equal(f.messages.length, 1);
  assert.deepEqual(f.pushes, []);
});

test('direct chat owner comes from token and push goes only to counterpart', async () => {
  const f = fixture();
  assert.equal((await f.request('POST', '/friend-chat/messages')).status, 201);
  assert.equal(f.messages.at(-1).authorUserId, 'a');
  assert.equal(f.pushes[0].uid, 'b');
});

test('direct read block is directional; send block works in either direction', async () => {
  for (const [blocks, readStatus] of [[[['b', 'a']], 403], [[['a', 'b']], 200]]) {
    const f = fixture({ blocks });
    assert.equal((await f.request('GET', '/friend-chat/messages')).status, readStatus);
    assert.equal((await f.request('POST', '/friend-chat/messages')).status, 403);
    assert.equal(f.messages.length, 1);
  }
});

test('block/friendship/read persistence failures do not grant access', async () => {
  for (const [method, failTable] of [['GET', 'SafetyBlock'], ['POST', 'SafetyBlock'],
    ['POST', 'Friendship'], ['GET', 'FriendChatMessage']]) {
    const f = fixture({ failTable });
    assert.equal((await f.request(method, '/friend-chat/messages')).status, 503);
    assert.ok(!f.calls.some(([kind]) => kind === 'write'));
    assert.deepEqual(f.pushes, []);
  }
});

test('chat suspension uses token identity', async () => {
  const f = fixture({ suspended: true });
  assert.equal((await f.request('POST', '/friend-chat/messages')).body.code, 'account_suspended');
  assert.deepEqual(f.calls[0], ['suspension', 'a']);
});

test('overview excludes blocked, malformed, legacy and substring-only rooms before preview', async () => {
  const f = fixture({ blocks: [['b', 'a']] });
  const result = await f.request('GET', '/friend-chat/overview');
  assert.equal(result.status, 200);
  assert.deepEqual(Array.from(result.body.conversations, c => c.roomId).sort(), ['a__c', 'group_g']);
  const previews = f.calls.filter(([, sql]) => typeof sql === 'string' && sql.includes('ORDER BY "createdAt" DESC'));
  assert.deepEqual(previews.map(call => call[2]).sort(), ['a__c', 'group_g']);
  assert.equal((await f.request('GET', '/friend-chat/overview', { query: { userId: 'b' } })).status, 403);
});

test('read and clear markers are always token-owned', async () => {
  const f = fixture();
  for (const route of ['/friend-chat/read', '/friend-chat/clear-for-me']) {
    assert.equal((await f.request('POST', route)).status, 200);
  }
  assert.deepEqual(f.markers.map(marker => marker.userId), ['a', 'a']);
});

test('group invitation claims and leave path are token-bound', async () => {
  const f = fixture();
  assert.equal((await f.request('POST', '/chat-groups/:id/members', {
    body: { actingUserId: 'b', memberUids: ['c'] },
  })).status, 403);
  assert.equal((await f.request('DELETE', '/chat-groups/:id/members/:userId', {
    params: { userId: 'b' },
  })).status, 403);
  assert.deepEqual(f.calls, []);
  assert.equal((await f.request('POST', '/chat-groups/:id/members', {
    body: { memberUids: ['c'] },
  })).status, 200);
  assert.equal(f.memberships[0].userId, 'c');
});

test('group member list is private and group owner cannot be spoofed', async () => {
  const f = fixture({ member: false });
  assert.equal((await f.request('GET', '/chat-groups/:id/members')).status, 403);
  const owner = fixture();
  assert.equal((await owner.request('POST', '/chat-groups', { body: { ownerUserId: 'b' } })).status, 403);
  assert.deepEqual(owner.calls, []);
  assert.equal((await owner.request('POST', '/chat-groups')).status, 201);
  assert.equal(owner.memberships[0].userId, 'a');
});

test('friendship accept is atomic, only the request recipient can accept', async () => {
  const recipient = fixture({ requestedBy: 'b' });
  assert.equal((await recipient.request('POST', '/api/friendships/accept')).status, 200);
  assert.equal(recipient.friendship.status, 'accepted');
  const sender = fixture({ requestedBy: 'a' });
  assert.equal((await sender.request('POST', '/api/friendships/accept')).status, 403);
  assert.equal(sender.friendship.status, 'pending');
  const stranger = fixture();
  assert.equal((await stranger.request('POST', '/api/friendships/accept', {
    token: 'c', body: { uid: 'a' },
  })).status, 403);
  assert.deepEqual(stranger.calls, []);
  assert.equal((await stranger.request('POST', '/api/friendships/accept', { token: 'c' })).status, 403);
});

test('friendship request actor and list path cannot be spoofed', async () => {
  const f = fixture();
  assert.equal((await f.request('POST', '/api/friendships/request', {
    body: { fromUid: 'b' },
  })).status, 403);
  assert.equal((await f.request('GET', '/api/friendships/:uid', {
    params: { uid: 'b' },
  })).status, 403);
  assert.deepEqual(f.calls, []);
  assert.equal((await f.request('POST', '/api/friendships/request')).status, 200);
  const insert = f.calls.find(([, sql]) => typeof sql === 'string' && sql.includes('INSERT INTO "Friendship"'));
  assert.equal(insert[5], 'a');
});

test('unblock cannot impersonate the blocked counterpart', async () => {
  const f = fixture();
  assert.equal((await f.request('POST', '/api/safety/unblock', {
    body: { blockerUserId: 'b', blockedUserId: 'a' },
  })).status, 403);
  assert.deepEqual(f.calls, []);
});

test('strict relationship helpers throw on DB failure but other callers retain fallback', async () => {
  const f = fixture({ failSchema: true });
  for (const name of ['areFriends', 'isBlockedBetween', 'hasBlockedMe']) {
    await assert.rejects(f.context[name]('a', 'b', { strict: true }), /Schema unavailable/);
    assert.equal(await f.context[name]('a', 'b'), false);
  }
});

for (const failure of ['registry', 'suspension']) {
  test(`strict suspension rejects ${failure} DB failure despite cached fallback`, async () => {
    const context = {
      ensureSocialSchemaReady: async () => {},
      friendRegistry: new Map(), safetySuspensions: new Set(),
      prisma: {
        $queryRawUnsafe: async sql => {
          if (failure === 'registry' || sql.includes('"SafetySuspension"')) {
            throw new Error('DB unavailable');
          }
          return [];
        },
      },
    };
    vm.createContext(context);
    vm.runInContext(slice('const _suspensionCache =', '/// Einheitliche 403-Antwort'), context);
    assert.equal(await context.isUserSuspended('a'), false);
    await assert.rejects(context.isUserSuspended('a', { strict: true }), /DB unavailable/);
  });
}

for (const [route, failTable] of [
  ['/friend-chat/read', 'ChatRead'],
  ['/friend-chat/clear-for-me', 'ChatCleared'],
  ['/friend-chat/delete-for-all', 'FriendChatMessage'],
]) {
  test(`${route}: failed mutation cannot report success`, async () => {
    const f = fixture({ failTable });
    assert.equal((await f.request('POST', route)).status, 503);
    assert.deepEqual(f.markers, []);
    assert.equal(f.messages.length, 1);
  });
}

test('real Express chain cannot bypass local GET/POST auth via global exceptions', async t => {
  const app = express();
  app.use(express.json());
  fixture({ app });
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => new Promise(resolve => { server.close(resolve); server.closeAllConnections(); }));
  const base = `http://127.0.0.1:${server.address().port}`;
  for (const [method, route] of chatRoutes) {
    assert.equal((await fetch(`${base}${route}?roomId=a__b`, { method })).status, 401);
  }
  assert.equal((await fetch(`${base}/friend-chat/messages?roomId=a__b`, {
    headers: { Authorization: 'Bearer c' },
  })).status, 403);
  assert.equal((await fetch(`${base}/friend-chat/messages?roomId=a__b`, {
    headers: { Authorization: 'Bearer a' },
  })).status, 200);
});
