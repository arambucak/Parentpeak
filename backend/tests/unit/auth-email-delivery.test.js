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

function emailRouteFixture({ provider = async () => true, firebase = true } = {}) {
  const routes = new Map();
  const sentEmails = [];
  const firebaseAuth = {
    generatePasswordResetLink: async email => {
      if (email === 'missing@example.com') {
        throw Object.assign(new Error('not found'), { code: 'auth/user-not-found' });
      }
      return 'https://firebase.example/action?oobCode=reset&apiKey=public';
    },
    generateEmailVerificationLink: async email => (
      `https://firebase.example/action?oobCode=verify&email=${encodeURIComponent(email)}`
    ),
    verifyIdToken: async token => {
      if (token !== 'valid-id-token') throw new Error('Invalid token');
      return { email: 'parent@example.com', name: 'Parent', email_verified: false };
    },
  };
  const context = vm.createContext({
    app: { post: (route, ...handlers) => routes.set(route, handlers) },
    firebaseAdmin: firebase ? { auth: () => firebaseAuth } : null,
    ACTION_HANDLER_BASE: 'https://parentpeak.example/auth/action',
    buildCustomActionUrl: (_link, mode) => `https://parentpeak.example/auth/action?mode=${mode}&code=abc`,
    buildPasswordResetEmail: url => `<a href="${url}">reset</a>`,
    buildPasswordResetEmailText: url => `reset ${url}`,
    buildVerificationEmail: (name, url) => `<p>${name}</p><a href="${url}">verify</a>`,
    buildVerificationEmailText: (name, url) => `${name} ${url}`,
    sendEmail: async email => {
      sentEmails.push(email);
      return provider(email);
    },
    console: { log() {}, error() {} },
  });
  vm.runInContext(
    [
      block("app.post('/auth/send-password-reset',", '\n/**\n * POST /auth/send-verification-email'),
      routeBlock("app.post('/auth/send-verification-email',"),
    ].join('\n'),
    context,
  );

  async function request(route, { email, token = 'valid-id-token' } = {}) {
    let status = 200;
    let payload;
    const req = {
      body: email === undefined ? {} : { email },
      headers: token ? { authorization: `Bearer ${token}` } : {},
    };
    const res = {
      status(code) { status = code; return res; },
      json(value) { payload = value; return res; },
    };
    await routes.get(route)[0](req, res);
    return { status, body: payload };
  }

  return { request, sentEmails };
}

test('password reset responds only after the email provider accepts delivery', async () => {
  let releaseDelivery;
  const fixture = emailRouteFixture({
    provider: () => new Promise(resolve => { releaseDelivery = resolve; }),
  });
  let settled = false;
  const request = fixture.request('/auth/send-password-reset', {
    email: 'parent@example.com',
  }).then(result => {
    settled = true;
    return result;
  });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(settled, false);
  assert.equal(fixture.sentEmails.length, 1);
  assert.equal(fixture.sentEmails[0].to, 'parent@example.com');
  assert.match(fixture.sentEmails[0].text, /reset/);
  releaseDelivery(true);
  assert.equal((await request).status, 200);
});

test('password reset reports provider/configuration failures so the app can fallback', async () => {
  const unavailable = emailRouteFixture({ provider: async () => false });
  assert.equal(
    (await unavailable.request('/auth/send-password-reset', {
      email: 'parent@example.com',
    })).status,
    503,
  );

  const unconfigured = emailRouteFixture({ firebase: false });
  assert.equal(
    (await unconfigured.request('/auth/send-password-reset', {
      email: 'parent@example.com',
    })).status,
    503,
  );

  const providerError = emailRouteFixture({
    provider: async () => { throw new Error('mail provider unavailable'); },
  });
  assert.equal(
    (await providerError.request('/auth/send-password-reset', {
      email: 'parent@example.com',
    })).status,
    503,
  );
});

test('password reset keeps account existence private', async () => {
  const fixture = emailRouteFixture();
  const known = await fixture.request('/auth/send-password-reset', {
    email: 'parent@example.com',
  });
  const unknown = await fixture.request('/auth/send-password-reset', {
    email: 'missing@example.com',
  });
  assert.equal(known.status, 200);
  assert.deepEqual(unknown, known);
  assert.equal(fixture.sentEmails.length, 1);
});

test('verification email requires a valid Firebase token and confirms actual delivery', async () => {
  const fixture = emailRouteFixture({ provider: async () => false });
  assert.equal(
    (await fixture.request('/auth/send-verification-email', {
      token: null,
    })).status,
    400,
  );
  assert.equal(
    (await fixture.request('/auth/send-verification-email', {
      token: 'invalid',
    })).status,
    503,
  );
  assert.equal(
    (await fixture.request('/auth/send-verification-email')).status,
    503,
  );
  assert.equal(fixture.sentEmails.length, 1);
  assert.match(fixture.sentEmails[0].text, /Parent/);
});

