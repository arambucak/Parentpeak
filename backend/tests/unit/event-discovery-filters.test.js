const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
const start = source.indexOf("app.get('/api/events',");
const route = source.slice(start, source.indexOf('\n});', start) + 4);
function event(id, overrides = {}) {
  return { id, hosterId: 'host', title: id, status: 'upcoming', visibility: 'publicNearby',
    startDate: new Date(Date.now() + 86400000), latitude: 52.4986, longitude: 13.4033,
    shareRadiusKm: 100, costPerPerson: null, participants: [], ...overrides };
}
function fixture(events) {
  let handler;
  const reads = [];
  vm.runInNewContext(route, {
    app: { get: (_path, callback) => { handler = callback; } },
    prisma: { event: { findMany: async options => { reads.push(options); return events; } } },
    authorizeEventParticipation: async (_db, row, uid) => {
      if (row.visibility !== 'publicNearby' && row.hosterId !== uid) {
        throw Object.assign(new Error('Forbidden'), { httpStatus: 403 });
      }
    },
    CONFIRMED: ['accepted', 'approved', 'attended'], console,
  });
  return { reads, request: async query => {
    let code = 200; let body;
    const res = { status(value) { code = value; return res; }, json(value) { body = value; return res; } };
    await handler({ query, firebaseUid: 'viewer' }, res);
    return { code, body };
  } };
}
const origin = { latitude: '52.4986', longitude: '13.4033', radiusKm: '50' };
test('unknown event and viewer coordinates stay visible normally, never fake proximity', async () => {
  const app = fixture([event('unknown', { latitude: null, longitude: null }), event('known')]);
  assert.equal((await app.request(origin)).body.events.length, 2);
  assert.equal((await app.request({ ...origin, nearbyOnly: 'true' })).body.events.length, 1);
  assert.equal((await app.request({ nearbyOnly: 'true' })).body.events.length, 0);
  assert.equal((await app.request({})).body.events.length, 2);
  assert.equal((await app.request({ ...origin, latitude: 'NaN' })).code, 400);
  assert.equal((await app.request({ ...origin, radiusKm: '-1' })).code, 400);
});
test('radius, share radius, future dates and filters apply before paging', async () => {
  const app = fixture([
    event('past', { startDate: new Date(Date.now() - 86400000) }),
    event('outside', { latitude: 53.55, longitude: 10 }),
    event('share-limited', { latitude: 52.4861, longitude: 13.2599, shareRadiusKm: 5 }),
    event('grunewald', { latitude: 52.4861, longitude: 13.2599 }),
    event('near'),
  ]);
  const response = await app.request({ ...origin, limit: '1' });
  assert.equal(response.body.total, 2);
  assert.equal(response.body.events[0].id, 'near');
  assert.equal(response.body.hasMore, true);
  assert.equal(app.reads[0].take, undefined);
  assert.equal(app.reads[0].skip, undefined);
  assert.equal((await app.request({ ...origin, limit: '1', offset: '1' })).body.events[0].id, 'grunewald');
  assert.equal((await app.request({ ...origin, radiusKm: '5' })).body.total, 1);
});
test('missing ages are unknown, mixed matches, only explicit zero price is free', async () => {
  const app = fixture([
    event('unknown-age', { costPerPerson: '0' }),
    event('mixed', { ageGroups: ['mixed'], costPerPerson: 0 }),
    event('matching', { ageGroups: ['preschool'], costPerPerson: 0 }),
    event('wrong-age', { ageGroups: ['teenager'], costPerPerson: 0 }),
    event('unknown-price'), event('paid', { costPerPerson: '12.50' }),
  ]);
  const response = await app.request({ ...origin, ageGroups: 'preschool', onlyFree: 'true' });
  assert.equal(response.body.total, 3);
  assert.equal(response.body.events[0].id, 'matching');
});
test('legacy Berlin candidates are marked unknown for client address resolution, not universally invalid', async () => {
  const app = fixture([event('legacy', { latitude: 52.52, longitude: 13.405, location: 'Grunewald, Berlin' })]);
  for (const nearbyOnly of ['false', 'true']) {
    const response = await app.request({ ...origin, radiusKm: '1', nearbyOnly });
    assert.equal(response.body.events[0].coordinatesNeedResolution, true);
    assert.equal(response.body.events[0].latitude, null);
  }
});
test('date windows respect the client UTC offset and never include yesterday', async () => {
  const now = new Date();
  const today = new Date(now.getTime() + 60000);
  const app = fixture([event('today', { startDate: today }),
    event('later', { startDate: new Date(now.getTime() + 3 * 86400000) })]);
  assert.equal((await app.request({ timeWindow: 'today', utcOffsetMinutes: '120' })).body.total, 1);
  assert.equal((await app.request({ timeWindow: 'invalid' })).code, 400);
  assert.equal((await app.request({ utcOffsetMinutes: '99999' })).code, 400);
});
test('visibility authorization still excludes restricted events', async () => {
  const app = fixture([event('private', { visibility: 'privateOnly' }), event('public')]);
  assert.equal((await app.request({})).body.events.length, 1);
});