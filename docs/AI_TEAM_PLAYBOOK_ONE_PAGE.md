# AI Team Playbook (1 Page)

Zweck: Kiro und Copilot arbeiten schnell, ohne Konflikte und mit klarer Verantwortung.

## 1) Ein Task, ein Owner

- Pro Task genau ein Implementierungs-Owner.
- Nur der Owner schreibt produktiven Code in den betroffenen Dateien.
- Der zweite Agent uebernimmt Review, Tests oder Refactor.

## 2) Branch-Regel

- Nie direkt auf `main` arbeiten.
- Branch-Namen:
  - `ai/kiro/<task-kurzname>`
  - `ai/copilot/<task-kurzname>`

## 3) Kein Parallel-Edit

- Keine gleichzeitigen Aenderungen in denselben Dateien.
- Wenn es notwendig ist:
  - Agent A merged zuerst.
  - Agent B rebased danach.

## 4) PR-Mindeststandard

Jede PR enthaelt:

- Ziel (1-2 Saetze)
- Geaenderte Bereiche
- Testnachweis
- Risiken / offene Punkte
- Rollback-Idee

## 5) Quality Gate vor Merge

- Relevante Checks/Tests gruener Status.
- Reviewer bestaetigt Scope und Risiken.
- Offene Punkte klar dokumentiert.

## 6) Release-Hygiene

- Kleine, fokussierte PRs.
- Nach Merge alle Arbeits-Branches auf main aktualisieren.
- Bei Incidents: Hotfix-Branch + kurze Postmortem-Notiz.

## 7) Rollenempfehlung

- Kiro: groessere Feature-Implementierung
- Copilot: Review, Debugging, Release/Deploy, Hotfixes

