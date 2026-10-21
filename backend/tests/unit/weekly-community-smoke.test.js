const assert = require('node:assert/strict');
const { execFile } = require('node:child_process');
const http = require('node:http');
const path = require('node:path');
const test = require('node:test');
const { promisify } = require('node:util');

const execute = promisify(execFile);
const script = path.join(__dirname, '../../../scripts/weekly_impulse_community_smoke_test.sh');

test('weekly smoke refuses a static backend token without both Firebase tokens', async () => {
  for (const [user, reviewer] of [['', ''], ['user', ''], ['', 'reviewer']]) {
    await assert.rejects(execute('bash', [script], {
      env: {
        ...process.env,
        BACKEND_BASE_URL: 'http://127.0.0.1:9',
        BACKEND_API_TOKEN: 'static-token-is-not-identity',
        FIREBASE_ID_TOKEN: user,
        INTERNAL_REVIEWER_ID_TOKEN: reviewer,
      },
    }), error => {
      assert.equal(error.code, 1);
      assert.match(error.stdout, /FIREBASE_ID_TOKEN and INTERNAL_REVIEWER_ID_TOKEN are required/);
      return true;
    });
  }
});

test('weekly smoke uses separate user/reviewer tokens and approves only its own request', async t => {
  const calls = [];
  let approved = false;
  const server = http.createServer(async (req, res) => {
    let raw = '';
    for await (const chunk of req) raw += chunk;
    const body = raw ? JSON.parse(raw) : {};
    const url = new URL(req.url, 'http://localhost');
    calls.push({ path: url.pathname, auth: req.headers.authorization, body });
    let status = 200;
    let response;
    const base = '/api/weekly-impulse/community';
    if (url.pathname === '/api/weekly-impulse') {
      response = { community_posts: [] };
    } else if (url.pathname === `${base}/verification-requests` && req.method === 'POST') {
      assert.equal(req.headers.authorization, 'Bearer user-token');
      assert.equal(body.userId, undefined);
      assert.equal(body.email, undefined);
      status = 201;
      response = { item: { id: 'verif_own', userId: 'firebase-user', status: 'pending' } };
    } else if (url.pathname === `${base}/verification-status`) {
      assert.equal(req.headers.authorization, 'Bearer user-token');
      assert.equal(url.search, '');
      response = { pendingRequest: !approved, verified: approved, verifiedProfile: approved ? {} : null };
    } else if (url.pathname === `${base}/verification-requests`) {
      if (req.headers.authorization === 'Bearer user-token') {
        assert.equal(url.searchParams.get('reviewerEmail'), 'lead@parentpeak.de');
        status = 403;
        response = { error: 'Forbidden' };
      } else {
        assert.equal(req.headers.authorization, 'Bearer reviewer-token');
        response = { items: [{ id: 'verif_unrelated' }, { id: 'verif_own' }] };
      }
    } else if (url.pathname === `${base}/verification-requests/verif_own/approve`) {
      assert.equal(req.headers.authorization, 'Bearer reviewer-token');
      approved = true;
      response = { item: { status: 'approved' } };
    } else if (url.pathname === `${base}/posts`) {
      assert.equal(req.headers.authorization, 'Bearer user-token');
      assert.equal(body.authorUserId, undefined);
      status = 201;
      response = { item: { verified_expert: approved } };
    } else {
      status = 404;
      response = { error: 'Unexpected request' };
    }
    res.writeHead(status, { 'content-type': 'application/json' });
    res.end(JSON.stringify(response));
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const result = await execute('bash', [script], {
    env: {
      ...process.env,
      BACKEND_BASE_URL: `http://127.0.0.1:${server.address().port}`,
      FIREBASE_ID_TOKEN: 'user-token',
      INTERNAL_REVIEWER_ID_TOKEN: 'reviewer-token',
      BACKEND_API_TOKEN: 'must-not-be-used',
    },
    timeout: 10000,
  });
  assert.match(result.stdout, /Completed/);
  assert.equal(calls.length, 8);
  assert.equal(approved, true);
});
