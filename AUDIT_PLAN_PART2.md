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
