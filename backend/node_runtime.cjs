const fs = require('node:fs');
const path = require('node:path');

function requirePinnedNode(actual = process.versions.node) {
  const expected = fs.readFileSync(path.join(__dirname, '.node-version'), 'utf8').trim();
  if (!/^\d+\.\d+\.\d+$/.test(expected)) {
    throw new Error('backend/.node-version must contain an exact Node version');
  }
  if (actual !== expected) {
    throw new Error(`Backend requires Node ${expected}; running ${actual}. Check Render NODE_VERSION and rootDir.`);
  }
  return expected;
}

if (require.main === module) {
  console.log(`Backend Node runtime verified: ${requirePinnedNode()}`);
}

module.exports = { requirePinnedNode };
