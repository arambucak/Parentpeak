const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');

const BACKEND_DIR = path.resolve(__dirname, '..', '..');
const SERVER_PATH = path.join(BACKEND_DIR, 'server.js');
const ENV_PATH = path.join(BACKEND_DIR, '.env');

function parseDotEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return {};
  const raw = fs.readFileSync(filePath, 'utf8');
  const out = {};

  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;

    const eqIdx = trimmed.indexOf('=');
    if (eqIdx <= 0) continue;

    const key = trimmed.slice(0, eqIdx).trim();
    let value = trimmed.slice(eqIdx + 1).trim();

    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    out[key] = value;
  }

  return out;
}

async function waitForHealth(baseUrl, timeoutMs = 15000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const response = await fetch(`${baseUrl}/health`);
      if (response.ok) return;
    } catch (_) {
      // Keep polling until timeout.
    }
    await new Promise(resolve => setTimeout(resolve, 150));
  }
  throw new Error(`Server health check timed out for ${baseUrl}`);
}

function startServer(port, extraEnv = {}) {
  const envFromFile = parseDotEnvFile(ENV_PATH);
  const child = spawn(process.execPath, [SERVER_PATH], {
    cwd: BACKEND_DIR,
    env: {
      ...process.env,
      ...envFromFile,
      REQUIRE_AUTH_FOR_WRITES: '0',
      PORT: String(port),
      ...extraEnv,
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  let logs = '';
  const collect = chunk => {
    logs += chunk.toString();
    if (logs.length > 20000) {
      logs = logs.slice(-20000);
    }
  };

  child.stdout.on('data', collect);
  child.stderr.on('data', collect);

  return {
    child,
    getLogs: () => logs,
    baseUrl: `http://127.0.0.1:${port}`,
  };
}

async function stopServer(child, timeoutMs = 7000) {
  if (!child || child.killed) return;

  child.kill('SIGTERM');
  const exited = await new Promise(resolve => {
    const timer = setTimeout(() => resolve(false), timeoutMs);
    child.once('exit', () => {
      clearTimeout(timer);
      resolve(true);
    });
  });

  if (!exited) {
    child.kill('SIGKILL');
    await new Promise(resolve => child.once('exit', () => resolve()));
  }
}

async function postJson(baseUrl, route, body) {
  const response = await fetch(`${baseUrl}${route}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const payload = await response.json();
  return { response, payload };
}

async function putJson(baseUrl, route, body) {
  const response = await fetch(`${baseUrl}${route}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const payload = await response.json();
  return { response, payload };
}

async function getJson(baseUrl, route) {
  const response = await fetch(`${baseUrl}${route}`);
  const payload = await response.json();
  return { response, payload };
}

async function deletePath(baseUrl, route) {
  const response = await fetch(`${baseUrl}${route}`, {
    method: 'DELETE',
  });

  let payload = null;
  const contentType = response.headers.get('content-type') || '';
  if (contentType.includes('application/json')) {
    payload = await response.json();
  }

  return { response, payload };
}

test('invite code persists in DB across restart and delete-data dryRun is non-destructive', async () => {
  const suffix = `${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;
  const inviteHostUser = `it_invite_host_${suffix}`;
  const inviteJoinUser = `it_invite_join_${suffix}`;
  const dryRunUser = `it_dryrun_${suffix}`;

  let serverA;
  let serverB;

  try {
    serverA = startServer(3025);
    await waitForHealth(serverA.baseUrl);

    const createInviteEvent = await postJson(serverA.baseUrl, '/events', {
      hosterId: inviteHostUser,
      title: `IT Invite Event ${suffix}`,
      visibility: 'inviteOnly',
      eventDate: '2026-07-02T10:00:00.000Z',
      invitedUserIds: [inviteJoinUser],
    });

    assert.equal(createInviteEvent.response.status, 201);
    assert.ok(createInviteEvent.payload?.item?.id);
    assert.ok(createInviteEvent.payload?.item?.inviteCode);

    const inviteCode = createInviteEvent.payload.item.inviteCode;

    const createDryRunEvent = await postJson(serverA.baseUrl, '/events', {
      hosterId: dryRunUser,
      title: `IT DryRun Event ${suffix}`,
      eventDate: '2026-07-03T10:00:00.000Z',
    });

    assert.equal(createDryRunEvent.response.status, 201);
    const dryRunEventId = createDryRunEvent.payload?.item?.id;
    assert.ok(dryRunEventId);

    const dryRunDelete = await postJson(
      serverA.baseUrl,
      '/account/delete-data?dryRun=true',
      { userId: dryRunUser },
    );
    assert.equal(dryRunDelete.response.status, 200);
    assert.equal(dryRunDelete.payload?.dryRun, true);

    const exportBeforeDelete = await getJson(
      serverA.baseUrl,
      `/account/export-data?userId=${encodeURIComponent(dryRunUser)}`,
    );
    assert.equal(exportBeforeDelete.response.status, 200);
    assert.ok(
      exportBeforeDelete.payload?.data?.hostedEvents?.some(
        item => item.id === dryRunEventId,
      ),
    );

    const listAfterDryRun = await getJson(serverA.baseUrl, `/events?hostUserId=${dryRunUser}`);
    assert.equal(listAfterDryRun.response.status, 200);
    assert.ok(Array.isArray(listAfterDryRun.payload?.items));
    assert.ok(listAfterDryRun.payload.items.some(item => item.id === dryRunEventId));

    await stopServer(serverA.child);

    serverB = startServer(3026);
    await waitForHealth(serverB.baseUrl);

    const joinByCode = await postJson(serverB.baseUrl, '/events/invitations/join', {
      code: inviteCode,
      userId: inviteJoinUser,
    });

    assert.equal(joinByCode.response.status, 201);
    assert.equal(joinByCode.payload?.item?.status, 'accepted');

    const realDelete = await postJson(serverB.baseUrl, '/account/delete-data', {
      userId: dryRunUser,
    });
    assert.equal(realDelete.response.status, 200);
    assert.equal(realDelete.payload?.dryRun, false);

    await stopServer(serverB.child);
    serverB = startServer(3026);
    await waitForHealth(serverB.baseUrl);

    const listAfterRealDelete = await getJson(serverB.baseUrl, `/events?hostUserId=${dryRunUser}`);
    assert.equal(listAfterRealDelete.response.status, 200);
    assert.ok(Array.isArray(listAfterRealDelete.payload?.items));
    assert.equal(listAfterRealDelete.payload.items.length, 0);

    // Best-effort cleanup of created test users.
    await postJson(serverB.baseUrl, '/account/delete-data', { userId: inviteHostUser });
    await postJson(serverB.baseUrl, '/account/delete-data', { userId: inviteJoinUser });
  } catch (error) {
    const extraLogs = [
      serverA ? `serverA logs:\n${serverA.getLogs()}` : '',
      serverB ? `serverB logs:\n${serverB.getLogs()}` : '',
    ]
      .filter(Boolean)
      .join('\n\n');

    throw new Error(`${error.message}\n\n${extraLogs}`);
  } finally {
    await stopServer(serverA?.child);
    await stopServer(serverB?.child);
  }
});

test('account export and deletion require authentication in production', async () => {
  const userId = `it_account_auth_${Date.now()}`;
  let server;

  try {
    server = startServer(3040, {
      NODE_ENV: 'production',
      BACKEND_API_TOKEN: '',
      FIREBASE_SERVICE_ACCOUNT_JSON: '',
      GOOGLE_APPLICATION_CREDENTIALS: '',
    });
    await waitForHealth(server.baseUrl);

    const exportResponse = await getJson(
      server.baseUrl,
      `/account/export-data?userId=${encodeURIComponent(userId)}`,
    );
    assert.equal(exportResponse.response.status, 401);

    const deleteResponse = await postJson(server.baseUrl, '/account/delete-data', {
      userId,
    });
    assert.equal(deleteResponse.response.status, 401);

    const socialDeleteResponse = await deletePath(
      server.baseUrl,
      `/api/account/${encodeURIComponent(userId)}`,
    );
    assert.equal(socialDeleteResponse.response.status, 401);
  } catch (error) {
    const extraLogs = server ? `server logs:\n${server.getLogs()}` : '';
    throw new Error(`${error.message}\n\n${extraLogs}`);
  } finally {
    await stopServer(server?.child);
  }
});

test('invite join rejects expired or invalid codes and dryRun delete requires userId', async () => {
  const suffix = `${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;
  const inviteHostUser = `it_invite_negative_host_${suffix}`;
  const inviteJoinUser = `it_invite_negative_join_${suffix}`;

  let server;

  try {
    server = startServer(3027);
    await waitForHealth(server.baseUrl);

    const createExpiredInviteEvent = await postJson(server.baseUrl, '/events', {
      hosterId: inviteHostUser,
      title: `IT Expired Invite Event ${suffix}`,
      visibility: 'inviteOnly',
      eventDate: '2026-07-04T10:00:00.000Z',
      inviteCodeExpiresAt: '2001-01-01T00:00:00.000Z',
      invitedUserIds: [inviteJoinUser],
    });

    assert.equal(createExpiredInviteEvent.response.status, 201);
    const expiredInviteCode = createExpiredInviteEvent.payload?.item?.inviteCode;
    assert.ok(expiredInviteCode);

    const joinExpiredCode = await postJson(server.baseUrl, '/events/invitations/join', {
      code: expiredInviteCode,
      userId: inviteJoinUser,
    });
    assert.equal(joinExpiredCode.response.status, 404);
    assert.match(joinExpiredCode.payload?.error || '', /ungültig|abgelaufen/i);

    const joinInvalidCode = await postJson(server.baseUrl, '/events/invitations/join', {
      code: 'PP-INVALID-CODE',
      userId: inviteJoinUser,
    });
    assert.equal(joinInvalidCode.response.status, 404);
    assert.match(joinInvalidCode.payload?.error || '', /ungültig|abgelaufen/i);

    const dryRunWithoutUser = await postJson(server.baseUrl, '/account/delete-data?dryRun=true', {});
    assert.equal(dryRunWithoutUser.response.status, 400);
    assert.match(dryRunWithoutUser.payload?.error || '', /userId/i);

    // Best-effort cleanup of created test users.
    await postJson(server.baseUrl, '/account/delete-data', { userId: inviteHostUser });
    await postJson(server.baseUrl, '/account/delete-data', { userId: inviteJoinUser });
  } catch (error) {
    const extraLogs = server ? `server logs:\n${server.getLogs()}` : '';
    throw new Error(`${error.message}\n\n${extraLogs}`);
  } finally {
    await stopServer(server?.child);
  }
});

test('discover enforces public, familyCircle, privateOnly and inviteOnly visibility', async () => {
  const suffix = `${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;
  const viewerUserId = 'host_demo_001';
  const publicHostUser = `it_discover_public_host_${suffix}`;
  const familyHostUser = `it_discover_family_host_${suffix}`;
  const privateHostUser = `it_discover_private_host_${suffix}`;
  const inviteHostUser = `it_discover_invite_host_${suffix}`;

  let server;
  const createdEventIds = [];

  try {
    server = startServer(3028);
    await waitForHealth(server.baseUrl);

    const publicEvent = await postJson(server.baseUrl, '/events', {
      hosterId: publicHostUser,
      title: `IT Discover Public ${suffix}`,
      visibility: 'publicNearby',
      eventDate: '2026-07-05T10:00:00.000Z',
    });
    assert.equal(publicEvent.response.status, 201);
    const publicEventId = publicEvent.payload?.item?.id;
    createdEventIds.push(publicEventId);

    const familyLink = await postJson(server.baseUrl, '/family/requests', {
      fromUserId: familyHostUser,
      toUserId: viewerUserId,
      actingUserId: familyHostUser,
      status: 'accepted',
    });
    assert.equal(familyLink.response.status, 201);

    const familyEvent = await postJson(server.baseUrl, '/events', {
      hosterId: familyHostUser,
      title: `IT Discover Family ${suffix}`,
      visibility: 'familyCircle',
      eventDate: '2026-07-05T11:00:00.000Z',
    });
    assert.equal(familyEvent.response.status, 201);
    const familyEventId = familyEvent.payload?.item?.id;
    createdEventIds.push(familyEventId);

    const privateEvent = await postJson(server.baseUrl, '/events', {
      hosterId: privateHostUser,
      title: `IT Discover Private ${suffix}`,
      visibility: 'privateOnly',
      eventDate: '2026-07-05T12:00:00.000Z',
    });
    assert.equal(privateEvent.response.status, 201);
    const privateEventId = privateEvent.payload?.item?.id;
    createdEventIds.push(privateEventId);

    const inviteOnlyEvent = await postJson(server.baseUrl, '/events', {
      hosterId: inviteHostUser,
      title: `IT Discover Invite ${suffix}`,
      visibility: 'inviteOnly',
      eventDate: '2026-07-05T13:00:00.000Z',
      invitedUserIds: [viewerUserId],
    });
    assert.equal(inviteOnlyEvent.response.status, 201);
    const inviteOnlyEventId = inviteOnlyEvent.payload?.item?.id;
    const inviteCode = inviteOnlyEvent.payload?.item?.inviteCode;
    createdEventIds.push(inviteOnlyEventId);
    assert.ok(inviteCode);

    const discoverBeforeJoin = await getJson(
      server.baseUrl,
      `/events/discover?viewerUserId=${viewerUserId}`,
    );
    assert.equal(discoverBeforeJoin.response.status, 200);
    const beforeJoinIds = new Set((discoverBeforeJoin.payload?.items || []).map(item => item.id));

    assert.ok(beforeJoinIds.has(publicEventId));
    assert.ok(beforeJoinIds.has(familyEventId));
    assert.ok(!beforeJoinIds.has(privateEventId));
    assert.ok(!beforeJoinIds.has(inviteOnlyEventId));

    const joinInvite = await postJson(server.baseUrl, '/events/invitations/join', {
      code: inviteCode,
      userId: viewerUserId,
    });
    assert.equal(joinInvite.response.status, 201);

    const discoverAfterJoin = await getJson(
      server.baseUrl,
      `/events/discover?viewerUserId=${viewerUserId}`,
    );
    assert.equal(discoverAfterJoin.response.status, 200);
    const afterJoinIds = new Set((discoverAfterJoin.payload?.items || []).map(item => item.id));

    assert.ok(afterJoinIds.has(publicEventId));
    assert.ok(afterJoinIds.has(familyEventId));
    assert.ok(!afterJoinIds.has(privateEventId));
    assert.ok(afterJoinIds.has(inviteOnlyEventId));

    const discoverForPrivateHost = await getJson(
      server.baseUrl,
      `/events/discover?viewerUserId=${privateHostUser}`,
    );
    assert.equal(discoverForPrivateHost.response.status, 200);
    const privateHostIds = new Set((discoverForPrivateHost.payload?.items || []).map(item => item.id));
    assert.ok(privateHostIds.has(privateEventId));
  } catch (error) {
    const extraLogs = server ? `server logs:\n${server.getLogs()}` : '';
    throw new Error(`${error.message}\n\n${extraLogs}`);
  } finally {
    if (server) {
      for (const eventId of createdEventIds) {
        if (!eventId) continue;
        try {
          await deletePath(server.baseUrl, `/events/item/${eventId}`);
        } catch (_) {
          // Ignore cleanup errors in tests.
        }
      }

      await postJson(server.baseUrl, '/account/delete-data', { userId: publicHostUser });
      await postJson(server.baseUrl, '/account/delete-data', { userId: familyHostUser });
      await postJson(server.baseUrl, '/account/delete-data', { userId: privateHostUser });
      await postJson(server.baseUrl, '/account/delete-data', { userId: inviteHostUser });
    }

    await stopServer(server?.child);
  }
});

test('family request lifecycle controls familyCircle discover access and blocks duplicates', async () => {
  const suffix = `${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;
  const viewerUserId = `it_family_viewer_${suffix}`;
  const familyHostUser = `it_family_host_${suffix}`;

  let server;
  const createdEventIds = [];

  try {
    server = startServer(3029);
    await waitForHealth(server.baseUrl);

    const familyEvent = await postJson(server.baseUrl, '/events', {
      hosterId: familyHostUser,
      title: `IT Family Lifecycle ${suffix}`,
      visibility: 'familyCircle',
      eventDate: '2026-07-07T11:00:00.000Z',
    });
    assert.equal(familyEvent.response.status, 201);
    const familyEventId = familyEvent.payload?.item?.id;
    createdEventIds.push(familyEventId);

    const discoverBeforeLink = await getJson(
      server.baseUrl,
      `/events/discover?viewerUserId=${viewerUserId}`,
    );
    assert.equal(discoverBeforeLink.response.status, 200);
    const beforeIds = new Set((discoverBeforeLink.payload?.items || []).map(item => item.id));
    assert.ok(!beforeIds.has(familyEventId));

    const createPending = await postJson(server.baseUrl, '/family/requests', {
      fromUserId: familyHostUser,
      toUserId: viewerUserId,
      actingUserId: familyHostUser,
      status: 'pending',
    });
    assert.equal(createPending.response.status, 201);
    const requestId = createPending.payload?.item?.id;
    assert.ok(requestId);

    const duplicatePendingReverse = await postJson(server.baseUrl, '/family/requests', {
      fromUserId: viewerUserId,
      toUserId: familyHostUser,
      actingUserId: viewerUserId,
      status: 'pending',
    });
    assert.equal(duplicatePendingReverse.response.status, 409);

    const markAccepted = await putJson(server.baseUrl, `/family/requests/${requestId}`, {
      status: 'accepted',
      actingUserId: viewerUserId,
    });
    assert.equal(markAccepted.response.status, 200);

    const duplicateAfterAccepted = await postJson(server.baseUrl, '/family/requests', {
      fromUserId: viewerUserId,
      toUserId: familyHostUser,
      actingUserId: viewerUserId,
      status: 'accepted',
    });
    assert.equal(duplicateAfterAccepted.response.status, 409);

    const discoverAfterAccepted = await getJson(
      server.baseUrl,
      `/events/discover?viewerUserId=${viewerUserId}`,
    );
    assert.equal(discoverAfterAccepted.response.status, 200);
    const afterIds = new Set((discoverAfterAccepted.payload?.items || []).map(item => item.id));
    assert.ok(afterIds.has(familyEventId));
  } catch (error) {
    const extraLogs = server ? `server logs:\n${server.getLogs()}` : '';
    throw new Error(`${error.message}\n\n${extraLogs}`);
  } finally {
    if (server) {
      for (const eventId of createdEventIds) {
        if (!eventId) continue;
        try {
          await deletePath(server.baseUrl, `/events/item/${eventId}`);
        } catch (_) {
          // Ignore cleanup errors in tests.
        }
      }

      await postJson(server.baseUrl, '/account/delete-data', { userId: viewerUserId });
      await postJson(server.baseUrl, '/account/delete-data', { userId: familyHostUser });
    }

    await stopServer(server?.child);
  }
});

test('family request query filters support fromUserId, toUserId, status and reject invalid status', async () => {
  const suffix = `${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;
  const fromUserId = `it_filter_from_${suffix}`;
  const toUserId = `it_filter_to_${suffix}`;
  const otherUserId = `it_filter_other_${suffix}`;

  let server;

  try {
    server = startServer(3030);
    await waitForHealth(server.baseUrl);

    const pendingReq = await postJson(server.baseUrl, '/family/requests', {
      fromUserId,
      toUserId,
      actingUserId: fromUserId,
      status: 'pending',
    });
    assert.equal(pendingReq.response.status, 201);
    const pendingId = pendingReq.payload?.item?.id;
    assert.ok(pendingId);

    const acceptedReq = await postJson(server.baseUrl, '/family/requests', {
      fromUserId: otherUserId,
      toUserId,
      actingUserId: otherUserId,
      status: 'accepted',
    });
    assert.equal(acceptedReq.response.status, 201);

    const byToUser = await getJson(server.baseUrl, `/family/requests?toUserId=${toUserId}`);
    assert.equal(byToUser.response.status, 200);
    assert.ok(Array.isArray(byToUser.payload?.requests));
    assert.ok(byToUser.payload.requests.length >= 2);

    const byFromAndStatus = await getJson(
      server.baseUrl,
      `/family/requests?fromUserId=${fromUserId}&toUserId=${toUserId}&status=pending`,
    );
    assert.equal(byFromAndStatus.response.status, 200);
    const filtered = byFromAndStatus.payload?.requests || [];
    assert.equal(filtered.length, 1);
    assert.equal(filtered[0]?.id, pendingId);
    assert.equal(filtered[0]?.status, 'pending');

    // Backward compatibility: userId still maps to toUserId filter.
    const byLegacyUserId = await getJson(server.baseUrl, `/family/requests?userId=${toUserId}`);
    assert.equal(byLegacyUserId.response.status, 200);
    const legacyIds = new Set((byLegacyUserId.payload?.requests || []).map(item => item.id));
    assert.ok(legacyIds.has(pendingId));

    const invalidStatus = await getJson(server.baseUrl, '/family/requests?status=unknown');
    assert.equal(invalidStatus.response.status, 400);
    assert.match(invalidStatus.payload?.error || '', /Ungültiger Status/i);
  } catch (error) {
    const extraLogs = server ? `server logs:\n${server.getLogs()}` : '';
    throw new Error(`${error.message}\n\n${extraLogs}`);
  } finally {
    if (server) {
      await postJson(server.baseUrl, '/account/delete-data', { userId: fromUserId });
      await postJson(server.baseUrl, '/account/delete-data', { userId: toUserId });
      await postJson(server.baseUrl, '/account/delete-data', { userId: otherUserId });
    }
    await stopServer(server?.child);
  }
});

test('family request security: actingUserId prevents impersonation and blocks sender from self-accepting', async () => {
  const suffix = `${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;
  const senderUser = `it_sec_sender_${suffix}`;
  const recipientUser = `it_sec_recipient_${suffix}`;
  const intruderUser = `it_sec_intruder_${suffix}`;

  let server;

  try {
    server = startServer(3031);
    await waitForHealth(server.baseUrl);

    // Wrong actingUserId on POST must return 403.
    const impersonateCreate = await postJson(server.baseUrl, '/family/requests', {
      fromUserId: senderUser,
      toUserId: recipientUser,
      actingUserId: intruderUser,
      status: 'pending',
    });
    assert.equal(impersonateCreate.response.status, 403);
    assert.match(impersonateCreate.payload?.error || '', /actingUserId/i);

    // Create a real pending request as sender.
    const validCreate = await postJson(server.baseUrl, '/family/requests', {
      fromUserId: senderUser,
      toUserId: recipientUser,
      actingUserId: senderUser,
      status: 'pending',
    });
    assert.equal(validCreate.response.status, 201);
    const requestId = validCreate.payload?.item?.id;
    assert.ok(requestId);

    // Intruder cannot respond to this request.
    const intruderRespond = await putJson(server.baseUrl, `/family/requests/${requestId}`, {
      status: 'accepted',
      actingUserId: intruderUser,
    });
    assert.equal(intruderRespond.response.status, 403);

    // Sender cannot self-accept their own request.
    const senderSelfAccept = await putJson(server.baseUrl, `/family/requests/${requestId}`, {
      status: 'accepted',
      actingUserId: senderUser,
    });
    assert.equal(senderSelfAccept.response.status, 403);
    assert.match(senderSelfAccept.payload?.error || '', /Empf\u00e4nger/i);

    // Sender can withdraw (decline) their own request.
    const senderWithdraw = await putJson(server.baseUrl, `/family/requests/${requestId}`, {
      status: 'declined',
      actingUserId: senderUser,
    });
    assert.equal(senderWithdraw.response.status, 200);
    assert.equal(senderWithdraw.payload?.item?.status, 'declined');

    // Create a fresh pending request for recipient accept test.
    const validCreate2 = await postJson(server.baseUrl, '/family/requests', {
      fromUserId: senderUser,
      toUserId: recipientUser,
      actingUserId: senderUser,
      status: 'pending',
    });
    assert.equal(validCreate2.response.status, 201);
    const requestId2 = validCreate2.payload?.item?.id;
    assert.ok(requestId2);

    // Recipient can accept.
    const recipientAccept = await putJson(server.baseUrl, `/family/requests/${requestId2}`, {
      status: 'accepted',
      actingUserId: recipientUser,
    });
    assert.equal(recipientAccept.response.status, 200);
    assert.equal(recipientAccept.payload?.item?.status, 'accepted');
  } catch (error) {
    const extraLogs = server ? `server logs:\n${server.getLogs()}` : '';
    throw new Error(`${error.message}\n\n${extraLogs}`);
  } finally {
    if (server) {
      await postJson(server.baseUrl, '/account/delete-data', { userId: senderUser });
      await postJson(server.baseUrl, '/account/delete-data', { userId: recipientUser });
      await postJson(server.baseUrl, '/account/delete-data', { userId: intruderUser });
    }
    await stopServer(server?.child);
  }
});

test('event ownership guard on DELETE and pagination on GET /events', async () => {
  const suffix = `${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;
  const ownerUser = `it_owner_${suffix}`;
  const intruderUser = `it_intruder_owner_${suffix}`;
  const createdEventIds = [];
  let server;

  try {
    server = startServer(3032);
    await waitForHealth(server.baseUrl);

    // Create 3 events for pagination test.
    for (let i = 0; i < 3; i++) {
      const ev = await postJson(server.baseUrl, '/events', {
        hosterId: ownerUser,
        title: `IT Paging Event ${i} ${suffix}`,
        eventDate: '2026-08-01T10:00:00.000Z',
      });
      assert.equal(ev.response.status, 201);
      createdEventIds.push(ev.payload?.item?.id);
    }

    // Pagination: limit=2 returns max 2 items and hasMore flag.
    const page1 = await getJson(server.baseUrl, `/events?hostUserId=${ownerUser}&limit=2&offset=0`);
    assert.equal(page1.response.status, 200);
    assert.equal(page1.payload?.items?.length, 2);
    assert.equal(page1.payload?.limit, 2);
    assert.equal(page1.payload?.offset, 0);
    assert.equal(page1.payload?.hasMore, true);

    // Second page should have 1 remaining item.
    const page2 = await getJson(server.baseUrl, `/events?hostUserId=${ownerUser}&limit=2&offset=2`);
    assert.equal(page2.response.status, 200);
    assert.equal(page2.payload?.items?.length, 1);
    assert.equal(page2.payload?.hasMore, false);

    // Intruder cannot delete owner's event.
    const forbidDelete = await deletePath(
      server.baseUrl,
      `/events/item/${createdEventIds[0]}?requestingUserId=${intruderUser}`,
    );
    assert.equal(forbidDelete.response.status, 403);
    assert.match(forbidDelete.payload?.error || '', /Hoster/i);

    // Owner can delete own event.
    const allowDelete = await deletePath(
      server.baseUrl,
      `/events/item/${createdEventIds[0]}?requestingUserId=${ownerUser}`,
    );
    assert.equal(allowDelete.response.status, 204);
    createdEventIds.shift(); // Already deleted.
  } catch (error) {
    const extraLogs = server ? `server logs:\n${server.getLogs()}` : '';
    throw new Error(`${error.message}\n\n${extraLogs}`);
  } finally {
    if (server) {
      for (const eventId of createdEventIds) {
        try { await deletePath(server.baseUrl, `/events/item/${eventId}?requestingUserId=${ownerUser}`); } catch (_) {}
      }
      await postJson(server.baseUrl, '/account/delete-data', { userId: ownerUser });
      await postJson(server.baseUrl, '/account/delete-data', { userId: intruderUser });
    }
    await stopServer(server?.child);
  }
});

test('family request DELETE removes relationship and intruder cannot delete', async () => {
  const suffix = `${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;
  const userA = `it_del_a_${suffix}`;
  const userB = `it_del_b_${suffix}`;
  const intruder = `it_del_intruder_${suffix}`;
  let server;

  try {
    server = startServer(3033);
    await waitForHealth(server.baseUrl);

    const createReq = await postJson(server.baseUrl, '/family/requests', {
      fromUserId: userA,
      toUserId: userB,
      actingUserId: userA,
      status: 'accepted',
    });
    assert.equal(createReq.response.status, 201);
    const reqId = createReq.payload?.item?.id;
    assert.ok(reqId);

    // Intruder cannot delete.
    const intruderDel = await fetch(`${server.baseUrl}/family/requests/${reqId}?actingUserId=${intruder}`, {
      method: 'DELETE',
    });
    assert.equal(intruderDel.status, 403);

    // Participant (userB) can delete.
    const validDel = await fetch(`${server.baseUrl}/family/requests/${reqId}?actingUserId=${userB}`, {
      method: 'DELETE',
    });
    assert.equal(validDel.status, 204);

    // Confirm it's gone.
    const listAfter = await getJson(
      server.baseUrl,
      `/family/requests?fromUserId=${userA}&toUserId=${userB}`,
    );
    assert.ok(Array.isArray(listAfter.payload?.requests));
    assert.equal(listAfter.payload.requests.filter(r => r.id === reqId).length, 0);
  } catch (error) {
    const extraLogs = server ? `server logs:\n${server.getLogs()}` : '';
    throw new Error(`${error.message}\n\n${extraLogs}`);
  } finally {
    if (server) {
      await postJson(server.baseUrl, '/account/delete-data', { userId: userA });
      await postJson(server.baseUrl, '/account/delete-data', { userId: userB });
      await postJson(server.baseUrl, '/account/delete-data', { userId: intruder });
    }
    await stopServer(server?.child);
  }
});

test('PUT /events/item/:id updates fields and enforces ownership', async () => {
  const suffix = `${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;
  const ownerUser = `it_update_owner_${suffix}`;
  const intruder = `it_update_intruder_${suffix}`;
  let server;
  const createdEventIds = [];

  try {
    server = startServer(3034);
    await waitForHealth(server.baseUrl);

    const created = await postJson(server.baseUrl, '/events', {
      hosterId: ownerUser,
      title: `Update Test Event ${suffix}`,
      eventDate: '2026-09-01T10:00:00.000Z',
    });
    assert.equal(created.response.status, 201);
    const eventId = created.payload?.item?.id;
    assert.ok(eventId);
    createdEventIds.push(eventId);

    // Intruder cannot update.
    const forbidUpdate = await putJson(server.baseUrl, `/events/item/${eventId}`, {
      title: 'Hijacked Title',
      requestingUserId: intruder,
    });
    assert.equal(forbidUpdate.response.status, 403);

    // Owner can update.
    const updated = await putJson(server.baseUrl, `/events/item/${eventId}`, {
      title: 'Updated Title',
      location: 'Hamburg',
      requestingUserId: ownerUser,
    });
    assert.equal(updated.response.status, 200);
    assert.equal(updated.payload?.item?.title, 'Updated Title');
    assert.equal(updated.payload?.item?.location, 'Hamburg');

    // No fields body returns 400.
    const noFields = await putJson(server.baseUrl, `/events/item/${eventId}`, {
      requestingUserId: ownerUser,
    });
    assert.equal(noFields.response.status, 400);

    // Nonexistent event returns 404.
    const notFound = await putJson(server.baseUrl, '/events/item/nonexistent_id', {
      title: 'x',
      requestingUserId: ownerUser,
    });
    assert.equal(notFound.response.status, 404);
  } catch (error) {
    const extraLogs = server ? `server logs:\n${server.getLogs()}` : '';
    throw new Error(`${error.message}\n\n${extraLogs}`);
  } finally {
    if (server) {
      for (const id of createdEventIds) {
        try { await deletePath(server.baseUrl, `/events/item/${id}?requestingUserId=${ownerUser}`); } catch (_) {}
      }
      await postJson(server.baseUrl, '/account/delete-data', { userId: ownerUser });
      await postJson(server.baseUrl, '/account/delete-data', { userId: intruder });
    }
    await stopServer(server?.child);
  }
});

test('FCM device token register and unregister', async () => {
  const suffix = `${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;
  const userId = `it_fcm_user_${suffix}`;
  let server;

  try {
    server = startServer(3035);
    await waitForHealth(server.baseUrl);

    // Register token.
    const reg = await postJson(server.baseUrl, '/devices/register-token', {
      userId,
      token: 'fcm_test_token_abc',
      platform: 'ios',
    });
    assert.equal(reg.response.status, 200);
    assert.equal(reg.payload?.ok, true);
    assert.ok(reg.payload?.tokenCount >= 1);

    // Register second token for same user.
    const reg2 = await postJson(server.baseUrl, '/devices/register-token', {
      userId,
      token: 'fcm_test_token_xyz',
      platform: 'android',
    });
    assert.equal(reg2.response.status, 200);
    assert.ok(reg2.payload?.tokenCount >= 2);

    // Missing userId returns 400.
    const noUser = await postJson(server.baseUrl, '/devices/register-token', {
      token: 'some_token',
    });
    assert.equal(noUser.response.status, 400);

    // Unregister first token.
    const unregRes = await fetch(`${server.baseUrl}/devices/register-token`, {
      method: 'DELETE',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ userId, token: 'fcm_test_token_abc' }),
    });
    assert.equal(unregRes.status, 200);
    const unregPayload = await unregRes.json();
    assert.equal(unregPayload.ok, true);
  } catch (error) {
    const extraLogs = server ? `server logs:\n${server.getLogs()}` : '';
    throw new Error(`${error.message}\n\n${extraLogs}`);
  } finally {
    if (server) {
      await postJson(server.baseUrl, '/account/delete-data', { userId });
    }
    await stopServer(server?.child);
  }
});

test('image upload endpoint accepts valid image and rejects non-image', async () => {
  const ownerUserId = `it_upload_owner_${Date.now()}`;
  const secondOwnerUserId = `it_upload_second_owner_${Date.now()}`;
  let uploadedFilePath;
  let server;

  try {
    server = startServer(3036);
    await waitForHealth(server.baseUrl);

    // Create a minimal valid 1x1 PNG in memory.
    const pngBytes = Buffer.from(
      '89504e470d0a1a0a0000000d494844520000000100000001080000000003' +
      '7a3f560000000a4944415408d76360000000020001e221bc330000000049454e44ae426082',
      'hex',
    );
    assert.equal(typeof FormData, 'function');
    assert.equal(typeof Blob, 'function');

    const fd = new FormData();
    fd.append('image', new Blob([pngBytes], { type: 'image/png' }), 'test.png');
    const okRes = await fetch(`${server.baseUrl}/uploads/image`, {
      method: 'POST',
      body: fd,
    });
    assert.equal(okRes.status, 201);
    const okPayload = await okRes.json();
    assert.ok(typeof okPayload.url === 'string');
    assert.ok(okPayload.url.includes('uploads'));
    assert.ok(typeof okPayload.filename === 'string');
    uploadedFilePath = path.join(BACKEND_DIR, 'uploads', okPayload.filename);
    assert.equal(fs.existsSync(uploadedFilePath), true);

    const eventResponse = await postJson(server.baseUrl, '/events', {
      hosterId: ownerUserId,
      title: 'Upload cleanup event',
      eventDate: '2026-09-04T10:00:00.000Z',
      photoUrl: okPayload.url,
    });
    assert.equal(eventResponse.response.status, 201);

    const secondEventResponse = await postJson(server.baseUrl, '/events', {
      hosterId: secondOwnerUserId,
      title: 'Shared upload cleanup event',
      eventDate: '2026-09-05T10:00:00.000Z',
      photoUrl: okPayload.url,
    });
    assert.equal(secondEventResponse.response.status, 201);

    const deleteResponse = await postJson(server.baseUrl, '/account/delete-data', {
      userId: ownerUserId,
    });
    assert.equal(deleteResponse.response.status, 200);
    assert.equal(fs.existsSync(uploadedFilePath), true);

    const secondDeleteResponse = await postJson(server.baseUrl, '/account/delete-data', {
      userId: secondOwnerUserId,
    });
    assert.equal(secondDeleteResponse.response.status, 200);
    assert.equal(fs.existsSync(uploadedFilePath), false);

    const badFd = new FormData();
    badFd.append('image', new Blob(['not-an-image'], { type: 'text/plain' }), 'bad.txt');
    const badRes = await fetch(`${server.baseUrl}/uploads/image`, {
      method: 'POST',
      body: badFd,
    });
    assert.equal(badRes.status, 400);
    const badPayload = await badRes.json();
    assert.match(badPayload?.error || '', /JPEG|PNG|WebP|GIF/i);
  } catch (error) {
    const extraLogs = server ? `server logs:\n${server.getLogs()}` : '';
    throw new Error(`${error.message}\n\n${extraLogs}`);
  } finally {
    await stopServer(server?.child);
    if (uploadedFilePath && fs.existsSync(uploadedFilePath)) {
      fs.unlinkSync(uploadedFilePath);
    }
  }
});

test('Stripe initiate validates input and rejects missing secret key', async () => {
  const suffix = `${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;
  const hosterId = `it_stripe_user_${suffix}`;
  let server;

  try {
    // Force missing secret in test so endpoint behavior is deterministic.
    server = startServer(3037, { STRIPE_SECRET_KEY: '' });
    await waitForHealth(server.baseUrl);

    const missingFields = await postJson(server.baseUrl, '/payments/stripe/initiate', {
      amount: 9.99,
    });
    assert.equal(missingFields.response.status, 400);

    const ok = await postJson(server.baseUrl, '/payments/stripe/initiate', {
      eventId: `event_${suffix}`,
      hosterId,
      amount: 12.5,
    });
    assert.equal(ok.response.status, 503);
    assert.match(String(ok.payload?.error || ''), /Stripe ist nicht konfiguriert/);
  } catch (error) {
    const extraLogs = server ? `server logs:\n${server.getLogs()}` : '';
    throw new Error(`${error.message}\n\n${extraLogs}`);
  } finally {
    if (server) {
      await postJson(server.baseUrl, '/account/delete-data', { userId: hosterId });
    }
    await stopServer(server?.child);
  }
});
