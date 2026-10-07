const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const policy = require('../../ai_memory_policy');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
function fixture({ enabled = true, version = policy.MEMORY_CONSENT_VERSION,
  verified = true, onFetch, beforeChildren, failWrite = false, failSettings = false } = {}) {
  const routes = new Map(), calls = [], writes = [];
  let settings = { enabled, consentVersion: version, consentRevision: 'revision-1' };
  const child = { id: 'child-a', userId: 'a', name: 'Ada',
    birthDate: new Date('2022-10-08T00:00:00Z'), gender: 'female',
    memoryItems: [
      { status: 'confirmed', category: 'medical', key: 'eczema', value: 'Ada, born 2022-10-08, needs gentle care' },
      { status: 'archived', category: 'note', key: 'old', value: 'DO NOT SEND' },
    ] };
  const context = {
    ...policy,
    crypto: require('node:crypto'),
    app: Object.fromEntries(['get', 'post', 'put', 'delete'].map(method =>
      [method, (route, handler) => routes.set(`${method}:${route}`, handler)])),
    verifyFirebaseIdToken: async req => ({ uid: req.uid ?? 'a', verified }),
    geminiApiKey: 'fake-not-a-real-key',
    allowedGeminiModels: new Set(['gemini-3.5-flash-lite']),
    getClientIp: () => 'local', checkRateLimit: () => true, checkDailyBudget: () => true,
    aiRateBuckets: {}, aiRateWindowMs: 1, aiRateMax: 1, aiDailyBudget: {}, aiDailyBudgetMax: 1,
    normalizeAppLanguage: language => language ?? 'en',
    buildLanguageInstruction: language => `Respond in ${language}`,
    AbortSignal, console: { warn() {}, error() {} },
    fetch: async (url, options) => {
      calls.push(JSON.parse(options.body));
      if (onFetch) return onFetch({ settings, setSettings: value => { settings = value; }, calls });
      return { ok: true, status: 200, json: async () => ({
        candidates: [{ content: { parts: [{ text: 'Care for [CHILD_1] gently.' }] } }],
      }) };
    },
    prisma: {
      aiMemorySettings: {
        findUnique: async () => {
          if (failSettings) throw new Error('settings read unavailable');
          return settings;
        },
        upsert: async ({ update }) => {
          if (failWrite) throw new Error('write failed');
          settings = { ...settings, ...update };
          writes.push(update);
          return settings;
        },
      },
      aiChildProfile: {
        findMany: async ({ where }) => {
          if (beforeChildren) beforeChildren(settings);
          return where.userId === child.userId && (!where.id || where.id === child.id) ? [child] : [];
        },
        findFirst: async ({ where }) => where.userId === child.userId ? child : null,
        create: async ({ data }) => { writes.push(data); return { id: 'new', ...data }; },
        update: async ({ data }) => { writes.push(data); return { ...child, ...data }; },
      },
      aiMemoryItem: {
        upsert: async ({ create }) => { writes.push(create); return { id: 'new-item', ...create }; },
        findFirst: async ({ where }) => where.child.userId === child.userId ? { id: 'entry', child } : null,
        update: async ({ data }) => { writes.push(data); return { id: 'entry', ...data }; },
      },
    },
  };
  const memoryStart = source.indexOf('const AI_MEMORY_MAX_CONTEXT_CHARS');
  const memoryEnd = source.indexOf('\n/**\n * GET /ai/health', memoryStart);
  assert.ok(memoryStart > 0 && memoryEnd > memoryStart);
  vm.runInNewContext(source.slice(memoryStart, memoryEnd), context);
  const start = source.indexOf("app.post('/ai/generate',");
  const end = source.indexOf('\n});', start) + 4;
  vm.runInNewContext(source.slice(start, end), context);
  return {
    calls, writes, child,
    get settings() { return settings; },
    async request(route = 'post:/ai/generate', body = {}, uid = 'a') {
      let status = 200, response;
      const res = { status(code) { status = code; return res; }, json(value) { response = value; return res; } };
      await routes.get(route)({
        uid, body: { prompt: 'How can we support bedtime?', childProfileId: 'child-a',
          memoryConsentVersion: policy.MEMORY_CONSENT_VERSION, ...body },
        params: { id: 'child-a', itemId: 'entry' }, query: {},
      }, res);
      return { status, body: response };
    },
  };
}

