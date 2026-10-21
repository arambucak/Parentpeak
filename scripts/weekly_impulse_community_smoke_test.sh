#!/usr/bin/env bash

set -euo pipefail

BASE_URL="${BACKEND_BASE_URL:-}"
SMOKE_ORIGIN="${SMOKE_ORIGIN:-https://parentpeak.de}"
AUTH_TOKEN="${FIREBASE_ID_TOKEN:-}"
REVIEWER_TOKEN="${INTERNAL_REVIEWER_ID_TOKEN:-}"

if [[ -z "$BASE_URL" ]]; then
  echo "[weekly_impulse_community_smoke_test] ERROR: BACKEND_BASE_URL is required"
  echo "Example: BACKEND_BASE_URL=https://api.parentpeak.de bash scripts/weekly_impulse_community_smoke_test.sh"
  exit 1
fi

if [[ -z "$AUTH_TOKEN" || -z "$REVIEWER_TOKEN" ]]; then
  echo "[weekly_impulse_community_smoke_test] ERROR: FIREBASE_ID_TOKEN and INTERNAL_REVIEWER_ID_TOKEN are required"
  echo "Use separate verified test accounts: a normal user and an allowlisted moderator."
  exit 1
fi

BASE_URL="${BASE_URL%/}"
SMOKE_TS="$(date +%s)"
SMOKE_NAME="Weekly Smoke ${SMOKE_TS}"
SMOKE_ROLE_TITLE="Familienberater:in"
SMOKE_ORG="Parentpeak Smoke Lab"
SMOKE_NOTE="Automatischer Smoke-Test fuer Fachverifizierung"

headers_file="$(mktemp)"
body_file="$(mktemp)"
trap 'rm -f "$headers_file" "$body_file"' EXIT

request_json() {
  local method="$1"
  local url="$2"
  local body="${3:-}"
  local token="${4:-$AUTH_TOKEN}"

  local curl_args=(
    -sS
    -D "$headers_file"
    -o "$body_file"
    -w "%{http_code}"
    -X "$method"
    "$url"
    -H "Origin: $SMOKE_ORIGIN"
    -H "Accept: application/json"
  )

  if [[ -n "$token" ]]; then
    curl_args+=( -H "Authorization: Bearer $token" )
  fi

  if [[ "$method" != "GET" ]]; then
    curl_args+=( -H "Content-Type: application/json" )
  fi

  if [[ -n "$body" ]]; then
    curl_args+=( --data "$body" )
  fi

  curl "${curl_args[@]}"
}

assert_exact_status() {
  local status="$1"
  local expected="$2"
  local label="$3"
  if [[ "$status" == "$expected" ]]; then
    echo "[OK] $label ($status)"
  else
    echo "[ERROR] $label expected $expected, got $status"
    echo "[ERROR] Response body:"
    cat "$body_file"
    return 1
  fi
}

assert_body_contains() {
  local needle="$1"
  local label="$2"
  if grep -Fq "$needle" "$body_file"; then
    echo "[OK] $label"
  else
    echo "[ERROR] $label missing '$needle'"
    echo "[ERROR] Response body:"
    cat "$body_file"
    return 1
  fi
}

echo "[weekly_impulse_community_smoke_test] Base URL: $BASE_URL"

status="$(request_json GET "$BASE_URL/api/weekly-impulse")"
assert_exact_status "$status" "200" "GET /api/weekly-impulse"
assert_body_contains 'community_posts' 'Weekly impulse hub payload includes community posts'

verification_request_body=$(cat <<JSON
{"displayName":"$SMOKE_NAME","roleTitle":"$SMOKE_ROLE_TITLE","organization":"$SMOKE_ORG","note":"$SMOKE_NOTE"}
JSON
)
status="$(request_json POST "$BASE_URL/api/weekly-impulse/community/verification-requests" "$verification_request_body")"
assert_exact_status "$status" "201" "POST verification request"
assert_body_contains '"status":"pending"' 'Verification request stored as pending'
request_id="$(node -e 'const body = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8")); if (!body.item?.id) process.exit(1); process.stdout.write(body.item.id)' "$body_file")"

status="$(request_json GET "$BASE_URL/api/weekly-impulse/community/verification-status")"
assert_exact_status "$status" "200" "GET verification status before approval"
assert_body_contains '"pendingRequest":true' 'Verification status shows pending request'

status="$(request_json GET "$BASE_URL/api/weekly-impulse/community/verification-requests?status=pending&reviewerEmail=lead@parentpeak.de")"
assert_exact_status "$status" "403" "Normal account cannot impersonate internal reviewer"

status="$(request_json GET "$BASE_URL/api/weekly-impulse/community/verification-requests?status=pending" "" "$REVIEWER_TOKEN")"
assert_exact_status "$status" "200" "Internal reviewer can load verification requests"
assert_body_contains "$request_id" 'Own pending verification request visible to reviewer'

approval_body=$(cat <<JSON
{"reviewNote":"Smoke approval","verificationLabel":"Verifizierte Fachstimme"}
JSON
)
status="$(request_json POST "$BASE_URL/api/weekly-impulse/community/verification-requests/$request_id/approve" "$approval_body" "$REVIEWER_TOKEN")"
assert_exact_status "$status" "200" "Approve verification request"
assert_body_contains '"status":"approved"' 'Verification request stored as approved'

status="$(request_json GET "$BASE_URL/api/weekly-impulse/community/verification-status")"
assert_exact_status "$status" "200" "GET verification status after approval"
assert_body_contains '"verified":true' 'Verification status shows verified expert'
assert_body_contains '"verifiedProfile":' 'Verification status exposes verified profile'

community_post_body=$(cat <<JSON
{"impulseId":"imp_years_3_gfk_w1","title":"Smoke Fachbeitrag","body":"Dies ist ein automatisch freigegebener Fachbeitrag fuer den Smoke-Test.","authorName":"$SMOKE_NAME","role":"Paedagog:in"}
JSON
)
status="$(request_json POST "$BASE_URL/api/weekly-impulse/community/posts" "$community_post_body")"
assert_exact_status "$status" "201" "POST verified educator community post"
assert_body_contains '"verified_expert":true' 'Approved educator post receives verified badge'

echo "[weekly_impulse_community_smoke_test] Completed"
