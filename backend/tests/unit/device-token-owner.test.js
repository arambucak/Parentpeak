const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
const helperStart = source.indexOf('async function authorizeProfileOwner(');
const helperEnd = source.indexOf('\n}', helperStart) + 2;
const start = source.indexOf('let deviceTokenSchemaReady;');
const end = source.indexOf('// ── Firebase Custom Auth Action Handler', start);
assert.ok(helperStart >= 0 && start >= 0 && end > start);

function fixture({ stored = new Map(), failWrites = 0, failReads = false,
  schemaFailures = 0, responseFor = () => ({ success: true }), firebase = true,
  afterSend = () => {}, errorCode = 'ECONNREFUSED' } = {}) {
  const routes = new Map();
  let persistenceCalls = 0;
  const queries = [];
  const pushes = [];
  const errors = [];
  const warnings = [];
  const failWrite = () => {
    if (failWrites > 0) {
      failWrites--;
      throw Object.assign(new Error('database unavailable'), { code: errorCode });
    }
  };
  const context = {
    app: {
      post: (url, fn) => routes.set(`POST ${url}`, fn),
      delete: (url, fn) => routes.set(`DELETE ${url}`, fn),
    },
    verifyFirebaseIdToken: async req => ({
      verified: ['a', 'b'].includes(req.tokenUid), uid: req.tokenUid,
    }),
    prisma: {
      async $executeRawUnsafe(sql, ...args) {
        persistenceCalls++;
        queries.push({ sql, args });
        if (sql.includes('CREATE') && schemaFailures > 0) {
          schemaFailures--;
          throw Object.assign(new Error('database unavailable'), { code: 'ECONNREFUSED' });
        }
        if (sql.includes('DELETE')) {
          failWrite();
          assert.match(sql, /WHERE "token" = \$1 AND "userId" = \$2/);
          if (stored.get(args[0])?.userId === args[1]) return Number(stored.delete(args[0]));
          return 0;
        }
        return 1;
      },
      async $queryRawUnsafe(sql, ...args) {
        persistenceCalls++;
        queries.push({ sql, args });
        if (sql.includes('INSERT')) {
          failWrite();
          assert.match(sql, /ON CONFLICT \("token"\) DO UPDATE/);
          assert.match(sql, /WHERE "DeviceToken"\."userId" = EXCLUDED\."userId"/);
          const [token, userId, platform] = args;
          const existing = stored.get(token);
          if (existing && existing.userId !== userId) return [];
          stored.set(token, { token, userId, platform });
          return [{ token }];
        }
        if (failReads) throw Object.assign(new Error('database unavailable'), { code: 'ECONNREFUSED' });
        assert.match(sql, /WHERE "userId" = \$1/);
        const rows = [...stored.values()].filter(row => row.userId === args[0]);
        return sql.includes('COUNT') ? [{ n: rows.length }] : rows;
      },
    },
    firebaseAdmin: firebase ? { messaging: () => ({
      sendEachForMulticast: async payload => {
        pushes.push(payload);
        await afterSend();
        return { responses: payload.tokens.map(responseFor) };
      },
    }) } : null,
    setTimeout: resolve => { resolve(); },
    console: { error: (...args) => errors.push(args), warn: (...args) => warnings.push(args) },
  };
  vm.createContext(context);
  vm.runInContext(source.slice(helperStart, helperEnd), context);
  vm.runInContext(source.slice(start, end), context);
  return {
    stored, queries, pushes, errors, warnings,
    send: (userId = 'a') => context.sendPushToUser(userId, {
      title: 'ParentPeak', body: 'Review', data: { type: 'moderation_report' },
    }),
    get persistenceCalls() { return persistenceCalls; },
    async request(method, tokenUid, userId = 'a', token = 'device-token', platform = 'ios') {
      let status = 200, body;
      const res = {
        status(code) { status = code; return res; },
        json(value) { body = value; return res; },
      };
      await routes.get(`${method} /devices/register-token`)(
        { tokenUid, body: { userId, token, platform } }, res,
      );
      return { status, body };
    },
  };
}

for (const method of ['POST', 'DELETE']) {
  for (const [uid, status] of [[undefined, 401], ['invalid', 401], ['b', 403]]) {
    test(`${method} device token rejects ${uid ?? 'missing'} owner`, async () => {
      const app = fixture();
      const result = await app.request(method, uid);
      assert.equal(result.status, status);
      assert.equal(app.persistenceCalls, 0);
    });
  }
  test(`${method} device token accepts matching owner`, async () => {
    const app = fixture();
    assert.equal((await app.request('POST', 'a')).status, 200);
    assert.equal((await app.request(method, 'a')).status, 200);
  });
}

