# ParentPeak - Audit-Fortsetzung

## Firebase Storage: Owner-Grenze und Rollout

- Neue Treasure-Fotos liegen unter `treasures/<firebaseUid>/<datei>`.
  Upload ohne Firebase-Session wird abgelehnt. Eigene Create/Update/Delete-
  Zugriffe sind owner-gebunden, Reads bleiben bewusst oeffentlich.
- Alte flache `treasures/<datei>`-Objekte bestehen read-only weiter:
  keine neuen flachen Writes, keine Client-Deletes. Keine automatische
  Migration oder Loeschung des Altbestands.
- Der ungenutzte Storage-Rules-Block fuer `events/` entfaellt. Bestehende
  Event-Medienbereinigung im Backend bleibt fuer historischen Bestand erhalten.
- Der Profil-Rules-Block bleibt unveraendert.
- Rules werden nur im Repo geaendert. Firebase-Rules-Deploy separat und nur
  nach ausdruecklicher Freigabe; kein automatischer Deploy durch diesen PR.
- Nach Rules-Haertung koennen alte Clients mit flachem Upload-Pfad keine
  neuen Treasure-Fotos mehr hochladen. Client-Rollout/Update und Rules-Deploy
  bewusst koordinieren; die alten gespeicherten Bild-URLs bleiben nutzbar.
- Bei Firebase-Kontowechsel waehrend des Uploads wird nicht mit dem neuen
  Konto im alten Ordner geloescht. Zurueckbleibende Objekte werden als
  fehlgeschlagene Bereinigung gemeldet, nicht als erfolgreicher Upload.
- Kein Rules-Emulator-Harness im Repo. Owner/Fremd/Anonymous, Create/Update/
  Delete, Groesse/MIME und flacher Altbestand muessen im Rules-Simulator
  bzw. bei der separat freigegebenen Rules-Abnahme verifiziert werden.
- Backend-Tree geaendert: frisches Backup und Merge-/Deploy-Freigabe noetig.
- Admin-Medienbereinigung erkennt eigene UID-Unterordner und flachen
  Altbestand, behaelt weiterhin referenzierte Bilder und verwirft fremde
  UID-Unterordner auch bei einer gespeicherten fremden URL.

## Backlog / Restrisiko: Bild-Privatsphaere

Firebase-Download-Token-URLs sind Bearer-Links - wer die URL kennt, kann das
Bild ohne Login abrufen. Echte Bild-Privatsphaere (auch fuer `profiles/`-
Avatare und Kinderfotos) erfordert backend-vermittelte Auslieferung oder
App Check. Nicht Launch-Blocker, aber vor breiter Vermarktung adressieren.

Praezisierung: App Check allein macht vorhandene Download-Token-URLs nicht
privat und ersetzt keine Nutzer-/Owner-Autorisierung. Fuer echte private
Bilder braucht es einen autorisierten Auslieferungspfad und ein Konzept
zum Entfernen/Rotieren bestehender Download-Tokens; App Check ist allenfalls
eine zusaetzliche Schutzschicht.

## Backend-Härtungs-Block (Defense-in-depth)

Keine der folgenden Positionen war ein bestätigter, ausnutzbarer Fehler; es
sind Best-Practice-Härtungen. Umgesetzt wurde, was echten Nutzen ohne
Betriebsrisiko bringt. Riskante oder für tote Features gedachte Änderungen
wurden bewusst nicht erzwungen.

### Umgesetzt
- **Zentrale Error-Middleware:** Fängt unbehandelte Fehler aus allen Routen ab,
  liefert dem Client generische Meldungen (kein `err.message`-/Stacktrace-Leak)
  und protokolliert Details nur serverseitig. 4xx für Parse-Fehler, sonst 500.
- **HSTS:** `Strict-Transport-Security` (max-age 1 Jahr, includeSubDomains) wird
  in Produktion gesetzt. Die übrigen Security-Header (nosniff, Frame-DENY,
  Referrer-Policy, Permissions-Policy) waren bereits aktiv.
- **DB-TLS konfigurierbar:** `rejectUnauthorized` ist jetzt über
  `DATABASE_SSL_STRICT=1` aktivierbar (optional `DATABASE_SSL_CA` für Renders
  CA). Default bleibt das bisherige, funktionierende Verhalten
  (`rejectUnauthorized: false`), damit die Produktions-DB-Verbindung nicht
  bricht. **To do (Render-Konfig):** Renders CA-Zertifikat hinterlegen und
  `DATABASE_SSL_STRICT=1` setzen, um die strikte Zertifikatsprüfung zu aktivieren.

### Bewusst Backlog (nicht umgesetzt, mit Begründung)
- **npm audit:** 7 high / 13 moderate, 0 critical. Die high-Meldungen sind
  transitiv (firebase-admin → @google-cloud/storage → retry-request/teeny-request)
  und auf dem genutzten Pfad nicht als App-Exploit nachgewiesen. `npm audit fix
  --force` würde Prisma auf 6.19.3 downgraden (Breaking Change) und wird NICHT
  ausgeführt. Gezielte, kompatible Updates als Wartung einplanen.
