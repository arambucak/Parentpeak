#!/usr/bin/env node
/*
 * READ-ONLY Diagnose des Migrations-Drifts in der Zieldatenbank.
 *
 * Ändert NICHTS. Prüft nur, welche für die hängenden Migrationen relevanten
 * Tabellen/Spalten/Constraints real existieren und welche Einträge in
 * _prisma_migrations stehen. Dient als Faktenbasis für eine anschließende,
 * ausdrücklich freigegebene `prisma migrate resolve`-Korrektur.
 *
 * DATABASE_URL kommt aus der Umgebung (GitHub-Secret).
 */
const { Client } = require('pg');

async function main() {
  const url = process.env.DATABASE_URL;
  if (!url) {
    console.error('DATABASE_URL nicht gesetzt.');
    process.exit(1);
  }
  const client = new Client({
    connectionString: url,
    ssl: { rejectUnauthorized: false },
  });
  await client.connect();

  const tableExists = async name => {
    const r = await client.query(
      "SELECT to_regclass($1) IS NOT NULL AS exists",
      [`public."${name}"`],
    );
    return r.rows[0].exists;
  };
  const columnExists = async (table, column) => {
    const r = await client.query(
      `SELECT EXISTS (
         SELECT 1 FROM information_schema.columns
         WHERE table_schema='public' AND table_name=$1 AND column_name=$2
       ) AS exists`,
      [table, column],
    );
    return r.rows[0].exists;
  };
  const constraintExists = async name => {
    const r = await client.query(
      `SELECT EXISTS (
         SELECT 1 FROM pg_constraint WHERE conname=$1
       ) AS exists`,
      [name],
    );
    return r.rows[0].exists;
  };

  console.log('=== Tabellen (relevant für hängende Migrationen) ===');
  for (const t of [
    'TreasureReport',
    'FoodOfferComment',
    'FoodOfferReservation',
    'TreasureItem',
    'Event',
  ]) {
    console.log(`  ${t}: ${(await tableExists(t)) ? 'EXISTS' : 'missing'}`);
  }

  console.log('=== Spalten ===');
  console.log(
    `  Event.ageGroups: ${(await columnExists('Event', 'ageGroups')) ? 'EXISTS' : 'missing'}`,
  );

  console.log('=== Constraints ===');
  console.log(
    `  Event_hosterId_fkey: ${(await constraintExists('Event_hosterId_fkey')) ? 'EXISTS' : 'missing'}`,
  );

  console.log('=== _prisma_migrations (Historie) ===');
  const hasMigrationsTable = await tableExists('_prisma_migrations');
  if (!hasMigrationsTable) {
    console.log('  _prisma_migrations fehlt komplett.');
  } else {
    const rows = await client.query(
      `SELECT migration_name,
              (finished_at IS NOT NULL) AS finished,
              (rolled_back_at IS NOT NULL) AS rolled_back,
              logs IS NOT NULL AS has_logs
       FROM _prisma_migrations
       ORDER BY started_at`,
    );
    for (const row of rows.rows) {
      console.log(
        `  ${row.migration_name} | finished=${row.finished} rolled_back=${row.rolled_back} has_logs=${row.has_logs}`,
      );
    }
  }

  await client.end();
  console.log('=== Diagnose fertig (read-only, nichts geändert) ===');
}

main().catch(err => {
  console.error('Diagnose-Fehler:', err.message);
  process.exit(1);
});
