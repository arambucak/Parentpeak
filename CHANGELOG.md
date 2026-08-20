# Changelog

Alle relevanten Änderungen an Parentpeak werden hier dokumentiert.

Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.1.0/).
Versionierung folgt [Semantic Versioning](https://semver.org/lang/de/).

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
