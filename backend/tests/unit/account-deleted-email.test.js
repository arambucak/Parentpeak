const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');

function block(startMarker, endMarker) {
  const start = source.indexOf(startMarker);
  const end = source.indexOf(endMarker, start + startMarker.length);
  assert.ok(start >= 0 && end > start, `Missing source block: ${startMarker}`);
  return source.slice(start, end);
}

function routeBlock(startMarker) {
  const start = source.indexOf(startMarker);
  const end = source.indexOf('\napp.', start + startMarker.length);
  assert.ok(start >= 0 && end > start, `Missing route block: ${startMarker}`);
  return source.slice(start, end);
}

// Kontext mit Vorlagen, Versandbegrenzung und den neuen Helfern. sendEmail und
// Firebase sind gemockt.
function mailFixture({
  user = { email: 'Mama@Example.com', displayName: 'Anna' },
  getUserError = null,
  provider = async () => true,
  withFirebase = true,
} = {}) {
  const sent = [];
  const context = vm.createContext({
    URL, Promise, setTimeout, clearTimeout, Date, Map, String, Boolean, Math,
    ACTION_HANDLER_BASE: 'https://parentpeak.example/auth/action',
    SUPPORT_EMAIL: 'support@parentpeak.example',
    firebaseAdmin: withFirebase
      ? {
          auth: () => ({
            getUser: async uid => {
              if (getUserError) throw getUserError;
              return { uid, ...user };
            },
          }),
        }
      : null,
    sendEmail: async mail => {
      sent.push(mail);
      return provider(mail);
    },
  });
  vm.runInContext(
    [
      block('// ── Versandbegrenzung fuer Auth-Mails', '/** Build a custom action URL'),
      block('const EMAIL_STYLE =', '\n/**\n * POST /auth/send-password-reset'),
    ].join('\n'),
    context,
  );
  return { context, sent };
}

test('account deleted email is branded, has no action button and escapes the name', () => {
  const { context } = mailFixture();
  const html = context.buildAccountDeletedEmail('<script>alert(1)</script>');
  assert.match(html, /Dein Konto wurde gelöscht/);
  assert.match(html, /<html lang="de">/);
  assert.match(html, /brand-logo\.png/);
  assert.match(html, /Das warst nicht du\?/);
  assert.match(html, /mailto:support@parentpeak\.example/);
  // Keine Aktion: weder Button noch "Link kopieren"-Hinweis.
  assert.doesNotMatch(html, /Der Button funktioniert nicht/);
  assert.doesNotMatch(html, /Der Link ist nur begrenzte Zeit gültig/);
  assert.doesNotMatch(html, /bgcolor="#153E5A"/);
  // Name wird escaped.
  assert.doesNotMatch(html, /<script>/);
  assert.match(html, /&lt;script&gt;/);
  const text = context.buildAccountDeletedEmailText('Anna');
  assert.match(text, /Hallo Anna,/);
  assert.match(text, /support@parentpeak\.example/);
  assert.match(context.buildAccountDeletedEmailText(''), /^Hallo,/);
});

test('action emails keep their button and fallback link', () => {
  const { context } = mailFixture();
  const html = context.buildPasswordResetEmail('https://parentpeak.example/auth/action?mode=resetPassword&oobCode=x');
  assert.match(html, /Neues Passwort festlegen/);
  assert.match(html, /Der Button funktioniert nicht/);
  assert.match(html, /bgcolor="#153E5A"/);
});

test('lookupAccountContact returns the normalized address and name, or null', async () => {
  const { context } = mailFixture();
  assert.deepEqual(
    JSON.parse(JSON.stringify(await context.lookupAccountContact('uid-1'))),
    { email: 'mama@example.com', name: 'Anna' },
  );
  const noEmail = mailFixture({ user: { displayName: 'Anna' } });
  assert.equal(await noEmail.context.lookupAccountContact('uid-1'), null);
  const noFirebase = mailFixture({ withFirebase: false });
  assert.equal(await noFirebase.context.lookupAccountContact('uid-1'), null);
});

test('confirmation mail goes only to the account address, once per account and day', async () => {
  const { context, sent } = mailFixture();
  const contact = { email: 'mama@example.com', name: 'Anna' };
  assert.equal(await context.sendAccountDeletedEmail('uid-1', contact), 'sent');
  assert.equal(sent.length, 1);
  assert.equal(sent[0].to, 'mama@example.com');
  assert.equal(sent[0].subject, 'Dein ParentPeak-Konto wurde gelöscht');
  assert.match(sent[0].html, /Hallo Anna,/);
  assert.match(sent[0].text, /Hallo Anna,/);
  // Wiederholte Loeschung (z. B. nach requires-recent-login): keine zweite Mail.
  assert.equal(await context.sendAccountDeletedEmail('uid-1', contact), 'skipped');
  assert.equal(sent.length, 1);
  // Anderes Konto ist unabhaengig.
  assert.equal(await context.sendAccountDeletedEmail('uid-2', contact), 'sent');
  assert.equal(sent.length, 2);
});

