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
