# Gruppen-Chat — Deploy-Check & Test-Anleitung

Kurzreferenz für das Deployment des Gruppen-Chat-Features (PR #42) auf Render
und das Ausführen des Integrationstests `tests/group-chat.test.js`.

## 1. Render-Konfiguration — Prüfergebnis

Geprüft: `render.yaml`, `backend/package.json`, `backend/.env.example`,
`ensureSocialSchemaReady()` in `backend/server.js`.

### Deployment-Ablauf
- `render.yaml` → `type: web`, `runtime: node`, `rootDir: backend`,
  `buildCommand: npm install`, `startCommand: npm start`, `autoDeploy: true`.
- Beim Merge auf `main` deployt Render automatisch.
- `npm install` löst `postinstall` → `prisma generate` aus (Prisma-Client wird gebaut).

### Datenbank-Schema (keine separate Migration nötig)
- Die neuen Tabellen **`ChatRead`, `ChatGroup`, `ChatGroupMember`** sowie die
  Indizes werden **lazy** über `ensureSocialSchemaReady()` angelegt
  (`CREATE TABLE IF NOT EXISTS`), beim ersten Chat-bezogenen Request.
- Das ist dasselbe Muster wie für `FriendChatMessage` und die übrigen
  Social-Tabellen. **Kein manueller Migrationsschritt erforderlich.**

### Environment-Variablen
- **Keine neuen Variablen** für den Gruppen-Chat nötig.
- Relevant und bereits in `render.yaml` deklariert (als `sync: false`, d.h.
  manuell im Render-Dashboard gesetzt):
  - `DATABASE_URL` — PostgreSQL (Pflicht; wird von Render-DB bereitgestellt)
  - `FIREBASE_SERVICE_ACCOUNT_JSON` — **nötig für Push-Benachrichtigungen**
    (ohne dies initialisiert sich `firebaseAdmin` nicht, und `sendPushToUser`
    ist ein No-Op — Nachrichten werden trotzdem gespeichert/zugestellt, nur
    ohne Push).
  - `BACKEND_API_TOKEN` — Bearer-Token für Write-Operationen / Tests
- `DISABLE_IN_MEMORY_FALLBACKS=1` ist in Produktion aktiv: Bei DB-Fehlern
  antworten die Endpunkte mit `503` statt stillem In-Memory-Fallback. Die
  neuen Endpunkte folgen diesem Muster korrekt.

### Checkliste vor/nach dem Merge
- [ ] Render-Dashboard: `DATABASE_URL`, `FIREBASE_SERVICE_ACCOUNT_JSON`,
      `BACKEND_API_TOKEN` gesetzt.
- [ ] Merge `feat/network-chat-redesign` → `main` (löst Auto-Deploy aus).
- [ ] `/health` grün (healthCheckPath).
- [ ] Integrationstest ausführen (siehe unten).

## 2. Integrationstest nach dem Deploy ausführen

Der Test (`tests/group-chat.test.js`) läuft gegen den **laufenden** Server,
nicht lokal. Er legt eine Gruppe an, prüft Mitglieder, Nachrichtenversand
(inkl. Push-Fan-out), den Nicht-Mitglied-Schutz (403), die Chat-Übersicht mit
Ungelesen-Zähler, "als gelesen markieren" und das Verlassen der Gruppe.

### Voraussetzungen
- Backend ist deployed und erreichbar.
- Gültiges `BACKEND_API_TOKEN` (dasselbe wie im Render-Dashboard).

### Ausführen (gegen Production)
```bash
cd backend
API_BASE=https://parentpeak.onrender.com \
BEARER_TOKEN=<DEIN_BACKEND_API_TOKEN> \
node tests/group-chat.test.js
```

### Ausführen (gegen lokalen Server)
```bash
cd backend
# Terminal 1: Server starten (benötigt DATABASE_URL etc.)
npm start
# Terminal 2:
API_BASE=http://localhost:3000 \
BEARER_TOKEN=<DEIN_BACKEND_API_TOKEN> \
node tests/group-chat.test.js
```

### Ergebnis
- Erfolg: `📊 Result: 7 passed, 0 failed`, Exit-Code `0`.
- Bei Fehlern: Exit-Code `1`, die fehlgeschlagenen Checks werden mit `✗`
  und Statuscode ausgegeben.

### Hinweis zu Push
Der Test prüft, dass der Nachrichtenversand **akzeptiert** wird (201) und damit
den Push-Fan-out auslöst. Die **tatsächliche Zustellung** der FCM-Nachricht
lässt sich nur auf echten Geräten mit registrierten Tokens final verifizieren
(dafür müssen `FIREBASE_SERVICE_ACCOUNT_JSON` gesetzt und Geräte-Tokens über
`/devices/register-token` registriert sein).