test('no contact means no mail; a provider that declines reports failed', async () => {
  const { context, sent } = mailFixture();
  assert.equal(await context.sendAccountDeletedEmail('uid-1', null), 'skipped');
  assert.equal(await context.sendAccountDeletedEmail('uid-1', {}), 'skipped');
  assert.equal(sent.length, 0);
  const declined = mailFixture({ provider: async () => false });
  assert.equal(
    await declined.context.sendAccountDeletedEmail('uid-3', { email: 'a@b.de', name: '' }),
    'failed',
  );
});

test('a slow mail provider cannot hold up the deletion', async () => {
  const { context } = mailFixture({ provider: () => new Promise(() => {}) });
  const started = Date.now();
  const result = await context.sendAccountDeletedEmailWithTimeout(
    'uid-slow', { email: 'a@b.de', name: '' }, 30,
  );
  assert.equal(result, 'timeout');
  assert.ok(Date.now() - started < 1000);
});

// ── Die komplette Loeschroute mit Mocks ─────────────────────────────────────

function routeFixture({ user, getUserError, provider } = {}) {
  const mail = mailFixture({ user, getUserError, provider });
  const handlers = new Map();
  const executed = [];
  const context = vm.createContext({
    console: { error() {}, log() {}, warn() {} },
    URL, Promise, setTimeout, clearTimeout, Date, Map, Set, String, Boolean, Math, JSON,
    app: { delete: (route, ...chain) => handlers.set(`DELETE ${route}`, chain) },
    firebaseAdmin: {
      auth: () => ({
        verifyIdToken: async token => {
          if (token !== 'owner-token') throw new Error('invalid');
          return { uid: 'uid-1' };
        },
        getUser: async uid => {
          if (getUserError) throw getUserError;
          return { uid, ...(user ?? { email: 'Mama@Example.com', displayName: 'Anna' }) };
        },
      }),
    },
    ACTION_HANDLER_BASE: 'https://parentpeak.example/auth/action',
    SUPPORT_EMAIL: 'support@parentpeak.example',
    sendEmail: async m => {
      mail.sent.push(m);
      return (provider ?? (async () => true))(m);
    },
    ensureSocialSchemaReady: async () => {},
    respondWithStrictPersistenceError: () => false,
    prisma: {
      $queryRawUnsafe: async () => [],
      $executeRawUnsafe: async sql => { executed.push(sql); return 1; },
    },
    onboardingProfiles: new Map(), userProfiles: new Map(), friendInvites: new Map(),
    friendships: new Map(), friendRegistry: new Map(), friendEdges: new Map(),
    friendPendingConnections: new Map(), safetyBlocks: new Map(), safetySuspensions: new Map(),
    invalidateSuspensionCache: () => {},
    deleteUnreferencedAccountMedia: async () => ({}),
  });
  vm.runInContext(
    [
      block('// ── Versandbegrenzung fuer Auth-Mails', '/** Build a custom action URL'),
      block('const EMAIL_STYLE =', '\n/**\n * POST /auth/send-password-reset'),
      block('async function verifyFirebaseIdToken(', '\nasync function requireVerifiedUser('),
      block('async function authorizeAccountOwner(', '\nasync function authorizeProfileOwner('),
      routeBlock("app.delete('/api/account/:userId',"),
    ].join('\n'),
    context,
  );

  async function request({ token = 'owner-token', userId = 'uid-1' } = {}) {
    let status = 200;
    let payload;
    const req = {
      headers: token === null ? {} : { authorization: `Bearer ${token}` },
      params: { userId },
      query: {},
    };
    const res = {
      status(code) { status = code; return res; },
      json(value) { payload = value; return res; },
    };
    await handlers.get('DELETE /api/account/:userId')[0](req, res, () => {});
    return { status, body: JSON.parse(JSON.stringify(payload ?? {})) };
  }
  return { request, sent: mail.sent, executed };
}

test('deleting an account deletes the data and then sends the confirmation mail', async () => {
  const f = routeFixture();
  const result = await f.request();
  assert.equal(result.status, 200);
  assert.equal(result.body.ok, true);
  assert.equal(result.body.deleted.confirmationEmail, 'sent');
  assert.ok(f.executed.length > 10, 'data deletion statements ran');
  assert.equal(f.sent.length, 1);
  assert.equal(f.sent[0].to, 'mama@example.com');
});

test('a failing mail provider never makes the deletion fail', async () => {
  const f = routeFixture({ provider: async () => { throw new Error('mail down'); } });
  const result = await f.request();
  assert.equal(result.status, 200);
  assert.equal(result.body.ok, true);
  assert.equal(result.body.deleted.confirmationEmail, 'failed');
  assert.ok(f.executed.length > 10);
});

test('if the address cannot be looked up the deletion still succeeds without mail', async () => {
  const f = routeFixture({ getUserError: new Error('firebase unavailable') });
  const result = await f.request();
  assert.equal(result.status, 200);
  assert.equal(result.body.deleted.confirmationEmail, 'skipped');
  assert.equal(f.sent.length, 0);
});

test('only the owner can delete: other accounts and missing tokens get no mail', async () => {
  const f = routeFixture();
  assert.equal((await f.request({ userId: 'someone-else' })).status, 403);
  assert.equal((await f.request({ token: null })).status, 401);
  assert.equal(f.sent.length, 0);
  assert.equal(f.executed.length, 0);
});
