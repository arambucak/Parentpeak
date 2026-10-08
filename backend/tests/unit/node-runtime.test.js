const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');
const { requirePinnedNode } = require('../../node_runtime.cjs');
const manifest = require('../../package.json');
const lock = require('../../package-lock.json');

test('backend pin and manifest agree on Node 24 with unchanged dependency entries', () => {
  assert.equal(fs.readFileSync(path.join(__dirname, '../../.node-version'), 'utf8').trim(), '24.21.0');
  assert.equal(manifest.engines.node, '>=24.0.0 <25.0.0');
  assert.deepEqual(lock.packages[''].engines, manifest.engines);
  assert.equal(lock.packages['node_modules/prisma'].version, '7.8.0');
  assert.equal(lock.packages['node_modules/nodemailer'].version, '10.0.16');
});

test('exact pinned runtime is accepted but other patches and majors fail closed', () => {
  assert.equal(requirePinnedNode('24.21.0'), '24.21.0');
  for (const version of ['24.14.1', '24.22.0', '26.11.1', '22.23.3']) {
    assert.throws(() => requirePinnedNode(version), /Backend requires Node 24\.21\.0/);
  }
});

test('build, pre-deploy and start all verify the pin before their operations', () => {
  for (const hook of ['preinstall', 'premigrate:deploy', 'prestart']) {
    assert.equal(manifest.scripts[hook], 'node node_runtime.cjs');
  }
  assert.equal(manifest.scripts.postinstall, 'prisma generate');
  assert.equal(manifest.scripts['migrate:deploy'], 'prisma migrate deploy');
  assert.equal(manifest.scripts.start, 'node server.js');
});

test('runtime check uses the actual test process and never an environment version claim', () => {
  const result = spawnSync(process.execPath, [path.join(__dirname, '../../node_runtime.cjs')], {
    encoding: 'utf8', env: { ...process.env, NODE_VERSION: '26.11.1' },
  });
  if (process.versions.node === '24.21.0') {
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /Backend Node runtime verified: 24\.21\.0/);
  } else {
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /Backend requires Node 24\.21\.0/);
  }
});

test('CI selects the backend version file and checks runtime before restoring dependencies', () => {
  const workflow = fs.readFileSync(path.join(__dirname, '../../../.github/workflows/flutter-analyze.yml'), 'utf8');
  assert.match(workflow, /node-version-file: backend\/\.node-version/);
  const verify = workflow.indexOf('run: node backend/node_runtime.cjs');
  const restore = workflow.indexOf('run: npm ci --prefix backend');
  assert.ok(verify >= 0 && restore > verify);
});
