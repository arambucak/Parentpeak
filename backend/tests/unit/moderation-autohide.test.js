const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');

function extract(name, async = false) {
  const start = source.indexOf(`${async ? 'async ' : ''}function ${name}(`);
  assert.ok(start >= 0, `Missing ${name}`);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

// Isolierter Kontext fuer discoverParentMatchingProfiles. Alle $queryRawUnsafe-
// Aufrufe werden anhand des SQL-Texts beantwortet; scoreParentMatchingCandidates
// wird gemockt und faengt die uebergebenen Argumente auf.
function fixture({ hiddenRows = [], reportedByMeRows = [] } = {}) {
  let scored;
  const candidates = [
    { id: 'p-a', ownerUserId: 'owner-a' },
    { id: 'p-b', ownerUserId: 'owner-b' },
  ];
  const context = {
    Set, Array, Number, Date, process: { env: {} },
    ownFamilyId: uid => `fam-${uid}`,
    getMyParentMatchingProfile: async () => ({ id: 'own', ownerUserId: 'me' }),
    ensureSocialSchemaReady: async () => {},
    prisma: {
      parentMatchingProfile: { findMany: async () => candidates },
      parentMatchingAction: { findMany: async () => [] },
      $queryRawUnsafe: async (sql) => {
        if (sql.includes('SafetyBlock')) return [];
        if (sql.includes('SafetySuspension')) return [];
        if (sql.includes('HAVING COUNT(DISTINCT')) return hiddenRows;
        if (sql.includes('WHERE "reporterUserId"')) return reportedByMeRows;
        return [];
      },
    },
    scoreParentMatchingCandidates: args => { scored = args; return { matches: [] }; },
  };
  vm.createContext(context);
  vm.runInContext(extract('discoverParentMatchingProfiles', true), context);
  return {
    run: () => context.discoverParentMatchingProfiles({ userId: 'me', limit: '10', maxDistanceKm: '25' }),
    hidden: () => [...scored.hiddenOwnerIds],
  };
}

test('profiles reported by >=3 distinct reporters are hidden for everyone', async () => {
  const f = fixture({ hiddenRows: [{ reportedUserId: 'owner-b' }] });
  await f.run();
  assert.deepEqual(f.hidden(), ['owner-b']);
});

test('a profile the user reported themselves is hidden (one-sided)', async () => {
  const f = fixture({ reportedByMeRows: [{ reportedUserId: 'owner-a' }] });
  await f.run();
  assert.deepEqual(f.hidden(), ['owner-a']);
});

test('threshold-hidden and self-reported combine without duplicates', async () => {
  const f = fixture({
    hiddenRows: [{ reportedUserId: 'owner-b' }],
    reportedByMeRows: [{ reportedUserId: 'owner-b' }, { reportedUserId: 'owner-a' }],
  });
  await f.run();
  assert.deepEqual(f.hidden().sort(), ['owner-a', 'owner-b']);
});

test('no reports => nothing hidden', async () => {
  const f = fixture();
  await f.run();
  assert.deepEqual(f.hidden(), []);
});
