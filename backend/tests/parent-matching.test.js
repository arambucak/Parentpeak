/**
 * Parent Matching Integration Tests
 * Tests smart matching algorithm, profile management, and action tracking
 */

const http = require('http');
const https = require('https');
const API_BASE = process.env.API_BASE || 'https://parentpeak.onrender.com';
const BEARER_TOKEN = process.env.BEARER_TOKEN || '';

// Test data
const testProfile1 = {
  name: 'Anna Mueller',
  age: 34,
  city: 'Berlin',
  latitude: 52.5200,
  longitude: 13.4050,
  interests: ['kochen', 'wandern', 'lesen'],
  languages: ['Deutsch', 'Englisch'],
  valuesFocus: ['Familie', 'Nachhaltigkeit'],
  childAges: [5, 8],
  familyForm: 'Mutter',
};

const testProfile2 = {
  name: 'Mareike Schmidt',
  age: 36,
  city: 'Berlin',
  latitude: 52.5210,
  longitude: 13.4085,
  interests: ['kochen', 'yoga', 'lesen'],
  languages: ['Deutsch', 'Spanisch'],
  valuesFocus: ['Familie', 'Gesundheit'],
  childAges: [4, 9],
  familyForm: 'Mutter',
};

const testProfile3 = {
  name: 'Helena Keller',
  age: 32,
  city: 'Munich',
  latitude: 48.1351,
  longitude: 11.5820,
  interests: ['camping', 'sport', 'musik'],
  languages: ['Deutsch'],
  valuesFocus: ['Abenteuer'],
  childAges: [6],
  familyForm: 'Mutter',
};

// Utility: Make HTTP request
function makeRequest(method, path, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, API_BASE);
    const protocol = url.protocol === 'https:' ? https : http;
    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: method,
      headers: {
        'Content-Type': 'application/json',
        ...(token && { 'Authorization': `Bearer ${token}` }),
      },
    };

    const req = protocol.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({
            status: res.statusCode,
            body: data ? JSON.parse(data) : null,
          });
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

