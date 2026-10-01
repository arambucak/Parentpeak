/**
 * Group Chat Integration Tests
 * Tests group creation, membership, messaging (push fan-out), the chat
 * overview (unread counts) and the member-only send guard.
 *
 * Run against a deployed backend:
 *   API_BASE=https://parentpeak.onrender.com BEARER_TOKEN=<token> \
 *     node tests/group-chat.test.js
 */
const http = require('http');
const https = require('https');

const API_BASE = process.env.API_BASE || 'https://parentpeak.onrender.com';
const BEARER_TOKEN = process.env.BEARER_TOKEN || '';

// Deterministic test users (owner + two members + one outsider).
const stamp = Date.now();
const owner = { id: `grp-owner-${stamp}`, name: 'Owner Parent' };
const memberA = { id: `grp-member-a-${stamp}`, name: 'Member A' };
const memberB = { id: `grp-member-b-${stamp}`, name: 'Member B' };
const outsider = { id: `grp-outsider-${stamp}`, name: 'Outsider' };

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

async function runTests() {
  console.log('\n🧪 Group Chat Integration Tests');
  console.log(`📍 API Base: ${API_BASE}\n`);

  let passed = 0;
  let failed = 0;
  let groupId;
  let roomId;

  // Test 1: Create a group with two members.
  try {
    console.log('📝 Test 1: Create group');
    const res = await makeRequest('POST', '/chat-groups', {
      name: 'Kita-Gruppe Sonnenschein',
      ownerUserId: owner.id,
      ownerName: owner.name,
      photoUrl: '',
      memberUids: [memberA.id, memberB.id],
      memberNames: { [memberA.id]: memberA.name, [memberB.id]: memberB.name },
    }, BEARER_TOKEN);
    if (res.status !== 201 && res.status !== 200) {
      throw new Error(`Expected 200/201, got ${res.status}: ${JSON.stringify(res.body)}`);
    }
    groupId = res.body.group.id;
    roomId = res.body.group.roomId;
    if (!groupId || !roomId || !roomId.startsWith('group_')) {
      throw new Error(`Invalid group response: ${JSON.stringify(res.body)}`);
    }
    console.log(`  ✓ Group created: ${groupId} (roomId ${roomId})`);
    passed++;
  } catch (e) {
    console.log(`  ✗ ${e.message}`);
    failed++;
  }

  // Test 2: Members list contains owner (role owner) + two members.
  try {
    console.log('📝 Test 2: Members list');
    const res = await makeRequest('GET', `/chat-groups/${groupId}/members`, null, BEARER_TOKEN);
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    const members = res.body.members || [];
    if (members.length !== 3) throw new Error(`Expected 3 members, got ${members.length}`);
    const ownerRow = members.find((m) => m.userId === owner.id);
    if (!ownerRow || ownerRow.role !== 'owner') {
      throw new Error('Owner missing or not role=owner');
    }
    console.log('  ✓ 3 members, owner has role=owner');
    passed++;
  } catch (e) {
    console.log(`  ✗ ${e.message}`);
    failed++;
  }

  // Test 3: A member can send a message (triggers push fan-out to others).
  try {
    console.log('📝 Test 3: Member sends message');
    const res = await makeRequest('POST', '/friend-chat/messages', {
      roomId,
      userId: memberA.id,
      userName: memberA.name,
      content: 'Hallo zusammen! 👋',
    }, BEARER_TOKEN);
    if (res.status !== 201) {
      throw new Error(`Expected 201, got ${res.status}: ${JSON.stringify(res.body)}`);
    }
    console.log('  ✓ Message accepted (push sent to other members)');
    passed++;
  } catch (e) {
    console.log(`  ✗ ${e.message}`);
    failed++;
  }

  // Test 4: A non-member is rejected (member-only send guard).
  try {
    console.log('📝 Test 4: Non-member send is rejected');
    const res = await makeRequest('POST', '/friend-chat/messages', {
      roomId,
      userId: outsider.id,
      userName: outsider.name,
      content: 'Darf ich hier rein?',
    }, BEARER_TOKEN);
    if (res.status !== 403) {
      throw new Error(`Expected 403, got ${res.status}: ${JSON.stringify(res.body)}`);
    }
    if (res.body && res.body.code !== 'not_member') {
      throw new Error(`Expected code=not_member, got ${res.body.code}`);
    }
    console.log('  ✓ Non-member rejected with 403 not_member');
    passed++;
  } catch (e) {
    console.log(`  ✗ ${e.message}`);
    failed++;
  }

  // Test 5: Overview for memberB shows the group with an unread message.
  try {
    console.log('📝 Test 5: Overview shows unread group');
    const res = await makeRequest('GET', `/friend-chat/overview?userId=${encodeURIComponent(memberB.id)}`, null, BEARER_TOKEN);
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    const convs = res.body.conversations || [];
    const group = convs.find((c) => c.roomId === roomId);
    if (!group) throw new Error('Group not found in overview');
    if (!group.isGroup) throw new Error('Conversation not flagged isGroup');
    if (group.unreadCount < 1) throw new Error(`Expected unread >= 1, got ${group.unreadCount}`);
    console.log(`  ✓ Group in overview, unreadCount=${group.unreadCount}`);
    passed++;
  } catch (e) {
    console.log(`  ✗ ${e.message}`);
    failed++;
  }

  // Test 6: After marking read, unread resets to 0.
  try {
    console.log('📝 Test 6: Mark read resets unread');
    const readRes = await makeRequest('POST', '/friend-chat/read', {
      roomId,
      userId: memberB.id,
    }, BEARER_TOKEN);
    if (readRes.status !== 200) throw new Error(`read expected 200, got ${readRes.status}`);
    const res = await makeRequest('GET', `/friend-chat/overview?userId=${encodeURIComponent(memberB.id)}`, null, BEARER_TOKEN);
    const group = (res.body.conversations || []).find((c) => c.roomId === roomId);
    if (group && group.unreadCount !== 0) {
      throw new Error(`Expected unread 0 after read, got ${group.unreadCount}`);
    }
    console.log('  ✓ Unread reset to 0 after read');
    passed++;
  } catch (e) {
    console.log(`  ✗ ${e.message}`);
    failed++;
  }

  // Test 7: Leaving the group removes the member.
  try {
    console.log('📝 Test 7: Member leaves group');
    const res = await makeRequest('DELETE', `/chat-groups/${groupId}/members/${encodeURIComponent(memberB.id)}`, null, BEARER_TOKEN);
    if (res.status !== 200) throw new Error(`Expected 200, got ${res.status}`);
    const members = await makeRequest('GET', `/chat-groups/${groupId}/members`, null, BEARER_TOKEN);
    const stillThere = (members.body.members || []).some((m) => m.userId === memberB.id);
    if (stillThere) throw new Error('Member B still present after leaving');
    console.log('  ✓ Member B left the group');
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