function writeGuardFixture() {
  const registeredGuards = [];
  const firebaseRequireStart = source.indexOf('const firebaseRequireAuth =');
  const firebaseRequireEnd = source.indexOf('\n// Middleware', firebaseRequireStart);
  const authMiddlewareStart = source.indexOf('async function firebaseAuthMiddleware(');
  const authMiddlewareEnd = source.indexOf('\n// Middleware', authMiddlewareStart);
  const authGuardStart = source.indexOf('  if (!requireAuthForWrites) {');
  const writeGuardStart = source.lastIndexOf('app.use(async (req, res, next) => {', authGuardStart);
  const writeGuardEnd = source.indexOf('\nconst allowedGeminiModels', authGuardStart);
  assert.ok(firebaseRequireStart >= 0 && firebaseRequireEnd > firebaseRequireStart);
  assert.ok(authMiddlewareStart >= 0 && authMiddlewareEnd > authMiddlewareStart);
  assert.ok(writeGuardStart >= 0 && writeGuardEnd > authGuardStart);

  const context = vm.createContext({
    app: { use: guard => registeredGuards.push(guard) },
    process: { env: { FIREBASE_REQUIRE_AUTH: '1' } },
    firebaseAdmin: {
      auth: () => ({
        verifyIdToken: async token => {
          if (token !== 'valid-id-token') throw new Error('Invalid token');
          return { uid: 'user-1' };
        },
      }),
    },
    backendApiToken: 'test-only-token',
    WRITE_METHODS: new Set(['POST', 'PUT', 'PATCH', 'DELETE']),
    requireAuthForWrites: true,
    isWriteRequest: req => ['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method),
    isNoTokenWritePath: reqPath => reqPath === '/auth/send-password-reset' ||
      reqPath.startsWith('/api/account/'),
  });
  vm.runInContext(
    [
      block('async function verifyFirebaseIdToken(', '\nasync function requireVerifiedUser('),
      source.slice(firebaseRequireStart, firebaseRequireEnd),
      source.slice(authMiddlewareStart, authMiddlewareEnd),
      source.slice(writeGuardStart, writeGuardEnd),
    ].join('\n'),
    context,
  );
  assert.equal(registeredGuards.length, 1);
  return [context.firebaseAuthMiddleware, registeredGuards[0]];
}

async function callGuard(guard, { path, token } = {}) {
  let status = 200;
  let continued = false;
  const req = {
    method: 'POST',
    path,
    headers: token ? { authorization: `Bearer ${token}` } : {},
  };
  const res = {
    status(code) { status = code; return res; },
    json() { return res; },
  };
  await guard(req, res, () => { continued = true; });
  return { status, continued };
}

test('anonymous password reset is explicitly allowed through both write auth guards', async () => {
  const [firebaseGuard, writeGuard] = writeGuardFixture();
  for (const guard of [firebaseGuard, writeGuard]) {
    assert.deepEqual(
      await callGuard(guard, { path: '/auth/send-password-reset' }),
      { status: 200, continued: true },
    );
    assert.deepEqual(
      await callGuard(guard, { path: '/api/account/delete-data' }),
      { status: 200, continued: true },
    );
    assert.deepEqual(
      await callGuard(guard, { path: '/auth/send-verification-email' }),
      { status: 401, continued: false },
    );
    assert.deepEqual(
      await callGuard(guard, {
        path: '/auth/send-verification-email',
        token: 'valid-id-token',
      }),
      { status: 200, continued: true },
    );
  }
});

test('auth email templates escape names and links and use clear parent-friendly language', () => {
  const context = vm.createContext({
    URL,
    ACTION_HANDLER_BASE: 'https://parentpeak.example/auth/action',
  });
  vm.runInContext(
    block('const EMAIL_STYLE =', '\n/**\n * POST /auth/send-password-reset'),
    context,
  );
  const verification = context.buildVerificationEmail(
    '<img src=x onerror=alert(1)>',
    'https://example.test/action?one=1&two=2',
  );
  const reset = context.buildPasswordResetEmail(
    'https://example.test/action?one=1&two=2',
  );
  assert.doesNotMatch(verification, /<img src=x/);
  assert.match(verification, /&lt;img/);
  assert.match(verification, /one=1&amp;two=2/);
  assert.match(verification, /Willkommen bei ParentPeak/);
  assert.match(verification, /Eltern-Community/);
  assert.match(reset, /Passwort sicher zurücksetzen/);
  assert.match(reset, /Dein Passwort bleibt unverändert/);
  for (const html of [reset, verification]) {
    assert.match(html, /<html lang="de">/);
    assert.match(html, /src="https:\/\/parentpeak\.example\/auth\/brand-logo\.png"/);
    assert.match(html, /alt="ParentPeak/);
    assert.match(html, /role="presentation"/);
    assert.match(html, /Kopiere diesen Link/);
    assert.doesNotMatch(html, /🌿|<script/);
  }
});

test('generated action links use the configured handler without forwarding redirects', () => {
  const context = vm.createContext({
    URL,
    ACTION_HANDLER_BASE: 'https://parentpeak.example/auth/action?old=1#fragment',
  });
  vm.runInContext(
    block('function buildCustomActionUrl(', '\nconst EMAIL_STYLE ='),
    context,
  );
  const result = new URL(context.buildCustomActionUrl(
    'https://firebase.example/action?oobCode=synthetic-code&apiKey=public&continueUrl=https://untrusted.example',
    'resetPassword',
  ));
  assert.equal(result.origin, 'https://parentpeak.example');
  assert.equal(result.pathname, '/auth/action');
  assert.deepEqual([...result.searchParams], [
    ['mode', 'resetPassword'],
    ['oobCode', 'synthetic-code'],
  ]);
  assert.equal(result.hash, '');
  assert.throws(() => context.buildCustomActionUrl('malformed', 'resetPassword'));
  assert.throws(() => context.buildCustomActionUrl('https://firebase.example', 'resetPassword'));
  assert.throws(() => context.buildCustomActionUrl('https://firebase.example?oobCode=code', 'unknown'));
  context.ACTION_HANDLER_BASE = 'http://public.example/auth/action';
  assert.throws(() => context.buildCustomActionUrl('https://firebase.example?oobCode=code', 'resetPassword'));
});
