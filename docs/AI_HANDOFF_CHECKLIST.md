# AI Handoff Checklist

Diese Checkliste wird vor jeder PR-Beschreibung abgearbeitet.

## A) Kontext

- [ ] Ziel des Changes klar formuliert
- [ ] Scope ist klar abgegrenzt (in/out)

## B) Umsetzung

- [ ] Nur relevante Dateien geaendert
- [ ] Keine ungeplanten Neben-Effekte bekannt

## C) Verifikation

- [ ] `Flutter: analyze (repo-safe)` ausgefuehrt
- [ ] `Git: Sync Guard (check)` ausgefuehrt
- [ ] Relevante Tests lokal gelaufen

## D) PR-Handoff Pflichtfelder

- [ ] Problem/Ziel
- [ ] Aenderungen
- [ ] Testnachweise
- [ ] Risiken / offene Punkte
- [ ] Rollback-Hinweis

## E) Merge-Bereitschaft

- [ ] Kein Parallel-Edit in denselben Dateien
- [ ] Branch ist aktuell (rebase/merge von `main`)
- [ ] PR ist klein und thematisch fokussiert
