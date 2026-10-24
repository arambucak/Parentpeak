const PREMIUM_ACCESS_STATES = new Set(['active', 'trial', 'grace']);

function toValidDate(value) {
  if (value == null) return null;
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function buildEntitlementSnapshot(record, now = new Date()) {
  const validFrom = toValidDate(record.validFrom);
  const validUntil = toValidDate(record.validUntil);
  const verifiedAt = toValidDate(record.verifiedAt);
  const revokedAt = toValidDate(record.revokedAt);
  const isCurrentPremium =
    record.tier === 'premium' &&
    PREMIUM_ACCESS_STATES.has(record.access) &&
    verifiedAt !== null &&
    validFrom !== null &&
    validUntil !== null &&
    validFrom <= now &&
    validUntil > now &&
    revokedAt === null;
  const access = isCurrentPremium
    ? record.access
    : revokedAt
      ? 'revoked'
      : validUntil && validUntil <= now
        ? 'expired'
        : 'none';

  return {
    state: 'verified',
    tier: isCurrentPremium ? 'premium' : 'free',
    access,
    validFrom: validFrom?.toISOString() ?? null,
    validUntil: validUntil?.toISOString() ?? null,
    verifiedAt: verifiedAt?.toISOString() ?? null,
    adsEligibleByEntitlement: false,
  };
}

async function readEntitlementSnapshot(prisma, userId, now = new Date()) {
  if (typeof userId !== 'string' || !userId.trim()) {
    throw new TypeError('A verified user ID is required');
  }

  const record = await prisma.userEntitlement.upsert({
    where: { userId },
    create: {
      userId,
      tier: 'free',
      access: 'none',
      validFrom: null,
      validUntil: null,
      verifiedAt: now,
      adsEligibleByEntitlement: false,
      revokedAt: null,
    },
    update: {},
  });
  const snapshot = buildEntitlementSnapshot(record, now);
  const shouldPersistDowngrade =
    record.tier !== snapshot.tier ||
    record.access !== snapshot.access ||
    record.adsEligibleByEntitlement !== false;

  if (!shouldPersistDowngrade) return snapshot;

  const normalized = await prisma.userEntitlement.updateMany({
    where: {
      userId,
      tier: record.tier,
      access: record.access,
      validFrom: record.validFrom,
      validUntil: record.validUntil,
      verifiedAt: record.verifiedAt,
      adsEligibleByEntitlement: record.adsEligibleByEntitlement,
      revokedAt: record.revokedAt,
    },
    data: {
      tier: snapshot.tier,
      access: snapshot.access,
      adsEligibleByEntitlement: false,
    },
  });
  if (normalized.count > 0) return snapshot;

  const latest = await prisma.userEntitlement.findUnique({ where: { userId } });
  if (!latest) throw new Error('Entitlement snapshot disappeared during update');
  return buildEntitlementSnapshot(latest, now);
}

module.exports = {
  buildEntitlementSnapshot,
  readEntitlementSnapshot,
};
