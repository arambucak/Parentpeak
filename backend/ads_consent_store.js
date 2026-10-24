const { randomUUID } = require('node:crypto');

const ADS_CONSENT_VERSION = 'ads.consent.v1';
const consentMetadata = {
  decision: true,
  consentVersion: true,
  consentRevision: true,
  consentedAt: true,
  withdrawnAt: true,
  createdAt: true,
  updatedAt: true,
};

function requireOwner(userId) {
  if (typeof userId !== 'string' || !userId.trim() || userId !== userId.trim()) {
    throw new TypeError('Verified account identity required');
  }
}

function consentSnapshot(record) {
  return {
    ...record,
    decision: record.consentVersion === ADS_CONSENT_VERSION &&
      ['unknown', 'denied', 'granted'].includes(record.decision)
      ? record.decision : 'unknown',
  };
}

async function readAdsConsent(prisma, userId) {
  requireOwner(userId);
  const record = await prisma.adsConsent.upsert({
    where: { userId },
    create: {
      userId,
      consentRevision: randomUUID(),
    },
    update: {},
    select: consentMetadata,
  });
  return consentSnapshot(record);
}

async function setAdsConsent(prisma, userId, input, now = new Date()) {
  requireOwner(userId);
  const keys = Object.keys(input || {});
  if (!input || !['granted', 'denied'].includes(input.decision) ||
      input.consentVersion !== ADS_CONSENT_VERSION ||
      typeof input.consentRevision !== 'string' ||
      !/^[a-f0-9-]{36}$/.test(input.consentRevision) ||
      keys.some(key => !['decision', 'consentVersion', 'consentRevision'].includes(key))) {
    throw Object.assign(new Error('Invalid consent decision or version'), {
      status: 400, code: 'invalid_ads_consent',
    });
  }
  // A stale grant must not undo a withdrawal from another device.
  const result = await prisma.adsConsent.updateMany({
    where: { userId, consentRevision: input.consentRevision },
    data: {
      decision: input.decision,
      consentVersion: ADS_CONSENT_VERSION,
      consentRevision: randomUUID(),
      consentedAt: input.decision === 'granted' ? now : null,
      withdrawnAt: input.decision === 'denied' ? now : null,
    },
  });
  if (result.count !== 1) {
    throw Object.assign(new Error('Consent changed; reload before deciding'), {
      status: 409, code: 'ads_consent_conflict',
    });
  }
  const record = await prisma.adsConsent.findUnique({
    where: { userId }, select: consentMetadata,
  });
  if (!record) throw new Error('Consent snapshot disappeared');
  return consentSnapshot(record);
}

module.exports = { ADS_CONSENT_VERSION, readAdsConsent, setAdsConsent };
