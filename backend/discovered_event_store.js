const { createHash } = require('node:crypto');

async function storeDiscoveredEvents(db, raw) {
  const start = raw.indexOf('[');
  const end = raw.lastIndexOf(']');
  const events = JSON.parse(raw.slice(start, end + 1));
  if (start < 0 || !Array.isArray(events)) throw new Error('Invalid discovered event array');
  const result = [];
  for (const event of events) {
    if (!event || typeof event.title !== 'string' || typeof event.url !== 'string') {
      throw new Error('Invalid discovered event');
    }
    let url;
    try { url = new URL(event.url); }
    catch { throw new Error('Invalid discovered event URL'); }
    if (!['https:', 'http:'].includes(url.protocol)) throw new Error('Invalid discovered event URL');
    url.hash = '';
    const id = createHash('sha256').update(JSON.stringify([
      url.toString(), event.eventDate ?? null, event.title.trim().toLowerCase(),
    ])).digest('hex');
    const item = { ...event, id };
    await db.$executeRawUnsafe(
      `INSERT INTO "DiscoveredEventDetail" ("id", "data") VALUES ($1, $2::jsonb)
       ON CONFLICT ("id") DO UPDATE SET "data" = EXCLUDED."data"`, id, JSON.stringify(item),
    );
    result.push(item);
  }
  return JSON.stringify(result);
}

module.exports = { storeDiscoveredEvents };
