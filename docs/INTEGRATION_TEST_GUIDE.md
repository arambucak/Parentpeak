# Integration Test Guide

This guide explains how to run the comprehensive integration tests for the new features: **Smart Parent Matching** and **Gemeinsam Satt** (recipe sharing).

## Prerequisites

- Node.js 18+ installed
- Access to the backend API (either local or Render production)
- A valid Bearer token (for production Render deployment)

## Test Suites

### 1. Smart Parent Matching Tests (`backend/tests/parent-matching.test.js`)

Tests the smart matching algorithm including:
- ✅ Profile creation with geographic coordinates
- ✅ Smart matching with scoring breakdown (proximity, interests, child age, family form)
- ✅ Action recording (like, pass, favorite)
- ✅ Matching result sorting and filtering

#### Running Locally

```bash
# Start backend in another terminal first
cd backend
npm start

# In another terminal, run tests (no auth required for local)
cd backend
node tests/parent-matching.test.js
```

#### Running Against Render Production

```bash
# Get BACKEND_API_TOKEN from Render environment variables
# https://dashboard.render.com → Parentpeak service → Environment

BEARER_TOKEN='your-backend-api-token' \
API_BASE='https://parentpeak.onrender.com' \
node backend/tests/parent-matching.test.js
```

#### Expected Output

```
🧪 Parent Matching Integration Tests
📍 API Base: https://parentpeak.onrender.com

📝 Test 1: Create profiles
  ✓ Profile 1 created: <uuid>
  ✓ Profile 2 created: <uuid>
  ✓ Profile 3 created (Munich): <uuid>

🎯 Test 2: Find matches for profile 1 (Berlin)
  Found 2 match(es)
  Top match: Mareike Schmidt (score: 85.5)
    Breakdown: proximity=95, interest=82, childAge=78, familyForm=90
  ✓ Correct match with good score

👍 Test 3: Record "like" action
  ✓ Action recorded successfully

📊 Test 4: Record multiple actions
  ✓ Multiple actions recorded

==================================================
Tests passed: 4
Tests failed: 0
==================================================
```

### 2. Gemeinsam Satt Recipe Tests (`backend/tests/gemeinsam-satt.test.js`)

Tests the recipe sharing platform including:
- ✅ Recipe creation with validation
- ✅ List recipes with pagination and filtering
- ✅ Recipe detail fetch with automatic view count increment
- ✅ Rating system with automatic average recalculation
- ✅ Ownership verification for updates/deletes
- ✅ Recipe deletion and cascade verification

#### Running Locally

```bash
# Start backend first (same terminal as Smart Matching tests)
cd backend
npm start

# In another terminal
cd backend
node tests/gemeinsam-satt.test.js
```

#### Running Against Render Production

```bash
BEARER_TOKEN='your-backend-api-token' \
API_BASE='https://parentpeak.onrender.com' \
node backend/tests/gemeinsam-satt.test.js
```

#### Expected Output

```
🍳 Gemeinsam Satt Integration Tests
📍 API Base: https://parentpeak.onrender.com

✍️  Test 1: Create recipes
  ✓ Recipe 1 created: <uuid>
    Title: Klassischer Kartoffelsalat
  ✓ Recipe 2 created: <uuid>

📋 Test 2: List recipes with pagination
  ✓ Found 2 recipe(s)
  Total in DB: 2

🏷️  Test 3: Filter recipes by category
  ✓ Found 1 Salat recipe(s)

👀 Test 4: Get recipe detail and check view count
  Initial view count: 0
  After second view: 2
  ✓ View count incremented correctly

⭐ Test 5: Rate recipe
  ✓ Recipe rated
  Average rating: 5.0
  Rating count: 1
  ✓ Rating persisted correctly

📊 Test 6: Multiple ratings and aggregation
  ✓ Multiple ratings: 5, 4, 5
  Calculated average: 4.67
  Stored average: 4.67

✏️  Test 7: Update recipe
  ✓ Recipe updated: Kartoffelsalat - Südwestdeutsche Variante

🔒 Test 8: Ownership verification
  ✓ Correctly rejected unauthorized update (403)

🗑️  Test 9: Delete recipe
  ✓ Recipe deleted
  ✓ Verified recipe no longer exists

==================================================
Tests passed: 9
Tests failed: 0
==================================================
```

