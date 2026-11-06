const CRITICAL_REASONS = new Set(['child_safety', 'sexual_content', 'violence_threat', 'self_harm']);
const REASONS = new Set([...CRITICAL_REASONS, 'harassment', 'spam', 'fraud', 'inappropriate', 'misinformation', 'other']);
const LEGACY_REASONS = {
  insult: 'harassment', fake: 'fraud', false_info: 'misinformation',
  hostile: 'harassment', unsafe: 'inappropriate',
  'unpassender ton': 'harassment',
  'nicht hilfreich': 'other',
  'nicht elternfreundlich': 'inappropriate',
  'fachlich fragwuerdig': 'misinformation',
  'fachlich fragwürdig': 'misinformation',
  'spam oder irrefuehrung': 'spam',
  'spam oder irreführung': 'spam',
  'unpassender inhalt': 'inappropriate',
  'betrug oder unsicherheit': 'fraud',
  'andere sorge': 'other',
};

function normalizeReportReason(value, { event = false } = {}) {
  const reason = String(value || '').trim().toLowerCase();
  if (event && reason === 'expired') return reason;
  if (Object.hasOwn(LEGACY_REASONS, reason)) return LEGACY_REASONS[reason];
  if (REASONS.has(reason)) return reason;
  const legacyPrefix = reason.split(':', 1)[0].trim();
  return Object.hasOwn(LEGACY_REASONS, legacyPrefix) ? LEGACY_REASONS[legacyPrefix] : 'other';
}

function reasonSeverity(reason) {
  return CRITICAL_REASONS.has(normalizeReportReason(reason)) ? 'critical' : 'normal';
}

const REASON_LABELS_DE = {
  child_safety: 'Gefährdung eines Kindes',
  sexual_content: 'Sexueller Inhalt / Missbrauch',
  violence_threat: 'Gewalt / Bedrohung',
  self_harm: 'Selbstgefährdung / Suizid',
  harassment: 'Belästigung / Hassrede',
  spam: 'Spam / Werbung',
  fraud: 'Betrug / Fake-Profil',
  inappropriate: 'Unangemessener Inhalt',
  misinformation: 'Falsche Information',
  other: 'Sonstiges',
  expired: 'Abgelaufen',
};

function reasonLabelDe(reason) {
  return Object.hasOwn(REASON_LABELS_DE, reason) ? REASON_LABELS_DE[reason] : reason;
}

