# Event-Serie folgen — Deploy-Check & Test-Anleitung (Issue #47 / PR #50)

Kurzreferenz für das Deployment des Features "wiederkehrenden Angeboten folgen"
und das Ausführen von `tests/events-series-follow.test.js`.

## ⚠️ WICHTIG: Prisma db push nach dem Merge erforderlich

Anders als die Chat-Tabellen (die lazy über `ensureSocialSchemaReady()` per
`CREATE TABLE IF NOT EXISTS` entstehen), leben `Event.seriesId` und das neue
Modell `EventSeriesFollower` im **Prisma-Schema**. Sie werden **nicht**
automatisch beim ersten Request angelegt.

**Nach dem Merge auf `main` muss das Schema in die Produktions-DB gepusht
werden**, sonst schlagen die neuen Endpunkte und das Event-Erstellen mit
`seriesId` fehl (Spalte/Tabelle fehlt):

```bash
cd backend
# DATABASE_URL = produktive Render-Postgres-URL
DATABASE_URL="<render_database_url>" npx prisma db push
```

- `prisma db push` legt `EventSeriesFollower` an und ergänzt die Spalte
  `Event.seriesId` (+ Indizes). Es ist additiv und non-destruktiv.
- Render führt `prisma db push` **nicht** automatisch aus (nur `prisma generate`
  via postinstall). Dieser Schritt ist manuell/CI-seitig anzustoßen.

## Verhalten (zur Abgrenzung)

- **Folgen ist ein aktives Opt-in** pro `(seriesId, userId)` — getrennt von
  `EventParticipation`. Teilnahme an einem Einzelevent macht NICHT zum Follower.
- Beim Erstellen eines neuen Events **mit** `seriesId` werden **nur** die aktiven
  Follower (außer dem Ersteller) per Push benachrichtigt
  (`type: event_series_new_date`). Kein Push an alle in der Nähe, kein Push aus
  einer KI-Erkennung.
- Push erreicht — wie das gesamte Push-System — nur Geräte mit aktuell
  registriertem FCM-Token (In-Memory-Tokenspeicher).

## Test ausführen (nach Deploy + db push)

Schreib-Endpunkte verlangen in Produktion einen gültigen Firebase-ID-Token
(siehe `README_group_chat.md`). Lokal ohne Auth:

```bash
cd backend
# Lokal (Auth aus):
FIREBASE_REQUIRE_AUTH=0 REQUIRE_AUTH_FOR_WRITES=0 NODE_ENV=development \
DATABASE_URL="<lokale_db>" npm start
# anderes Terminal:
API_BASE=http://localhost:3000 node tests/events-series-follow.test.js
```

Erfolg: `📊 Result: 7 passed, 0 failed` (Exit 0).
