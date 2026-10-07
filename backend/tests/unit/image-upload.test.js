const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const http = require('node:http');
const { createRequire } = require('node:module');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const express = require('express');

// Local validation can use an isolated package install without reinstalling
// unrelated backend dependencies. CI uses the normal locked backend package.
const multerPath = process.env.PARENTPEAK_MULTER_TEST_PACKAGE || 'multer';
const multer = require(multerPath);
const multerVersion = require(`${multerPath}/package.json`).version;
const lockedVersion = require('../../package-lock.json').packages['node_modules/multer'].version;
const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
const boundary = 'parentpeak-upload-regression';
const limit = 10 * 1024 * 1024;

function multipart({
  bytes = Buffer.from('image bytes'),
  name = 'image', filename = 'Photo.PNG', mime = 'image/png', fields = [],
  file = true, terminate = true,
} = {}) {
  const chunks = [];
  for (const [field, value] of fields) {
    chunks.push(Buffer.from(
      `--${boundary}\r\nContent-Disposition: form-data; name="${field}"\r\n\r\n${value}\r\n`,
    ));
  }
  if (file) {
    chunks.push(Buffer.from(
      `--${boundary}\r\nContent-Disposition: form-data; name="${name}"; filename="${filename}"\r\nContent-Type: ${mime}\r\n\r\n`,
    ), bytes);
    if (terminate) chunks.push(Buffer.from('\r\n'));
  }
  if (terminate) chunks.push(Buffer.from(`--${boundary}--\r\n`));
  return Buffer.concat(chunks);
}

async function waitUntil(predicate) {
  const deadline = Date.now() + 5000;
  while (!predicate()) {
    if (Date.now() > deadline) throw new Error('Upload regression timed out');
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
}

async function fixture(t, { delayFilename = false } = {}) {
  assert.equal(multerVersion, lockedVersion, 'Run regressions with the patched locked Multer');
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'parentpeak-upload-test-'));
  const streams = [];
  const errors = [];
  let pendingFilename;
  const app = express();
  const diskPath = path.join(path.dirname(require.resolve(multerPath)), 'storage/disk.js');
  const diskRequire = createRequire(diskPath);
  const diskModule = { exports: {} };
  vm.runInNewContext(fs.readFileSync(diskPath, 'utf8'), {
    module: diskModule,
    require: (name) => name === 'fs' ? {
      ...fs,
      createWriteStream(...args) {
        const stream = fs.createWriteStream(...args);
        streams.push(stream);
        return stream;
      },
    } : diskRequire(name),
  }, { filename: diskPath });
  const observedMulter = Object.assign((options) => multer(options), {
    diskStorage: diskModule.exports,
  });
  const context = vm.createContext({
    __dirname: directory,
    multer: observedMulter, path, crypto, app,
    fs: {
      existsSync: fs.existsSync,
      mkdirSync: fs.mkdirSync,
    },
    process: { env: { PUBLIC_BASE_URL: 'https://uploads.example' } },
    observeUpload: (error) => errors.push(error),
    holdFilename: (callback) => { pendingFilename = callback; },
  });
  // Execute the real production configuration and handler, not a copied version.
  const configStart = source.indexOf('// Multer for image uploads');
  const configEnd = source.indexOf('\nconst databaseUrl', configStart);
  assert.ok(configStart >= 0 && configEnd > configStart);
  vm.runInContext(source.slice(configStart, configEnd), context);
  if (delayFilename) {
    vm.runInContext(`
      const originalFilename = multerStorage.getFilename;
      let delayNextFilename = true;
      multerStorage.getFilename = (req, file, callback) => {
        if (!delayNextFilename) return originalFilename(req, file, callback);
        delayNextFilename = false;
        holdFilename(() => originalFilename(req, file, callback));
      };
    `, context);
  }
  vm.runInContext(`
    const originalSingle = upload.single.bind(upload);
    upload.single = (...args) => {
      const middleware = originalSingle(...args);
      return (req, res, next) => middleware(req, res, error => {
        observeUpload(error);
        next(error);
      });
    };
  `, context);
  const routeStart = source.indexOf("app.post('/uploads/image'");
  const routeEnd = source.indexOf('\n});', routeStart) + 4;
  assert.ok(routeStart >= 0 && routeEnd > routeStart);
  vm.runInContext(source.slice(routeStart, routeEnd), context);

  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(async () => {
    server.closeAllConnections();
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
    fs.rmSync(directory, { recursive: true, force: true });
  });
  const port = server.address().port;
  return {
    directory: path.join(directory, 'uploads'), errors, streams,
    async request(body, contentType = `multipart/form-data; boundary=${boundary}`) {
      return new Promise((resolve, reject) => {
        const request = http.request({
          host: '127.0.0.1', port, path: '/uploads/image', method: 'POST',
          headers: { 'Content-Type': contentType, 'Content-Length': body.length },
          timeout: 5000,
        }, (response) => {
          const chunks = [];
          response.on('data', (chunk) => chunks.push(chunk));
          response.on('error', reject);
          response.on('end', () => {
            try {
              resolve({ status: response.statusCode, body: JSON.parse(Buffer.concat(chunks)) });
            } catch (error) { reject(error); }
          });
        });
        request.on('timeout', () => request.destroy(new Error('Upload response timed out')));
        request.on('error', reject);
        request.end(body);
      });
    },
    async abortUpload({ beforeFilename = false } = {}) {
      const previous = errors.length;
      const body = multipart({ bytes: Buffer.alloc(64 * 1024), terminate: false });
      const request = http.request({
        host: '127.0.0.1', port, path: '/uploads/image', method: 'POST',
        headers: {
          'Content-Type': `multipart/form-data; boundary=${boundary}`,
          'Content-Length': body.length + 1024,
        },
      });
      const closed = new Promise((resolve, reject) => {
        request.on('error', (error) => error.code === 'ECONNRESET' ? resolve() : reject(error));
        request.on('close', resolve);
      });
      request.write(body);
      await waitUntil(() => beforeFilename
        ? pendingFilename !== undefined
        : fs.readdirSync(path.join(directory, 'uploads')).length === 1);
      request.destroy();
      await closed;
      await waitUntil(() => errors.length === previous + 1);
      if (beforeFilename) {
        pendingFilename();
        await new Promise((resolve) => setImmediate(resolve));
      }
      await waitUntil(() => (beforeFilename || streams.length > 0) &&
        streams.every((stream) => stream.closed) &&
        fs.readdirSync(path.join(directory, 'uploads')).length === 0);
    },
  };
}

