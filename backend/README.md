# Parentpeak Marktplatz Backend

## Installation

1. **Node.js installieren** (falls nicht vorhanden)
   - https://nodejs.org/ (Version 16+)

2. **Dependencies installieren:**
   ```bash
   cd backend
   npm install
   ```

3. **Backend starten:**
   ```bash
   npm start
   ```

Das Backend läuft dann auf: **http://localhost:3000**

## Produktions-Hardening

Für produktionsnahe Nutzung setze folgende Umgebungsvariablen vor dem Start:

- `BACKEND_API_TOKEN`: Erwarteter Bearer-Token für Schreibzugriffe
- `GEMINI_API_KEY`: Server-seitiger Gemini-Schlüssel für `/ai/generate` (nie im Client-Build)
- `FIREBASE_REQUIRE_AUTH=1`: Verifiziert Firebase-ID-Tokens für Client-Schreibzugriffe
- `REQUIRE_AUTH_FOR_WRITES=1`: Aktiviert Auth-Pflicht für `POST/PUT/PATCH/DELETE`
- `CORS_ALLOWED_ORIGINS`: Kommagetrennte Origin-Allowlist
- `WRITE_RATE_LIMIT_WINDOW_MS`: Zeitfenster für Write-Rate-Limit (ms)
- `WRITE_RATE_LIMIT_MAX`: Max. Schreibanfragen pro Fenster und Client
- `INTERNAL_MODERATOR_EMAILS`: explizite interne Moderations-/Review-Accounts (kommagetrennt)
- `INTERNAL_MODERATOR_DOMAINS`: erlaubte interne Domains für Moderation und Fachverifizierung
- `WEEKLY_IMPULSE_SCHEMA_PATH`: optionaler absoluter Pfad zur `weekly_impulse_schema_year3.json` (nur noetig bei abweichendem Deploy-Arbeitsverzeichnis)
- `STRIPE_WEBHOOK_SECRET`: Stripe Endpoint Signing Secret (`whsec_...`)
- `STRIPE_WEBHOOK_TOLERANCE_SEC`: erlaubte Zeitabweichung fuer Stripe Signaturen
- `ALLOW_CLIENT_PROVIDER_EVENTS=0`: deaktiviert clientseitige Provider-Statusupdates

Beispiel:

```bash
export BACKEND_API_TOKEN="..."
export GEMINI_API_KEY="..."
export FIREBASE_REQUIRE_AUTH=1
export REQUIRE_AUTH_FOR_WRITES=1
export CORS_ALLOWED_ORIGINS="https://parentpeak.de,https://www.parentpeak.de"
export INTERNAL_MODERATOR_EMAILS="lead@parentpeak.de,ops@parentpeak.de"
export INTERNAL_MODERATOR_DOMAINS="parentpeak.de,parentpeak.com"
export WEEKLY_IMPULSE_SCHEMA_PATH="/opt/render/project/src/backend/weekly_impulse_schema_year3.json"
export STRIPE_WEBHOOK_SECRET="whsec_..."
export STRIPE_WEBHOOK_TOLERANCE_SEC=300
export ALLOW_CLIENT_PROVIDER_EVENTS=0
node server.js
```

## Wochenimpuls Community, Moderation und Fachverifizierung

Der Wochenimpuls-Bereich besitzt jetzt drei produktionsrelevante Ebenen:

- Community-Posts, Likes und Kommentare
- Moderations-Reports mit globalem Ausblenden/Wiederfreigeben
- Fachverifizierung für paedagogische Stimmen

Wichtige Endpunkte:

- `GET /api/weekly-impulse`
- `POST /api/weekly-impulse/community/posts`
- `POST /api/weekly-impulse/community/posts/:postId/report`
- `GET /api/weekly-impulse/community/reports`
- `POST /api/weekly-impulse/community/reports/:reportId/resolve`
- `POST /api/weekly-impulse/community/posts/:postId/moderation-visibility`
- `GET /api/weekly-impulse/community/verification-status`
- `POST /api/weekly-impulse/community/verification-requests`
- `GET /api/weekly-impulse/community/verification-requests`
- `POST /api/weekly-impulse/community/verification-requests/:requestId/approve`

Sicherheitsmodell:

- Normale Community-Aktionen bleiben fuer App-Nutzer:innen offen.
- Moderations- und Verifizierungs-Review-Endpunkte verlangen jetzt serverseitig eine interne E-Mail (`INTERNAL_MODERATOR_EMAILS` oder `INTERNAL_MODERATOR_DOMAINS`).
- UI-Sichtbarkeit allein reicht also nicht mehr aus, um diese Endpunkte zu nutzen.

Empfohlener Go-Live-Check:

