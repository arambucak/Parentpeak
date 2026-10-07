const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const { publicTreasure } = require('../../treasure_public_view');
const treasureGeometry = require('../../treasure_geometry');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
const treasure = {
  id: 'listing',
  userId: 'owner',
  title: 'Bicycle',
  description: 'Ready for the next family',
  location: 'Neighbourhood',
  latitude: 52.5186123,
  longitude: 13.3331456,
  category: 'vehicles',
  condition: 'good',
  photoUrl: 'https://example.test/photo.jpg',
  photoUrls: ['https://example.test/photo.jpg'],
  pickupSlots: ['sunday_morning'],
  status: 'available',
  shareRadiusKm: 10,
  rating: 4,
  ratingCount: 2,
  handovers: [
    { id: 'private', requesterId: 'requester', status: 'reserved', notes: 'Private contact', location: 'Private address' },
    { status: 'pending' }, { status: 'confirmed' }, { status: 'completed' },
  ],
  ratings: [{ fromUser: { firstName: 'Private', lastName: 'Identity' } }],
  futurePrivateField: 'Must never be public',
};

test('public view rounds coordinates and exposes only aggregate handover counts', () => {
  const result = publicTreasure(treasure, { distanceKm: 1.2 });
  assert.equal(result.latitude, 52.52);
  assert.equal(result.longitude, 13.33);
  assert.equal(result.approximateLocation, true);
  assert.equal(result.distanceKm, 1.2);
  assert.equal(result.reservedCount, 2);
  assert.equal(result.availableHandovers, 1);
  assert.equal(result.claimedCount, 2);
  assert.equal(result.rating, 4);
  assert.equal(result.ratingCount, 2);
  for (const key of ['handovers', 'ratings', 'futurePrivateField']) {
    assert.equal(Object.hasOwn(result, key), false);
  }
  assert.equal(JSON.stringify(result).includes('Private'), false);
  assert.equal(treasure.latitude, 52.5186123);
  assert.equal(treasure.handovers[0].notes, 'Private contact');
});

test('public view preserves public listing fields and handles missing positions', () => {
  const result = publicTreasure(treasure);
  for (const key of ['id', 'userId', 'title', 'description', 'location', 'category',
    'condition', 'photoUrl', 'status', 'shareRadiusKm']) {
    assert.equal(result[key], treasure[key]);
  }
  assert.deepEqual(result.photoUrls, treasure.photoUrls);
  assert.deepEqual(result.pickupSlots, treasure.pickupSlots);
  assert.equal(result.ownerUserId, 'owner');
  assert.equal(result.distanceKm, null);
  for (const value of [null, undefined, '', NaN, Infinity, 'invalid']) {
    assert.equal(publicTreasure({ latitude: value }).latitude, null);
  }
  assert.equal(publicTreasure({ latitude: 0 }).latitude, 0);
  assert.equal(publicTreasure({ longitude: -0.123456 }).longitude, -0.12);
  assert.equal(publicTreasure({ latitude: '52.5186123' }).latitude, 52.52);
});

function fixture({ missing = false, fails = false } = {}) {
  const handlers = {};
  const calls = [];
  const context = {
    app: { get: (route, handler) => { handlers[route] = handler; } },
    publicTreasure,
    treasureGeometry,
    haversineDistance: () => 1.234,
    console: { error: () => {} },
    prisma: { treasureItem: {
      findUnique: async args => {
        calls.push(args);
        if (fails) throw new Error('database unavailable');
        return missing ? null : treasure;
      },
      findMany: async () => [treasure],
      update: async args => { calls.push(args); },
    } },
  };
  for (const route of ['/api/treasures', '/api/treasures/:id']) {
    const start = source.indexOf(`app.get('${route}',`);
    const end = source.indexOf('\n});', start) + 4;
    assert.ok(start >= 0 && end > start);
    vm.runInNewContext(source.slice(start, end), context);
  }
  return {
    calls,
    async request(route, query = {}) {
      let status = 200;
      let body;
      const res = {
        status(code) { status = code; return res; },
        json(value) { body = value; return res; },
      };
      await handlers[route]({ params: { id: 'listing' }, query }, res);
      return { status, body };
    },
  };
}

test('real public detail route never returns raw positions, identities or handovers', async () => {
  const app = fixture();
  const result = await app.request('/api/treasures/:id');
  assert.equal(result.status, 200);
  assert.deepEqual(result.body.treasure, publicTreasure(treasure));
  assert.deepEqual(JSON.parse(JSON.stringify(app.calls[0].include)),
    { handovers: { select: { status: true } } });
  assert.equal(app.calls[1].data.views.increment, 1);
});

test('real list and detail routes share the public view while keeping server distance', async () => {
  const app = fixture();
  const list = await app.request('/api/treasures', { latitude: '52.52', longitude: '13.33' });
  const detail = await app.request('/api/treasures/:id');
  assert.equal(list.status, 200);
  assert.equal(list.body.treasures.length, 1);
  assert.equal(list.body.treasures[0].distanceKm, 0);
  assert.deepEqual({ ...list.body.treasures[0], distanceKm: null }, detail.body.treasure);
});

test('detail route keeps missing and failed lookups explicit', async () => {
  assert.equal((await fixture({ missing: true }).request('/api/treasures/:id')).status, 404);
  assert.equal((await fixture({ fails: true }).request('/api/treasures/:id')).status, 500);
});