### 3. Verschenkmarkt Tests (`backend/tests/treasures.test.js`)

Deckt lokale Sichtbarkeit, Moderation und den vollständigen Übergabeablauf ab:

- Anzeige veröffentlichen und lokal abrufen
- Reservierung durch eine interessierte Familie
- Reservierung in `Meine Anzeigen` sehen
- Übergabe bestätigen und als übergeben abschließen
- Erneute Reservierung eines abgeschlossenen Artikels ablehnen

#### Running Against Render Production

```bash
BEARER_TOKEN='your-backend-api-token' \
API_BASE='https://parentpeak.onrender.com' \
REQUESTER_USER_ID='registered-user-id' \
node backend/tests/treasures.test.js
```

Der Test startet gegen `parentpeak.onrender.com` absichtlich nicht ohne
`BEARER_TOKEN`, damit keine unautorisierten Produktionsanfragen erfolgen. Wenn
der Standardnutzer `host_demo_001` nicht vorhanden ist, muss
`REQUESTER_USER_ID` auf die ID eines registrierten Testkontos gesetzt werden.

## Environment Variables

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `BEARER_TOKEN` | No (local) | Bearer token for auth | `Bearer token from Render environment` |
| `API_BASE` | No | Base URL of backend | `https://parentpeak.onrender.com` |
| `NODE_ENV` | No | Environment name | `production` |

## Troubleshooting

### Error: "Expected 200/201, got 401: {"error":"Unauthorized"}"

**Cause:** Missing or invalid Bearer token on production.

**Solution:** 
1. Get `BACKEND_API_TOKEN` from Render dashboard
2. Pass it as `BEARER_TOKEN` env var

```bash
BEARER_TOKEN='actual-token-value' node backend/tests/parent-matching.test.js
```

### Error: "Expected 200, got 500: {"error":"Matching konnte nicht durchgeführt werden"}"

**Cause:** Backend error during matching algorithm or profile lookups.

**Solution:**
1. Check backend logs: `tail -f build/reports/server.log` (if logging enabled)
2. Verify PostgreSQL connection is active
3. Ensure Prisma migrations are up-to-date

### Error: "Connection refused"

**Cause:** Backend service is not running.

**Solution:**
- For local testing: Start backend with `npm start` in backend directory
- For Render production: Ensure service is active at https://parentpeak.onrender.com

## CI/CD Integration

To integrate into GitHub Actions:

```yaml
- name: Run Integration Tests
  env:
    BEARER_TOKEN: ${{ secrets.BACKEND_API_TOKEN }}
    API_BASE: https://parentpeak.onrender.com
  run: |
    cd backend
    npm install
    node tests/parent-matching.test.js
    node tests/gemeinsam-satt.test.js
```

## Manual Smoke Test Checklist

Before production deployment, verify manually:

### Smart Matching
- [ ] Create profile as "Test Parent A" (Berlin, coordinates: 52.5200, 13.4050)
- [ ] Create profile as "Test Parent B" (Berlin, same interests)
- [ ] Call `/api/parent-matching/find` for Parent A
- [ ] Verify Parent B appears in matches with score > 70
- [ ] Like Parent B
- [ ] Verify action persists in database

### Gemeinsam Satt
- [ ] Create recipe titled "Test Recipe"
- [ ] Fetch recipe detail
- [ ] Verify view count incremented
- [ ] Rate recipe with 5 stars
- [ ] Create another rating (4 stars)
- [ ] Verify average shows ~4.5
- [ ] Update recipe title (should succeed)
- [ ] Try updating recipe as different user (should fail with 403)
- [ ] Delete recipe
- [ ] Verify recipe no longer appears in list

## Performance Baselines

Expected response times (Render free tier):

| Endpoint | Time |
|----------|------|
| POST /api/parent-matching/profiles | 200-500ms |
| GET /api/parent-matching/find | 300-800ms |
| POST /api/food-feed/recipes | 200-400ms |
| GET /api/food-feed/recipes | 100-300ms |
| POST /api/food-feed/recipes/:id/rate | 150-350ms |

If times are significantly higher, check Render CPU/memory usage.
