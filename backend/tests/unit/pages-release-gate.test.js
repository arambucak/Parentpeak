const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { validateEvidence, checkRelease, waitForRelease } = require('../../../scripts/pages_release_gate.cjs');

const sha = 'a'.repeat(40);
const oldSha = 'b'.repeat(40);
const evidence = () => ({
  status: 'ready', commit: sha,
  compatibilityVersion: 'parentpeak-memory-consent-v1',
  memoryConsentVersion: 'chat-memory-v1',
  migrations: ['20261006000000_optional_parent_matching_age', '20261007000000_ai_memory_consent'],
  schema: { consentVersion: 'nullable-text', consentRevision: 'nullable-text' },
});
function fixture({ ci = 'success', backend = evidence(), backendStatus = 200,
  mainSha = sha, secondMain = mainSha, analyze = 'success', runSha = sha } = {}) {
  const calls = [];
  let mainCalls = 0;
  return {
    calls,
    options: {
      repository: 'example/repo', sha, token: 'test-token', backendUrl: 'https://backend.example',
      tree: () => 'same-tree',
      fetchImpl: async (url, options) => {
        calls.push({ url, options });
        let body;
        let status = 200;
        if (url.endsWith('/commits/main')) body = { sha: ++mainCalls === 1 ? mainSha : secondMain };
        else if (url.includes('/workflows/')) body = { workflow_runs: [{
          id: 12, head_sha: runSha, head_branch: 'main', event: 'push',
          status: ci === 'pending' ? 'in_progress' : 'completed', conclusion: ci,
        }] };
        else if (url.includes('/jobs?')) body = { jobs: [
          { name: 'analyze', status: 'completed', conclusion: analyze },
          { name: 'ios-smoke-build', status: 'completed', conclusion: 'skipped' },
        ] };
        else { body = backend; status = backendStatus; }
        return { ok: status === 200, status, json: async () => body };
      },
    },
  };
}

test('passes only exact main CI and matching backend contract', async () => {
  const f = fixture();
  assert.equal((await checkRelease(f.options)).ready, true);
  const request = f.calls.find((call) => call.url.includes('/release/readiness'));
  assert.ok(!request.options.headers.Authorization);
  assert.equal(request.options.redirect, 'error');
});

test('client-only release accepts identical backend tree from older commit', () => {
  validateEvidence({ ...evidence(), commit: oldSha }, sha, () => 'same');
});

test('different backend tree blocks release even with matching compatibility identifier', () => {
  assert.throws(() => validateEvidence({ ...evidence(), commit: oldSha }, sha, (ref) => ref), /sources differ/);
});

for (const field of ['commit', 'compatibilityVersion', 'memoryConsentVersion', 'schema', 'migrations']) {
  test(`missing ${field} fails closed`, () => {
    const body = evidence();
    delete body[field];
    assert.throws(() => validateEvidence(body, sha));
  });
}

test('health-only legacy payload fails closed', () => {
  assert.throws(() => validateEvidence({ status: 'OK' }, sha));
});

for (const config of [
  { ci: 'failure' }, { ci: 'cancelled' }, { analyze: 'skipped' },
  { backendStatus: 404 }, { backendStatus: 503 },
  { mainSha: oldSha }, { secondMain: oldSha },
]) {
  test(`rejects ${JSON.stringify(config)}`, async () => {
    await assert.rejects(checkRelease(fixture(config).options));
  });
}

test('a successful CI run for a different SHA cannot authorize release', async () => {
  const result = await checkRelease(fixture({ runSha: oldSha }).options);
  assert.equal(result.ready, false);
});

test('pending main CI is bounded and never contacts backend', async () => {
  const f = fixture({ ci: 'pending' });
  await assert.rejects(waitForRelease(f.options, {
    attempts: 2, sleep: async () => {}, log: () => {},
  }), /Timed out/);
  assert.ok(!f.calls.some((call) => call.url.includes('/release/readiness')));
});

test('non-HTTPS or credential-bearing backend URLs fail closed', async () => {
  for (const backendUrl of ['http://backend.example', 'https://user:password@backend.example']) {
    const f = fixture();
    await assert.rejects(checkRelease({ ...f.options, backendUrl }));
    assert.equal(f.calls.length, 0);
  }
});

test('workflow gates build and publication and preserves dependabot action upgrades', () => {
  const workflow = fs.readFileSync(path.join(__dirname, '../../../.github/workflows/deploy-web-pages.yml'), 'utf8');
  assert.match(workflow, /actions: read/);
  assert.match(workflow, /build:\n\s+needs: release-gate/);
  assert.match(workflow, /needs: \[release-gate, build\]/);
  assert.equal(workflow.split('run: node scripts/pages_release_gate.cjs').length - 1, 2);
  assert.match(workflow, /actions\/configure-pages@v6/);
  assert.match(workflow, /actions\/deploy-pages@v5/);
});
