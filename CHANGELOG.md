# Changelog

Alle relevanten Änderungen an Parentpeak werden hier dokumentiert.

Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.1.0/).
Versionierung folgt [Semantic Versioning](https://semver.org/lang/de/).

---

## [Unreleased] — 2026-10-03

### Behoben
- **Kalender** — Monats-Grid füllt vollständige Wochen (Mo–So) inkl. Folgemonatstage; Edit verliert keine Daten mehr bei Abbruch; Doppel-Submit beim Speichern verhindert; Schnelleingabe (NLP) weist ungültige Uhrzeit/Datum sauber ab statt still falsch zu interpretieren; wiederkehrende Termine kalendergenau (monatlich/jährlich, schaltjahrsicher). (#59)
- **Events** — „Gastgeber" ersetzt durch ehrliches „Eingetragen von" / „Geteilt von" bei nicht selbst veranstalteten Events; differenziert über `EventHostRelation`. (#67, #68)
- **Events** — Kein irreführendes „0 bestätigt" mehr bei eingetragenen Dritt-Veranstaltungen; stattdessen Hinweis auf Anmeldung beim Veranstalter. (#76)
- **Events** — KI-Suche-Fehler werden sichtbar gemacht (retry-barer Hinweis) statt stumm verschluckt; Parser überspringt defekte Einträge statt den ganzen Feed zu verwerfen. (#71)
- **Events / Auth** — Fehlende KI-Funde behoben: Firebase-ID-Token wird jetzt bei Bedarf erneuert (`getIdToken(true)`), sodass authentifizierte Backend-Calls (u. a. `/ai/generate`) keinen abgelaufenen Token mehr senden. (#75)
- **Events** — Altersgruppen werden am Event persistiert und für Filterung/Ranking genutzt. (#60)

### Hinzugefügt
- **Kalender** — Vollständiges Qualitäts-Audit mit Unit-/Widget-Tests und Bericht (`docs/CALENDAR_QUALITY_AUDIT_2026-10-03.md`); i18n für alle Kalender-Strings in 16 Picker-Sprachen; Datums-/Zeitformate folgen der App-Sprache; `UserAvatar` in Terminkarten.
- **Events** — Qualitäts-Audit-Bericht (`docs/EVENTS_QUALITY_AUDIT_2026-10-03.md`).
- **Backend** — `/ai/health?grounding=1` testet den echten KI-Event-Pfad (Google-Search-Grounding + JSON-Array) für Launch-Monitoring.
- **Backend-Client** — Typisierte `BackendApiException` mit HTTP-Status und Server-Fehlermeldung (unterscheidet Auth- von Upstream-Fehlern in Logs).

### Infrastruktur
- **DB-Migrationen** — `render.yaml` `preDeployCommand` wendet Prisma-Migrationen automatisch beim Deploy an; neues `migrate:deploy`-Script.
- **GitHub Actions** — Neue Workflows: `prisma-migrate-deploy`, `prisma-migrate-diagnose` (read-only), `prisma-migrate-resolve` (Drift-Behebung) — ermöglichen DB-Migrationen und -Diagnose ohne Render-Shell-Zugang. `DATABASE_URL` als GitHub-Secret.
- **DB** — Produktions-Migrations-Drift (hängende `treasure_items`-Migration) über `migrate resolve` bereinigt; `Event.ageGroups`-Spalte angewandt.
- **Verifikation** — `scripts/verify_event_age_groups.sh` als Post-Migration-Smoke-Check.

### Hinweise
- KI-Event-Suche erfordert weiterhin eine authentifizierte Sitzung (gültiger Firebase-Token). Eine Öffnung für Gäste ist bewusst eine offene Produkt-/Kostenentscheidung und nicht umgesetzt.

---

## [1.0.0-beta.1] — 2026-08-20

### Hinzugefügt
- **Events & Aktivitäten** — Lokale Familien-Events via KI (Gemini), standortbasiert mit Entfernungsanzeige
- **Verschenkmarkt** — Kindersachen verschenken, lokal & solidarisch
- **KI-Elternberatung** — 8 pädagogische Ansätze (GfK, Hüther, Montessori, Reggio, Freinet, Fröbel, Situationsansatz, Juul)
- **Familienkalender** — Termine, Feiertage, Schulferien (DE/AT/CH/TR/GB)
- **Familien-Küche** — 1-Tap Rezept-Generator, altersbasiert, saisonal, mit Einkaufsliste
- **Eltern-Netzwerk** — Spielfreunde finden, 5-Schritt Wizard, ParentCoins
- **Familien-Geld** — Leistungs-Wegweiser für 6 Länder (DE, AT, CH, TR, GB, Generic)
- **Familien-Zentrale** — Einkaufsliste, To-do, Kind-Dossier mit U-Untersuchungen
- **Impulse & Entwicklung** — Tagesimpuls, Entwicklungs-Check (220+ Fragen), Eltern-Wissen FAQ
- **Wochenrückblick** — 5-Fragen Reflexion mit KI-Feedback
- **28 Sprachen** — Vollständige Lokalisierung inkl. Kurdisch (Ala-Rengin Flagge)
- **Firebase Auth** — Email/Password + Google Sign-In
- **CI/CD** — Flutter Analyze, Web Deploy, Backend Keep-Alive, AI Daily Check
- **Web-Deploy** — GitHub Pages via GitHub Actions (parentpeak.de)
- **Backend** — Node.js/Express + Prisma + PostgreSQL auf Render

### Infrastruktur
- GitHub Actions: 4 Workflows (Analyze, Deploy, Keep-Alive, Pedagogical AI Check)
- Dependabot-Konfiguration für Dart + GitHub Actions
- iOS/macOS Smoke Builds in CI
- Backend Security Baseline Verification

---

## Legende

- **Hinzugefügt** — Neue Features
- **Geändert** — Änderungen an bestehenden Features
- **Behoben** — Bugfixes
- **Entfernt** — Entfernte Features
- **Sicherheit** — Sicherheitsrelevante Änderungen
- **Infrastruktur** — CI/CD, DevOps, Tooling