function escapeEmailHtml(value) {
  return String(value).replace(/[&<>"']/g, char => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[char]);
}

function withReportSeverity(report) {
  const reason = normalizeReportReason(report.reason, {
    event: report.source === 'community_event' || ['community_event', 'event'].includes(report.contentType),
  });
  return { ...report, reason, severity: reasonSeverity(reason) };
}

function criticalFirst(a, b) {
  return Number(b.severity === 'critical') - Number(a.severity === 'critical')
    || new Date(b.createdAt || b.lastReportedAt || b.reportedAt || 0)
      - new Date(a.createdAt || a.lastReportedAt || a.reportedAt || 0);
}

const LEGACY_COUNTS = {
  safety: ['SafetyReport', 'reportedUserId', 'reporterUserId'],
  event_chat: ['ChatReport', 'messageId', 'reportedById'],
  treasure: ['TreasureReport', 'treasureId', 'reporterUserId'],
  food_feed: ['RecipeReport', 'recipeId', 'reportedById'],
  community_event: ['CommunityEventFlag', 'eventId', 'userId'],
};

function createModerationService({ prisma, sendEmail, sendPushToUser, adminUserIds, env = process.env, logger = console }) {
  let schemaReady;
  async function ensureSchema() {
    if (!schemaReady) {
      schemaReady = (async () => {
        await prisma.$executeRawUnsafe(`CREATE TABLE IF NOT EXISTS "ModerationReport" (
          "id" TEXT PRIMARY KEY, "source" TEXT NOT NULL, "targetId" TEXT NOT NULL,
          "reporterUserId" TEXT NOT NULL, "reason" TEXT NOT NULL,
          "status" TEXT NOT NULL DEFAULT 'pending', "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )`);
        await prisma.$executeRawUnsafe(`CREATE INDEX IF NOT EXISTS "idx_moderation_target"
          ON "ModerationReport" ("source", "targetId")`);
        await prisma.$executeRawUnsafe(`CREATE TABLE IF NOT EXISTS "ModerationNotificationClaim" (
          "key" TEXT PRIMARY KEY, "expiresAt" TIMESTAMPTZ
        )`);
        await prisma.$executeRawUnsafe(`ALTER TABLE "ModerationNotificationClaim"
          ADD COLUMN IF NOT EXISTS "leaseToken" TEXT`);
      })().catch(error => { schemaReady = null; throw error; });
    }
    return schemaReady;
  }

  async function persistModerationReport({ id, source, targetId, reporterUserId, reason, contentType }) {
    await ensureSchema();
    await prisma.$executeRawUnsafe(`INSERT INTO "ModerationReport"
      ("id", "source", "targetId", "reporterUserId", "reason") VALUES ($1,$2,$3,$4,$5)
      ON CONFLICT ("id") DO NOTHING`, `${source}:${id}`, source, targetId, reporterUserId,
    normalizeReportReason(reason, { event: source === 'community_event' || contentType === 'event' }));
  }

  async function claim(key) {
    const token = randomUUID();
    const rows = await prisma.$queryRawUnsafe(`INSERT INTO "ModerationNotificationClaim" ("key", "expiresAt", "leaseToken")
      VALUES ($1, NOW() + INTERVAL '60 seconds', $2)
      ON CONFLICT ("key") DO UPDATE SET "expiresAt" = EXCLUDED."expiresAt", "leaseToken" = EXCLUDED."leaseToken"
      WHERE "ModerationNotificationClaim"."expiresAt" IS NOT NULL
        AND "ModerationNotificationClaim"."expiresAt" <= NOW()
      RETURNING "key"`, key, token);
    return rows.length > 0 ? { key, token } : null;
  }

  async function completeClaim(lease, success, cooldown) {
    if (!lease) return;
    if (success) {
      await prisma.$executeRawUnsafe(`UPDATE "ModerationNotificationClaim"
        SET "expiresAt" = CASE WHEN $3::boolean THEN NOW() + INTERVAL '15 minutes' ELSE NULL END,
            "leaseToken" = NULL WHERE "key" = $1 AND "leaseToken" = $2`,
      lease.key, lease.token, cooldown);
    } else {
      await prisma.$executeRawUnsafe(`DELETE FROM "ModerationNotificationClaim"
        WHERE "key" = $1 AND "leaseToken" = $2`, lease.key, lease.token);
    }
  }

  function bounded(operation) {
    const configured = Number.parseInt(env.MODERATION_SEND_TIMEOUT_MS || '10000', 10);
    const timeoutMs = configured > 0 ? Math.min(configured, 30000) : 10000;
    let timer;
    return Promise.race([
      Promise.resolve().then(operation),
      new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error(`notification timeout (${timeoutMs}ms)`)), timeoutMs);
      }),
    ]).finally(() => clearTimeout(timer));
  }

  async function distinctReporters({ source, targetId }) {
    const legacy = LEGACY_COUNTS[source];
    const legacySql = legacy
      ? `UNION SELECT "${legacy[2]}" AS reporter FROM "${legacy[0]}" WHERE "${legacy[1]}" = $2`
      : '';
    const rows = await prisma.$queryRawUnsafe(`SELECT COUNT(DISTINCT reporter)::int AS n FROM (
      SELECT "reporterUserId" AS reporter FROM "ModerationReport" WHERE "source" = $1 AND "targetId" = $2
      ${legacySql}) reporters`, source, targetId);
    return Number(rows[0]?.n || 0);
  }

  async function notifyModeration(report) {
    if (String(env.MODERATION_NOTIFY_ENABLED || 'true').toLowerCase() === 'false'
      || env.MODERATION_NOTIFY_ENABLED === '0') return;
    const reason = normalizeReportReason(report.reason, {
      event: report.source === 'community_event' || report.contentType === 'event',
    });
    const severity = reasonSeverity(reason);
    // Push is deliberately independent of email claims and database availability.
    const pushes = Promise.all([...adminUserIds].map(async userId => {
      try {
        const sent = await bounded(() => sendPushToUser(userId, {
          title: severity === 'critical' ? 'ParentPeak · Kritische Meldung' : 'ParentPeak · Neue Meldung',
          body: 'Bitte im Moderations-Dashboard prüfen.',
          data: { type: 'moderation_report', reportId: report.id, source: report.source, severity },
        }));
        if (sent === false) logger.error('[moderation] Push nicht versendet:', userId);
      } catch (error) {
        logger.error('[moderation] Push fehlgeschlagen:', error.message);
      }
    }));
    let criticalClaim;
    let thresholdClaim;
    try {
      await persistModerationReport(report);
      const count = await distinctReporters(report);
      const configuredThreshold = Number.parseInt(env.PARENT_MATCHING_REPORT_HIDE_THRESHOLD || '3', 10);
      const threshold = configuredThreshold > 0 ? configuredThreshold : 3;
      criticalClaim = severity === 'critical'
        && await claim(JSON.stringify(['critical', report.source, report.targetId, reason]));
      thresholdClaim = count >= threshold
        && await claim(JSON.stringify(['threshold', report.source, report.targetId]));
      if (!criticalClaim && !thresholdClaim) return;
      const timestamp = new Intl.DateTimeFormat('de-DE', {
        timeZone: 'Europe/Berlin', dateStyle: 'medium', timeStyle: 'long',
      }).format(new Date());
      const text = `ParentPeak – Moderation\n\n${severity === 'critical' ? 'Kritische Meldung' : 'Meldeschwelle erreicht'}`
        + `\nGrund: ${reasonLabelDe(reason)}\nBereich: ${report.source}\nVerschiedene meldende Konten: ${count}`
        + `\nZeit (Europe/Berlin): ${timestamp}\n\nBitte im geschützten Moderations-Dashboard prüfen.`;
      const html = `<div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;color:#203b35">`
        + `<h1 style="color:#287568">ParentPeak</h1><p>${escapeEmailHtml(text).replace(/\n/g, '<br>')}</p></div>`;
      const sent = await bounded(() => sendEmail({
        to: env.MODERATION_EMAIL || 'support@parentpeak.com',
        subject: `ParentPeak · ${severity === 'critical' ? 'Kritische Meldung' : 'Meldeschwelle erreicht'}`,
        text, html,
      }));
      if (sent !== true) throw new Error('E-Mail nicht versendet (Provider fehlt oder false).');
      await completeClaim(criticalClaim, true, true);
      criticalClaim = null;
      await completeClaim(thresholdClaim, true, false);
      thresholdClaim = null;
    } catch (error) {
      logger.error('[moderation] Benachrichtigung fehlgeschlagen:', error.message);
      for (const lease of [criticalClaim, thresholdClaim]) {
        try {
          await completeClaim(lease, false);
        } catch (releaseError) {
          logger.error('[moderation] Claim-Freigabe fehlgeschlagen; Lease läuft ab:', releaseError.message);
        }
      }
    } finally {
      await pushes;
    }
  }

  async function loadAdditionalReports(status) {
    await ensureSchema();
    const rows = await prisma.$queryRawUnsafe(`
      SELECT "id", 'treasure' AS "source", "treasureId" AS "targetId", "reporterUserId", "reason", "status", "createdAt" FROM "TreasureReport"
      UNION ALL SELECT "id", 'food_feed', "recipeId", "reportedById", "reason", "status", "createdAt" FROM "RecipeReport"
      UNION ALL SELECT "id", 'event_chat', "messageId", "reportedById", "reason", "status", "createdAt" FROM "ChatReport"
      UNION ALL SELECT f."id", 'community_event', f."eventId", f."userId", f."reason",
        COALESCE(m."status", 'pending'), f."createdAt" FROM "CommunityEventFlag" f
        LEFT JOIN "ModerationReport" m ON m."id" = 'community_event:' || f."id"
      UNION ALL SELECT "id", "source", "targetId", "reporterUserId", "reason", "status", "createdAt" FROM "ModerationReport" WHERE "source" = 'weekly'`);
    return rows.filter(row => status === 'all' || row.status === status).map(row => withReportSeverity({
      ...row, reportedUserId: `${row.source}:${row.targetId}`, contentType: row.source, content: '',
    }));
  }

  async function resolveEventFlags(column, value) {
    await prisma.$executeRawUnsafe(`INSERT INTO "ModerationReport"
      ("id", "source", "targetId", "reporterUserId", "reason", "status", "createdAt")
      SELECT 'community_event:' || "id", 'community_event', "eventId", "userId", "reason", 'resolved', "createdAt"
      FROM "CommunityEventFlag" WHERE "${column}" = $1
      ON CONFLICT ("id") DO UPDATE SET "status" = 'resolved'`, value);
  }

  async function resolveAdditionalReport({ reportId, reportedUserId }) {
    await ensureSchema();
    const sources = {
      treasure: ['TreasureReport', 'treasureId'], food_feed: ['RecipeReport', 'recipeId'],
      event_chat: ['ChatReport', 'messageId'],
    };
    if (reportId) {
      for (const [table] of Object.values(sources)) {
        await prisma.$executeRawUnsafe(`UPDATE "${table}" SET "status" = 'resolved' WHERE "id" = $1`, reportId);
      }
      await prisma.$executeRawUnsafe(`UPDATE "ModerationReport" SET "status" = 'resolved' WHERE "id" = $1`, reportId);
      await resolveEventFlags('id', reportId);
    } else if (reportedUserId) {
      const colon = reportedUserId.indexOf(':');
      const source = reportedUserId.slice(0, colon);
      const targetId = reportedUserId.slice(colon + 1);
      if (sources[source]) {
        const [table, target] = sources[source];
        await prisma.$executeRawUnsafe(`UPDATE "${table}" SET "status" = 'resolved' WHERE "${target}" = $1`, targetId);
      }
      if (source === 'community_event') await resolveEventFlags('eventId', targetId);
      await prisma.$executeRawUnsafe(`UPDATE "ModerationReport" SET "status" = 'resolved'
        WHERE "source" = $1 AND "targetId" = $2`, source, targetId);
    }
  }

  // Sicherheitsnetz: fasst offene Meldungen periodisch zusammen und mailt sie.
  // Fängt den seltenen Fall ab, dass eine Sofort-Benachrichtigung (notifyModeration)
  // scheiterte, ohne dass der Melde-Request fehlschlagen durfte. Rein lesend +
  // E-Mail; verändert KEINEN Status, kann also nichts kaputtmachen. Berücksichtigt
  // nur Meldungen, die mindestens MODERATION_DIGEST_MIN_AGE_MIN alt sind, damit
  // frische Meldungen (deren Sofort-Mail gerade läuft) nicht doppelt gemailt werden.
  async function sendPendingDigest() {
    await ensureSchema();
    const minAgeMin = Math.max(
      0, Number.parseInt(env.MODERATION_DIGEST_MIN_AGE_MIN || '30', 10) || 0);
    const configuredThreshold = Number.parseInt(
      env.PARENT_MATCHING_REPORT_HIDE_THRESHOLD || '3', 10);
    const threshold = configuredThreshold > 0 ? configuredThreshold : 3;

    // Offene Meldungen je Ziel: Anzahl, verschiedene Melder, kritisch?, älteste offene.
    const rows = await prisma.$queryRawUnsafe(`
      SELECT "source", "targetId",
             COUNT(*)::int AS "reportCount",
             COUNT(DISTINCT "reporterUserId")::int AS "distinctReporters",
             ARRAY_AGG(DISTINCT "reason" ORDER BY "reason") AS "reasons",
             BOOL_OR(LOWER(BTRIM("reason")) IN ('child_safety','sexual_content','violence_threat','self_harm')) AS "critical",
             MIN("createdAt") AS "oldestAt",
             MAX("createdAt") AS "newestAt"
      FROM "ModerationReport"
      WHERE "status" = 'pending'
        AND "createdAt" <= NOW() - ($1 || ' minutes')::interval
      GROUP BY "source", "targetId"
      ORDER BY "critical" DESC, MIN("createdAt") ASC`, String(minAgeMin));

    // Nur handlungsrelevante: kritische immer, normale ab Melder-Schwelle.
    const pending = rows.filter(
      r => r.critical === true || Number(r.distinctReporters) >= threshold);
    if (pending.length === 0) {
      return { sent: false, pendingCount: 0 };
    }

    const criticalCount = pending.filter(r => r.critical === true).length;
    const fmt = new Intl.DateTimeFormat('de-DE', {
      timeZone: 'Europe/Berlin', dateStyle: 'medium', timeStyle: 'short',
    });
    const lines = pending.map(r => {
      const tag = r.critical === true ? '[KRITISCH] ' : '';
      const reasons = r.reasons.map(reasonLabelDe).join(', ');
      return `${tag}${r.source} · Ziel ${r.targetId} · Grund: ${reasons} · ${r.distinctReporters} Melder · offen seit ${fmt.format(new Date(r.oldestAt))}`;
    });
    const header = `ParentPeak – Offene Meldungen (Sicherheitsnetz)\n\n`
      + `${pending.length} offene Meldung(en), davon ${criticalCount} kritisch.`
      + `\nBitte im geschützten Moderations-Dashboard bearbeiten.\n\n`;
    const text = header + lines.join('\n');
    const html = `<div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;color:#203b35">`
      + `<h1 style="color:#287568">ParentPeak</h1>`
      + `<p><strong>${pending.length} offene Meldung(en)</strong>, davon ${criticalCount} kritisch.</p>`
      + `<ul>${lines.map(line => `<li>${escapeEmailHtml(line).replace(/^\[KRITISCH\]/, '<strong>[KRITISCH]</strong>')}</li>`).join('')}</ul>`
      + `<p>Bitte im geschützten Moderations-Dashboard bearbeiten.</p></div>`;

    const sent = await bounded(() => sendEmail({
      to: env.MODERATION_EMAIL || 'support@parentpeak.com',
      subject: `ParentPeak · ${pending.length} offene Meldung(en)`
        + (criticalCount > 0 ? ` (${criticalCount} kritisch)` : ''),
      text, html,
    }));
    if (sent !== true) {
      throw new Error('Digest-E-Mail nicht versendet (Provider fehlt oder false).');
    }
    return { sent: true, pendingCount: pending.length, criticalCount };
  }

  return {
    notifyModeration, persistModerationReport, loadAdditionalReports,
    resolveAdditionalReport, sendPendingDigest,
  };
}

