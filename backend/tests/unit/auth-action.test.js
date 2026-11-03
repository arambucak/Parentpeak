const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const publicDir = path.join(__dirname, '../../public');
const html = fs.readFileSync(path.join(publicDir, 'auth-action.html'), 'utf8');
const script = fs.readFileSync(path.join(publicDir, 'auth-action.js'), 'utf8');
const server = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');

function fixture({
  mode = 'resetPassword',
  code = 'synthetic-once-only-code',
  verify = async () => 'parent@example.test',
  confirm = async () => {},
  operation = 'VERIFY_EMAIL',
  apply = async () => {},
  sdk = true,
} = {}) {
  const elements = new Map();
  for (const match of html.matchAll(/<([a-z0-9]+)\b([^>]*\bid="([^"]+)"[^>]*)>/g)) {
    const [, tag, attributes, id] = match;
    const element = {
      id,
      hidden: /\bhidden\b/.test(attributes),
      value: '',
      type: attributes.match(/\btype="([^"]+)"/)?.[1],
      disabled: false,
      textContent: '',
      style: {},
      attributes: {},
      listeners: {},
      focused: false,
      focus() { this.focused = true; },
      setAttribute(key, value) { this.attributes[key] = value; },
      getAttribute(key) { return this.attributes[key]; },
      removeAttribute(key) { delete this.attributes[key]; },
      addEventListener(event, handler) { this.listeners[event] = handler; },
    };
    if (tag === 'h1') element.textContent = id;
    elements.set(id, element);
  }
  const toggles = ['new-password', 'confirm-password'].map(id => ({
    attributes: { 'aria-controls': id },
    listeners: {},
    setAttribute(key, value) { this.attributes[key] = value; },
    getAttribute(key) { return this.attributes[key]; },
    addEventListener(event, handler) { this.listeners[event] = handler; },
  }));
  const calls = { verify: [], confirm: [], apply: [], check: [] };
  const auth = {
    async verifyPasswordResetCode(value) {
      calls.verify.push(value);
      return verify(value);
    },
    async confirmPasswordReset(value, password) {
      calls.confirm.push([value, password]);
      return confirm(value, password);
    },
    async checkActionCode(value) {
      calls.check.push(value);
      return { operation };
    },
    async applyActionCode(value) {
      calls.apply.push(value);
      return apply(value);
    },
  };
  let clearedPath;
  const context = vm.createContext({
    URLSearchParams,
    document: {
      getElementById: id => {
        assert.ok(elements.has(id), `Missing DOM element: ${id}`);
        return elements.get(id);
      },
      querySelectorAll: selector => selector === '.visibility-toggle'
        ? toggles
        : [...elements.values()].filter(element => element.id.startsWith('screen-')),
      querySelector: selector => {
        const screen = selector.match(/^#screen-(.+) h1$/)?.[1];
        return screen ? elements.get(`${screen}-title`) : null;
      },
    },
    window: {
      location: {
        pathname: '/auth/action',
        search: `?mode=${mode}&oobCode=${code}&continueUrl=https://untrusted.example`,
      },
      history: { replaceState: (_state, _title, url) => { clearedPath = url; } },
    },
    ...(sdk ? { firebase: { initializeApp() {}, auth: () => auth } } : {}),
  });
  vm.runInContext(script, context);
  return {
    elements, calls, toggles, context,
    get clearedPath() { return clearedPath; },
    async ready() { await new Promise(resolve => setImmediate(resolve)); },
    async submit(password, repeated = password) {
      elements.get('new-password').value = password;
      elements.get('confirm-password').value = repeated;
      await elements.get('reset-form').onsubmit({ preventDefault() {} });
    },
  };
}

test('auth page assets are public, explicitly routed and action responses are private', () => {
  const routes = new Map();
  const start = server.indexOf("app.get('/auth/action',");
  const end = server.indexOf('// ── Branded Email Service', start);
  vm.runInNewContext(server.slice(start, end), {
    app: { get: (route, handler) => routes.set(route, handler) },
    path, publicDir,
  });
  const headers = {};
  let servedFile;
  routes.get('/auth/action')({}, {
    setHeader(key, value) { headers[key] = value; },
    sendFile(file) { servedFile = file; },
  });
  assert.equal(servedFile, path.join(publicDir, 'auth-action.html'));
  assert.equal(headers['Cache-Control'], 'no-store');
  assert.equal(headers['Referrer-Policy'], 'no-referrer');
  assert.match(headers['Content-Security-Policy'], /frame-ancestors 'none'/);
  assert.match(headers['Content-Security-Policy'], /form-action 'none'/);
  assert.doesNotMatch(headers['Content-Security-Policy'], /unsafe-inline/);
  for (const [route, name] of [
    ['/auth/brand-logo.png', 'brand-logo.png'],
    ['/auth/action.css', 'auth-action.css'],
    ['/auth/action.js', 'auth-action.js'],
  ]) {
    routes.get(route)({}, { sendFile(file) { servedFile = file; } });
    assert.equal(servedFile, path.join(publicDir, name));
    assert.ok(fs.statSync(servedFile).size > 0);
    assert.ok(html.includes(`"${route}"`));
  }
  assert.match(html, /name="robots" content="noindex, nofollow"/);
  assert.doesNotMatch(html, /<script[^>]*>[^<\s]/);
});

