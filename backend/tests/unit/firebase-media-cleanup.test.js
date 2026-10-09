const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
const start = source.indexOf('function firebaseStorageObjectFromUrl(');
const end = source.indexOf('async function deleteAccountDataByUserIdPrisma(', start);
assert.ok(start >= 0 && end > start);
const bucketName = 'test-bucket.firebasestorage.app';
const url = object => `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(object)}?alt=media&token=test`;

function fixture(references = []) {
  const deleted = [];
  const context = {
    URL, firebaseStorageBucket: bucketName,
    prisma: { $queryRawUnsafe: async () => references.map(url => ({ url })) },
    localUploadFilenameFromUrl: () => null,
    firebaseAdmin: { storage: () => ({
      bucket: name => {
        assert.equal(name, bucketName);
        return { file: object => ({
          delete: async options => {
            assert.equal(options.ignoreNotFound, true);
            deleted.push(object);
          },
        }) };
      },
    }) },
    console,
  };
  vm.createContext(context);
  vm.runInContext(source.slice(start, end), context);
  return { context, deleted };
}

test('parser accepts scoped treasure paths and flat legacy treasure/event paths', () => {
  const { context } = fixture();
  for (const object of ['treasures/a/photo.jpg', 'treasures/legacy.jpg', 'events/legacy.jpg']) {
    assert.equal(context.firebaseStorageObjectFromUrl(url(object)), object);
  }
});

test('parser supports both Google Storage URL forms for scoped treasures', () => {
  const { context } = fixture();
  for (const value of [
    `https://storage.googleapis.com/${bucketName}/treasures/a/photo.jpg`,
    `https://${bucketName}.storage.googleapis.com/treasures/a/photo.jpg`,
  ]) {
    assert.equal(context.firebaseStorageObjectFromUrl(value), 'treasures/a/photo.jpg');
  }
});

test('parser rejects foreign bucket, unsupported folders and traversal/nesting', () => {
  const { context } = fixture();
  for (const object of [
    'profiles/a/photo.jpg', 'treasures/a/nested/photo.jpg',
    'events/a/photo.jpg', 'treasures/a/../photo.jpg', 'treasures/a/',
  ]) {
    assert.equal(context.firebaseStorageObjectFromUrl(url(object)), null);
  }
  assert.equal(context.firebaseStorageObjectFromUrl(
    url('treasures/a/photo.jpg').replace(bucketName, 'foreign-bucket')), null);
});

test('cleanup deletes scoped own and legacy media, deduplicating URLs', async () => {
  const { context, deleted } = fixture();
  const result = await context.deleteUnreferencedAccountMedia([
    url('treasures/a/photo.jpg'), url('treasures/legacy.jpg'),
    url('events/legacy.jpg'), url('treasures/a/photo.jpg'),
  ], 'a');
  assert.deepEqual(deleted, ['treasures/a/photo.jpg', 'treasures/legacy.jpg', 'events/legacy.jpg']);
  assert.equal(result.removedFirebaseObjects, 3);
});

test('cleanup preserves scoped and legacy objects still referenced elsewhere', async () => {
  const refs = [url('treasures/a/photo.jpg'), url('treasures/legacy.jpg')];
  const { context, deleted } = fixture(refs);
  const result = await context.deleteUnreferencedAccountMedia([
    ...refs, url('treasures/a/unreferenced.jpg'),
  ], 'a');
  assert.deepEqual(deleted, ['treasures/a/unreferenced.jpg']);
  assert.equal(result.removedFirebaseObjects, 1);
});

test('cleanup cannot delete another UID folder via a stored foreign URL', async () => {
  const { context, deleted } = fixture();
  const result = await context.deleteUnreferencedAccountMedia([
    url('treasures/b/foreign.jpg'), url('treasures/a/own.jpg'),
  ], 'a');
  assert.deepEqual(deleted, ['treasures/a/own.jpg']);
  assert.equal(result.removedFirebaseObjects, 1);
});
