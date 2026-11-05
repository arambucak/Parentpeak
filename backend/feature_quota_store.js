const { randomUUID } = require('node:crypto');
const { readEntitlementSnapshot } = require('./entitlement_store');

const LIMITS = Object.freeze({ chat: 3, recipes: 1, events: 3, contacts: 3 });

class FeatureQuotaError extends Error {
  constructor(code, feature, status, snapshot) {
    super(code);
    this.code = code;
    this.feature = feature;
    this.status = status;
    this.snapshot = snapshot;
  }
}

function quotaPeriod(feature, now) {
  if (!Object.hasOwn(LIMITS, feature)) throw new TypeError('Unknown quota feature');
  const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  let end;
  if (feature === 'events') {
    start.setUTCDate(start.getUTCDate() - (start.getUTCDay() + 6) % 7);
    end = new Date(start);
    end.setUTCDate(end.getUTCDate() + 7);
  } else if (feature === 'contacts') {
    start.setUTCDate(1);
    end = new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth() + 1, 1));
  } else {
    end = new Date(start);
    end.setUTCDate(end.getUTCDate() + 1);
  }
  return { start, end };
}

function limitsEnabled() {
  const value = process.env.PP_ABO_LIMITS_ENABLED ?? 'false';
  if (!['true', 'false'].includes(value)) {
    throw new Error('PP_ABO_LIMITS_ENABLED must be true or false');
  }
  return value === 'true';
}

async function serverNow(db) {
  const [row] = await db.$queryRawUnsafe('SELECT CURRENT_TIMESTAMP AS "now"');
  if (!(row?.now instanceof Date) || Number.isNaN(row.now.getTime())) {
    throw new Error('Database time unavailable');
  }
  return row.now;
}

function usageSnapshot(feature, period, count, premium, enabled) {
  return {
    feature, enabled, premium, limit: LIMITS[feature],
    used: count, remaining: premium || !enabled ? null : Math.max(0, LIMITS[feature] - count),
    periodStart: period.start.toISOString(), resetsAt: period.end.toISOString(),
  };
}

async function quotaStatus(db, userId, enabled = limitsEnabled()) {
  const now = await serverNow(db);
  const entitlement = await readEntitlementSnapshot(db, userId, now);
  const items = {};
  for (const feature of Object.keys(LIMITS)) {
    const period = quotaPeriod(feature, now);
    const rows = enabled ? await db.$queryRawUnsafe(
      'SELECT "count" FROM "FeatureQuota" WHERE "userId" = $1 AND "feature" = $2 AND "periodStart" = $3',
      userId, feature, period.start,
    ) : [];
    items[feature] = usageSnapshot(feature, period, rows[0]?.count ?? 0,
      entitlement.tier === 'premium', enabled);
  }
  return { enabled, serverTime: now.toISOString(), tier: entitlement.tier, items };
}