test('reset verifies the code, clears the URL and validates before submitting', async () => {
  const f = fixture();
  await f.ready();
  assert.equal(f.elements.get('screen-reset').hidden, false);
  assert.equal(f.clearedPath, '/auth/action');
  assert.deepEqual(f.calls.verify, ['synthetic-once-only-code']);
  await f.submit('short');
  assert.equal(f.calls.confirm.length, 0);
  assert.equal(f.elements.get('new-password').attributes['aria-invalid'], 'true');
  await f.submit('a unique long password', 'different');
  assert.equal(f.calls.confirm.length, 0);
  assert.equal(f.elements.get('confirm-password').focused, true);
  await f.submit('a unique long password');
  assert.deepEqual(f.calls.confirm, [['synthetic-once-only-code', 'a unique long password']]);
  assert.equal(f.elements.get('screen-reset-done').hidden, false);
  assert.equal(f.elements.get('new-password').value, '');
  assert.equal(f.elements.get('confirm-password').value, '');
});

test('password visibility toggles do not submit and expose the accessible state', async () => {
  const f = fixture();
  await f.ready();
  for (const toggle of f.toggles) {
    toggle.listeners.click();
    assert.equal(toggle.attributes['aria-pressed'], 'true');
    assert.equal(f.elements.get(toggle.attributes['aria-controls']).type, 'text');
    toggle.listeners.click();
    assert.equal(toggle.attributes['aria-pressed'], 'false');
    assert.equal(f.elements.get(toggle.attributes['aria-controls']).type, 'password');
  }
  assert.equal(f.calls.confirm.length, 0);
});

test('reset reports server policy errors without success and prevents duplicate writes', async () => {
  let reject;
  const f = fixture({ confirm: () => new Promise((_resolve, fail) => { reject = fail; }) });
  await f.ready();
  const submission = f.submit('long enough password');
  assert.equal(f.elements.get('reset-btn').disabled, true);
  await f.submit('long enough password');
  assert.equal(f.calls.confirm.length, 1);
  reject({ code: 'auth/password-does-not-meet-requirements' });
  await submission;
  assert.equal(f.elements.get('screen-reset-done').hidden, true);
  assert.match(f.elements.get('reset-alert').textContent, /Sicherheitsanforderungen/);
  assert.equal(f.elements.get('reset-btn').disabled, false);
});

test('expired, used, malformed and unsupported links never change credentials', async () => {
  for (const errorCode of ['auth/expired-action-code', 'auth/invalid-action-code']) {
    const f = fixture({ verify: async () => { throw { code: errorCode }; } });
    await f.ready();
    assert.equal(f.elements.get('screen-error').hidden, false);
    assert.equal(f.elements.get('screen-reset').hidden, true);
    assert.equal(f.elements.get('retry-btn').hidden, true);
    assert.equal(f.calls.confirm.length, 0);
  }
  for (const options of [{ code: '' }, { mode: 'untrusted' }, { sdk: false }]) {
    const f = fixture(options);
    await f.ready();
    assert.equal(f.elements.get('screen-error').hidden, false);
    assert.equal(f.calls.verify.length, 0);
    assert.equal(f.calls.apply.length, 0);
  }
});

test('network errors can retry the same code after it has left the URL', async () => {
  let attempts = 0;
  const f = fixture({
    verify: async () => {
      if (++attempts === 1) throw { code: 'auth/network-request-failed' };
    },
  });
  await f.ready();
  assert.equal(f.elements.get('retry-btn').hidden, false);
  await f.elements.get('retry-btn').onclick();
  assert.equal(f.elements.get('screen-reset').hidden, false);
  assert.deepEqual(f.calls.verify, ['synthetic-once-only-code', 'synthetic-once-only-code']);
});

test('verification and recovery check action types before applying codes', async () => {
  for (const [mode, operation, done] of [
    ['verifyEmail', 'VERIFY_EMAIL', 'screen-verify-done'],
    ['recoverEmail', 'RECOVER_EMAIL', 'screen-recover-done'],
  ]) {
    const f = fixture({ mode, operation });
    await f.ready();
    if (mode === 'recoverEmail') {
      assert.equal(f.calls.apply.length, 0);
      await f.elements.get('recover-btn').onclick();
    }
    assert.equal(f.elements.get(done).hidden, false);
    assert.deepEqual(f.calls.apply, ['synthetic-once-only-code']);
    const wrongType = fixture({ mode, operation: 'PASSWORD_RESET' });
    await wrongType.ready();
    assert.equal(wrongType.elements.get('screen-error').hidden, false);
    assert.equal(wrongType.calls.apply.length, 0);
  }
});

test('verification and recovery failures never show completion', async () => {
  for (const [mode, operation, done] of [
    ['verifyEmail', 'VERIFY_EMAIL', 'screen-verify-done'],
    ['recoverEmail', 'RECOVER_EMAIL', 'screen-recover-done'],
  ]) {
    const f = fixture({
      mode, operation,
      apply: async () => { throw { code: 'auth/expired-action-code' }; },
    });
    await f.ready();
    if (mode === 'recoverEmail') await f.elements.get('recover-btn').onclick();
    assert.equal(f.elements.get(done).hidden, true);
  }
});
