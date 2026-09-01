#!/usr/bin/env bash

set -euo pipefail

BASE_URL="${BACKEND_BASE_URL:-}"
AUTH_TOKEN="${BACKEND_API_TOKEN:-}"
EXPECT_WRITE_AUTH="${EXPECT_WRITE_AUTH:-1}"
SMOKE_ORIGIN="${SMOKE_ORIGIN:-https://parentpeak.de}"

if [[ -z "$BASE_URL" ]]; then
  echo "[backend_security_smoke_test] ERROR: BACKEND_BASE_URL is required"
  echo "Example: BACKEND_BASE_URL=https://api.parentpeak.de bash scripts/backend_security_smoke_test.sh"
  exit 1
fi

BASE_URL="${BASE_URL%/}"

echo "[backend_security_smoke_test] Base URL: $BASE_URL"

tmp_headers="$(mktemp)"
trap 'rm -f "$tmp_headers"' EXIT

request_status() {
  local method="$1"
  local url="$2"
  local auth="$3"
  local body="${4:-}"

  local curl_args=(
    -sS
    -o /dev/null
    -D "$tmp_headers"
    -w "%{http_code}"
    -X "$method"
    "$url"
    -H "Origin: $SMOKE_ORIGIN"
    -H "Accept: application/json"
  )

  if [[ "$method" != "GET" ]]; then
    curl_args+=( -H "Content-Type: application/json" )
  fi

  if [[ -n "$auth" ]]; then
    curl_args+=( -H "Authorization: Bearer $auth" )
  fi

  if [[ -n "$body" ]]; then
    curl_args+=( --data "$body" )
  fi

  curl "${curl_args[@]}"
}

assert_status_prefix() {
  local status="$1"
  local prefix="$2"
  local label="$3"
  if [[ "$status" == "$prefix"* ]]; then
    echo "[OK] $label ($status)"
  else
    echo "[ERROR] $label expected ${prefix}xx, got $status"
    return 1
  fi
}

assert_exact_status() {
  local status="$1"
  local expected="$2"
  local label="$3"
  if [[ "$status" == "$expected" ]]; then
    echo "[OK] $label ($status)"
  else
    echo "[ERROR] $label expected $expected, got $status"
    return 1
  fi
}

# 1) Health endpoint
status="$(request_status GET "$BASE_URL/health" "")"
assert_status_prefix "$status" "2" "GET /health"

if grep -qi '^x-content-type-options:' "$tmp_headers"; then
  echo "[OK] X-Content-Type-Options header present"
else
  echo "[WARN] X-Content-Type-Options header missing"
fi

if grep -qi '^x-frame-options:' "$tmp_headers"; then
  echo "[OK] X-Frame-Options header present"
else
  echo "[WARN] X-Frame-Options header missing"
fi

if grep -qi '^referrer-policy:' "$tmp_headers"; then
  echo "[OK] Referrer-Policy header present"
else
  echo "[WARN] Referrer-Policy header missing"
fi

# 2) Public read endpoint
status="$(request_status GET "$BASE_URL/events" "")"
assert_status_prefix "$status" "2" "GET /events"

# 3) Write endpoint without auth
todo_body='{"title":"smoke test","familyId":"smoke-family","completed":false}'
status="$(request_status POST "$BASE_URL/todos" "" "$todo_body")"
if [[ "$EXPECT_WRITE_AUTH" == "1" ]]; then
  assert_exact_status "$status" "401" "POST /todos without auth"
else
  echo "[INFO] EXPECT_WRITE_AUTH=0, skipping strict unauthorized assertion (status=$status)"
fi

ai_body='{"prompt":"security smoke","model":"gemini-3.5-flash-lite"}'
status="$(request_status POST "$BASE_URL/ai/generate" "" "$ai_body")"
if [[ "$EXPECT_WRITE_AUTH" == "1" ]]; then
  assert_exact_status "$status" "401" "POST /ai/generate without auth"
fi

# 4) Write endpoint with auth token (if available)
if [[ -n "$AUTH_TOKEN" ]]; then
  status="$(request_status POST "$BASE_URL/todos" "$AUTH_TOKEN" "$todo_body")"
  assert_status_prefix "$status" "2" "POST /todos with auth"
else
  echo "[WARN] BACKEND_API_TOKEN not provided; skipping authenticated write test"
fi

echo "[backend_security_smoke_test] Completed"