1. Setze `INTERNAL_MODERATOR_EMAILS` und/oder `INTERNAL_MODERATOR_DOMAINS` im Hosting.
2. Pruefe mit einem internen Account, dass das Moderationspanel Reports laden kann.
3. Pruefe mit einem normalen Account, dass Moderations- oder Freigabe-Endpunkte `403` liefern.
4. Erzeuge testweise eine Fachverifizierungsanfrage und gib sie mit internem Account frei.

## Stripe Webhook (Produktion)

Sichere Stripe-Integration laeuft ueber:

```bash
POST /payments/stripe/webhook
```

Wichtig:
- Dieser Endpoint erwartet `application/json` Raw Body und den Header `Stripe-Signature`.
- Die Signatur wird serverseitig gegen `STRIPE_WEBHOOK_SECRET` geprueft.
- `completed` und `refunded` werden nur aus verifizierten Provider-Events akzeptiert.
- Der Legacy-Dev-Pfad `POST /payments/provider-events` sollte in Produktion deaktiviert sein (`ALLOW_CLIENT_PROVIDER_EVENTS=0`).

Empfohlene Stripe Event-Abos fuer den Endpoint:
- `payment_intent.succeeded`
- `payment_intent.payment_failed`
- `charge.refunded`

## Post-Deploy Smoke Checks

1. Health pruefen:

```bash
curl -i https://api.example.com/health
```

2. Client-Provider-Events muessen in Produktion geblockt sein:

```bash
curl -i -X POST https://api.example.com/payments/provider-events \
   -H "Content-Type: application/json" \
   -d '{"provider":"stripe","providerTransactionRef":"pi_test","status":"completed","verified":true}'
```

Erwartung: `403`.

Automatisiert (empfohlen):

```bash
BACKEND_BASE_URL=https://api.example.com \
STRIPE_WEBHOOK_SECRET=whsec_... \
bash scripts/stripe_webhook_smoke_test.sh
```

Kombiniert (Security + Stripe in einem Lauf):

```bash
BACKEND_BASE_URL=https://api.example.com \
BACKEND_API_TOKEN=... \
STRIPE_WEBHOOK_SECRET=whsec_... \
bash scripts/release_smoke_suite.sh
```

Wochenimpuls-Community und Fachverifizierung gezielt pruefen:

```bash
BACKEND_BASE_URL=https://api.example.com \
INTERNAL_REVIEWER_EMAIL=lead@parentpeak.de \
INTERNAL_REVIEWER_NAME="Lead Review" \
bash scripts/weekly_impulse_community_smoke_test.sh
```

Oder im Gesamtlauf aktivieren:

```bash
BACKEND_BASE_URL=https://api.example.com \
RUN_BACKEND_SECURITY_SMOKE=1 \
RUN_STRIPE_WEBHOOK_SMOKE=0 \
RUN_WEEKLY_IMPULSE_COMMUNITY_SMOKE=1 \
INTERNAL_REVIEWER_EMAIL=lead@parentpeak.de \
bash scripts/release_smoke_suite.sh
```

Schneller Smoke-Test gegen eine laufende Instanz:

```bash
BACKEND_BASE_URL=https://api.example.com \
BACKEND_API_TOKEN=... \
bash scripts/backend_security_smoke_test.sh
```

## API Endpoints

### 📋 Alle Anbieter abrufen
```
GET /api/providers
```

### 🔍 Nach Kategorie filtern
```
GET /api/providers/category/{category}
```

### 👤 Einzelnen Anbieter abrufen
```
GET /api/providers/{id}
```

### 🔎 Suchen
```
GET /api/search?q={suchtext}
```

### 📊 Alle Kategorien
```
GET /api/categories
```

### ⭐ Bewertung hinzufügen
```
POST /api/providers/{id}/review
Body: { "rating": 5, "comment": "...", "parentName": "..." }
```

### 🎯 Erweiterte Filter
```
POST /api/providers/filter
Body: { 
  "categories": ["Mathe", "Deutsch"],
  "maxPrice": 30,
  "minRating": 4.5
}
```

### 💚 Health Check
```
GET /health
```

## Testdaten

Die `providers.json` enthält 10 Beispiel-Anbieter:
- 6 Nachhilfelehrer (Mathe, Deutsch, Englisch, etc.)
- 4 Betreuer/Nannys (Kleinkinder, Schulkinder, Fahrdienste, etc.)

## Für Flutter-App konfigurieren

In der Flutter-App, update die Backend-URL:
```dart
const String backendUrl = 'http://192.168.x.x:3000';  // IP des Computers
```

## Optional: Für extern erreichbar machen

Um die App auf dem physischen Handy zu testen:
1. Finde deine Computer-IP: `ipconfig` (Windows) oder `ifconfig` (Mac/Linux)
2. Starte Backend mit: `npm start`
3. In der Flutter-App: `http://{DEINE_IP}:3000`
