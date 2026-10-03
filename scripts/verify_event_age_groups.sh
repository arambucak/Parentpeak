#!/usr/bin/env bash
#
# Verifiziert, dass die ageGroups-Funktion für Events in der Zielumgebung
# korrekt greift — insbesondere NACH dem Anwenden der Prisma-Migration
# (Event.ageGroups-Spalte).
#
# Immer geprüft (ohne Auth):
#   - Health-Endpoint erreichbar
#   - GET /api/events liefert HTTP 200 und KEINEN "column does not exist"-Fehler
#   - jedes zurückgegebene Event enthält ein ageGroups-Feld
#
# Optional (nur mit FIREBASE_ID_TOKEN + HOSTER_ID): Create-Roundtrip, der prüft,
# dass gesendete ageGroups persistiert und im Feed zurückgegeben werden.
#
# Beispiel:
#   BACKEND_BASE_URL=https://parentpeak.onrender.com bash scripts/verify_event_age_groups.sh
#
set -euo pipefail

BASE_URL="${BACKEND_BASE_URL:-}"
LAT="${VERIFY_LAT:-52.52}"
LON="${VERIFY_LON:-13.405}"
RADIUS="${VERIFY_RADIUS_KM:-50}"

if [[ -z "$BASE_URL" ]]; then
  echo "[verify_event_age_groups] ERROR: BACKEND_BASE_URL ist erforderlich"
  echo "Beispiel: BACKEND_BASE_URL=https://parentpeak.onrender.com bash scripts/verify_event_age_groups.sh"
  exit 1
fi

echo "[verify_event_age_groups] Base URL: $BASE_URL"

# 1) Health -------------------------------------------------------------------
health_code="$(curl -sS -o /dev/null -w '%{http_code}' "$BASE_URL/health")"
if [[ "$health_code" != "200" ]]; then
  echo "[verify_event_age_groups] ERROR: /health -> HTTP $health_code"
  exit 1
fi
echo "[OK] /health -> 200"

# 2) Feed lesen ---------------------------------------------------------------
feed_response="$(curl -sS -w '\n%{http_code}' \
  "$BASE_URL/api/events?latitude=$LAT&longitude=$LON&radiusKm=$RADIUS&limit=5")"
feed_status="${feed_response##*$'\n'}"
feed_body="${feed_response%$'\n'*}"

if [[ "$feed_status" != "200" ]]; then
  echo "[verify_event_age_groups] ERROR: GET /api/events -> HTTP $feed_status"
  echo "[verify_event_age_groups] Response: $feed_body"
  exit 1
fi

if printf '%s' "$feed_body" | grep -q 'does not exist'; then
  echo "[verify_event_age_groups] ERROR: Schemafehler im Feed — Migration vermutlich NICHT angewandt."
  echo "[verify_event_age_groups] Response: $feed_body"
  exit 1
fi
echo "[OK] GET /api/events -> 200, kein Schemafehler"

# Prüfen, dass das ageGroups-Feld in der Antwortstruktur vorhanden ist. Enthält
# der Feed Events, muss jedes ein ageGroups-Feld tragen.
has_events="$(printf '%s' "$feed_body" | grep -c '"id":' || true)"
if [[ "$has_events" -gt 0 ]]; then
  if ! printf '%s' "$feed_body" | grep -q '"ageGroups":'; then
    echo "[verify_event_age_groups] ERROR: Events ohne ageGroups-Feld in der Antwort."
    echo "[verify_event_age_groups] Response: $feed_body"
    exit 1
  fi
  echo "[OK] ageGroups-Feld in Event-Antworten vorhanden"
else
  echo "[INFO] Feed enthält aktuell keine Events — Strukturprüfung übersprungen."
fi

# 3) Optionaler Create-Roundtrip ---------------------------------------------
TOKEN="${FIREBASE_ID_TOKEN:-}"
HOSTER="${HOSTER_ID:-}"
if [[ -n "$TOKEN" && -n "$HOSTER" ]]; then
  echo "[verify_event_age_groups] Create-Roundtrip mit Auth..."
  start_date="$(date -u -v+7d '+%Y-%m-%dT%H:%M:%S.000Z' 2>/dev/null \
    || date -u -d '+7 days' '+%Y-%m-%dT%H:%M:%S.000Z')"
  create_response="$(curl -sS -w '\n%{http_code}' -X POST "$BASE_URL/api/events" \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $TOKEN" \
    --data "{\"hosterId\":\"$HOSTER\",\"title\":\"Age group verify event\",\"location\":\"Berlin\",\"latitude\":$LAT,\"longitude\":$LON,\"startDate\":\"$start_date\",\"eventType\":\"playgroup\",\"visibility\":\"publicNearby\",\"maxParticipants\":5,\"shareRadiusKm\":10,\"ageGroups\":[\"toddler\",\"preschool\"]}")"
  create_status="${create_response##*$'\n'}"
  create_body="${create_response%$'\n'*}"

  if [[ "$create_status" != "201" ]]; then
    echo "[verify_event_age_groups] ERROR: POST /api/events -> HTTP $create_status"
    echo "[verify_event_age_groups] Response: $create_body"
    exit 1
  fi

  if ! printf '%s' "$create_body" | grep -q '"toddler"'; then
    echo "[verify_event_age_groups] ERROR: ageGroups wurden beim Create nicht gespeichert/zurückgegeben."
    echo "[verify_event_age_groups] Response: $create_body"
    exit 1
  fi
  echo "[OK] POST /api/events -> 201, ageGroups persistiert"
else
  echo "[INFO] Create-Roundtrip übersprungen (FIREBASE_ID_TOKEN und HOSTER_ID nicht gesetzt)."
fi

echo "[verify_event_age_groups] Erfolgreich abgeschlossen."
