const { execFileSync } = require('node:child_process');

const CONTRACT = 'parentpeak-memory-consent-v1';
const MIGRATIONS = [
  '20261006000000_optional_parent_matching_age',
  '20261007000000_ai_memory_consent',
];

function backendTree(ref) {
  if (!/^[a-f0-9]{40}$/.test(ref)) throw new Error('Invalid backend commit identity');
  return execFileSync('git', ['rev-parse', `${ref}:backend`], { encoding: 'utf8' }).trim();
}

function validateEvidence(evidence, releaseSha, tree = backendTree) {
  if (!evidence || evidence.status !== 'ready' ||
      !/^[a-f0-9]{40}$/.test(evidence.commit || '')) {
    throw new Error('Backend release identity is unavailable');
  }
  // Client/docs-only releases can use an older backend with identical sources.
  // This avoids forcing a Render deploy when its root-directory filter skips it.
  if (evidence.commit !== releaseSha && tree(evidence.commit) !== tree(releaseSha)) {
    throw new Error('Live backend sources differ from release backend sources');
  }
  if (evidence.compatibilityVersion !== CONTRACT ||
      evidence.memoryConsentVersion !== 'chat-memory-v1' ||
      !Array.isArray(evidence.migrations) ||
      !MIGRATIONS.every((name) => evidence.migrations.includes(name)) ||
      evidence.schema?.consentVersion !== 'nullable-text' ||
      evidence.schema?.consentRevision !== 'nullable-text') {
    throw new Error('Backend compatibility or schema evidence is insufficient');
  }
}

async function json(fetchImpl, url, options = {}) {
  const response = await fetchImpl(url, {
    ...options,
    redirect: 'error',
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) throw new Error(`Release verification HTTP ${response.status}`);
  return response.json();
}

async function checkRelease({
  repository, sha, token, backendUrl, fetchImpl = fetch, tree = backendTree,
}) {
  if (!/^[\w.-]+\/[\w.-]+$/.test(repository || '') ||
      !/^[a-f0-9]{40}$/.test(sha || '') || !token) {
    throw new Error('Missing valid GitHub release identity or token');
  }
  let base;
  try {
    base = new URL(backendUrl);
  } catch {
    throw new Error('Backend base URL is invalid');
  }
  if (base.protocol !== 'https:' || base.username || base.password ||
      base.search || base.hash) {
    throw new Error('Backend must use a credential-free HTTPS base URL');
  }
  const headers = {
    Authorization: `Bearer ${token}`,
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };
  const api = `https://api.github.com/repos/${repository}`;
  const main = await json(fetchImpl, `${api}/commits/main`, { headers });
  if (main.sha !== sha) throw new Error('Release is not current main');
  const runs = await json(fetchImpl,
    `${api}/actions/workflows/flutter-analyze.yml/runs?head_sha=${sha}&event=push&branch=main&per_page=100`,
    { headers });
  const matching = runs.workflow_runs?.filter((run) =>
    run.head_sha === sha && run.head_branch === 'main' && run.event === 'push');
  const latest = matching?.sort((a, b) => b.id - a.id)[0];
  if (!latest) return { ready: false, reason: 'Waiting for main CI run' };
  if (latest.status !== 'completed') return { ready: false, reason: 'Waiting for main CI completion' };
  if (latest.conclusion !== 'success') throw new Error('Main CI did not succeed');
  const jobs = await json(fetchImpl, `${api}/actions/runs/${latest.id}/jobs?filter=latest&per_page=100`, { headers });
  if (!jobs.jobs?.some((job) => job.name === 'analyze' &&
      job.status === 'completed' && job.conclusion === 'success')) {
    throw new Error('Required analyze job did not succeed');
  }
  const endpoint = `${base.href.replace(/\/$/, '')}/release/readiness`;
  const evidence = await json(fetchImpl, endpoint, {
    headers: { Accept: 'application/json', 'Cache-Control': 'no-cache' },
  });
  validateEvidence(evidence, sha, tree);
  // Re-check main after remote evidence to reject a superseded release.
  const current = await json(fetchImpl, `${api}/commits/main`, { headers });
  if (current.sha !== sha) throw new Error('Release was superseded during verification');
  return { ready: true, backendCommit: evidence.commit };
}

async function waitForRelease(options, {
  attempts = 60,
  sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
  log = console.log,
} = {}) {
  for (let i = 0; i < attempts; i++) {
    const result = await checkRelease(options);
    if (result.ready) {
      log(`Release verified: ${options.sha}; backend: ${result.backendCommit}`);
      return result;
    }
    log(result.reason);
    if (i + 1 < attempts) await sleep(20000);
  }
  throw new Error('Timed out waiting for successful main CI');
}

if (require.main === module) {
  if (process.env.GITHUB_REF !== 'refs/heads/main') {
    console.error('Pages release is restricted to main');
    process.exitCode = 1;
  } else {
    waitForRelease({
      repository: process.env.GITHUB_REPOSITORY,
      sha: process.env.GITHUB_SHA,
      token: process.env.GITHUB_TOKEN,
      backendUrl: process.env.BACKEND_BASE_URL || 'https://parentpeak.onrender.com',
    }).catch((error) => {
      // Never log URLs, headers, response bodies or tokens.
      console.error(`Pages release blocked: ${error.message.replace(/https?:\/\/\S+/g, '[URL]')}`);
      process.exitCode = 1;
    });
  }
}

module.exports = { validateEvidence, checkRelease, waitForRelease };
