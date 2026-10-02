const MODES = new Set(['legacyApproval', 'direct', 'interest']);
const CONFIRMED = ['approved', 'accepted', 'attended'];

function fail(status, message) {
  const error = new Error(message);
  error.httpStatus = status;
  throw error;
}

function validateEventMode(mode, externalUrl) {
  if (!MODES.has(mode)) fail(400, 'Invalid participationMode');
  if (externalUrl != null && externalUrl !== '') {
    if (typeof externalUrl !== 'string' || externalUrl.length > 2048 || externalUrl.trim() !== externalUrl) {
      fail(400, 'Invalid externalUrl');
    }
    let url;
    try { url = new URL(externalUrl); } catch { fail(400, 'Invalid externalUrl'); }
    if (!['https:', 'http:'].includes(url.protocol) || !url.hostname || url.username || url.password) {
      fail(400, 'Invalid externalUrl');
    }
  }
  if (mode === 'interest' && !externalUrl) fail(400, 'externalUrl required for shared offers');
  if (mode !== 'interest' && externalUrl) fail(400, 'externalUrl only allowed for shared offers');
}

async function changeParticipation(prisma, { eventId, userId, action = 'join', authorize }) {
  if (!['join', 'withdraw', 'approve', 'decline', 'acceptInvite', 'declineInvite'].includes(action)) fail(400, 'Invalid action');
  return prisma.$transaction(async transaction => {
    await transaction.$queryRaw`SELECT "id" FROM "Event" WHERE "id" = ${eventId} FOR UPDATE`;
    const event = await transaction.event.findUnique({ where: { id: eventId } });
    if (!event) fail(404, 'Event not found');
    const mode = event.participationMode || 'legacyApproval';
    if (!MODES.has(mode)) fail(409, 'Unsupported participation mode');
    const current = await transaction.eventParticipation.findUnique({
      where: { eventId_userId: { eventId, userId } },
    });
    if (authorize) await authorize(transaction, event, current);
    const invitationResponse = action === 'acceptInvite' || action === 'declineInvite';
    const ownerResponse = action === 'approve' || action === 'decline';
    if (!ownerResponse && event.hosterId === userId) fail(403, 'Hosts cannot join their own event');
    if (action === 'withdraw') {
      if (!current || current.status === 'cancelled') return current;
      return transaction.eventParticipation.update({ where: { id: current.id }, data: { status: 'cancelled' } });
    }
    if (event.status === 'cancelled' || event.status === 'completed' || new Date(event.startDate) <= new Date()) {
      fail(409, 'Event is no longer open');
    }
    if (invitationResponse && mode === 'interest') fail(409, 'Interest is not a booking');
    if (invitationResponse && current?.status === 'pending') return current;
    if (action === 'acceptInvite' && CONFIRMED.includes(current?.status)) return current;
    if (ownerResponse) {
      if (!current || current.status !== 'pending') fail(409, 'Only pending requests can be reviewed');
      if (mode === 'interest') fail(409, 'Interest is not a booking');
    } else if (!invitationResponse && current && !['cancelled', 'declined', 'invited'].includes(current.status)) {
      return current;
    }
    const status = action === 'decline' || action === 'declineInvite' ? 'declined'
      : action === 'acceptInvite' ? 'accepted'
        : action === 'approve' || mode === 'direct' ? 'approved'
        : mode === 'interest' ? 'interested' : 'pending';
    if (invitationResponse && current?.status === status) return current;
    if (CONFIRMED.includes(status) && event.maxParticipants != null) {
      const count = await transaction.eventParticipation.count({
        where: { eventId, status: { in: CONFIRMED } },
      });
      if (count >= event.maxParticipants) fail(409, 'Event is full');
    }
    return transaction.eventParticipation.upsert({
      where: { eventId_userId: { eventId, userId } },
      update: { status }, create: { eventId, userId, status },
    });
  });
}

async function updateOwnedEvent(prisma, id, userId, data) {
  return prisma.$transaction(async transaction => {
    await transaction.$queryRaw`SELECT "id" FROM "Event" WHERE "id" = ${id} FOR UPDATE`;
    const event = await transaction.event.findUnique({ where: { id } });
    if (!event) fail(404, 'Event not found');
    if (event.hosterId !== userId) fail(403, 'Host only');
    const mode = data.participationMode !== undefined ? data.participationMode : event.participationMode ?? 'legacyApproval';
    const externalUrl = data.externalUrl !== undefined ? data.externalUrl : event.externalUrl;
    validateEventMode(mode, externalUrl);
    if (mode !== (event.participationMode || 'legacyApproval') && event.participationMode && event.participationMode !== 'legacyApproval') {
      fail(409, 'Published participation mode cannot be changed');
    }
    if (mode === 'interest' && (data.visibility || event.visibility) !== 'publicNearby') fail(400, 'Shared offers must be public');
    const count = await transaction.eventParticipation.count({ where: { eventId: id, status: { in: CONFIRMED } } });
    if (mode === 'interest' && count > 0) fail(409, 'Confirmed meetup cannot become an external offer');
    const capacity = data.maxParticipants !== undefined ? data.maxParticipants : event.maxParticipants;
    if (mode === 'direct' && capacity == null) fail(400, 'Direct meetup requires capacity');
    if (mode !== 'interest' && capacity != null && (!Number.isInteger(capacity) || capacity < Math.max(1, count))) {
      fail(400, 'Capacity cannot be lower than confirmed attendance');
    }
    if (data.startDate !== undefined && (!Number.isFinite(new Date(data.startDate).getTime()) || new Date(data.startDate) <= new Date())) {
      fail(400, 'Future startDate required');
    }
    return transaction.event.update({ where: { id }, data: {
      ...data, ...(mode === 'interest' && { maxParticipants: null }),
    }, include: { participants: true } });
  });
}

module.exports = { changeParticipation, updateOwnedEvent, validateEventMode, CONFIRMED };