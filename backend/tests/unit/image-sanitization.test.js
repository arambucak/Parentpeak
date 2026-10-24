const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const express = require('express');
const multer = require('multer');
const sharp = require('sharp');
const { publishSanitizedImage, allowPublicImage, InvalidImageError } = require('../../image_upload');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
function block(start, end) {
  const a = source.indexOf(start), b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, start);
  return source.slice(a, b);
}

async function image(format = 'png') {
  return sharp({ create: { width: 3, height: 2, channels: 4, background: '#ff0000' } })
    .toFormat(format).toBuffer();
}

async function fixture(t, { configured = true, publish = publishSanitizedImage } = {}) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'pp-image-sanitize-'));
  const app = express();
  const context = vm.createContext({
    __dirname: directory, app, multer, express, fs, path, crypto,
    publishSanitizedImage: publish, allowPublicImage, InvalidImageError,
    console: { error() {} }, process: { env: { PUBLIC_BASE_URL: 'https://images.example' } },
    firebaseAdmin: configured ? { auth: () => ({
      verifyIdToken: async token => {
        if (token === 'unavailable') throw Object.assign(new Error('Unavailable'), { code: 'app/network-error' });
        if (token !== 'a') throw new Error('Invalid token');
        return { uid: 'a' };
      },
    }) } : null,
  });
  vm.runInContext([
    block('// Multer for image uploads', '\nconst databaseUrl'),
    block('async function verifyFirebaseIdToken(', 'function resolveVerifiedUserId('),
    block("app.use('/uploads',", '// MEAL PLANNER / ESSENSPLANER ENDPOINTS'),
  ].join('\n'), context);
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(async () => {
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
    fs.rmSync(directory, { recursive: true, force: true });
  });
  const base = `http://127.0.0.1:${server.address().port}`;
  const uploads = path.join(directory, 'uploads');
  const temporary = path.join(directory, '.upload-tmp');
  async function upload(bytes, { token = 'a', filename = 'camera.png', mime = 'image/png', query = '' } = {}) {
    const body = new FormData();
    body.append('image', new Blob([bytes], { type: mime }), filename);
    const response = await fetch(`${base}/uploads/image${query}`, {
      method: 'POST', body, headers: token === null ? {} : { Authorization: `Bearer ${token}` },
    });
    return { status: response.status, body: await response.json() };
  }
  return { base, upload, uploads, temporary };
}

for (const token of [null, 'invalid', 'shared', 'unavailable']) {
  test(`upload token ${token} rejected before parsing/storage`, async t => {
    const f = await fixture(t);
    const result = await f.upload(Buffer.from('not an image'), { token });
    assert.equal(result.status, token === 'unavailable' ? 503 : 401);
    assert.deepEqual(fs.readdirSync(f.uploads), []);
    assert.deepEqual(fs.readdirSync(f.temporary), []);
  });
}
test('missing Firebase configuration never permits an upload', async t => {
  const f = await fixture(t, { configured: false });
  assert.equal((await f.upload(await image())).status, 401);
  assert.deepEqual(fs.readdirSync(f.temporary), []);
});
test('foreign query actor is rejected before multipart parsing', async t => {
  const f = await fixture(t);
  assert.equal((await f.upload(await image(), { query: '?userId=b' })).status, 403);
  assert.deepEqual(fs.readdirSync(f.temporary), []);
  assert.deepEqual(fs.readdirSync(f.uploads), []);
});

