# Übergabe ParentPeak – Stand 2026-11-03

Reine Übergabe. Keine Code-Änderung, kein Merge, kein Deploy.

## Stand

- `origin/main` = `dd5b035` (nach #238, #239, #240).
- Live-Backend auf Render = `2114ead` (#238). #239 und #240 ändern nur App
  und Doku, daher kein neuer Deploy.
- Deploy `2114ead`: `prisma migrate deploy` meldet „No pending migrations to
  apply.“, danach „Your service is live“. `/release/readiness` meldet
  `status: ready`, `/health` liefert 200.

## Gemergt

| PR | Inhalt |
|---|---|
| #234 | Tastatur-Layout im Spielfreunde-Wizard und anderen Formularen |
| #235 | Umlaute und Sprachnamen (Autonyme), lokalisierbare Labels |
| #237 | Prisma-Fix: Verifizierungsfelder im Schema, Profil-Anlage repariert |
| #238 | W1: Kontaktanfragen aus der Entdeckung werden nie automatisch bestätigt |
| #239 | f0: `same_city` lokalisiert, Pflichtfelder in Wizard-Schritt 1 |
| #240 | Konzept für das Eltern-Netzwerk-Redesign (`ELTERN_NETZWERK_REDESIGN.md`) |

## Offen

- **#236 (Draft)** `fix/playmate-publish-errors`, Head `8a74b46`:
  strukturierte, lokalisierte Fehlercodes beim Veröffentlichen des Profils.
  Auf `dd5b035` gebracht. `flutter analyze --no-pub` ergibt 9 Infos
  (Baseline), `flutter test` 1849 bestanden und 1 übersprungen, Backend
  1036 von 1036 bestanden. Wartet auf Review und Freigabe.

## Wichtigster Blocker: Sicherheitsbefund (HIGH)

- Es gibt einen offenen Sicherheitsbefund zur Backend-Authentifizierung
  (HIGH).
- Das Repo ist öffentlich. Deshalb stehen die Details absichtlich **nicht** in
  diesem Dokument.
- Die Analyse ist nur lokal gesichert: Branch `docs/backend-token-security`
  (nicht gepusht), Datei `docs/BACKEND_TOKEN_SECURITY.md`. Sie enthält keine
  Secret-Werte.
- Diesen Branch erst pushen, wenn der Fix live ist und gegebenenfalls
  rotiert wurde.
- **Offene Frage an den Nutzer:** Womit wird der Android-Play-Store-Build
  gebaut, über `fastlane/Fastfile` oder über `scripts/flutter_repo.sh`? Die
  Antwort entscheidet, ob eine Secret-Rotation nötig ist.

## Nächste Schritte (Reihenfolge)

1. Backend-Fix nach der lokalen Sicherheitsanalyse: Admin-Zugang und
   Eigentümerprüfungen.
2. App-Fix nach derselben Analyse.
3. Gegebenenfalls Secret-Rotation in Render (Ablauf in der Analyse).
4. Eltern-Netzwerk-Redesign:
   - (a) Designsystem
   - (b) Navigation
   - Moderations-Paket m1 bis m5

   Danach folgt der Match-Ablauf (c bis e) als zusammenhängendes Paket.

## Store-Konten (Nutzer)

- Apple Developer und Google Play früh beantragen.
- Bei neuen privaten Konten verlangt Google Play einen Closed Test mit
  12 Testern über 14 Tage.
- Sign in with Apple fehlt noch.

## Offene Worktrees

`pp-main`, `pp-pr2`, `pp-pr3`, `pp-token-security`, `parentpeak-diagnosis`,
`pp-handoff`. Nach der Entscheidung zu #236 aufräumen.
`pp-token-security` erst entfernen, wenn der Branch
`docs/backend-token-security` anderweitig gesichert ist.

## Grundregeln

- Keine Force-Pushes.
- `backup/local-unsynced-2026-10-21` und `stash@{0}` nicht anfassen.
- Keine Secrets ausgeben.
- Kein Merge ohne Kiros Review und ausdrückliche Freigabe des Nutzers.
