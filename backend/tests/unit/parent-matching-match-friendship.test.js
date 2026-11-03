const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');

function extract(name) {
  const start = source.indexOf(`async function ${name}(`);
  assert.ok(start >= 0, `Missing ${name}`);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

function fixture({ blocked = false } = {}) {
  const execCalls = [];
  const context = {
    console: { error() {} },
    ensureSocialSchemaReady: async () => {},
    isBlockedBetween: async () => blocked,
    pairKey: (a, b) => [a, b].sort(),
    prisma: {
      $executeRawUnsafe: async (sql, ...args) => {
        execCalls.push({ sql, args });
        return 1;
      },
    },
  };
  vm.createContext(context);
  vm.runInContext(extract('ensureMatchFriendship'), context);
  return { context, execCalls };
}

test('creates an accepted friendship for a mutual match', async () => {
  const f = fixture();
  await f.context.ensureMatchFriendship('owner', 'other');
  assert.equal(f.execCalls.length, 1);
  assert.match(f.execCalls[0].sql, /INSERT INTO "Friendship"/);
  assert.match(f.execCalls[0].sql, /'accepted'/);
  // pairKey sortiert: low=other, high=owner
  assert.deepEqual(f.execCalls[0].args, ['other', 'owner', 'owner']);
});

test('does nothing when the two are blocked', async () => {
  const f = fixture({ blocked: true });
  await f.context.ensureMatchFriendship('owner', 'other');
  assert.equal(f.execCalls.length, 0);
});

test('ignores self-match and empty ids', async () => {
  const f = fixture();
  await f.context.ensureMatchFriendship('owner', 'owner');
  await f.context.ensureMatchFriendship('owner', '');
  await f.context.ensureMatchFriendship('', 'other');
  assert.equal(f.execCalls.length, 0);
});

test('swallows persistence errors (match must not fail on chat setup)', async () => {
  const context = {
    console: { error() {} },
    ensureSocialSchemaReady: async () => {},
    isBlockedBetween: async () => false,
    pairKey: (a, b) => [a, b].sort(),
    prisma: {
      $executeRawUnsafe: async () => { throw new Error('db down'); },
    },
  };
  vm.createContext(context);
  vm.runInContext(extract('ensureMatchFriendship'), context);
  // Darf nicht werfen.
  await context.ensureMatchFriendship('owner', 'other');
  assert.ok(true);
});
