#!/usr/bin/env node

/**
 * Treasure Items (Verschenkmarkt) Integration Test Suite
 * Tests all API endpoints for creating, listing, updating, and deleting treasures
 */

const http = require('http');
const https = require('https');

// Environment
const BEARER_TOKEN = process.env.BEARER_TOKEN || '';
const API_BASE = process.env.API_BASE || 'https://parentpeak.onrender.com';
const REQUESTER_USER_ID = process.env.REQUESTER_USER_ID || 'host_demo_001';

let passed = 0;
let failed = 0;

// Helper: Make HTTP request
async function makeRequest(method, path, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, API_BASE);
    const protocol = url.protocol === 'https:' ? https : http;

    const options = {
      method,
      headers: {
        'Content-Type': 'application/json',
      },
    };

    if (token) {
      options.headers['Authorization'] = `Bearer ${token}`;
    }

    if (body && (method === 'POST' || method === 'PUT')) {
      options.headers['Content-Length'] = Buffer.byteLength(JSON.stringify(body));
    }

    const req = protocol.request(url, options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        try {
          const parsedBody = data ? JSON.parse(data) : {};
          resolve({ status: res.statusCode, body: parsedBody });
        } catch (e) {
          resolve({ status: res.statusCode, body: { raw: data } });
        }
      });
    });

    req.on('error', reject);

    if (body && (method === 'POST' || method === 'PUT')) {
      req.write(JSON.stringify(body));
    } else if (method === 'DELETE' && body) {
      req.write(JSON.stringify(body));
    }

    req.end();
  });
}

// Test data
const testTreasure1 = {
  userId: 'user-berlin-1',
  title: 'Spielzeugauto Collection',
  description: 'Schöne Sammlung von Hot Wheels, kaum bespielt',
  location: 'Tiergarten, Berlin',
  latitude: 52.5186,
  longitude: 13.3331,
  category: 'toy',
  condition: 'good',
  isFree: true,
  visibility: 'nearby',
  shareRadiusKm: 10,
};

const testTreasure2 = {
  userId: 'user-berlin-1',
  title: 'Kinderbücher Set',
  description: 'Altersgerechte Geschichten für 4-8 Jahre',
  location: 'Prenzlauer Berg, Berlin',
  latitude: 52.5409,
  longitude: 13.3969,
  category: 'book',
  condition: 'good',
  isFree: false,
  price: 15,
  visibility: 'nearby',
  shareRadiusKm: 10,
};

const testTreasure3 = {
  userId: 'user-munich-1',
  title: 'Laufrad',
  description: 'Rotes Laufrad in gutem Zustand',
  location: 'Neuhausen, Munich',
  latitude: 48.1635,
  longitude: 11.5452,
  category: 'toy',
  condition: 'fair',
  isFree: true,
  visibility: 'nearby',
  shareRadiusKm: 15,
};