function buildModerationOverview(groups, safetyReports, additionalReports) {
  const reports = [...safetyReports.map(withReportSeverity), ...additionalReports].sort(criticalFirst);
  const result = groups.map(group => ({
    ...group, lastReason: normalizeReportReason(group.lastReason, { event: group.lastContentType === 'event' }),
    severity: group.severity === 'critical' || reasonSeverity(group.lastReason) === 'critical'
      || reports.some(report => report.reportedUserId === group.reportedUserId
        && report.severity === 'critical') ? 'critical' : 'normal',
  }));
  const extraGroups = new Map();
  for (const report of additionalReports) {
    const key = report.reportedUserId;
    let group = extraGroups.get(key);
    if (!group) {
      group = { reportedUserId: key, source: report.source, targetId: report.targetId,
        reportCount: 0, distinctReporters: 0, severity: 'normal', suspended: false,
        lastReportedAt: report.createdAt, lastReason: report.reason, reporters: new Set() };
      extraGroups.set(key, group);
    }
    group.reportCount++;
    group.reporters.add(report.reporterUserId);
    group.distinctReporters = group.reporters.size;
    if (report.severity === 'critical') group.severity = 'critical';
    if (new Date(report.createdAt) >= new Date(group.lastReportedAt)) {
      group.lastReportedAt = report.createdAt;
      group.lastReason = report.reason;
    }
  }
  result.push(...[...extraGroups.values()].map(({ reporters, ...group }) => group));
  return { groups: result.sort(criticalFirst), reports };
}

module.exports = {
  normalizeReportReason, reasonSeverity, reasonLabelDe, withReportSeverity, criticalFirst,
  createModerationService, buildModerationOverview,
};
const { randomUUID } = require('node:crypto');
