# Parentpeak Sync Playbook (VS Code + KIRO)

Ziel: Keine doppelte Arbeit und immer derselbe Code-Stand.

## Regel 1: Ein Hauptordner

Arbeitet immer im gleichen lokalen Ordner. Wenn zwei Ordner existieren, waehlt einen als Standard.

## Regel 2: Vor jeder Session 1 Sync-Befehl

Im Projektordner ausfuehren:

```bash
bash scripts/sync_guard.sh check
```

Wenn das Script meldet, dass main hinterherhaengt:

```bash
bash scripts/sync_guard.sh fix
```

## Regel 3: Neue Arbeit nie direkt auf main

```bash
git checkout main
git pull --ff-only origin main
git checkout -b fix/<thema>
```

## Regel 4: Session sauber beenden

```bash
git add .
git commit -m "<klare aenderungsbeschreibung>"
git push origin <branch>
```

## Regel 5: Vor App-Test immer remote Stand holen

```bash
git fetch origin
git log --oneline --decorate origin/main -n 5
```

Wenn der letzte Commit hier nicht sichtbar ist, arbeitet ihr nicht auf dem aktuellen Stand.

## Kurztext fuer KIRO

Nutze immer zuerst:

```bash
bash scripts/sync_guard.sh check
```

Wenn ich hinter origin/main bin oder in falschem Branch bin, korrigiere erst den Git-Stand,
bevor du Dateien aenderst. Arbeite nie in zwei verschiedenen lokalen Parentpeak-Ordnern parallel.
