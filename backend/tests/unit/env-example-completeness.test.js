const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

test('every server environment access has a documented example assignment', () => {
  const server = fs.readFileSync(path.join(__dirname, '../../server.js'), 'utf8');
  const example = fs.readFileSync(path.join(__dirname, '../../.env.example'), 'utf8');
  const used = new Set([...server.matchAll(/process\.env\.([A-Z][A-Z0-9_]*)/g)].map(match => match[1]));
  const configured = new Set([...example.matchAll(/^([A-Z][A-Z0-9_]*)=/gm)].map(match => match[1]));
  assert.ok(used.size > 0, 'server environment inventory must not be empty');
  assert.deepEqual([...used].filter(key => !configured.has(key)).sort(), []);
  for (const key of used) {
    const lines = example.split('\n');
    const index = lines.findIndex(line => line.startsWith(`${key}=`));
    assert.ok(index > 0 && lines[index - 1].startsWith('#'), `${key} needs an adjacent explanation`);
  }
});