test('valid image preserves 201, URL, filename, size and disk bytes', async (t) => {
  const f = await fixture(t);
  const bytes = Buffer.from('valid image fixture');
  const result = await f.request(multipart({ bytes }));
  assert.equal(result.status, 201);
  assert.match(result.body.filename, /^\d+-[a-f0-9]{12}\.png$/);
  assert.equal(result.body.url, `https://uploads.example/uploads/${result.body.filename}`);
  assert.equal(result.body.size, bytes.length);
  assert.deepEqual(fs.readFileSync(path.join(f.directory, result.body.filename)), bytes);
});

test('all four existing MIME types remain supported', async (t) => {
  const f = await fixture(t);
  for (const [mime, filename] of [
    ['image/jpeg', 'image.jpg'], ['image/png', 'image.png'],
    ['image/webp', 'image.webp'], ['image/gif', 'image.gif'],
  ]) {
    assert.equal((await f.request(multipart({ mime, filename }))).status, 201);
  }
});

test('exactly 10 MiB is accepted by the corrected inclusive size limit', async (t) => {
  const f = await fixture(t);
  const result = await f.request(multipart({ bytes: Buffer.alloc(limit) }));
  assert.equal(result.status, 201);
  assert.equal(result.body.size, limit);
});

test('10 MiB plus one byte is rejected and its partial disk file removed', async (t) => {
  const f = await fixture(t);
  const result = await f.request(multipart({ bytes: Buffer.alloc(limit + 1) }));
  assert.equal(result.status, 400);
  assert.equal(f.errors[0].code, 'LIMIT_FILE_SIZE');
  assert.equal(result.body.error, 'File too large');
  assert.deepEqual(fs.readdirSync(f.directory), []);
});

test('unsupported MIME, wrong file field and missing image keep explicit errors', async (t) => {
  const f = await fixture(t);
  const wrongMime = await f.request(multipart({ mime: 'application/pdf' }));
  assert.equal(wrongMime.status, 400);
  assert.equal(wrongMime.body.error, 'Nur JPEG, PNG, WebP und GIF sind erlaubt');
  assert.equal((await f.request(multipart({ name: 'other' }))).status, 400);
  const missing = await f.request(multipart({ file: false, fields: [['note', 'text']] }));
  assert.equal(missing.status, 400);
  assert.equal(missing.body.error, 'Kein Bild empfangen');
  assert.deepEqual(fs.readdirSync(f.directory), []);
});

test('malformed multipart boundary reports 400 and the handler remains responsive', async (t) => {
  const f = await fixture(t);
  assert.equal((await f.request(Buffer.from('malformed'), 'multipart/form-data')).status, 400);
  assert.deepEqual(fs.readdirSync(f.directory), []);
  assert.equal((await f.request(multipart())).status, 201);
});

test('oversized array indexes are rejected before CPU-heavy field conversion', async (t) => {
  const f = await fixture(t);
  const result = await f.request(multipart({
    fields: [['field[4294967294]', 'value'], ['field[key]', 'value']],
  }));
  assert.equal(result.status, 400);
  assert.equal(f.errors[0].code, 'LIMIT_FIELD_ARRAY_INDEX');
  assert.deepEqual(fs.readdirSync(f.directory), []);
  assert.equal((await f.request(multipart())).status, 201);
});

test('ordinary text metadata remains accepted without unbounded array indexes', async (t) => {
  const f = await fixture(t);
  const result = await f.request(multipart({ fields: [['note', 'optional metadata']] }));
  assert.equal(result.status, 201);
});

test('truncated multipart releases streams, removes files and allows the next upload', async (t) => {
  const f = await fixture(t);
  const result = await f.request(multipart({
    bytes: Buffer.alloc(64 * 1024), terminate: false,
  }));
  assert.equal(result.status, 400);
  assert.ok(f.errors[0]);
  assert.deepEqual(fs.readdirSync(f.directory), []);
  assert.ok(f.streams.length > 0);
  assert.ok(f.streams.every((stream) => stream.closed),
    'Disk descriptors must be closed, not just unlinked');
  assert.equal((await f.request(multipart())).status, 201);
});

test('repeated client aborts remove partial uploads and do not block later uploads', async (t) => {
  const f = await fixture(t);
  for (let i = 0; i < 3; i++) {
    const previous = f.errors.length;
    // Each abort must finish cleanup, not just observe a previous callback.
    await f.abortUpload();
    assert.equal(f.errors.length, previous + 1);
    assert.deepEqual(fs.readdirSync(f.directory), []);
  }
  assert.equal((await f.request(multipart())).status, 201);
});

test('abort before filename assignment leaves no orphan file when storage resumes', async (t) => {
  const f = await fixture(t, { delayFilename: true });
  await f.abortUpload({ beforeFilename: true });
  assert.deepEqual(fs.readdirSync(f.directory), []);
  assert.equal(f.streams.length, 0, 'Aborted file must not open a destination descriptor');
  assert.equal((await f.request(multipart())).status, 201);
});
