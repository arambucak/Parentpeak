const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const { updateOwnedEvent } = require('../../event_participation_policy');

const source = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
const start = source.indexOf("app.put('/api/events/:id'");
const end = source.indexOf('\n// ============================================================================', start);
assert.ok(start >= 0 && end > start, 'The owner route block must exist');

function fixture() {
  const routes = {};
  const calls = [];
  const event = { id: 'event1', hosterId: 'owner', title: 'Picnic' };
  const context = {
    updateOwnedEvent,
    app: {
      put: (route, handler) => { routes.PUT = handler; },
      delete: (route, handler) => { routes.DELETE = handler; },
    },
    prisma: { event: {
      findUnique: async () => { calls.push('read'); return event; },
      update: async ({ data }) => { calls.push('update'); return { ...event, ...data }; },
      delete: async () => { calls.push('delete'); },
    } },
    console,
  };
  context.prisma.$transaction = async operation => operation({
    ...context.prisma,
    $queryRaw: async () => [],
    eventParticipation: { count: async () => 0 },
  });
  vm.runInNewContext(source.slice(start, end), context);
  async function request(method, hosterId, firebaseUid) {
    let status = 200;
    let body;
    const req = { params: { id: 'event1' }, firebaseUid,
      body: { hosterId, title: 'Updated picnic' }, query: { hosterId } };
    const res = {
      status: (code) => { status = code; return res; },
      json: (value) => { body = value; return res; },
    };
    await routes[method](req, res);
    return { status, body };
  }
  return { request, calls };
}

for (const method of ['PUT', 'DELETE']) {
  test(`${method}: authenticated stranger cannot claim the owner ID`, async () => {
    const route = fixture();
    assert.equal((await route.request(method, 'owner', 'stranger')).status, 403);
    assert.deepEqual(route.calls, []);
  });

  test(`${method}: matching claim cannot change a different owner's event`, async () => {
    const route = fixture();
    assert.equal((await route.request(method, 'stranger', 'stranger')).status, 403);
    assert.deepEqual(route.calls, ['read']);
  });

  test(`${method}: authenticated owner receives acknowledged success`, async () => {
    const route = fixture();
    const result = await route.request(method, 'owner', 'owner');
    assert.equal(result.status, 200);
    assert.deepEqual(route.calls, method === 'PUT' ? ['read', 'read', 'update'] : ['read', 'delete']);
    if (method === 'PUT') assert.equal(result.body.event.title, 'Updated picnic');
    else assert.equal(result.body.success, true);
  });

  test(`${method}: server-token without Firebase UID cannot claim ownership`, async () => {
    const route = fixture();
    assert.equal((await route.request(method, 'owner')).status, 401);
    assert.deepEqual(route.calls, []);
  });
}