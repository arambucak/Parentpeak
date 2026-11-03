const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');

function slice(start, end) {
  const a = source.indexOf(start);
  const b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `Missing block: ${start}`);
  return source.slice(a, b);
}

// Isolierte Umgebung für die Momente-Routen (M-B1). Die Raw-SQL-Aufrufe werden
// über eine kleine In-Memory-Tabelle beantwortet; Freundschaften und Blocks
// sind steuerbar, damit der Sichtbarkeitsfilter geprüft werden kann.
function fixture({
  verifiedUids = ['me', 'friend', 'stranger', 'blocked'],
  moments = [],
  friends = [], // Paare [a,b] = accepted Friendship
  blocks = [], // Paare [blocker, blocked]
  suspended = [],
} = {}) {
  const routes = new Map();
  const store = new Map(moments.map(m => [m.id, { ...m }]));

  function friendUidsOf(uid) {
    const set = new Set();
    for (const [a, b] of friends) {
      if (a === uid) set.add(b);
      if (b === uid) set.add(a);
    }
    return set;
  }

  const prisma = {
    $queryRawUnsafe: async (sql, ...args) => {
      if (sql.includes('FROM "Moment" ORDER BY')) {
        return [...store.values()].sort((a, b) =>
          (b.createdAt || '').localeCompare(a.createdAt || ''));
      }
      if (sql.includes('FROM "Moment" WHERE "id"') && sql.includes('authorUserId')) {
        const row = store.get(args[0]);
        return row ? [{ authorUserId: row.authorUserId }] : [];
      }
      if (sql.includes('SELECT * FROM "Moment" WHERE "id"')) {
        const row = store.get(args[0]);
        return row ? [row] : [];
      }
      if (sql.includes('FROM "Friendship"')) {
        return [...friendUidsOf(args[0])].map(u =>
          args[0] < u ? { userLow: args[0], userHigh: u } : { userLow: u, userHigh: args[0] });
      }
      if (sql.includes('FROM "SafetyBlock"') && sql.includes('OR "blockedUserId"')) {
        return blocks
          .filter(([a, b]) => a === args[0] || b === args[0])
          .map(([a, b]) => ({ blockerUserId: a, blockedUserId: b }));
      }
      if (sql.includes('FROM "SafetyBlock"')) {
        const a = args[0], b = args[1];
        return blocks.some(([x, y]) =>
          (x === a && y === b) || (x === b && y === a)) ? [{ one: 1 }] : [];
      }
      if (sql.includes('FROM "MomentReaction"')) return [];
      if (sql.includes('FROM "MomentComment"')) return [{ n: 0 }];
      return [];
    },
    $executeRawUnsafe: async (sql, ...args) => {
      if (sql.includes('INSERT INTO "Moment"')) {
        const [id, authorUserId, authorName, text, imageUrls, visibility] = args;
        store.set(id, {
          id, authorUserId, authorName, text, imageUrls, visibility,
          createdAt: new Date().toISOString(),
        });
      } else if (sql.includes('DELETE FROM "Moment" WHERE')) {
        store.delete(args[0]);
      }
      return 1;
    },
  };

  const context = {
    console: { error() {}, log() {}, warn() {} },
    Set, Map, Array, Number, Date, Math, JSON,
    process: { env: {} },
    prisma,
    app: {
      get: (url, ...chain) => routes.set(`GET ${url}`, chain),
      post: (url, ...chain) => routes.set(`POST ${url}`, chain),
      delete: (url, ...chain) => routes.set(`DELETE ${url}`, chain),
    },
    requireVerifiedUser: (req, res, next) => {
      const uid = req.tokenUid;
      if (!uid || !verifiedUids.includes(uid)) {
        return res.status(401).json({ error: 'token' });
      }
      const claimed = req.body?.userId ?? req.query?.userId;
      if (claimed !== undefined && claimed !== uid) {
        return res.status(403).json({ error: 'owner' });
      }
      req.firebaseUid = uid;
      return next();
    },
    ensureSocialSchemaReady: async () => {},
    generateId: prefix => `${prefix}-test-${store.size + 1}`,
    respondWithStrictPersistenceError: () => false,
    parseJsonArray: raw => {
      try {
        const v = typeof raw === 'string' ? JSON.parse(raw) : raw;
        return Array.isArray(v) ? v.map(x => x.toString()) : [];
      } catch (_) { return []; }
    },
    isUserSuspended: async uid => suspended.includes(uid),
    respondSuspended: res => res.status(403).json({ error: 'suspended' }),
    isBlockedBetween: async (a, b) =>
      blocks.some(([x, y]) => (x === a && y === b) || (x === b && y === a)),
    areFriends: async (a, b) => friends.some(([x, y]) =>
      (x === a && y === b) || (x === b && y === a)),
  };
  vm.createContext(context);
  vm.runInContext(
    slice(
      '// MOMENTE — Eltern teilen Familien-Momente',
      '// ─── DSGVO: Konto-Loeschung',
    ),
    context,
  );

  async function call(route, tokenUid, { body = {}, params = {}, query = {} } = {}) {
    let status = 200;
    let payload;
    const req = { tokenUid, body, params, query, headers: {} };
    const res = {
      status(c) { status = c; return res; },
      json(v) { payload = v; return res; },
    };
    const chain = routes.get(route);
    assert.ok(chain, `Route not registered: ${route}`);
    const run = async i => { if (chain[i]) await chain[i](req, res, () => run(i + 1)); };
    await run(0);
    return { status, body: payload };
  }
  return { call, store };
}