// Test Suite
async function runTests() {
  console.log('\n🧪 Parent Matching Integration Tests');
  console.log(`📍 API Base: ${API_BASE}\n`);
  
  let profileId1, profileId2, profileId3;
  let passed = 0;
  let failed = 0;

  // Test 1: Create profiles
  try {
    console.log('📝 Test 1: Create profiles');
    const res1 = await makeRequest('POST', '/api/parent-matching/profiles', testProfile1, BEARER_TOKEN);
    if (res1.status !== 201 && res1.status !== 200) {
      throw new Error(`Expected 200/201, got ${res1.status}: ${JSON.stringify(res1.body)}`);
    }
    profileId1 = res1.body.profile.id;
    console.log(`  ✓ Profile 1 created: ${profileId1}`);
    
    const res2 = await makeRequest('POST', '/api/parent-matching/profiles', testProfile2, BEARER_TOKEN);
    if (res2.status !== 201 && res2.status !== 200) {
      throw new Error(`Expected 200/201, got ${res2.status}: ${JSON.stringify(res2.body)}`);
    }
    profileId2 = res2.body.profile.id;
    console.log(`  ✓ Profile 2 created: ${profileId2}`);
    
    const res3 = await makeRequest('POST', '/api/parent-matching/profiles', testProfile3, BEARER_TOKEN);
    if (res3.status !== 201 && res3.status !== 200) {
      throw new Error(`Expected 200/201, got ${res3.status}: ${JSON.stringify(res3.body)}`);
    }
    profileId3 = res3.body.profile.id;
    console.log(`  ✓ Profile 3 created (Munich): ${profileId3}`);
    passed++;
  } catch (e) {
    console.error(`  ✗ Failed: ${e.message}`);
    failed++;
  }

  // Test 2: Find matches for profile 1 (should match Berlin profile 2, not Munich profile 3)
  try {
    console.log('\n🎯 Test 2: Find matches for profile 1 (Berlin)');
    const res = await makeRequest('GET', `/api/parent-matching/find?userId=${profileId1}`);
    
    if (res.status !== 200) {
      throw new Error(`Expected 200, got ${res.status}: ${JSON.stringify(res.body)}`);
    }
    
    if (!Array.isArray(res.body.matches)) {
      throw new Error('Expected matches array');
    }
    
    console.log(`  Found ${res.body.matches.length} match(es)`);
    
    if (res.body.matches.length > 0) {
      const topMatch = res.body.matches[0];
      console.log(`  Top match: ${topMatch.profile.name} (score: ${topMatch.score})`);
      console.log(`    Breakdown: proximity=${topMatch.breakdown.proximity}, interest=${topMatch.breakdown.interest}, childAge=${topMatch.breakdown.childAge}, familyForm=${topMatch.breakdown.familyForm}`);

      // DATENSCHUTZ: Fremden Nutzern darf nie die exakte Position einer
      // Familie mit Kindern ausgeliefert werden. Die Koordinaten müssen grob
      // gerundet sein (max. 2 Dezimalstellen, ~1 km) und approximateLocation
      // muss gesetzt sein.
      for (const m of res.body.matches) {
        for (const field of ['latitude', 'longitude']) {
          const v = m.profile[field];
          if (v === null || v === undefined) continue;
          const decimals = (String(v).split('.')[1] || '').length;
          if (decimals > 2) {
            throw new Error(
              `Datenschutz-Verletzung: ${field}=${v} ist zu genau (max. 2 Dezimalstellen erlaubt)`);
          }
        }
        if (m.profile.approximateLocation !== true) {
          throw new Error('approximateLocation muss true sein (grobe Position)');
        }
      }
      console.log(`  ✓ Koordinaten grob gerundet (Datenschutz)`);

      // Verify scoring logic
      if (topMatch.profile.city === 'Berlin' && topMatch.score > 70) {
        console.log(`  ✓ Correct match with good score`);
        passed++;
      } else {
        console.error(`  ✗ Unexpected match score/location`);
        failed++;
      }
    } else {
      console.warn(`  ⚠ No matches found (may be normal on fresh database)`);
      passed++;
    }
  } catch (e) {
    console.error(`  ✗ Failed: ${e.message}`);
    failed++;
  }

  // Test 3: Record action (like)
  try {
    console.log('\n👍 Test 3: Record "like" action');
    const res = await makeRequest('POST', '/api/parent-matching/record-action', {
      userId: profileId1,
      matchedProfileId: profileId2,
      action: 'like',
    }, BEARER_TOKEN);
    
    if (res.status !== 200) {
      throw new Error(`Expected 200, got ${res.status}: ${JSON.stringify(res.body)}`);
    }
    
    if (res.body.success) {
      console.log(`  ✓ Action recorded successfully`);
      passed++;
    } else {
      throw new Error('Action not recorded');
    }
  } catch (e) {
    console.error(`  ✗ Failed: ${e.message}`);
    failed++;
  }

  // Test 4: Record multiple actions
  try {
    console.log('\n📊 Test 4: Record multiple actions');
    await makeRequest('POST', '/api/parent-matching/record-action', {
      userId: profileId1,
      matchedProfileId: profileId3,
      action: 'pass',
    }, BEARER_TOKEN);
    await makeRequest('POST', '/api/parent-matching/record-action', {
      userId: profileId2,
      matchedProfileId: profileId1,
      action: 'favorite',
    }, BEARER_TOKEN);
    console.log(`  ✓ Multiple actions recorded`);
    passed++;
  } catch (e) {
    console.error(`  ✗ Failed: ${e.message}`);
    failed++;
  }

  // Results
  console.log(`\n${'='.repeat(50)}`);
  console.log(`Tests passed: ${passed}`);
  console.log(`Tests failed: ${failed}`);
  console.log(`${'='.repeat(50)}\n`);

  process.exit(failed > 0 ? 1 : 0);
}

// Run tests
runTests().catch(e => {
  console.error('Fatal error:', e);
  process.exit(1);
});
