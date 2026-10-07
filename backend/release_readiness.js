const { MEMORY_CONSENT_VERSION } = require('./ai_memory_policy');

const REQUIRED_MIGRATIONS = [
  '20261006000000_optional_parent_matching_age',
  '20261007000000_ai_memory_consent',
];
const COMPATIBILITY_VERSION = 'parentpeak-memory-consent-v1';

async function releaseReadiness(prisma, commit) {
  if (!/^[a-f0-9]{40}$/.test(commit || '')) {
    throw new Error('Release commit identity unavailable');
  }
  const migrations = await prisma.$queryRawUnsafe(
    `SELECT migration_name FROM public."_prisma_migrations"
     WHERE migration_name IN ('20261006000000_optional_parent_matching_age',
                              '20261007000000_ai_memory_consent')
       AND finished_at IS NOT NULL AND rolled_back_at IS NULL`,
  );
  if (!REQUIRED_MIGRATIONS.every((name) =>
    migrations.some((row) => row.migration_name === name))) {
    throw new Error('Required release migrations unavailable');
  }
  const columns = await prisma.$queryRawUnsafe(
    `SELECT column_name, data_type, is_nullable
     FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'AiMemorySettings'
       AND column_name IN ('consentVersion', 'consentRevision')`,
  );
  if (!['consentVersion', 'consentRevision'].every((name) =>
    columns.some((row) => row.column_name === name &&
      row.data_type === 'text' && row.is_nullable === 'YES'))) {
    throw new Error('Required consent schema unavailable');
  }
  // Exercise the running generated Prisma client, but return no account data.
  await prisma.aiMemorySettings.findFirst({
    select: { consentVersion: true, consentRevision: true },
  });
  return {
    status: 'ready',
    commit,
    compatibilityVersion: COMPATIBILITY_VERSION,
    memoryConsentVersion: MEMORY_CONSENT_VERSION,
    migrations: REQUIRED_MIGRATIONS,
    schema: { consentVersion: 'nullable-text', consentRevision: 'nullable-text' },
  };
}

module.exports = { releaseReadiness, REQUIRED_MIGRATIONS, COMPATIBILITY_VERSION };