function moment(id, author, visibility, extra = {}) {
  return {
    id, authorUserId: author, authorName: author, text: `text-${id}`,
    imageUrls: '[]', visibility, createdAt: `2026-11-0${id.slice(-1) || 1}`, ...extra,
  };
}

// ── Erstellen ─────────────────────────────────────────────────────────────

test('POST /api/moments requires a verified token', async () => {
  const { call, store } = fixture();
  for (const uid of [undefined, 'nobody']) {
    const r = await call('POST /api/moments', uid, { body: { text: 'Hallo' } });
    assert.equal(r.status, 401);
  }
  assert.equal(store.size, 0);
});

test('POST /api/moments rejects a spoofed author', async () => {
  const { call } = fixture();
  const r = await call('POST /api/moments', 'me', {
    body: { authorUserId: 'someone-else', text: 'Hallo' },
  });
  assert.equal(r.status, 403);
});

test('POST /api/moments needs text or at least one image', async () => {
  const { call } = fixture();
  const empty = await call('POST /api/moments', 'me', { body: { text: '   ' } });
  assert.equal(empty.status, 400);
  const withImage = await call('POST /api/moments', 'me', {
    body: { imageUrls: ['/uploads/a.jpg'] },
  });
  assert.equal(withImage.status, 201);
  assert.deepEqual(
    JSON.parse(JSON.stringify(withImage.body.moment.imageUrls)),
    ['/uploads/a.jpg'],
  );
});

test('POST /api/moments stores text, defaults to friends visibility, max 10 images', async () => {
  const { call } = fixture();
  const r = await call('POST /api/moments', 'me', {
    body: {
      text: 'Unser Ausflug',
      imageUrls: Array.from({ length: 15 }, (_, i) => `/uploads/${i}.jpg`),
      visibility: 'bogus',
    },
  });
  assert.equal(r.status, 201);
  assert.equal(r.body.moment.text, 'Unser Ausflug');
  assert.equal(r.body.moment.visibility, 'friends'); // bogus -> default
  assert.equal(r.body.moment.imageUrls.length, 10); // gekappt
  assert.equal(r.body.moment.isMine, true);
});

test('POST /api/moments blocks suspended users', async () => {
  const { call } = fixture({ suspended: ['me'] });
  const r = await call('POST /api/moments', 'me', { body: { text: 'Hallo' } });
  assert.equal(r.status, 403);
});

// ── Feed-Sichtbarkeit ───────────────────────────────────────────────────────

test('GET /api/moments: public visible to all, friends only to connected, private only to author', async () => {
  const { call } = fixture({
    moments: [
      moment('m1', 'stranger', 'public'),
      moment('m2', 'friend', 'friends'),
      moment('m3', 'stranger', 'friends'),
      moment('m4', 'stranger', 'private'),
      moment('m5', 'me', 'private'),
    ],
    friends: [['me', 'friend']],
  });
  const r = await call('GET /api/moments', 'me', {});
  assert.equal(r.status, 200);
  const ids = JSON.parse(JSON.stringify(r.body.moments.map(m => m.id))).sort();
  // public (m1), friend's friends-post (m2), own private (m5). NOT m3/m4.
  assert.deepEqual(ids, ['m1', 'm2', 'm5']);
});

test('GET /api/moments hides authors blocked in either direction', async () => {
  const { call } = fixture({
    moments: [
      moment('m1', 'stranger', 'public'),
      moment('m2', 'blocked', 'public'),
    ],
    blocks: [['me', 'blocked']],
  });
  const r = await call('GET /api/moments', 'me', {});
  assert.deepEqual(JSON.parse(JSON.stringify(r.body.moments.map(m => m.id))), ['m1']);
});

// ── Einzeln + Löschen ───────────────────────────────────────────────────────

test('GET /api/moments/:id enforces friends visibility', async () => {
  const { call } = fixture({
    moments: [moment('m2', 'friend', 'friends'), moment('m3', 'stranger', 'friends')],
    friends: [['me', 'friend']],
  });
  assert.equal((await call('GET /api/moments/:id', 'me', { params: { id: 'm2' } })).status, 200);
  assert.equal((await call('GET /api/moments/:id', 'me', { params: { id: 'm3' } })).status, 403);
});

test('DELETE /api/moments/:id only by the author', async () => {
  const { call, store } = fixture({
    moments: [moment('m1', 'stranger', 'public')],
  });
  const foreign = await call('DELETE /api/moments/:id', 'me', { params: { id: 'm1' } });
  assert.equal(foreign.status, 403);
  assert.equal(store.has('m1'), true);

  const { call: call2, store: store2 } = fixture({
    moments: [moment('m1', 'me', 'public')],
  });
  const own = await call2('DELETE /api/moments/:id', 'me', { params: { id: 'm1' } });
  assert.equal(own.status, 200);
  assert.equal(store2.has('m1'), false);
});
