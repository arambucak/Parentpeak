#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-check}"
EXPECTED_REMOTE="https://github.com/fatihbucak56-beep/Parentpeak.git"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: Bitte im Parentpeak Git-Repository ausfuehren."
  exit 2
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo "=== Parentpeak Sync Guard ==="
echo "Repo: $REPO_ROOT"
echo "Mode: $MODE"

remote_url="$(git remote get-url origin 2>/dev/null || true)"
if [[ -z "$remote_url" ]]; then
  echo "ERROR: Remote 'origin' nicht gefunden."
  exit 2
fi

echo "Origin: $remote_url"
if [[ "$remote_url" != "$EXPECTED_REMOTE" ]]; then
  echo "WARNUNG: Unerwartetes Remote. Erwartet: $EXPECTED_REMOTE"
fi

echo
echo "[1/4] Fetch"
git fetch origin --prune

current_branch="$(git branch --show-current)"
head_sha="$(git rev-parse --short HEAD)"
origin_main_sha="$(git rev-parse --short origin/main)"

echo
echo "[2/4] Branch-Stand"
echo "Aktueller Branch: $current_branch"
echo "HEAD: $head_sha"
echo "origin/main: $origin_main_sha"

counts_main="$(git rev-list --left-right --count origin/main...HEAD)"
read -r behind_main ahead_main <<<"$counts_main"
echo "Delta zu origin/main -> ahead: $ahead_main, behind: $behind_main"

if git rev-parse --verify -q "origin/$current_branch" >/dev/null; then
  counts_branch="$(git rev-list --left-right --count "origin/$current_branch"...HEAD)"
  read -r behind_branch ahead_branch <<<"$counts_branch"
  echo "Delta zu origin/$current_branch -> ahead: $ahead_branch, behind: $behind_branch"
fi

echo
echo "[3/4] Lokale Aenderungen"
dirty_count="$(git status --porcelain | wc -l | tr -d ' ')"
if [[ "$dirty_count" -eq 0 ]]; then
  echo "Arbeitsverzeichnis: clean"
else
  echo "Arbeitsverzeichnis: $dirty_count offene Aenderungen"
  git status --short
fi

echo
echo "[4/4] Empfehlung"
if [[ "$MODE" == "fix" ]]; then
  if [[ "$dirty_count" -ne 0 ]]; then
    echo "ABBRUCH: Es gibt lokale Aenderungen. Bitte zuerst committen oder staschen."
    exit 1
  fi
  if [[ "$current_branch" != "main" ]]; then
    echo "Wechsel auf main..."
    git checkout main
  fi
  echo "Pull main (fast-forward only)..."
  git pull --ff-only origin main
  echo "OK: main ist jetzt synchron."
  exit 0
fi

if [[ "$dirty_count" -eq 0 && "$behind_main" -eq 0 ]]; then
  echo "OK: Kein Sync-Risiko erkannt."
else
  echo "Hinweis: Vor neuer Arbeit entweder 'scripts/sync_guard.sh fix' ausfuehren"
  echo "oder manuell: git checkout main && git pull --ff-only origin main"
fi
