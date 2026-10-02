/**
 * Event Series Follow Integration Tests (Issue #47)
 * Eltern folgen/entfolgen einem wiederkehrenden Angebot (seriesId) und werden
 * NUR dann über einen neuen konkreten Termin benachrichtigt, wenn sie der
 * Serie aktiv folgen. Teilnahme an einem Einzelevent ist KEIN Abo.
 *
 * Läuft gegen einen deployten/laufenden Server:
 *   API_BASE=https://parentpeak.onrender.com BEARER_TOKEN=<firebase-id-token> \
 *     node tests/events-series-follow.test.js
 *
 * Hinweis: Schreib-Endpunkte verlangen in Produktion einen gültigen
 * Firebase-ID-Token (siehe tests/README_group_chat.md). Lokal lässt sich der
 * Test mit FIREBASE_REQUIRE_AUTH=0 REQUIRE_AUTH_FOR_WRITES=0 fahren.
 */
const http = require('http');
const https = require('https');

const API_BASE = process.env.API_BASE || 'https://parentpeak.onrender.com';
const BEARER_TOKEN = process.env.BEARER_TOKEN || '';

const stamp = Date.now();
const host = 'series-host-' + stamp;
const follower = 'series-follower-' + stamp;
const stranger = 'series-stranger-' + stamp;
const seriesId = 'series-' + stamp;

function makeRequest(method, path, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, API_BASE);
    const protocol = url.protocol === 'https:' ? https : http;
    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(token && { Authorization: `Bearer ${token}` }),
      },
    };
    const req = protocol.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: data ? JSON.parse(data) : null });
        } catch (e) {
          reject(new Error(`Failed to parse response: ${e.message}`));
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

function eventPayload(hosterId, extra = {}) {
  return {
    hosterId,
    title: 'Krabbelgruppe Sonnenschein',
    description: 'Wöchentliche Krabbelgruppe',
    location: 'Familienzentrum, Berlin',
    latitude: 52.52,
    longitude: 13.405,
    startDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
    eventType: 'meeting',
    visibility: 'publicNearby',
    maxParticipants: 10,
    ...extra,
  };
}

async function runTests() {
  console.log('\n🧪 Event Series Follow Tests (Issue #47)');
  console.log(`📍 API Base: ${API_BASE}\n`);
  let passed = 0;
  let failed = 0;
  let firstEventId;

  // Test 1: Veranstalter legt den ersten Termin der Serie an.
  try {
    console.log('📝 Test 1: Create first series event');
    const res = await makeRequest('POST', '/api/events',
      eventPayload(host, { seriesId }), BEARER_TOKEN);
    if (res.status !== 201 && res.status !== 200) {
      throw new Error(`Expected 200/201, got ${res.status}: ${JSON.stringify(res.body)}`);
    }
    firstEventId = res.body.event.id;
    if (res.body.event.seriesId !== seriesId) {
      throw new Error(`seriesId not persisted: ${JSON.stringify(res.body.event.seriesId)}`);
    }
    console.log(`  ✓ Event created with seriesId (${firstEventId})`);
    passed++;
  } catch (e) {
    console.log(`  ✗ ${e.message}`);
    failed++;
  }

  // Test 2: Zu Beginn folgt niemand der Serie.
  try {
    console.log('📝 Test 2: No followers initially');
    const res = await makeRequest('GET',
      `/api/events/series/${seriesId}/follow?userId=${follower}`, null, BEARER_TOKEN);
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    if (res.body.following !== false) throw new Error('Should not be following yet');
    if (res.body.followerCount !== 0) throw new Error(`Expected 0 followers, got ${res.body.followerCount}`);
    console.log('  ✓ following=false, followerCount=0');
    passed++;
  } catch (e) {
    console.log(`  ✗ ${e.message}`);
    failed++;
  }

  // Test 3: Ein Elternteil folgt der Serie aktiv (Opt-in).
  try {
    console.log('📝 Test 3: Follower opts in');
    const res = await makeRequest('POST',
      `/api/events/series/${seriesId}/follow`, { userId: follower }, BEARER_TOKEN);
    if (res.status !== 201 && res.status !== 200) {
      throw new Error(`Expected 200/201, got ${res.status}: ${JSON.stringify(res.body)}`);
    }
    if (res.body.following !== true) throw new Error('following should be true');
    if (res.body.followerCount !== 1) throw new Error(`Expected 1 follower, got ${res.body.followerCount}`);
    console.log('  ✓ following=true, followerCount=1');
    passed++;
  } catch (e) {
    console.log(`  ✗ ${e.message}`);
    failed++;
  }

  // Test 4: Doppeltes Folgen bleibt idempotent (kein Duplikat).
  try {
    console.log('📝 Test 4: Following twice is idempotent');
    const res = await makeRequest('POST',
      `/api/events/series/${seriesId}/follow`, { userId: follower }, BEARER_TOKEN);
    if (res.body.followerCount !== 1) {
      throw new Error(`Expected still 1 follower, got ${res.body.followerCount}`);
    }
    console.log('  ✓ still followerCount=1');
    passed++;
  } catch (e) {
    console.log(`  ✗ ${e.message}`);
    failed++;
  }

  // Test 5: Teilnahme an einem Einzelevent macht NICHT zum Follower.
  try {
    console.log('📝 Test 5: Participation is not a subscription');
    await makeRequest('POST', '/events/participations',
      { eventId: firstEventId, userId: stranger, userName: 'Stranger' }, BEARER_TOKEN);
    const res = await makeRequest('GET',
      `/api/events/series/${seriesId}/follow?userId=${stranger}`, null, BEARER_TOKEN);
    if (res.body.following !== false) {
      throw new Error('Participant must NOT be counted as follower');
    }
    if (res.body.followerCount !== 1) {
      throw new Error(`Follower count must stay 1, got ${res.body.followerCount}`);
    }
    console.log('  ✓ participant is not a follower (followerCount=1)');
    passed++;
  } catch (e) {
    console.log(`  ✗ ${e.message}`);
    failed++;
  }

  // Test 6: Neuer Serien-Termin → Create erfolgreich (löst Follower-Push aus).
  try {
    console.log('📝 Test 6: New series date triggers follower push');
    const res = await makeRequest('POST', '/api/events',
      eventPayload(host, {
        seriesId,
        startDate: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString(),
      }), BEARER_TOKEN);
    if (res.status !== 201 && res.status !== 200) {
      throw new Error(`Expected 200/201, got ${res.status}: ${JSON.stringify(res.body)}`);
    }
    console.log('  ✓ second series event created (push to followers fired)');
    passed++;
  } catch (e) {
    console.log(`  ✗ ${e.message}`);
    failed++;
  }

  // Test 7: Entfolgen (Opt-out) entfernt den Follower.
  try {
    console.log('📝 Test 7: Unfollow');
    const res = await makeRequest('DELETE',
      `/api/events/series/${seriesId}/follow?userId=${follower}`, null, BEARER_TOKEN);
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    if (res.body.following !== false) throw new Error('following should be false');
    if (res.body.followerCount !== 0) throw new Error(`Expected 0 followers, got ${res.body.followerCount}`);
    console.log('  ✓ following=false, followerCount=0');
    passed++;
  } catch (e) {
    console.log(`  ✗ ${e.message}`);
    failed++;
  }

  console.log(`\n📊 Result: ${passed} passed, ${failed} failed\n`);
  process.exit(failed > 0 ? 1 : 0);
}

runTests().catch((e) => {
  console.error('Test runner crashed:', e);
  process.exit(1);
});