test('token cannot be rebound to another owner until deregistered', async () => {
  const app = fixture();
  assert.equal((await app.request('POST', 'a')).status, 200);
  assert.equal((await app.request('POST', 'b', 'b')).status, 409);
  assert.equal((await app.request('DELETE', 'b', 'a')).status, 403);
  assert.equal((await app.request('POST', 'b', 'b')).status, 409);
  assert.equal((await app.request('DELETE', 'a')).status, 200);
  assert.equal((await app.request('POST', 'b', 'b')).status, 200);
});

test('own repeated registration is idempotent and foreign DELETE leaves it intact', async () => {
  const app = fixture();
  await app.request('POST', 'a');
  assert.equal((await app.request('POST', 'a')).body.tokenCount, 1);
  assert.equal((await app.request('DELETE', 'b', 'a')).status, 403);
  assert.equal((await app.request('POST', 'b', 'b')).status, 409);
});

test('registration is durable, updates platform and counts all devices from DB', async () => {
  const app = fixture();
  assert.equal((await app.request('POST', 'a')).body.tokenCount, 1);
  assert.equal((await app.request('POST', 'a', 'a', 'device-token', 'android')).body.tokenCount, 1);
  assert.equal(app.stored.get('device-token').platform, 'android');
  assert.equal((await app.request('POST', 'a', 'a', 'second')).body.tokenCount, 2);
  const ddl = app.queries.find(q => q.sql.includes('CREATE TABLE')).sql;
  assert.match(ddl, /"token" TEXT PRIMARY KEY/);
  assert.match(ddl, /"createdAt" TIMESTAMPTZ/);
  assert.match(ddl, /"updatedAt" TIMESTAMPTZ/);
  assert.equal(app.queries.filter(q => q.sql.includes('CREATE TABLE')).length, 1);
});

test('DB ownership survives restart and simultaneous registrations cannot rebind', async () => {
  const stored = new Map();
  const a = fixture({ stored });
  const b = fixture({ stored });
  const results = await Promise.all([
    a.request('POST', 'a'),
    b.request('POST', 'b', 'b'),
  ]);
  assert.deepEqual(results.map(r => r.status).sort(), [200, 409]);
  const restarted = fixture({ stored });
  assert.equal((await restarted.request('POST', 'b', 'b')).status, 409);
  assert.equal((await restarted.request('DELETE', 'b', 'b')).status, 200);
  assert.equal(stored.get('device-token').userId, 'a');
  assert.equal((await restarted.request('DELETE', 'a')).status, 200);
  assert.equal(stored.has('device-token'), false);
  assert.equal((await restarted.request('DELETE', 'a')).status, 200);
  assert.equal((await restarted.request('POST', 'b', 'b')).status, 200);
});

test('registration and deletion retry once but never claim success on DB failure', async () => {
  for (const method of ['POST', 'DELETE']) {
    const stored = new Map([['device-token', { token: 'device-token', userId: 'a' }]]);
    const recovered = fixture({ stored, failWrites: 1 });
    assert.equal((await recovered.request(method, 'a')).status, 200);
    assert.equal(recovered.warnings.length, 1);

    const failed = fixture({ failWrites: 3 });
    const result = await failed.request(method, 'a');
    assert.equal(result.status, 503);
    assert.equal(result.body.ok, false);
    assert.equal(failed.warnings.length, 1);
    assert.equal(failed.errors.length, 1);
    assert.equal(failed.stored.size, 0);
  }
});

test('schema initialization retries after outage and permanent errors are not retried', async () => {
  const app = fixture({ schemaFailures: 2 });
  assert.equal((await app.request('POST', 'a')).status, 503);
  assert.equal((await app.request('POST', 'a')).status, 200);
  const denied = fixture({ failWrites: 1, errorCode: '42501' });
  assert.equal((await denied.request('POST', 'a')).status, 503);
  assert.equal(denied.warnings.length, 0);
});

test('push after restart reads only persisted owner tokens, without a RAM cache', async () => {
  const stored = new Map();
  const registered = fixture({ stored });
  await registered.request('POST', 'a');
  await registered.request('POST', 'a', 'a', 'second');
  await registered.request('POST', 'b', 'b', 'foreign');
  const restarted = fixture({ stored });
  assert.equal(await restarted.send(), true);
  assert.deepEqual([...restarted.pushes[0].tokens], ['device-token', 'second']);
  assert.equal(restarted.pushes[0].data.accountUserId, 'a');
  assert.equal(restarted.pushes[0].data.type, 'moderation_report');
  assert.equal(await restarted.send('no-token'), undefined);
  assert.equal(restarted.pushes.length, 1);
});

