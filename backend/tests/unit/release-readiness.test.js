const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { releaseReadiness, REQUIRED_MIGRATIONS } = require('../../release_readiness');

const commit = 'a'.repeat(40);
function database({ missingMigration = false, invalidColumn = false, clientFailure = false } = {}) {
  const queries = [];
  return {
    queries,
    async $queryRawUnsafe(sql) {
      queries.push(sql);
      if (sql.includes('_prisma_migrations')) {
        return REQUIRED_MIGRATIONS.slice(missingMigration ? 1 : 0)
          .map((migration_name) => ({ migration_name }));
      }
      return ['consentVersion', 'consentRevision'].map((column_name) => ({
        column_name, data_type: invalidColumn ? 'integer' : 'text', is_nullable: 'YES',
      }));
    },
    aiMemorySettings: {
      async findFirst(args) {
        assert.deepEqual(args, { select: { consentVersion: true, consentRevision: true } });
        if (clientFailure) throw new Error('Outdated Prisma client');
        return { consentVersion: 'private-version', consentRevision: 'private-revision' };
      },
    },
  };
}

test('readiness verifies migrations, schema and generated client without exposing user values', async () => {
  const db = database();
  const result = await releaseReadiness(db, commit);
  assert.equal(result.status, 'ready');
  assert.equal(result.commit, commit);
  assert.equal(result.compatibilityVersion, 'parentpeak-memory-consent-v1');
  assert.equal(result.memoryConsentVersion, 'chat-memory-v1');
  assert.deepEqual(result.migrations, REQUIRED_MIGRATIONS);
  assert.ok(!JSON.stringify(result).includes('private-'));
  assert.ok(db.queries.every((sql) => sql.trim().startsWith('SELECT')));
  assert.match(db.queries[0], /finished_at IS NOT NULL AND rolled_back_at IS NULL/);
});

test('no known commit fails closed before DB access', async () => {
  const db = database();
  await assert.rejects(releaseReadiness(db, undefined), /commit identity/);
  assert.equal(db.queries.length, 0);
});

for (const scenario of ['missingMigration', 'invalidColumn', 'clientFailure']) {
  test(`${scenario} fails readiness`, async () => {
    await assert.rejects(releaseReadiness(database({ [scenario]: true }), commit));
  });
}

test('readiness route uses Render identity, disables caching and fails with 503', () => {
  const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
  const route = source.slice(source.indexOf("app.get('/release/readiness'"), source.indexOf("app.get('/health'"));
  assert.match(route, /Cache-Control.*no-store/);
  assert.match(route, /process\.env\.RENDER_GIT_COMMIT/);
  assert.match(route, /res\.status\(503\)/);
  assert.ok(!route.includes('req.body'));
});