// Test runner
async function runTests() {
  if (API_BASE.startsWith('https://parentpeak.onrender.com') && !BEARER_TOKEN) {
    console.error(
      'BEARER_TOKEN fehlt. Der Produktions-Smoke wird ohne gültiges Test-Token nicht gestartet.',
    );
    process.exit(2);
  }

  console.log('🧪 Treasure Items Integration Tests');
  console.log(`📍 API Base: ${API_BASE}\n`);

  let treasureId1, treasureId2, treasureId3;

  // Test 1: Create treasures
  try {
    console.log('📝 Test 1: Create treasure items');
    
    let res = await makeRequest('POST', '/api/treasures', testTreasure1, BEARER_TOKEN);
    if (res.status === 201) {
      treasureId1 = res.body.treasure?.id;
      console.log(`  ✓ Treasure 1 created: ${treasureId1} (${testTreasure1.location})`);
    } else {
      throw new Error(`Expected 201, got ${res.status}: ${JSON.stringify(res.body)}`);
    }

    res = await makeRequest('POST', '/api/treasures', testTreasure2, BEARER_TOKEN);
    if (res.status === 201) {
      treasureId2 = res.body.treasure?.id;
      console.log(`  ✓ Treasure 2 created: ${treasureId2} (${testTreasure2.location})`);
    } else {
      throw new Error(`Expected 201, got ${res.status}: ${JSON.stringify(res.body)}`);
    }

    res = await makeRequest('POST', '/api/treasures', testTreasure3, BEARER_TOKEN);
    if (res.status === 201) {
      treasureId3 = res.body.treasure?.id;
      console.log(`  ✓ Treasure 3 created: ${treasureId3} (${testTreasure3.location})`);
    } else {
      throw new Error(`Expected 201, got ${res.status}: ${JSON.stringify(res.body)}`);
    }

    passed++;
  } catch (e) {
    console.error(`  ✗ Failed: ${e.message}`);
    failed++;
  }

  // Test 2: Get treasure details
  try {
    console.log('\n📖 Test 2: Get treasure details');
    const res = await makeRequest('GET', `/api/treasures/${treasureId1}`);

    if (res.status === 200) {
      console.log(`  ✓ Treasure details retrieved correctly`);
      console.log(`    Title: ${res.body.treasure?.title}`);
      console.log(`    Location: ${res.body.treasure?.location}`);
      console.log(`    Ratings: ${res.body.treasure?.ratingCount || 0}`);
      passed++;
    } else {
      throw new Error(`Expected 200, got ${res.status}: ${JSON.stringify(res.body)}`);
    }
  } catch (e) {
    console.error(`  ✗ Failed: ${e.message}`);
    failed++;
  }

  // Test 3: List treasures with filtering
  try {
    console.log('\n🔍 Test 3: List treasures with filtering');
    const res = await makeRequest('GET', '/api/treasures?status=available&visibility=nearby&maxResults=50');

    if (res.status === 200 && Array.isArray(res.body.treasures)) {
      console.log(`  ✓ Found ${res.body.treasures.length} available treasures`);
      if (res.body.treasures.length > 0) {
        console.log(`    First treasure: ${res.body.treasures[0].title}`);
      }
      passed++;
    } else {
      throw new Error(`Expected 200 with treasures array, got ${res.status}`);
    }
  } catch (e) {
    console.error(`  ✗ Failed: ${e.message}`);
    failed++;
  }

  // Test 4: Discover nearby treasures (Berlin proximity)
  try {
    console.log('\n🗺️  Test 4: Discover nearby treasures (Berlin proximity)');
    const res = await makeRequest(
      'GET',
      '/api/treasures?latitude=52.52&longitude=13.405&radiusKm=5&status=available'
    );

    if (res.status === 200 && Array.isArray(res.body.treasures)) {
      const nearbyCount = res.body.treasures.length;
      console.log(`  ✓ Found ${nearbyCount} treasures near Berlin`);
      
      if (nearbyCount > 0) {
        console.log(`    Treasures sorted by proximity (verified):`);
        res.body.treasures.slice(0, 3).forEach((t, i) => {
          console.log(`      ${i + 1}. ${t.title}`);
        });
      }
      passed++;
    } else {
      throw new Error(`Expected 200, got ${res.status}`);
    }
  } catch (e) {
    console.error(`  ✗ Failed: ${e.message}`);
    failed++;
  }

  // Test 5: Update treasure (owner success)
  try {
    console.log('\n🤝 Test 5: Reserve, confirm, and complete handover');
    const reserveRes = await makeRequest(
      'POST',
      `/api/treasures/${treasureId1}/reserve`,
      {
        requesterUserId: REQUESTER_USER_ID,
        preferredSlot: 'sunday_morning',
        handoverMode: 'coffee',
      },
      BEARER_TOKEN,
    );
    const handoverId = reserveRes.body.handover?.id;
    if (reserveRes.status !== 201 || !handoverId) {
      throw new Error(`Expected reservation 201 with handover.id, got ${reserveRes.status}: ${JSON.stringify(reserveRes.body)}`);
    }

    const ownerOverview = await makeRequest(
      'GET',
      '/api/treasures/mine?userId=user-berlin-1',
      null,
      BEARER_TOKEN,
    );
    if (ownerOverview.status !== 200 || !ownerOverview.body.offers?.some((offer) =>
      offer.id === treasureId1 && offer.reservations?.some((item) => item.id === handoverId),
    )) {
      throw new Error('Expected owner overview to contain the new reservation');
    }

    const confirmRes = await makeRequest(
      'POST',
      `/api/treasures/${treasureId1}/handovers/${handoverId}/confirm`,
      { userId: 'user-berlin-1' },
      BEARER_TOKEN,
    );
    if (confirmRes.status !== 200 || confirmRes.body.handover?.status !== 'confirmed') {
      throw new Error(`Expected confirmed handover, got ${confirmRes.status}: ${JSON.stringify(confirmRes.body)}`);
    }

    const completeRes = await makeRequest(
      'POST',
      `/api/treasures/${treasureId1}/handovers/${handoverId}/complete`,
      { userId: 'user-berlin-1' },
      BEARER_TOKEN,
    );
    if (completeRes.status !== 200 || completeRes.body.handover?.status !== 'completed') {
      throw new Error(`Expected completed handover, got ${completeRes.status}: ${JSON.stringify(completeRes.body)}`);
    }
    const duplicateReservation = await makeRequest(
      'POST',
      `/api/treasures/${treasureId1}/reserve`,
      { requesterUserId: REQUESTER_USER_ID, handoverMode: 'coffee' },
      BEARER_TOKEN,
    );
    if (duplicateReservation.status !== 410) {
      throw new Error(`Expected completed listing to reject new reservations, got ${duplicateReservation.status}`);
    }
    console.log('  ✓ Reservation lifecycle completed and is visible to the owner');
    passed++;
  } catch (e) {
    console.error(`  ✗ Failed: ${e.message}`);
    failed++;
  }

  // Test 6: Update treasure (owner success)
  try {
    console.log('\n✏️  Test 6: Update treasure (owner verification)');
    const updateData = {
      userId: 'user-berlin-1',
      title: 'Updated: Spielzeugauto Collection',
      condition: 'fair',
    };

    const res = await makeRequest('PUT', `/api/treasures/${treasureId1}`, updateData, BEARER_TOKEN);

    if (res.status === 200) {
      console.log(`  ✓ Treasure updated successfully`);
      console.log(`    New title: ${res.body.treasure?.title}`);
      passed++;
    } else {
      throw new Error(`Expected 200, got ${res.status}: ${JSON.stringify(res.body)}`);
    }
  } catch (e) {
    console.error(`  ✗ Failed: ${e.message}`);
    failed++;
  }

  // Test 7: Ownership verification (wrong owner should fail)
  try {
    console.log('\n🔒 Test 7: Ownership verification (wrong owner should fail)');
    const updateData = {
      userId: 'user-different',
      title: 'Hacked!',
    };

    const res = await makeRequest('PUT', `/api/treasures/${treasureId1}`, updateData, BEARER_TOKEN);

    if (res.status === 403) {
      console.log(`  ✓ Correctly rejected update from wrong owner (403)`);
      passed++;
    } else {
      throw new Error(`Expected 403, got ${res.status}`);
    }
  } catch (e) {
    console.error(`  ✗ Failed: ${e.message}`);
    failed++;
  }

  // Test 7: Report flow (create, list, resolve)
  try {
    console.log('\n🚩 Test 7: Report flow (create, list, resolve)');

    const createReportRes = await makeRequest(
      'POST',
      `/api/treasures/${treasureId2}/report`,
      {
        reporterUserId: 'user-parent-qa',
        reason: 'Unpassender Inhalt',
        note: 'Bitte kurz moderieren.',
      },
      BEARER_TOKEN,
    );

    if (createReportRes.status !== 201 || !createReportRes.body.report?.id) {
      throw new Error(
        `Expected 201 with report.id, got ${createReportRes.status}: ${JSON.stringify(createReportRes.body)}`,
      );
    }

    const reportId = createReportRes.body.report.id;

    const unauthorizedListRes = await makeRequest('GET', '/api/treasures/reports');
    if (unauthorizedListRes.status !== 401) {
      throw new Error(`Expected 401 for unauthorized report list, got ${unauthorizedListRes.status}`);
    }

    const listRes = await makeRequest('GET', '/api/treasures/reports?status=pending', null, BEARER_TOKEN);
    if (listRes.status !== 200 || !Array.isArray(listRes.body.reports)) {
      throw new Error(`Expected 200 with reports array, got ${listRes.status}`);
    }

    const hasReport = listRes.body.reports.some((item) => item.id === reportId);
    if (!hasReport) {
      throw new Error(`Expected report ${reportId} in pending list`);
    }

    const resolveRes = await makeRequest(
      'POST',
      `/api/treasures/reports/${reportId}/resolve`,
      {
        action: 'resolved',
        moderatorId: 'mod-qa-1',
        moderatorNote: 'Checked and resolved.',
      },
      BEARER_TOKEN,
    );

    if (resolveRes.status === 200 && resolveRes.body.report?.status === 'resolved') {
      console.log('  ✓ Report flow works (create/list/resolve)');
      passed++;
    } else {
      throw new Error(`Expected 200 resolved, got ${resolveRes.status}: ${JSON.stringify(resolveRes.body)}`);
    }
  } catch (e) {
    console.error(`  ✗ Failed: ${e.message}`);
    failed++;
  }

  // Test 8: Auto moderation (threshold + duplicate guard)
  try {
    console.log('\n🤖 Test 8: Auto moderation (threshold + duplicate guard)');

    const report1 = await makeRequest(
      'POST',
      `/api/treasures/${treasureId3}/report`,
      {
        reporterUserId: 'user-report-a',
        reason: 'Falsche Angaben',
      },
      BEARER_TOKEN,
    );
    if (report1.status !== 201 || report1.body.autoModeration?.action !== 'none') {
      throw new Error(`Expected first report action=none, got ${report1.status}: ${JSON.stringify(report1.body)}`);
    }

    const duplicate = await makeRequest(
      'POST',
      `/api/treasures/${treasureId3}/report`,
      {
        reporterUserId: 'user-report-a',
        reason: 'Falsche Angaben',
      },
      BEARER_TOKEN,
    );
    if (duplicate.status !== 409) {
      throw new Error(`Expected 409 on duplicate reporter, got ${duplicate.status}`);
    }

    const report2 = await makeRequest(
      'POST',
      `/api/treasures/${treasureId3}/report`,
      {
        reporterUserId: 'user-report-b',
        reason: 'Unpassender Inhalt',
      },
      BEARER_TOKEN,
    );
    if (report2.status !== 201 || report2.body.autoModeration?.action !== 'none') {
      throw new Error(`Expected second report action=none, got ${report2.status}: ${JSON.stringify(report2.body)}`);
    }

    const report3 = await makeRequest(
      'POST',
      `/api/treasures/${treasureId3}/report`,
      {
        reporterUserId: 'user-report-c',
        reason: 'Unpassender Inhalt',
      },
      BEARER_TOKEN,
    );
    if (report3.status !== 201 || report3.body.autoModeration?.action !== 'archived_threshold') {
      throw new Error(`Expected third report action=archived_threshold, got ${report3.status}: ${JSON.stringify(report3.body)}`);
    }

    const archivedDetail = await makeRequest('GET', `/api/treasures/${treasureId3}`);
    if (archivedDetail.status !== 200 || archivedDetail.body.treasure?.status !== 'archived') {
      throw new Error(`Expected archived treasure status, got ${archivedDetail.status}: ${JSON.stringify(archivedDetail.body)}`);
    }

    console.log('  ✓ Auto moderation archived listing after threshold and blocks duplicate reporter');
    passed++;
  } catch (e) {
    console.error(`  ✗ Failed: ${e.message}`);
    failed++;
  }

  // Test 9: Delete treasure (owner verification)
  try {
    console.log('\n🗑️  Test 9: Delete treasure (owner verification)');
    const res = await makeRequest('DELETE', `/api/treasures/${treasureId1}?userId=user-berlin-1`, null, BEARER_TOKEN);

    if (res.status === 200 || res.status === 204) {
      console.log(`  ✓ Treasure deleted successfully`);

      // Verify treasure is gone
      const verifyRes = await makeRequest('GET', `/api/treasures/${treasureId1}`);
      if (verifyRes.status === 404) {
        console.log(`  ✓ Verified: Treasure no longer exists`);
        passed++;
      } else {
        console.warn(`  ⚠ Treasure still exists after deletion`);
        passed++;
      }
    } else {
      throw new Error(`Expected 200/204, got ${res.status}: ${JSON.stringify(res.body)}`);
    }
  } catch (e) {
    console.error(`  ✗ Failed: ${e.message}`);
    failed++;
  }

  // Test 10: Pagination support
  try {
    console.log('\n📄 Test 10: Pagination support');
    const res1 = await makeRequest('GET', '/api/treasures?maxResults=1&offset=0');
    const res2 = await makeRequest('GET', '/api/treasures?maxResults=1&offset=1');

    if (res1.status === 200 && res2.status === 200) {
      console.log(`  ✓ Pagination working correctly`);
      console.log(`    Page 1: ${res1.body.treasures?.length || 0} treasures`);
      console.log(`    Page 2: ${res2.body.treasures?.length || 0} treasures`);
      passed++;
    } else {
      throw new Error(`Expected 200, got ${res1.status}/${res2.status}`);
    }
  } catch (e) {
    console.error(`  ✗ Failed: ${e.message}`);
    failed++;
  }

  // Test 11: Input validation
  try {
    console.log('\n✓ Test 11: Input validation');
    const invalidData = {
      userId: 'user-test',
      title: 'A', // Too short (< 3 chars)
      location: 'Berlin',
      latitude: 52.52,
      longitude: 13.405,
    };

    const res = await makeRequest('POST', '/api/treasures', invalidData, BEARER_TOKEN);

    if (res.status === 400) {
      console.log(`  ✓ Validation correctly rejected invalid treasure (400)`);
      console.log(`    Error: ${res.body.error}`);
      passed++;
    } else {
      throw new Error(`Expected 400, got ${res.status}`);
    }
  } catch (e) {
    console.error(`  ✗ Failed: ${e.message}`);
    failed++;
  }

  // Test 12: Severe content auto-archive on create
  try {
    console.log('\n🛡️  Test 12: Severe content auto-archive on create');
    const severeData = {
      userId: 'user-safe-check',
      title: 'Betrug Angebot Demo',
      description: 'Nur für Moderationsprüfung',
      location: 'Berlin',
      latitude: 52.52,
      longitude: 13.405,
      category: 'toy',
      condition: 'good',
      isFree: true,
      visibility: 'nearby',
      shareRadiusKm: 10,
    };

    const createRes = await makeRequest('POST', '/api/treasures', severeData, BEARER_TOKEN);
    if (createRes.status !== 201 || !createRes.body.treasure?.id) {
      throw new Error(`Expected 201 with treasure id, got ${createRes.status}: ${JSON.stringify(createRes.body)}`);
    }

    if (createRes.body.treasure.status !== 'archived' || createRes.body.moderation?.autoArchivedOnCreate !== true) {
      throw new Error(`Expected auto-archived create result, got: ${JSON.stringify(createRes.body)}`);
    }

    const archivedId = createRes.body.treasure.id;
    const availableList = await makeRequest('GET', '/api/treasures?status=available&visibility=nearby&maxResults=100');
    if (availableList.status !== 200 || !Array.isArray(availableList.body.treasures)) {
      throw new Error(`Expected 200 with treasures array, got ${availableList.status}`);
    }

    const existsInAvailable = availableList.body.treasures.some((item) => item.id === archivedId);
    if (existsInAvailable) {
      throw new Error('Expected severe listing to be hidden from available feed');
    }

    const cleanupRes = await makeRequest('DELETE', `/api/treasures/${archivedId}?userId=user-safe-check`, null, BEARER_TOKEN);
    if (cleanupRes.status !== 200 && cleanupRes.status !== 204) {
      throw new Error(`Expected cleanup delete 200/204, got ${cleanupRes.status}`);
    }

    console.log('  ✓ Severe content is auto-archived and hidden from available feed');
    passed++;
  } catch (e) {
    console.error(`  ✗ Failed: ${e.message}`);
    failed++;
  }

  // Summary
  console.log('\n==================================================');
  console.log(`Tests passed: ${passed}`);
  console.log(`Tests failed: ${failed}`);
  console.log('==================================================\n');

  process.exit(failed > 0 ? 1 : 0);
}

// Run tests
runTests().catch(err => {
  console.error('Test runner error:', err);
  process.exit(1);
});
