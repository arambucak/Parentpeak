#!/usr/bin/env bash

set -uo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "[flutter_repo] ERROR: flutter is not installed or not on PATH."
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOTENV_FILE="$REPO_ROOT/.env"

add_dart_defines_from_env_file() {
  local env_file="$1"
  local -a dart_defines=()
  local key value line

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" != *=* ]] && continue

    key="${line%%=*}"
    value="${line#*=}"

    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"

    case "$value" in
      REPLACE_*|CHANGE_ME|TODO|YOUR_*|example|EXAMPLE|"")
        continue
        ;;
    esac

    case "$key" in
      GEMINI_MODEL_NAME|BACKEND_BASE_URL|BACKEND_API_TOKEN|STRIPE_PUBLISHABLE_KEY|PRIVACY_POLICY_URL|TERMS_OF_SERVICE_URL|CONTACT_EMAIL|CONTACT_SUPPORT_URL)
        dart_defines+=("--dart-define=${key}=${value}")
        ;;
    esac
  done < "$env_file"

  printf '%s\n' "${dart_defines[@]}"
}

should_inject_dart_defines() {
  case "${1:-}" in
    run|build)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Repo-local safeguard against Flutter plugin SPM warnings on Apple platforms.
if flutter config --help 2>/dev/null | grep -q "enable-swift-package-manager"; then
  flutter config --no-enable-swift-package-manager >/dev/null 2>&1 || true
fi

OUTPUT_FILE="$(mktemp)"
trap 'rm -f "$OUTPUT_FILE"' EXIT

flutter_args=("$@")

if should_inject_dart_defines "${flutter_args[0]:-}" && [[ -f "$DOTENV_FILE" ]]; then
  dotenv_defines=()
  while IFS= read -r dotenv_define; do
    dotenv_defines+=("$dotenv_define")
  done < <(add_dart_defines_from_env_file "$DOTENV_FILE")
  if [[ "${#dotenv_defines[@]}" -gt 0 ]]; then
    if [[ "${flutter_args[0]}" == "build" && "${#flutter_args[@]}" -gt 1 ]]; then
      flutter_args=("${flutter_args[0]}" "${flutter_args[1]}" "${dotenv_defines[@]}" "${flutter_args[@]:2}")
    else
      flutter_args=("${flutter_args[0]}" "${dotenv_defines[@]}" "${flutter_args[@]:1}")
    fi
  fi
fi

flutter "${flutter_args[@]}" 2>&1 | tee "$OUTPUT_FILE" | awk '
  BEGIN { skip=0 }
  /^The following plugins do not support Swift Package Manager for ios:/ { skip=1; next }
  /^The following plugins do not support Swift Package Manager for macos:/ { skip=1; next }
  skip && /^  - / { next }
  skip && /^This will become an error in a future version of Flutter\./ { next }
  skip && /^plugin maintainers to request Swift Package Manager adoption\./ { skip=0; next }
  { print }
'
EXIT_CODE=${PIPESTATUS[0]}
exit "$EXIT_CODE"