test('invalid tokens are deleted from DB; temporary FCM errors preserve tokens', async () => {
  const codes = ['messaging/invalid-registration-token', 'messaging/registration-token-not-registered'];
  for (const code of [...codes, 'messaging/server-unavailable']) {
    const stored = new Map([['bad', { token: 'bad', userId: 'a' }], ['good', { token: 'good', userId: 'a' }]]);
    const app = fixture({ stored, responseFor: token => token === 'bad'
      ? { success: false, error: { code } } : { success: true } });
    assert.equal(await app.send(), false);
    assert.equal(stored.has('bad'), !codes.includes(code));
    assert.equal(stored.has('good'), true);
    assert.equal(app.errors.length, 1);
  }
});

test('delayed invalid response never deletes a token rebound to another owner', async () => {
  const stored = new Map([['token', { token: 'token', userId: 'a' }]]);
  const app = fixture({
    stored,
    afterSend: () => stored.set('token', { token: 'token', userId: 'b' }),
    responseFor: () => ({ success: false, error: { code: 'messaging/registration-token-not-registered' } }),
  });
  assert.equal(await app.send(), false);
  assert.equal(stored.get('token').userId, 'b');
});

test('DB read/cleanup failures return false and log without token values', async () => {
  const readFailure = fixture({ failReads: true });
  assert.equal(await readFailure.send(), false);
  assert.equal(readFailure.pushes.length, 0);
  const stored = new Map([['private-token', { token: 'private-token', userId: 'a' }]]);
  const cleanupFailure = fixture({
    stored, failWrites: 1,
    responseFor: () => ({ success: false, error: { code: 'messaging/invalid-registration-token' } }),
  });
  assert.equal(await cleanupFailure.send(), false);
  assert.equal(stored.has('private-token'), true);
  assert.doesNotMatch(JSON.stringify(cleanupFailure.errors), /private-token/);
});

test('persisted device sets are sent in batches of at most 500', async () => {
  const stored = new Map(Array.from({ length: 501 }, (_, i) => [
    `token-${i}`, { token: `token-${i}`, userId: 'a' },
  ]));
  const app = fixture({ stored });
  assert.equal(await app.send(), true);
  assert.deepEqual(app.pushes.map(p => p.tokens.length), [500, 1]);
});

test('invalid-token cleanup outage does not suppress later valid multicast batches', async () => {
  const stored = new Map(Array.from({ length: 501 }, (_, i) => [
    `token-${i}`, { token: `token-${i}`, userId: 'a' },
  ]));
  const app = fixture({
    stored, failWrites: 1,
    responseFor: token => token === 'token-0'
      ? { success: false, error: { code: 'messaging/invalid-registration-token' } } : { success: true },
  });
  assert.equal(await app.send(), false);
  assert.deepEqual(app.pushes.map(p => p.tokens.length), [500, 1]);
  assert.equal(stored.has('token-0'), true);
  assert.equal(app.errors.length, 2);
});

test('unconfigured Firebase remains a no-op without a database lookup', async () => {
  const app = fixture({ firebase: false });
  assert.equal(await app.send(), undefined);
  assert.equal(app.persistenceCalls, 0);
  assert.equal(app.pushes.length, 0);
});

test('delete-data clears persisted tokens only for an actual owner deletion, not a dry run', async () => {
  const routeStart = source.indexOf("app.post('/account/delete-data',");
  const routeEnd = source.indexOf('\napp.', routeStart + 1);
  for (const dryRun of [true, false]) {
    let handler;
    const deletedUsers = [];
    const context = {
      app: { post: (_route, _guard, fn) => { handler = fn; } },
      requireVerifiedUser() {},
      authorizeAccountOwner: async () => true,
      deleteAccountDataByUserIdPrisma: async () => ({ removed: 2, hostedEventIds: [], mediaUrls: [] }),
      countAccountDataByUserIdInMemory: () => 0,
      deleteAccountDataByUserIdInMemory: () => 0,
      writeDeviceToken: async operation => operation(),
      prisma: { $executeRawUnsafe: async (sql, userId) => {
        assert.match(sql, /DELETE FROM "DeviceToken" WHERE "userId" = \$1/);
        deletedUsers.push(userId);
        return 1;
      } },
      deleteUnreferencedAccountMedia: async () => ({}),
      respondFamilyPersistenceError: () => { throw new Error('Unexpected error'); },
    };
    vm.runInNewContext(source.slice(routeStart, routeEnd), context);
    let payload;
    const res = { json: value => { payload = value; } };
    await handler({ body: { userId: 'a' }, query: { dryRun: String(dryRun) } }, res);
    assert.deepEqual(deletedUsers, dryRun ? [] : ['a']);
    assert.equal(payload.removedDbEntries, dryRun ? 2 : 3);
  }
});
