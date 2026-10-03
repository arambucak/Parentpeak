const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

// resilientEventFindMany + Hilfsfunktionen aus server.js extrahieren.
const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
function block(marker) {
  const start = source.indexOf(marker);
  assert.ok(start >= 0, `marker not found: ${marker}`);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}
const selectConst = (() => {
  const start = source.indexOf('const EVENT_SCALAR_SELECT_WITHOUT_AGE_GROUPS');
  return source.slice(start, source.indexOf('};', start) + 2);
})();

function load(prismaMock) {
  const context = { prisma: prismaMock, console: { error() {} } };
  vm.createContext(context);
  vm.runInContext(selectConst, context);
  vm.runInContext(block('function isMissingAgeGroupsColumnError('), context);
  vm.runInContext(block('async function resilientEventFindMany('), context);
  return context;
}

test('Happy Path: reicht Ergebnisse unverändert durch', async () => {
  let seenArgs;
  const ctx = load({
    event: {
      findMany: async args => { seenArgs = args; return [{ id: 'e1', ageGroups: ['toddler'] }]; },
    },
  });
  const rows = await ctx.resilientEventFindMany({ where: { status: 'upcoming' } });
  assert.equal(rows.length, 1);
  assert.deepEqual([...rows[0].ageGroups], ['toddler']);
  assert.deepEqual(seenArgs, { where: { status: 'upcoming' } });
});

test('Fallback: fehlende ageGroups-Spalte wird abgefangen und [] ergänzt', async () => {
  const argsLog = [];
  let call = 0;
  const ctx = load({
    event: {
      findMany: async args => {
        argsLog.push(args);
        call += 1;
        if (call === 1) {
          throw new Error(
            'The column `Event.ageGroups` does not exist in the current database.',
          );
        }
        // Zweiter Aufruf: Fallback mit explizitem select, ohne ageGroups.
        return [{ id: 'e1', title: 'X', participants: [] }];
      },
    },
  });
  const rows = await ctx.resilientEventFindMany({
    where: { status: 'upcoming' },
    include: { participants: true },
  });
  assert.equal(call, 2, 'muss genau einmal erneut versuchen');
  assert.deepEqual([...rows[0].ageGroups], []);
  // Fallback muss include durch select ersetzt haben (Prisma-Ausschluss).
  const fallbackArgs = argsLog[1];
  assert.equal(fallbackArgs.include, undefined);
  assert.ok(fallbackArgs.select, 'select muss gesetzt sein');
  assert.equal(fallbackArgs.select.participants, true, 'Relation bleibt erhalten');
  assert.equal(fallbackArgs.select.ageGroups, undefined, 'ageGroups darf nicht selektiert werden');
  assert.equal(fallbackArgs.select.id, true);
});

test('andere Fehler werden nicht verschluckt', async () => {
  const ctx = load({
    event: { findMany: async () => { throw new Error('connection refused'); } },
  });
  await assert.rejects(
    () => ctx.resilientEventFindMany({ where: {} }),
    /connection refused/,
  );
});
