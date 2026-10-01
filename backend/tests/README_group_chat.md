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

### WICHTIG: Welcher Token wird gebraucht?
In **Produktion** gilt `FIREBASE_REQUIRE_AUTH=1`. Die `firebaseAuthMiddleware`
verlangt bei allen Write-Requests (POST/PUT/DELETE) einen **gültigen
Firebase-ID-Token** eines eingeloggten Nutzers. Ein `BACKEND_API_TOKEN`
genügt dafür **nicht** (401: "Gültiger Firebase ID-Token erforderlich").

Es gibt daher zwei Wege, den Test auszuführen:

### Weg A — gegen Production, mit echtem Firebase-ID-Token
`BEARER_TOKEN` muss ein frischer Firebase-ID-Token eines eingeloggten
Test-Accounts sein (z. B. in der App via `FirebaseAuth.instance.currentUser!.getIdToken()`
geloggt, oder über das Firebase Auth REST-API mit E-Mail/Passwort geholt).
Diese Tokens laufen nach ~1 Stunde ab.

```bash
cd backend
API_BASE=https://parentpeak.onrender.com \
BEARER_TOKEN=<FIREBASE_ID_TOKEN> \
node tests/group-chat.test.js
```

Hinweis: Alle Test-Nutzer-IDs im Script müssten in diesem Fall der echten
UID des eingeloggten Accounts entsprechen, da das Backend prüft, dass Token
und `userId` zusammenpassen. Für einen vollständigen Mehrpersonen-Test
(Owner + Mitglieder + Außenstehender) braucht es daher mehrere echte
Accounts/Tokens — in der Praxis am besten manuell in der App verifizieren.

### Weg B (empfohlen zum Logik-Test) — lokal ohne Firebase-Pflicht
Lokal die Auth-Pflicht abschalten, dann prüft der Test die reine
Business-Logik (Mitgliedschaft, Overview, Unread, Verlassen):

```bash
cd backend
# Terminal 1: Server lokal mit deaktivierter Auth starten
FIREBASE_REQUIRE_AUTH=0 REQUIRE_AUTH_FOR_WRITES=0 NODE_ENV=development \
DATABASE_URL="<lokale_oder_test_db>" npm start

# Terminal 2:
API_BASE=http://localhost:3000 node tests/group-chat.test.js
```

### Was der fehlgeschlagene Production-Lauf mit BACKEND_API_TOKEN zeigt
Erhält man `401: "Gültiger Firebase ID-Token erforderlich"` bei Test 1, ist
das **kein Feature-Fehler**: Die Endpunkte existieren und die Firebase-Auth
greift wie vorgesehen. Es bedeutet nur, dass der verwendete Token kein
gültiger Firebase-ID-Token war.

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