test('completed age changes on the birthday, not six months before', () => {
  assert.equal(policy.completedYears('2022-10-08', new Date('2026-10-07T23:59:59Z')), 3);
  assert.equal(policy.completedYears('2022-10-08', new Date('2026-10-08T00:00:00Z')), 4);
  assert.equal(policy.completedYears('2028-01-01', new Date('2026-10-08')), null);
  assert.equal(policy.completedYears('invalid'), null);
  assert.equal(policy.completedYears(null), null);
  assert.equal(policy.completedYears('', new Date('2026-10-07')), null);
  assert.equal(policy.completedYears('2026-10-07T23:00:00Z', new Date('2026-10-07T01:00:00Z')), 0);
  assert.equal(policy.completedYears('2024-02-29', new Date('2025-02-28')), 0);
  assert.equal(policy.completedYears('2024-02-29', new Date('2025-03-01')), 1);
  const context = policy.buildMemoryContext([{ name: 'Ada', birthDate: new Date('2022-10-08'),
    memoryItems: [] }], new Date('2026-10-07'));
  assert.match(context, /completed age in years: 3/);
  assert.ok(!context.includes('Ada') && !context.includes('2022'));
});

test('stored relative placeholders stay associated with the correct child', () => {
  const children = ['Ada', 'Ben'].map(name => ({ name, memoryItems: [
    { category: 'note', key: 'sleep', value: '[THIS_CHILD] needs support', status: 'confirmed' },
  ] }));
  const text = policy.buildMemoryContext(children);
  assert.match(text, /\[CHILD_1\] needs support/);
  assert.match(text, /\[CHILD_2\] needs support/);
  assert.ok(!text.includes('Ada') && !text.includes('Ben'));
  assert.equal(policy.minimizeMemoryText('Ada Marie and Ada', [{ name: 'Ada' }, { name: 'Ada Marie' }]),
    '[CHILD_2] and [CHILD_1]');
});

test('actual provider body has neutral identity, confirmed values and no name/date/gender', async () => {
  const app = fixture();
  assert.equal((await app.request()).status, 200);
  const body = JSON.stringify(app.calls[0]);
  assert.match(body, /\[CHILD_1\]/);
  assert.match(body, /completed age in years: \d+/);
  assert.match(body, /eczema/);
  for (const forbidden of ['Ada', '2022-10-08', 'female', 'DO NOT SEND']) assert.ok(!body.includes(forbidden));
  assert.equal(app.child.name, 'Ada');
  assert.equal(app.child.memoryItems[0].value, 'Ada, born 2022-10-08, needs gentle care');
  assert.equal(app.writes.length, 0);
});

for (const options of [{ enabled: false }, { version: null }, { version: 'old-version' }, { verified: false }]) {
  test(`memory transfer rejects missing/old consent or authentication ${JSON.stringify(options)}`, async () => {
    const app = fixture(options);
    const result = await app.request();
    assert.ok([401, 403].includes(result.status));
    assert.equal(app.calls.length, 0);
    assert.equal(app.writes.length, 0);
  });
}

test('no request consent cannot inject memory; ordinary chat needs no memory consent', async () => {
  const app = fixture({ enabled: false });
  assert.equal((await app.request('post:/ai/generate', { childProfileId: '', memoryConsentVersion: undefined })).status, 200);
  assert.ok(!JSON.stringify(app.calls[0]).includes('eczema'));
  const blocked = fixture();
  assert.equal((await blocked.request('post:/ai/generate', { memoryConsentVersion: undefined })).status, 403);
  assert.equal(blocked.calls.length, 0);
});

test('owner filter excludes another account child context', async () => {
  const app = fixture();
  assert.equal((await app.request('post:/ai/generate', {}, 'b')).status, 200);
  assert.ok(!JSON.stringify(app.calls[0]).includes('eczema'));
});

test('revocation while context loads prevents even the first provider call', async () => {
  const app = fixture({ beforeChildren: settings => { settings.enabled = false; } });
  assert.equal((await app.request()).status, 403);
  assert.equal(app.calls.length, 0);
});

test('failed server consent lookup blocks provider explicitly rather than falling back silently', async () => {
  const app = fixture({ failSettings: true });
  assert.equal((await app.request()).status, 503);
  assert.equal(app.calls.length, 0);
  assert.equal(app.writes.length, 0);
});