- **OTP-Rate-Limiting an verifizierte UID:** SMS/OTP ist nicht funktionsfähig
  und wird nicht beworben. Das Rate-Limiting greift erst, wenn das Feature live
  geht; vor Aktivierung von SMS/OTP nachrüsten (verifizierte UID statt
  behaupteter UID, Empfänger-/Versand-Cooldown).

## Lokalisierung: FR/ES/IT/AR vollständig auf Deutsch-Niveau (Stand)

Alle vier Zielsprachen sind jetzt **vollständig** auf Deutsch-Niveau
übersetzt und live — UI UND amtlicher Finanz-/Leistungs-Wegweiser:

| Sprache | Kern-PR | Tiefe-PR(s) | Keys gesamt | RTL |
|---------|---------|-------------|-------------|-----|
| Französisch | #183 | #188, #191 | 1876 | nein |
| Spanisch | #184 | #192 | 1875 | nein |
| Italienisch | #185 | #193 | 1875 | nein |
| Arabisch | #186 | #194 | 1875 | ja |

Jede Sprache deckt alle nutzersichtbaren Keys ab; offen bleiben pro Sprache
nur die 2 bewusst ausgeschlossenen Keys (`development_consent_body` und
`finance_content_turkey_note_11` → EN-Fallback, von Tests so verlangt).

### Escaping-Bug behoben (#191)
Die l10n-Build-Pipeline verdoppelte bei jedem Re-Merge den Backslash vor
jedem Apostroph. Die Kaskade war seit #188 in main live (FR 312, IT 28
Zeilen rendern sichtbare Backslashes). Beide Dateien normalisiert, der
Merge-Parser (`.tmp/build_full_lang.py`) korrigiert, ein
Normalisierer (`.tmp/normalize_extra.py`) ergänzt. Alle vier Extra-Dateien
tragen jetzt 0 Backslash-Kaskaden.

### Was „Kern" umfasst (sichtbarer erster Eindruck)
Onboarding, Home inkl. aller Spielideen/Aktivitäten, Profil, kompletter
Login-/Registrierungs-Flow, Mood-Check-in, Navigation, Kachel-Titel, Rituale,
generische Aktionen/Status. Übersetzungen liegen in
`app_localizations_<lang>_extra.dart` und werden per Spread in den jeweiligen
Sprach-Block von `app_localizations_all.dart` eingebunden. Platzhalter
(`{count}`, `{name}` …) sind programmatisch verifiziert erhalten.

### Jetzt übersetzt (Tiefe)
Alle vormals offenen Ebenen sind pro Sprache übersetzt:
- Chat-/Netzwerk-Interna, Küchen-/Rezept-/Fridge-/Satt-Detailtexte,
  Treasure-/Verschenkmarkt, Admin-Bereich, Antrags-Flow, Tooltips,
  Entwicklungs-UI, Profil, Memory, Matching, Host-Dashboard, U-Untersuchungen.
- **Amtliche Finanzinhalte** (354 Keys: länderspezifische Leistungen DE/AT/
  CH/TR/UK, Beträge, Antragswege) mit Fachprüfungs-Vermerk im Text. Amtliche
  Leistungsnamen bleiben im Original (in Klammern), Rechtsverweise wörtlich.

### Bewusst NICHT übersetzt — Fallback auf DE/EN
- **KI-System-Prompts** (22 chat-Keys): reine Backend-Instruktionen, nie
  nutzersichtbar; bleiben Deutsch (Gemini ist mehrsprachig).
- **PDF/Report-Keys** (`development_pdf_i18n_test` `requiredKeys`): bleiben
  absichtlich auf EN, nicht pro Sprache übersetzen.
- `development_consent_body`, `finance_content_turkey_note_11`: EN-Fallback
  (von i18n-Tests so geprüft).

### Qualitätsstand (wichtig vor Vermarktung)
- FR/ES/IT: vollständiger, sorgfältiger Entwurf, nicht muttersprachlich
  abgenommen. Finanz-/Antragstexte tragen einen Fachprüfungs-Vermerk.
- **AR: vollständiger Entwurf eines Nicht-Muttersprachlers, RTL, im Team
  nicht prüfbar.** Vor aktiver Bewerbung von Arabisch dringend
  Muttersprachler-Review einholen — besonders gemischte LTR/RTL-Zeilen
  (Beträge mit €/£/₺, Pipe-Segmente der Leistungs-Keys, Pfeile →) und die
  pädagogischen Formulierungen am Gerät visuell gegenprüfen.
- Die Übersetzungs-Pipeline (`.tmp/` Skripte, `missing_template.json`,
  `core_source.json`) kann für Nachträge oder einen externen Dienst
  wiederverwendet werden.
