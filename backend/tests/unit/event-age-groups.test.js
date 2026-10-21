const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

// Test the free canonical event creation handler without a live database.
const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
const start = source.indexOf("app.post('/api/events',");
const end = source.indexOf('\n});', start) + 4;
assert.ok(start >= 0 && end > start);

// Arrays aus dem vm-Realm haben einen anderen Array.prototype als der
// Test-Realm. Vor dem Vergleich daher in ein lokales Array kopieren, damit
// deepStrictEqual nicht an der Prototyp-Prüfung scheitert.
const local = value => (Array.isArray(value) ? [...value] : value);

function fixture() {
  const created = [];
  let handlers;
  const context = vm.createContext({
    app: { post: (_path, ...callbacks) => { handlers = callbacks; } },
    requireVerifiedUser: async (req, _res, next) => { req.firebaseUid = 'viewer'; return next(); },
    prisma: { event: { create: async options => {
      created.push(options);
      return { id: 'evt-1', ...options.data, participants: [] };
    } } },
    validateEventMode: () => {},
    isUserSuspended: async () => false,
    respondSuspended: res => res.status(403).json({ error: 'suspended' }),
    crypto: require('node:crypto'),
    notifyFollowersOfNewSeriesEvent: async () => {},
    console,
  });
  vm.runInContext(source.slice(start, end), context);
  return {
    created,
    request: async body => {
      let code = 200; let payload;
      const res = { status(value) { code = value; return res; },
        json(value) { payload = value; return res; } };
      const req = { body };
      let index = 0;
      const next = () => handlers[index++]?.(req, res, next);
      await next();
      return { code, body: payload };
    },
  };
}

function baseEvent(overrides = {}) {
  return {
    hosterId: 'viewer',
    title: 'Krabbelgruppe im Park',
    location: 'Tiergarten, Berlin',
    latitude: 52.5186,
    longitude: 13.3331,
    startDate: new Date(Date.now() + 7 * 86400000).toISOString(),
    eventType: 'playgroup',
    visibility: 'publicNearby',
    maxParticipants: 10,
    shareRadiusKm: 25,
    ...overrides,
  };
}

test('ageGroups werden kostenlos persistiert und zurückgegeben', async () => {
  const app = fixture();
  const res = await app.request(baseEvent({ ageGroups: ['toddler', 'preschool'] }));
  assert.equal(res.code, 201);
  assert.deepEqual(local(app.created[0].data.ageGroups), ['toddler', 'preschool']);
  assert.deepEqual(local(res.body.event.ageGroups), ['toddler', 'preschool']);
});

test('ageGroups werden getrimmt, dedupliziert und von Leerwerten befreit', async () => {
  const app = fixture();
  await app.request(baseEvent({ ageGroups: [' toddler ', 'toddler', '', '   ', 'mixed'] }));
  assert.deepEqual(local(app.created[0].data.ageGroups), ['toddler', 'mixed']);
});

test('fehlende oder ungültige ageGroups ergeben ein leeres Array', async () => {
  const app = fixture();
  await app.request(baseEvent({})); // kein Feld
  assert.deepEqual(local(app.created[0].data.ageGroups), []);

  const app2 = fixture();
  await app2.request(baseEvent({ ageGroups: 'preschool' })); // kein Array
  assert.deepEqual(local(app2.created[0].data.ageGroups), []);

  const app3 = fixture();
  await app3.request(baseEvent({ ageGroups: [1, 2, null, {}] })); // keine Strings
  assert.deepEqual(local(app3.created[0].data.ageGroups), []);
});

test('überlange Werte werden gefiltert und die Anzahl begrenzt', async () => {
  const app = fixture();
  const tooLong = 'x'.repeat(41);
  const many = Array.from({ length: 20 }, (_, i) => `g${i}`);
  await app.request(baseEvent({ ageGroups: [tooLong, ...many] }));
  const stored = local(app.created[0].data.ageGroups);
  assert.ok(!stored.includes(tooLong), 'zu langer Wert darf nicht gespeichert werden');
  assert.ok(stored.length <= 12, 'maximal 12 Altersgruppen');
});
