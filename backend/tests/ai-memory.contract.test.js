const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
const test = require('node:test');

const backendRoot = path.resolve(__dirname, '..');
const schema = fs.readFileSync(path.join(backendRoot, 'prisma/schema.prisma'), 'utf8');
const server = fs.readFileSync(path.join(backendRoot, 'server.js'), 'utf8');

test('AI memory schema contains opt-in settings and cascading child memory', () => {
  assert.match(schema, /model AiMemorySettings\s*\{/);
  assert.match(schema, /model AiChildProfile\s*\{/);
  assert.match(schema, /model AiMemoryItem\s*\{/);
  assert.match(schema, /enabled\s+Boolean\s+@default\(false\)/);
  assert.match(schema, /child\s+AiChildProfile\s+@relation\([^)]*onDelete: Cascade/);
  assert.match(schema, /@@unique\(\[childId, category, key\]\)/);
});

test('AI memory API exposes CRUD, settings, context, and account integration', () => {
  for (const route of [
    "app.get('/ai/settings'",
    "app.put('/ai/settings'",
    "app.get('/ai/children'",
    "app.post('/ai/children'",
    "app.put('/ai/children/:id'",
    "app.delete('/ai/children/:id'",
    "app.get('/ai/children/:id/memory'",
    "app.post('/ai/children/:id/memory'",
    "app.put('/ai/children/:id/memory/:itemId'",
    "app.delete('/ai/children/:id/memory/:itemId'",
    "app.get('/ai/context'",
  ]) {
    assert.ok(server.includes(route), `missing route: ${route}`);
  }
  assert.match(server, /function requireAiMemoryUser\(req, res\)/);
  assert.match(server, /verifyFirebaseIdToken\(req\)/);
  assert.match(server, /AI_MEMORY_MAX_CONTEXT_CHARS = 2800/);
  assert.match(server, /getAiMemoryContext\(uid, childProfileId\)/);
  assert.match(server, /aiChildProfiles/);
  assert.match(server, /aiMemoryItems/);
});

test('AI memory routes do not trust a caller-supplied userId', () => {
  const routeBlock = server.slice(
    server.indexOf("app.get('/ai/settings'"),
    server.indexOf("app.get('/ai/health'")
  );
  assert.doesNotMatch(routeBlock, /req\.body\??\.userId/);
  assert.doesNotMatch(routeBlock, /req\.query\??\.userId/);
  assert.match(routeBlock, /requireAiMemoryUser\(req, res\)/);
});