for (const format of ['jpeg', 'png', 'webp', 'gif']) {
  test(`${format} is decoded and published with canonical server extension, not original filename`, async t => {
    const f = await fixture(t);
    const result = await f.upload(await image(format), {
      filename: 'untrusted.html', mime: 'image/png',
    });
    assert.equal(result.status, 201);
    const extension = format === 'jpeg' ? 'jpg' : format;
    assert.match(result.body.filename, new RegExp(`^sanitized-[a-f0-9]{32}\\.${extension}$`));
    assert.equal(result.body.url, `https://images.example/uploads/${result.body.filename}`);
    const stored = fs.readFileSync(path.join(f.uploads, result.body.filename));
    assert.equal(result.body.size, stored.length);
    const metadata = await sharp(stored).metadata();
    assert.equal(metadata.format, format);
    assert.equal(metadata.width, 3);
    assert.equal(metadata.height, 2);
    assert.equal(metadata.exif, undefined);
    assert.deepEqual(fs.readdirSync(f.temporary), []);
    const served = await fetch(`${f.base}/uploads/${result.body.filename}`);
    assert.equal(served.status, 200);
    assert.equal(served.headers.get('content-type'), `image/${format}`);
    assert.equal(served.headers.get('x-content-type-options'), 'nosniff');
    assert.match(served.headers.get('content-security-policy'), /sandbox/);
    assert.deepEqual(Buffer.from(await served.arrayBuffer()), stored);
    const head = await fetch(`${f.base}/uploads/${result.body.filename}`, { method: 'HEAD' });
    assert.equal(head.status, 200);
  });
}

test('real EXIF/GPS and profile removed, orientation applied before publication', async t => {
  const f = await fixture(t);
  const original = await sharp(await image('jpeg'))
    .withMetadata({ orientation: 6 })
    .withExifMerge({
      IFD0: { Make: 'SyntheticDevice', Model: 'SyntheticCamera' },
      IFD3: {
        GPSLatitudeRef: 'N', GPSLatitude: '52/1 31/1 0/1',
        GPSLongitudeRef: 'E', GPSLongitude: '13/1 24/1 0/1',
      },
    }).toBuffer();
  const before = await sharp(original).metadata();
  assert.equal(before.orientation, 6);
  assert.ok(before.exif.includes(Buffer.from('SyntheticDevice')));
  // The GPS IFD pointer (0x8825) proves this is GPS-bearing EXIF, not just a label.
  assert.ok(before.exif.includes(Buffer.from([0x25, 0x88])));
  assert.ok(before.icc);
  const result = await f.upload(original, { filename: 'camera.jpg', mime: 'image/jpeg' });
  assert.equal(result.status, 201);
  const stored = fs.readFileSync(path.join(f.uploads, result.body.filename));
  const after = await sharp(stored).metadata();
  for (const key of ['exif', 'icc', 'xmp', 'iptc', 'orientation']) {
    assert.equal(after[key], undefined, key);
  }
  assert.equal(after.width, 2);
  assert.equal(after.height, 3);
  assert.equal(stored.includes(Buffer.from('SyntheticDevice')), false);
});
for (const format of ['png', 'webp']) {
  test(`${format} keeps real transparency after sanitization`, async t => {
    const f = await fixture(t);
    const pixels = Buffer.from([255, 0, 0, 0, 0, 0, 255, 128]);
    const original = await sharp(pixels, { raw: { width: 2, height: 1, channels: 4 } })
      .toFormat(format, { lossless: true }).toBuffer();
    const result = await f.upload(original, { mime: `image/${format}` });
    assert.equal(result.status, 201);
    const stored = fs.readFileSync(path.join(f.uploads, result.body.filename));
    const decoded = await sharp(stored).ensureAlpha().raw().toBuffer();
    assert.equal(decoded[3], 0);
    assert.equal(decoded[7], 128);
  });
}

for (const format of ['gif', 'webp']) {
  test(`animated ${format} keeps frames and timing without original comments/metadata`, async t => {
    const f = await fixture(t);
    const pixels = Buffer.alloc(2 * 4 * 4);
    for (let i = 0; i < pixels.length; i += 4) {
      pixels[i + (i < 16 ? 0 : 2)] = 255;
      pixels[i + 3] = 255;
    }
    let original = await sharp(pixels, {
      raw: { width: 2, height: 4, channels: 4, pageHeight: 2 },
    }).toFormat(format, { delay: [100, 200], loop: 0 }).toBuffer();
    if (format === 'gif') {
      const comment = Buffer.from('SyntheticCameraGPS');
      original = Buffer.concat([
        original.subarray(0, -1), Buffer.from([0x21, 0xfe, comment.length]),
        comment, Buffer.from([0, 0x3b]),
      ]);
    }
    const before = await sharp(original, { animated: true }).metadata();
    assert.equal(before.pages, 2);
    const result = await f.upload(original, { mime: `image/${format}` });
    assert.equal(result.status, 201);
    const stored = fs.readFileSync(path.join(f.uploads, result.body.filename));
    const after = await sharp(stored, { animated: true }).metadata();
    assert.equal(after.pages, 2);
    assert.deepEqual(after.delay, before.delay);
    assert.equal(after.loop, before.loop);
    assert.equal(stored.includes(Buffer.from('SyntheticCameraGPS')), false);
  });
}

