const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');

// vm.runInContext erzeugt Objekte in einem anderen Realm; deepEqual vergleicht
// dann Prototyp-Identitaet. Ein JSON-Roundtrip normalisiert in den Test-Realm.
const plain = value => JSON.parse(JSON.stringify(value));

function extract(name) {
  const start = source.indexOf(`async function ${name}(`);
  assert.ok(start >= 0, `Missing function ${name}`);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

// Baut einen isolierten Kontext für getParentMatchingInterestIds. Die
// Mutual-Logik selbst wird gemockt (eigene Tests decken sie ab); hier geht es
// nur darum, dass outgoing = eigene offene likes OHNE die matched-Menge ist
// und matched korrekt durchgereicht wird.
function fixture({ myActions, mutual }) {
  const context = vm.createContext({
    // Geteilte Realm-Globals, damit im vm erzeugte Arrays/Objekte von
    // assert.deepEqual als strukturgleich akzeptiert werden.
    Array, Object, Set, Map, Promise,
    ensureParentMatchingSchemaReady: async () => {},
    latestActionByProfile: actions => {
      const latest = new Map();
      for (const a of actions) if (!latest.has(a.profileId)) latest.set(a.profileId, a.action);
      return latest;
    },
    getMutualConnectionProfileIds: async () => mutual,
    prisma: {
      parentMatchingProfile: {
        findMany: async () => [{ id: 'own-1' }],
      },
      parentMatchingAction: {
        findMany: async () => myActions,
      },
    },
  });
  vm.runInContext(extract('getParentMatchingInterestIds'), context);
  return context;
}

test('interest splits outgoing (open likes) from matched', async () => {
  const ctx = fixture({
    myActions: [
      { profileId: 'p-matched', action: 'like', createdAt: new Date() },
      { profileId: 'p-open', action: 'like', createdAt: new Date() },
      { profileId: 'p-passed', action: 'pass', createdAt: new Date() },
    ],
    mutual: ['p-matched'],
  });
  const result = await ctx.getParentMatchingInterestIds('fam', 'owner');
  assert.deepEqual(plain(result.matched), ['p-matched']);
  assert.deepEqual(plain(result.outgoing), ['p-open']);
});

test('interest is empty when no own profile exists', async () => {
  const context = vm.createContext({
    Array, Object, Set, Map, Promise,
    ensureParentMatchingSchemaReady: async () => {},
    latestActionByProfile: () => new Map(),
    getMutualConnectionProfileIds: async () => [],
    prisma: {
      parentMatchingProfile: { findMany: async () => [] },
      parentMatchingAction: { findMany: async () => [] },
    },
  });
  vm.runInContext(extract('getParentMatchingInterestIds'), context);
  const result = await context.getParentMatchingInterestIds('fam', 'owner');
  assert.deepEqual(plain(result), { matched: [], outgoing: [] });
});

test('interest is empty when the user has no likes', async () => {
  const ctx = fixture({
    myActions: [{ profileId: 'p1', action: 'pass', createdAt: new Date() }],
    mutual: [],
  });
  const result = await ctx.getParentMatchingInterestIds('fam', 'owner');
  assert.deepEqual(plain(result), { matched: [], outgoing: [] });
});

test('a later pass overrides an earlier like (not outgoing anymore)', async () => {
  const older = new Date(Date.now() - 1000);
  const newer = new Date();
  const ctx = fixture({
    myActions: [
      { profileId: 'p1', action: 'pass', createdAt: newer },
      { profileId: 'p1', action: 'like', createdAt: older },
    ],
    mutual: [],
  });
  const result = await ctx.getParentMatchingInterestIds('fam', 'owner');
  assert.deepEqual(plain(result.outgoing), []);
});