// The row lock serializes all devices/instances for one UID, feature and UTC
// period. Receipt creation and count increment commit together, or neither does.
async function consumeQuota(db, userId, feature, itemKey = randomUUID(),
  enabled = limitsEnabled(), operation) {
  if (typeof userId !== 'string' || !userId.trim()) throw new TypeError('Verified UID required');
  if (typeof itemKey !== 'string' || !itemKey.trim() || itemKey.length > 512) {
    throw new TypeError('Invalid quota item');
  }
  return db.$transaction(async tx => {
    const now = await serverNow(tx);
    const period = quotaPeriod(feature, now);
    const entitlement = await readEntitlementSnapshot(tx, userId, now);
    const premium = entitlement.tier === 'premium';
    await tx.$executeRawUnsafe(
      `INSERT INTO "FeatureQuota" ("userId", "feature", "periodStart", "count")
       VALUES ($1, $2, $3, 0) ON CONFLICT DO NOTHING`, userId, feature, period.start,
    );
    const [bucket] = await tx.$queryRawUnsafe(
      `SELECT "count" FROM "FeatureQuota" WHERE "userId" = $1 AND "feature" = $2
       AND "periodStart" = $3 FOR UPDATE`, userId, feature, period.start,
    );
    const [existing] = await tx.$queryRawUnsafe(
      `SELECT * FROM "FeatureQuotaItem" WHERE "userId" = $1 AND "feature" = $2
       AND "periodStart" = $3 AND "itemKey" = $4`, userId, feature, period.start, itemKey,
    );
    const snapshot = usageSnapshot(feature, period, bucket.count, premium, enabled);
    if (existing) {
      if (operation) await operation(tx);
      return { ...snapshot, receipt: existing.id, repeated: true };
    }
    if (enabled && !premium && bucket.count >= LIMITS[feature]) {
      throw new FeatureQuotaError('feature_limit_reached', feature, 429, snapshot);
    }
    if (operation) await operation(tx);
    const id = randomUUID();
    await tx.$executeRawUnsafe(
      `INSERT INTO "FeatureQuotaItem" ("id", "userId", "feature", "periodStart", "itemKey", "expiresAt")
       VALUES ($1, $2, $3, $4, $5, $6)`, id, userId, feature, period.start, itemKey, period.end,
    );
    const count = bucket.count + (enabled && !premium ? 1 : 0);
    if (count !== bucket.count) {
      await tx.$executeRawUnsafe(
        `UPDATE "FeatureQuota" SET "count" = "count" + 1
         WHERE "userId" = $1 AND "feature" = $2 AND "periodStart" = $3`,
        userId, feature, period.start,
      );
    }
    return { ...usageSnapshot(feature, period, count, premium, enabled),
      receipt: id, repeated: false };
  });
}

async function requireFinancePremium(db, userId, enabled = limitsEnabled()) {
  if (!enabled) return;
  const entitlement = await readEntitlementSnapshot(db, userId, await serverNow(db));
  if (entitlement.tier !== 'premium') {
    throw new FeatureQuotaError('feature_premium_required', 'finance', 403);
  }
}

async function useRecipeReceipt(db, userId, receipt) {
  const changed = await db.$executeRawUnsafe(
    `UPDATE "FeatureQuotaItem" SET "aiUsed" = true WHERE "id" = $1 AND "userId" = $2
     AND "feature" = 'recipes' AND "expiresAt" > CURRENT_TIMESTAMP AND "aiUsed" = false
     AND "result" IS NULL`, receipt, userId,
  );
  if (changed !== 1) throw new FeatureQuotaError('recipe_receipt_invalid', 'recipes', 409);
}

async function todayRecipe(db, userId) {
  const period = quotaPeriod('recipes', await serverNow(db));
  const [row] = await db.$queryRawUnsafe(
    `SELECT "result" FROM "FeatureQuotaItem" WHERE "userId" = $1 AND "feature" = 'recipes'
     AND "periodStart" = $2 AND "result" IS NOT NULL ORDER BY "id" LIMIT 1`, userId, period.start,
  );
  return { item: row?.result ?? null, periodStart: period.start.toISOString(),
    resetsAt: period.end.toISOString() };
}

async function saveRecipeResult(db, userId, receipt, result) {
  if (!result || typeof result !== 'object' || Array.isArray(result) ||
      typeof result.title !== 'string' || !Array.isArray(result.ingredients) ||
      !Array.isArray(result.steps) || JSON.stringify(result).length > 50000) {
    throw new FeatureQuotaError('recipe_result_invalid', 'recipes', 400);
  }
  const changed = await db.$executeRawUnsafe(
    `UPDATE "FeatureQuotaItem" SET "result" = $3::jsonb WHERE "id" = $1 AND "userId" = $2
     AND "feature" = 'recipes' AND "expiresAt" > CURRENT_TIMESTAMP AND "result" IS NULL`,
    receipt, userId, JSON.stringify(result),
  );
  if (changed !== 1) throw new FeatureQuotaError('recipe_receipt_invalid', 'recipes', 409);
}

module.exports = { LIMITS, FeatureQuotaError, quotaPeriod, limitsEnabled, serverNow,
  quotaStatus, consumeQuota, requireFinancePremium, useRecipeReceipt, todayRecipe, saveRecipeResult };
