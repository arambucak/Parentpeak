const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const treasureGeometry = require('../../treasure_geometry');
const { publicTreasure } = require('../../treasure_public_view');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
const item = (id, latitude, shareRadiusKm = 25) => ({
  id, latitude, longitude: 0, shareRadiusKm, category: 'books',
  title: 'A book', status: 'available', createdAt: new Date(2026),
});

function app(rows = [], severe = false) {
  const handlers = {};
  const calls = [];
  let created;
  const context = {
    app: {
      get: (route, handler) => { handlers.get = handler; },
      post: (route, handler) => { handlers.post = handler; },
    },
    treasureGeometry, publicTreasure,
    resolveVerifiedUserId: () => 'owner',
    hasExplicitUserMismatch: () => false,
    isUserSuspended: async () => false,
    isTreasureContentSevere: () => severe,
    console: { error: () => {} },
    prisma: { treasureItem: {
      findMany: async args => {
        calls.push(args);
        return rows.slice(args.skip, args.skip + args.take);
      },
      create: async args => { created = args.data; return { ...args.data, id: 'created' }; },
    } },
  };
  for (const method of ['get', 'post']) {
    const start = source.indexOf(`app.${method}('/api/treasures',`);
    const end = source.indexOf('\n});', start) + 4;
    assert.ok(start >= 0 && end > start);
    vm.runInNewContext(source.slice(start, end), context);
  }
  return {
    calls,
    get created() { return created; },
    async request(method, input = {}) {
      let status = 200, body;
      const res = {
        status(code) { status = code; return res; },
        json(value) { body = value; return res; },
      };
      await handlers[method]({ query: input, body: input, firebaseUid: 'owner' }, res);
      return { status, body };
    },
  };
}

test('real create confirms archived save without claiming availability', async () => {
  const fixture = app([], true);
  const result = await fixture.request('post', {
    title: 'An item', location: 'Test city', latitude: 50, longitude: 8,
  });
  assert.equal(result.status, 201);
  assert.equal(result.body.treasure.status, 'archived');
  assert.equal(result.body.moderation.autoArchivedOnCreate, true);
  assert.equal(fixture.created.status, 'archived');
});

test('coarse geometry preserves public rounding and admits valid zero coordinates', () => {
  assert.deepEqual(treasureGeometry.position(-0.125, 0), { latitude: -0.12, longitude: 0 });
  assert.equal(treasureGeometry.distanceKm(
    { latitude: 50.001, longitude: 8.001 }, { latitude: 50.004, longitude: 8.004 }), 0);
  assert.ok(Math.abs(treasureGeometry.distanceKm(
    { latitude: 0, longitude: 0 }, { latitude: 0.01, longitude: 0 }) - 1.1119492664455874) < 1e-10);
  for (const value of [null, undefined, '', 'NaN', Infinity, 90.001]) {
    assert.equal(treasureGeometry.position(value, 0), null);
  }
});

test('radius and matching include exact metre boundary and exclude one metre less', () => {
  const viewer = { latitude: 0, longitude: 0 };
  const boundary = item('boundary', 0.01, 1.112);
  assert.equal(treasureGeometry.discover([boundary], viewer, 1.112).length, 1);
  assert.equal(treasureGeometry.discover([boundary], viewer, 1.111).length, 0);
  assert.equal(treasureGeometry.discover([{ ...boundary, shareRadiusKm: 1.111 }], viewer, 25).length, 0);
  assert.equal(treasureGeometry.radiusKm(100), 25);
  assert.equal(treasureGeometry.radiusKm(0.05), 1);
  for (const value of [0, -1, NaN, Infinity, 'invalid']) {
    assert.equal(treasureGeometry.radiusKm(value), null);
  }
});

test('real discovery scans past first DB batch, sorts then paginates geographic matches', async () => {
  const fixture = app([
    ...Array.from({ length: 200 }, (_, i) => item(`far-${i}`, 20)),
    item('next', 0.02), item('nearest', 0.01), item('same-grid', 0.004),
  ]);
  const result = await fixture.request('get', {
    latitude: '0.001', longitude: '0.001', radiusKm: '25', maxResults: '1', offset: '1',
  });
  assert.equal(result.status, 200);
  assert.deepEqual(Array.from(result.body.treasures, t => t.id), ['nearest']);
  assert.equal(result.body.treasures[0].distanceKm, 1.112);
  assert.equal(result.body.treasures[0].latitude, 0.01);
  assert.equal(fixture.calls.length, 2);
  assert.equal(fixture.calls[0].take, 200);
  assert.equal(fixture.calls[1].skip, 200);
});

test('real discovery uses both radii, coarse positions and maximum 25 km', async () => {
  const fixture = app([
    item('same-grid', 0.004, 1), item('outside-listing', 0.01, 1),
    item('outside-market', 0.23, 100), item('within-market', 0.22, 100),
  ]);
  const result = await fixture.request('get', { latitude: '0', longitude: '0', radiusKm: '100' });
  assert.deepEqual(Array.from(result.body.treasures, t => t.id), ['same-grid', 'within-market']);
  assert.equal(result.body.treasures[0].distanceKm, 0);
  const limited = await fixture.request('get', { latitude: '0', longitude: '0', radiusKm: '1' });
  assert.deepEqual(Array.from(limited.body.treasures, t => t.id), ['same-grid']);
});

test('real discovery rejects invalid/partial coordinates and radius, keeps nongeo pagination', async () => {
  const fixture = app([item('one', 0), item('two', 0)]);
  for (const query of [
    { latitude: '0' }, { latitude: 'NaN', longitude: '0' },
    { latitude: '0', longitude: '181' }, { radiusKm: 'Infinity' }, { radiusKm: '-1' },
  ]) {
    assert.equal((await fixture.request('get', query)).status, 400);
  }
  const result = await fixture.request('get', { offset: '1', maxResults: '1' });
  assert.deepEqual(result.body.treasures.map(t => t.id), ['two']);
  assert.equal(result.body.treasures[0].distanceKm, null);
});

test('real create stores category and 1/25 km radii independently of distance', async () => {
  const fixture = app();
  for (const radius of [1, 25]) {
    const result = await fixture.request('post', {
      title: 'A book', location: 'Area', latitude: 0, longitude: 0,
      category: 'books', shareRadiusKm: radius,
    });
    assert.equal(result.status, 201);
    assert.equal(fixture.created.category, 'books');
    assert.equal(fixture.created.shareRadiusKm, radius);
  }
  assert.equal((await fixture.request('post', {
    title: 'A book', location: 'Area', latitude: 0, longitude: 0, shareRadiusKm: 'NaN',
  })).status, 400);
});
