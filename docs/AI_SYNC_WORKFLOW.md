# AI Sync Workflow (Kiro + Copilot)

Ziel: Kiro und Copilot arbeiten schnell, ohne Konflikte und mit reproduzierbarer Qualitaet.

## 1) Branching-Regeln

- Nie direkt auf `main` arbeiten.
- Pro Task genau ein Feature-Branch.
- Namensschema:
  - `ai/kiro/<task-kurzname>`
  - `ai/copilot/<task-kurzname>`

## 2) Task-Ownership

- Pro Task genau ein Implementierungs-Owner.
- Nur der Owner schreibt produktiven Code in den betroffenen Dateien.
- Der zweite Agent uebernimmt nur eine dieser Rollen:
  - Review
  - Tests
  - Refactor nach Merge

## 3) Kein Parallel-Edit in denselben Dateien

- Wenn beide an derselben Datei arbeiten muessen:
  - Agent A merged zuerst.
  - Agent B rebased danach und arbeitet weiter.

## 4) Start-Protokoll vor jedem Task

- Aktuellen Stand holen und lokal synchronisieren.
- Kurz definieren:
  - Ziel
  - betroffene Dateien
  - Abnahmekriterien

## 5) Qualitaets-Gates vor Push/PR

- Analyse: `Flutter: analyze (repo-safe)`
- Sync Guard: `Git: Sync Guard (check)`
- Relevante Tests fuer den geaenderten Bereich

Hinweis: Bei Build-/Test-Problemen zuerst fixen, dann pushen.

## 6) Handoff-Standard (Pflicht in jeder PR)

- Problem/Ziel in 1-2 Saetzen
- Geaenderte Bereiche (Dateien/Module)
- Was wurde getestet?
- Risiken / offene Punkte
- Rollback-Idee (falls notwendig)

## 7) Merge-Strategie

- Merge nur per Pull Request.
- Kleinere PRs bevorzugen (ein Thema pro PR).
- Nach Merge: alle offenen Arbeits-Branches rebasen.

## 8) Empfohlene Rollenverteilung

- Kiro: groessere Feature-Implementierungen
- Copilot: Release, Deploy, DNS, Debugging, Code-Review, Hotfix

## 9) Quick-Commands

- Analyse starten: nutze Task `Flutter: analyze (repo-safe)`
- Sync Guard: nutze Task `Git: Sync Guard (check)`
- Optional Fix: nutze Task `Git: Sync Guard (fix)`

## 10) Definition of Done

Ein Task ist fertig, wenn:

- alle PR-Checks gruen sind,
- Analyse/Tests durch sind,
- Handoff in der PR enthalten ist,
- keine unklaren offenen Punkte verbleiben.