for (const bytes of [
  Buffer.from('<html><script>synthetic</script></html>'),
  Buffer.from('<svg xmlns="http://www.w3.org/2000/svg" width="2" height="2"><rect width="2" height="2"/></svg>'),
  Buffer.from('corrupt bytes'),
]) {
  test('spoofed/unsupported content never becomes public and temp input is removed', async t => {
    const f = await fixture(t);
    const result = await f.upload(bytes, { filename: 'photo.html' });
    assert.equal(result.status, 400);
    assert.deepEqual(fs.readdirSync(f.uploads), []);
    assert.deepEqual(fs.readdirSync(f.temporary), []);
  });
}
test('pixel limit and truncated image fail closed', async t => {
  const f = await fixture(t);
  const huge = await sharp({ create: { width: 6400, height: 6400, channels: 3, background: 'red' } })
    .png().toBuffer();
  for (const bytes of [huge, (await image('jpeg')).subarray(0, 80)]) {
    assert.equal((await f.upload(bytes)).status, 400);
    assert.deepEqual(fs.readdirSync(f.uploads), []);
    assert.deepEqual(fs.readdirSync(f.temporary), []);
  }
});
test('exactly 10 MiB input is accepted but only decoded pixels are published', async t => {
  const f = await fixture(t);
  const png = await image();
  const marker = Buffer.from('<html>SyntheticAppendedMetadata</html>');
  const bytes = Buffer.concat([png, marker, Buffer.alloc(10 * 1024 * 1024 - png.length - marker.length)]);
  const result = await f.upload(bytes);
  assert.equal(result.status, 201);
  const stored = fs.readFileSync(path.join(f.uploads, result.body.filename));
  assert.ok(stored.length < bytes.length);
  assert.equal(stored.includes(marker), false);
});
test('publication IO error is 500, not success or invalid-input response; raw file is removed', async t => {
  const f = await fixture(t, {
    publish: (file) => publishSanitizedImage(file, path.join('missing-parent', 'missing-directory')),
  });
  const result = await f.upload(await image());
  assert.equal(result.status, 500);
  assert.equal(result.body.url, undefined);
  assert.equal(result.body.error, 'Bild konnte nicht gespeichert werden');
  assert.deepEqual(fs.readdirSync(f.temporary), []);
});
test('original never enters public directory while decoding is pending', async t => {
  let release, observed;
  const seen = new Promise(resolve => { observed = resolve; });
  const pending = new Promise(resolve => { release = resolve; });
  const f = await fixture(t, { publish: async (file, dir) => {
    observed(file);
    await pending;
    return publishSanitizedImage(file, dir);
  } });
  const request = f.upload(await image(), { filename: 'camera.html' });
  const file = await seen;
  assert.equal(path.dirname(file.path), f.temporary);
  assert.match(file.filename, /^[a-f0-9]{32}\.tmp$/);
  assert.deepEqual(fs.readdirSync(f.uploads), []);
  const probe = await fetch(`${f.base}/uploads/${file.filename}`);
  assert.equal(probe.status, 404);
  release();
  assert.equal((await request).status, 201);
});
test('legacy active extensions, directories and traversal are not served; legacy images remain', async t => {
  const f = await fixture(t);
  fs.writeFileSync(path.join(f.uploads, 'legacy.html'), '<html>synthetic</html>');
  fs.writeFileSync(path.join(f.uploads, 'legacy.svg'), '<svg/>');
  fs.writeFileSync(path.join(f.uploads, 'legacy.png'), await image());
  for (const name of ['legacy.html', 'legacy.svg', 'legacy%2ehtml', '.hidden.png', 'nested/image.png', '']) {
    const response = await fetch(`${f.base}/uploads/${name}`);
    assert.equal(response.status, 404, name);
  }
  assert.equal((await fetch(`${f.base}/uploads/legacy.png`)).status, 200);
});