for (const upstreamStatus of [200, 401, 403, 500]) {
  test(`revocation after provider status ${upstreamStatus} blocks result and all retries`, async () => {
    const app = fixture({ onFetch: ({ settings }) => {
      settings.enabled = false;
      return { status: upstreamStatus, ok: upstreamStatus === 200,
        json: async () => ({ candidates: [{ content: { parts: [{ text: 'old private answer' }] } }] }) };
    } });
    const result = await app.request('post:/ai/generate', { useGoogleSearch: true });
    assert.equal(result.status, 403);
    assert.equal(result.body.text, undefined);
    assert.equal(app.calls.length, 1);
  });
}

test('disable/re-enable during a provider call invalidates its unique revision', async () => {
  const app = fixture({ onFetch: ({ settings, setSettings }) => {
    setSettings({ ...settings, enabled: true, consentRevision: 'revision-2' });
    return { status: 200, ok: true, json: async () => ({}) };
  } });
  assert.equal((await app.request()).status, 403);
  assert.equal(app.calls.length, 1);
});

for (const retry of ['auth', 'grounding-error', 'grounding-empty']) {
  test(`permitted ${retry} retry retains minimized payload and consent checks`, async () => {
    const app = fixture({ onFetch: ({ calls }) => {
      const first = calls.length === 1;
      const status = first && retry === 'auth' ? 401 : first && retry === 'grounding-error' ? 500 : 200;
      const text = first && retry === 'grounding-empty' ? '' : 'Support [CHILD_1].';
      return { ok: status === 200, status, json: async () => ({
        candidates: [{ content: { parts: [{ text }] } }],
      }) };
    } });
    assert.equal((await app.request('post:/ai/generate', { useGoogleSearch: retry !== 'auth' })).status, 200);
    assert.equal(app.calls.length, 2);
    for (const body of app.calls) {
      assert.ok(!JSON.stringify(body).includes('Ada'));
      assert.ok(!JSON.stringify(body).includes('2022-10-08'));
    }
  });
}

test('memory withdrawal during name lookup prevents persistent item write', async () => {
  const app = fixture({ beforeChildren: settings => { settings.enabled = false; } });
  assert.equal((await app.request('post:/ai/children/:id/memory',
    { category: 'note', key: 'sleep', value: 'Ada sleeps' })).status, 403);
  assert.equal(app.writes.length, 0);
});

for (const route of ['post:/ai/children', 'put:/ai/children/:id', 'post:/ai/children/:id/memory', 'put:/ai/children/:id/memory/:itemId']) {
  test(`persistent write ${route} requires versioned server and request consent`, async () => {
    const app = fixture({ version: null });
    assert.equal((await app.request(route, { name: 'Ada', category: 'note', key: 'sleep', value: 'Ada sleeps' })).status, 403);
    assert.equal(app.writes.length, 0);
    const requestDenied = fixture();
    assert.equal((await requestDenied.request(route, { memoryConsentVersion: undefined })).status, 403);
    assert.equal(requestDenied.writes.length, 0);
  });
}

test('new child storage never writes the submitted clear name', async () => {
  const app = fixture();
  assert.equal((await app.request('post:/ai/children', { name: 'Ada' })).status, 201);
  assert.equal(app.writes[0].name, '[CHILD_1]');
});

test('confirmed memory storage minimizes known child identity', async () => {
  const app = fixture();
  assert.equal((await app.request('post:/ai/children/:id/memory',
    { category: 'note', key: 'Ada', value: 'ada born 08.10.2022' })).status, 201);
  assert.equal(app.writes[0].key, '[THIS_CHILD]');
  assert.equal(app.writes[0].value, '[THIS_CHILD] born [BIRTH_DATE]');
});

test('old enabled settings are not consent; enable requires version and disable preserves originals', async () => {
  const app = fixture({ version: null });
  assert.equal((await app.request('get:/ai/settings')).body.enabled, false);
  assert.equal((await app.request('put:/ai/settings', { enabled: true, memoryConsentVersion: undefined })).status, 403);
  assert.equal(app.writes.length, 0);
  assert.equal((await app.request('put:/ai/settings', { enabled: true })).body.enabled, true);
  const revision = app.settings.consentRevision;
  assert.equal((await app.request('put:/ai/settings', { enabled: false })).body.enabled, false);
  assert.notEqual(app.settings.consentRevision, revision);
  assert.equal(app.child.name, 'Ada');
});
