# Zurückgestellte Backend-Auditbereiche: Inventar und Risiken

**Stand:** 24.10.2026; ausschließlich `origin/main` bei `ef9be73e03515dd81590d4ed91ad7498a51a383c`.
**Branch:** `audit/medium-backend-routes`, direkt von diesem Remote-Stand angelegt.
**Umfang:** FoodFeed, Community create/delete/interest einschließlich zugehöriger Event-/Teilnahmewege, Referral, Foto-Metadaten/Serving und Serien-Follows.
**Freigabe:** Nur Analyse/Dokumentation. Keine Route, kein Client, kein Flag und kein Datenbestand wurde geändert. Keine Fix-Freigabe, kein Merge.

## 1. Vorgehen und Auth-Legende

Alle Datei:Zeile-Belege beziehen sich auf den oben genannten Commit, nicht auf spätere Änderungen. Bewertung beruht auf Quellcode und vorhandenen Testfällen, **nicht** auf Exploitversuchen gegen Produktion. „Verifiziert“ bedeutet hier statisch nachvollziehbarer Daten-/Kontrollfluss, nicht beobachteter Missbrauch.

- **G-W:** Globale Schreibguards in [`server.js:3981`](../backend/server.js#L3981) und [`server.js:4155`](../backend/server.js#L4155). Nur Schreibmethoden, konfigurationsabhängig; erlauben auch den konfigurierten gemeinsamen Backend-Bearer. Firebase-Verifikation setzt gegebenenfalls `req.firebaseUid`, bindet aber nicht automatisch alle Actorfelder im Body/Query daran. Render setzt laut [`render.yaml`](../render.yaml) beide Schreib-Auth-Flags. Das ist Konfigurationsevidenz, kein erneutes Auslesen des tatsächlichen Render-Environments. Fehlende lokale Ownerprüfung bleibt auch bei gültigem Firebase-Token eines anderen Accounts relevant.
- **V:** `requireVerifiedUser`, [`server.js:3880`](../backend/server.js#L3880): verifizierter Firebase-Token, UID aus Token; fremde `body.userId`/`query.userId` werden abgewiesen. Aliasfelder wie `creatorId`, `inviteeId`, `reportedById`, `hosterId` brauchen zusätzliche explizite Claimprüfung.
- **A:** `requireActorClaims`, [`server.js:9633`](../backend/server.js#L9633), prüft zusätzlich übergebene Actor-Aliasse gegen die verifizierte UID; kein Ersatz für V.
- **E:** `eventIdentityMiddleware`, [`server.js:11378`](../backend/server.js#L11378), unter `/events` und `/api/events`. Ohne Header lässt sie GETs durch; mit Token verifiziert sie, sofern nicht bereits eine UID gesetzt ist. **Keine eigene Owner-/Actorbindung**. Gilt nicht für `/api/community-events`.
- **O:** Explizite UID-/Ownerprüfung im Handler. Zusammen mit E verlangen mehrere bestehende Routen bereits zwingend eine Firebase-UID; fehlendes V als deklarierte Middleware ist dort allein noch kein Befund.
- **ADM:** `isAdminTokenAuthorized`, [`server.js:15302`](../backend/server.js#L15302): exakter Vergleich mit serverseitigem Backend-Token, bei fehlender Konfiguration false. Nicht dieselbe Funktion wie Firebase-basierte Adminrollen. Vorhandene Schutzwirkung anerkennen; kein Secretwert wurde gelesen oder dokumentiert.
- **Ö:** Im Code anonym erreichbare Leseansicht. „Öffentlich implementiert“ ist keine pauschale rechtliche Freigabe für jedes zurückgelieferte Feld.

Bestehende Referenzen: #215 (`74ded99`, Weekly-Moderation: verifizierte Firebase-Identität, Rollen und verifizierter Client), #222 (`b7df6ff`, Event-/Familien-/Payment-Ownerbindung und negative Identitätstests). #216 (`3f36c5c`) betrifft **Client-Discovery/Datum/Quellen/Ort**, keine Backend-Auth-Middleware; nicht fälschlich als Auth-Fix-Schablone behandeln. Sichere lokale Beispiele sind [`server.js:9946`](../backend/server.js#L9946) für Familienrezepte, [`server.js:15049`](../backend/server.js#L15049) für Community-Meldungen und [`backend_service_factory.dart:70`](../lib/logic/backend_service_factory.dart#L70) für Clients ohne statischen Tokenfallback.

## 2. FoodFeed

Dieser Pfad ist **nicht** identisch mit den bereits separat gehärteten Familienrezepten unter `/api/recipes`. Alle folgenden Handler stehen in [`server.js`](../backend/server.js). Flutter-Aufrufer stehen, sofern nicht anders angegeben, in [`gemeinsam_satt_backend_service.dart`](../lib/logic/gemeinsam_satt_backend_service.dart).

| Methode + Pfad; Backend-Beleg | Auth / Identität / Öffentlichkeit | Konkretes Risiko und minimaler Vorschlag | Flutter-Aufrufer |
| --- | --- | --- | --- |
| `GET /api/food-feed/recipes`; `server.js:13610` | Ö, keine lokale Auth; `isPublished:true`, begrenzte Ergebniszahl. | Veröffentlichter Feed grundsätzlich öffentlich belassen. Kein Actor-Spoofing auf diesem GET. `creatorUserId`, `familyId`, Trust-Aggregate sind öffentlich; `familyId`-Notwendigkeit prüfen/minimieren. Kein allein aus UID-Ausgabe abgeleiteter Blocker. | `gemeinsam_satt_backend_service.dart:241` |
| `GET /api/food-feed/recipes/:id`; `server.js:13680` | Ö; `findUnique(id)` ohne `isPublished`-Filter, volle Rezeptdaten plus fünf Ratings. | **F6, mittel:** anders als die Liste keine Publikationsprüfung; sofern unveröffentlichte Datensätze existieren, sind sie per bekannter ID erreichbar. Existenz solcher Datensätze nicht geprüft. Öffentliche Detailprojektion auf veröffentlichte Rezepte begrenzen; private Owneransicht separat authentifizieren, falls benötigt. Rating-UIDs nicht ungeprüft übernehmen; GET erhöht auch Viewcounter (Manipulierbarkeit, keine Abrechnung nachgewiesen). | `gemeinsam_satt_backend_service.dart:269` |
| `POST /api/food-feed/recipes`; `server.js:13716` | G-W, kein V/O; `body.userId` wird Creator, `familyId` frei. | **F2, hoch:** fremde Autorenschaft möglich. V, Creator aus UID, fremden Claim ablehnen. Optionalen Familienclaim über bestehende eigene Familienprüfung validieren, statt beliebige Zuordnung zu übernehmen. | `gemeinsam_satt_backend_service.dart:314` |
| `PUT /api/food-feed/recipes/:id`; `server.js:13776` | G-W; Creatorvergleich ausschließlich gegen `body.userId`. | **F2, hoch:** fremdes Rezept durch behauptete Creator-ID bearbeitbar. V + gespeicherter Creator gleich Token-UID. | `gemeinsam_satt_backend_service.dart:374` |
| `DELETE /api/food-feed/recipes/:id`; `server.js:13822` | G-W; Query-/Body-`userId` wird mit Creator verglichen. | **F2, hoch:** fremde Löschung trotz gültigem Token eines anderen Accounts möglich. V + gespeicherter Creator gleich UID; Queryclaim abweisen. | `gemeinsam_satt_backend_service.dart:407` |
| `POST /api/food-feed/recipes/:id/rate`; `server.js:13854` | G-W; `body.userId` als Rating-Actor. | **F2:** fremde Bewertung setzen/überschreiben. V, Actor aus UID. | `gemeinsam_satt_backend_service.dart:447` |
| `GET /api/food-feed/recipes/:id/comments`; `server.js:13897` | Ö; Rezept-Existenzprüfung, limitierte öffentliche Kommentare mit Autoren-UID/Text/Zeit. | Öffentliche Kommentare nicht blind sperren. **F6:** wie Detail kein Veröffentlichungsfilter; denselben Sichtbarkeitsresolver nutzen. Kein Nachweis, dass öffentliche Kommentartexte an sich privat sein sollen. | `gemeinsam_satt_backend_service.dart:477` |
| `POST /api/food-feed/recipes/:id/comments`; `server.js:13930` | G-W; Autor aus `body.userId`. | **F2:** Identität für Kommentare übernehmbar. V, Actor UID; Sichtbarkeit des Zielrezepts mitprüfen. | `gemeinsam_satt_backend_service.dart:508` |
| `GET /api/food-feed/recipes/:id/reservations`; `server.js:13985` | Ö; Aggregate plus `myReservation` für frei gewählte Query-`userId`. | **F6, mittel:** fremde individuelle Reservierung samt UID/Portionen/Zeitpunkten lesbar. Aggregate dürfen öffentlich bleiben; personalisierten Anteil nur für verifizierte UID liefern, fremden Queryclaim ablehnen. Publikationsprüfung ergänzen. Kein pauschales Sperren des Aggregat-GET. | `gemeinsam_satt_backend_service.dart:619` |
| `POST /api/food-feed/recipes/:id/reserve`; `server.js:14034` | G-W; `body.userId`. | **F2:** fremde Reservierung setzen/überschreiben. V, UID verwenden. | `gemeinsam_satt_backend_service.dart:537` |
| `DELETE /api/food-feed/recipes/:id/reserve`; `server.js:14087` | G-W; Query-/Body-`userId`. | **F2:** fremde Reservierung löschen. V, Löschbedingung aus UID. | `gemeinsam_satt_backend_service.dart:567` |
| `POST /api/food-feed/recipes/:id/complete`; `server.js:14125` | G-W; `body.userId`. | **F2:** fremde Reservierung abschließen; Vertrauens-/Completion-Aggregate beeinflussbar. V, Actor UID; keine monetäre Folge belegt. | `gemeinsam_satt_backend_service.dart:592` |
| `POST /api/food-feed/recipes/:id/report`; `server.js:14175` | G-W; `reportedById` bzw. `userId`. | **F2:** fremde Melderschaft. V und A für beide vorhandenen Aliasse, Reporter ausschließlich UID. Vorhandene Moderationssemantik beibehalten. | `gemeinsam_satt_backend_service.dart:646` |
| `GET /api/food-feed/reports`; `server.js:14280` | ADM im Handler; keine anonyme Reportliste bei fehlendem/falschem Admin-Token. | **Kein nachgewiesener Auth-Bypass.** Nicht durch gewöhnliches V ersetzen und damit für alle Nutzer öffnen. Spätere Rollenvereinheitlichung separat; Client-Konfiguration nicht als Secretbeweis interpretieren. | `ui/backend_status_screen.dart:171` |
| `POST /api/food-feed/reports/:reportId/resolve`; `server.js:14319` | G-W + ADM; erlaubte Aktionen explizit geprüft. | **Kein nachgewiesener Auth-/Ownerfehler.** Adminschutz erhalten; Rollenmigration nicht Teil eines Recipe-CRUD-Fixes. | `ui/backend_status_screen.dart:195` |

Clientverträglichkeit: [`gemeinsam_satt_backend_service.dart:201`](../lib/logic/gemeinsam_satt_backend_service.dart#L201) bevorzugt Firebase, fällt aber auf einen statischen API-Token zurück. Für später gehärtete Actoraktionen verifizierten Client/Tokenpflicht verwenden; öffentliche Feedansichten getrennt erhalten. Ein UI-Login macht frei behauptete Backend-IDs nicht vertrauenswürdig.

## 3. Community und bestehende Event-/Teilnahmewege

### 3.1 Eigenständige Community-Discovery

Alle Serverbelege in [`server.js`](../backend/server.js); Client in [`community_event_service.dart`](../lib/logic/community_event_service.dart).

| Methode + Pfad; Backend-Beleg | Auth / Identität / Öffentlichkeit | Risiko / minimaler Fix | Flutter-Aufrufer |
| --- | --- | --- | --- |
| `GET /api/community-events`; `server.js:14906` | Ö, Stadt-/Filterparameter; keine Accountidentität als Autorität. | Öffentliche Discovery; **kein nachgewiesener Actorfehler**. Nicht wegen benachbarter Schreibfehler sperren. Feldminimierung/Standortdarstellung getrennt bewerten. | `community_event_service.dart:61` |
| `POST /api/community-events`; `server.js:14947` | G-W; `body.creatorId`, kein V/A/O. | **F3, mittel:** fremde Autorenschaft. V + A für `creatorId`, speichern aus UID. | `community_event_service.dart:131` |
| `DELETE /api/community-events/:id`; `server.js:15025` | G-W; gespeicherter Creator nur gegen `query.creatorId` geprüft. | **F3, mittel:** fremde Events mit bekannter Creator-ID löschbar. V/A + Creator gleich UID. | `community_event_service.dart:262` |
| `POST /api/community-events/:id/flag`; `server.js:15049` | V; Reporter aus `req.firebaseUid`, kein frei behaupteter Reporter als Autorität. | **Kein nachgewiesener Identitätsfehler**, vorhandenes Muster für die Nachbarrouten wiederverwenden. | `community_event_service.dart:155` |
| `POST /api/community-events/:id/interest`; `server.js:15089` | G-W; `body.userId` für Upsert, frei übergebener Anzeigename/Nachricht. | **F3:** fremde Interessenbekundung überschreibbar. V, Actor UID. Anzeigename nicht zur Autorisierung verwenden. | `community_event_service.dart:188` |
| `GET /api/community-events/:id/attendees`; `server.js:15127` | Ö; bis 50 Einträge mit UID, Anzeigename, Nachricht und Beitrittszeit. | Öffentlich implementierte Teilnehmerdarstellung. **Vermutetes Datenschutzrisiko**, keine belegte private Sichtbarkeitszusage. Öffentliche Anzeige nicht blind abschalten; UID/Zeit/Nachricht auf Notwendigkeit prüfen, UI-Zusage/Einwilligung vor Erweiterung abgleichen. Kein eigenständiger bewiesener Zugriffsbruch allein aus „kein V“. | `community_event_service.dart:222` |

### 3.2 Nicht mit den ungeprüften Community-Routen verwechseln

Die folgenden bestehenden Haupt-Eventrouten wurden zur Abgrenzung einbezogen. Sie sind nicht pauschal ebenfalls unsicher. Clientbelege in [`event_backend_service.dart`](../lib/logic/event_backend_service.dart).

| Methode + Pfad; Backend-Beleg | Aktuelle Auth / Ownerbindung | Ergebnis / Vorschlag | Flutter-Aufrufer |
| --- | --- | --- | --- |
| `POST /api/events`; `server.js:14378` | E + V; `hosterId` muss UID entsprechen. | **Kein belegter Creator-Bypass**; erhalten. | `event_backend_service.dart:152` |
| `PUT /api/events/:id`; `server.js:14725` | E + O; UID erforderlich, Body-Host gleich UID und gespeichertem Host. | **Kein belegter Owner-Bypass**; nicht nur wegen fehlendem V im Routenkopf ändern. | `event_backend_service.dart:194` |
| `DELETE /api/events/:id`; `server.js:14785` | E + O; UID erforderlich, Query-Host gleich UID und gespeichertem Host. | **Kein belegter Owner-Bypass**; erhalten. | `event_backend_service.dart:166` |
| `GET /api/events/:id`; `server.js:14682` | E; `authorizeEventParticipation` (`server.js:12103`) prüft Event-Sichtbarkeit. Öffentliche Events anonym zugänglich. | **F1, hoch / Blocker:** `include.chat.messages` und Spread `...event` liefern fünf Chatnachrichten mit, ohne `authorizeEventChat`. Öffentliche Detailprojektion von Chatdaten befreien; Chat nur über geschützten Chatendpoint. Öffentliche Events nicht pauschal sperren. Teilnehmerprojektion ebenfalls gegen berechtigte öffentliche Daten prüfen. | `event_backend_service.dart:112`; regulärer Chat: `meetup_chat_service.dart:53` |
| `POST /events`; `server.js:11649` | E + V + Host gleich UID. | Kein hier nachgewiesener Creator-Bypass. | Primärer Client nutzt `/api/events`; Altpfad nicht als separater Flutter-Hauptaufruf gefunden. |
| `DELETE /events/item/:id`; `server.js:11786` | E + V; `requestingUserId` aus UID, Ownerprüfung. | Kein hier nachgewiesener Owner-Bypass. | Primärer Client nutzt `/api/events/:id`; kein separater direkter Aufrufer belegt. |
| `GET /events/participations`; `server.js:12015` | E + O; Query-`userId` muss UID sein. | Keine fremde Teilnehmerkonto-Abfrage nachgewiesen. | `event_backend_service.dart:337`, `:418` |
| `GET /events/participations/pending`; `server.js:12042` | E + O; `hostUserId` muss UID sein, Auswahl eigener Events. | Kein Host-Bypass nachgewiesen. | `event_backend_service.dart:352` |
| `POST /events/participations`; `server.js:12075` | E + O; `userId` gleich UID, `ensureAuthenticatedEventUser`, Sichtbarkeitsprüfung in transaktionaler Teilnahmeänderung. | Kein Fremdteilnahme-Bypass nachgewiesen. | `event_backend_service.dart:369` |
| `PUT /events/participations/withdraw`; `server.js:12124` | E + O; Body-`userId` gleich UID. | Kein fremder Widerruf nachgewiesen. | `event_backend_service.dart:403` |
| `PUT /events/participations/:id/respond`; `server.js:12137` | E + O; gespeicherte Teilnahme, Hostprüfung gegen UID innerhalb Autorisierung. | Keine fremde Hostbestätigung nachgewiesen. | `event_backend_service.dart:387` |
| `GET /events/:id/participations/approved`; `server.js:12161` | E; Event-Sichtbarkeitsprüfung, nur bestätigte Teilnahmen; Interest-Modus leere Liste. | Öffentliche Teilnehmeransicht für öffentliche Events nicht blind sperren. Kein Nachweis privater Eventumgehung hier; Feldminimierung getrennt. | `event_backend_service.dart:439` |
| `GET /events/:id/chat/messages`; `server.js:12215` | E + V + `authorizeEventChat` (`server.js:12188`); Host, Moderator oder bestätigte Teilnahme. | Kein hier nachgewiesener Chat-Auth-Bypass. **Gerade dieser Schutz wird durch F1 im anderen Detailpfad umgangen.** | `meetup_chat_service.dart:53` |

Weitere Einladungs-/Chat-Schreibwege sind keine vollständige erneute Auditierung aller Eventfeatures; sie werden hier nicht als geprüft/frei von Fehlern zertifiziert.

## 4. Referral / ParentCoins

| Methode + Pfad; Backend-Beleg | Auth / Identität | Konkretes Risiko / Fixvorschlag | Flutter-Aufrufer |
| --- | --- | --- | --- |
| `POST /referrals/record`; [`server.js:7533`](../backend/server.js#L7533) | G-W, kein V/A; `inviteeId`, `inviteeName` und Referralcode aus Body; DB bzw. Fallback nach bestehender Persistenzpolicy. | **F7, mittel:** Einträge für fremde Nutzer möglich; Codebesitz/-gültigkeit nicht verifiziert. Falls weiter benötigt: V, `inviteeId` aus UID, fremden Aliasclaim abweisen und gültigen Zielcode prüfen. Alternativ nach expliziter Freigabe stillgelegte Funktion entfernen, nicht ParentCoins wieder einführen. | **Kein aktueller HTTP-Aufrufer gefunden.** |
| `GET /referrals/pending/:code`; [`server.js:7566`](../backend/server.js#L7566) | Ö, Code ist alleiniger Filter; keine Eigentümerbindung. | **F7:** zu bekanntem Code Liste mit `inviteeId`, Namen und Zeitpunkten öffentlich lesbar; keine Begrenzung im Handler. Codeentropie/aktive Daten unbekannt, daher keine pauschale Brute-Force-Behauptung. Nicht als notwendige öffentliche Invite-Landing-Route behandeln. Stilllegen oder verifizierten Code-Owner verlangen; keine Ownerzuordnung aus Clientbehauptung erfinden. | Kein aktueller HTTP-Aufrufer gefunden. |
| `DELETE /referrals/claim/:code`; [`server.js:7582`](../backend/server.js#L7582) | G-W, keine UID-/Code-Ownerprüfung; löscht alle Einträge zum Code. | **F7:** anderer angemeldeter Nutzer kann fremde ausstehende Referrals löschen; keine bewiesene Coin-Auszahlung. Falls benötigt: Code-Owner serverseitig auflösen, V/O, atomare Claim-Verarbeitung. Registry-/Datenmigration vor Fix klären, nicht blind Codebesitz als Berechtigung annehmen. | Kein aktueller HTTP-Aufrufer gefunden. |

[`home_screen.dart:185`](../lib/ui/home_screen.dart#L185) dokumentiert ausdrücklich die Entfernung des ParentCoin-Belohnungssystems; `:188` verwirft lediglich lokal gespeicherte ausstehende Codes nach Login. Einstiegscode wird in [`main.dart:261`](../lib/main.dart#L261) geparst und in [`home_screen.dart:164`](../lib/ui/home_screen.dart#L164) übernommen. **Das sind keine Aufrufer der drei Backend-Routen.** In den untersuchten Serverrouten und im Prisma-Schema wurde kein aktiver ParentCoins-Guthaben-/Auszahlungspfad gefunden. Keine Aussage über externe/ältere Clients oder historische DB-Inhalte.

Empfehlung: eigener kleiner Legacy-Referral-PR nach Bestätigung, ob diese ungenutzten API-Pfade entfernt werden dürfen. Das ist kein Grund, in diesem Audit eigenmächtig eine Funktion abzuschalten oder ein Belohnungssystem neu zu entwerfen.

## 5. Fotos: Album-Metadaten, Binär-Upload und Serving

| Methode + Pfad; Backend-Beleg | Auth / Identität / Datenfluss | Risiko / minimaler Fix | Flutter-Aufrufer |
| --- | --- | --- | --- |
| `GET /photos`; [`server.js:8555`](../backend/server.js#L8555) | Ö; gibt gesamte globale `photoAlbums`-Liste zurück, ohne Familienfilter. Seedliste bei `server.js:5029`; darin auch neue per POST angelegte Einträge. | **F8, mittel:** familyId, Titel, Anzahl, Zeitpunkte aller Alben sichtbar; keine Bilddateien/EXIF in diesem Handler. Aktuell vorhandene echte Daten nicht geprüft. Für private Familienalben V + `requireOwnFamily` und ausschließlich eigene Daten; falls Demo-Feature stillgelegt, Entfernung separat bestätigen. | [`photo_backend_service.dart:20`](../lib/logic/photo_backend_service.dart#L20) |
| `POST /photos`; [`server.js:8559`](../backend/server.js#L8559) | G-W; freie `body.familyId`, sonst Demo-Familie; kein V/`requireOwnFamily`; globale In-Memory-Liste. | **F8:** Metadaten fremden Familien zuschreiben, Liste füllen; keine dauerhafte Familienpersistenz hier. Eigene Familie serverseitig ableiten, Fremdclaim abweisen, bestehende Family-Patterns verwenden; Persistenz/Demo-Lifecycle separat klären. | [`photo_backend_service.dart:38`](../lib/logic/photo_backend_service.dart#L38); Family aus APIConfig, späteren Clientfix einplanen. |
| `POST /uploads/image`; [`server.js:13109`](../backend/server.js#L13109) | G-W, kein lokales V; `upload.single('image')`; höchstens 10 MiB; MIME-Allowlist aus Multipartfeld. Keine Ownerzuordnung zum gespeicherten Dateinamen. | **F4, mittel:** Originalbytes werden gespeichert, keine serverseitige Dekodierung/Metadatenentfernung. Dateiendung aus frei gewähltem Originalnamen bei `server.js:73`; dadurch auch aktive HTML-Auslieferung möglich, wenn behaupteter Bild-MIME akzeptiert wird. V für Accountuploads, echte Bilddekodierung + kanonische Neukodierung ohne Metadaten, serverbestimmte Endung. Mengen-/Quotenmodell separat, keine DoS-Zusage ohne Lasttest. | [`event_backend_service.dart:210`](../lib/logic/event_backend_service.dart#L210), `:231`; [`family_recipe_share_service.dart:65`](../lib/logic/family_recipe_share_service.dart#L65); [`friend_chat_service.dart:291`](../lib/logic/friend_chat_service.dart#L291) |
| `GET/HEAD /uploads/<Dateiname>`; statische Middleware [`server.js:13107`](../backend/server.js#L13107) | Ö über `express.static`; zufälliger Dateiname ist keine Ownerautorisierung. Keine Transformation; Inhalt aus Uploadverzeichnis. | **F4:** mitgespeicherte EXIF-/GPS-/Geräteinformationen werden mit Originaldatei ausgeliefert, sofern Eingang sie enthält. Zusätzlich aktiver Inhalt unter Backend-Origin durch falsche Endung möglich. Öffentliche Eventbilder dürfen öffentlich bleiben; nur bereinigte kanonische Bilder veröffentlichen. Für Chat-/Familienbilder privaten Storage/autorisierten Zugriff prüfen, statt öffentliche URL als Zugriffsschutz zu werten. | URLs werden von Uploadantworten übernommen; Chat-/Event-/Rezeptdienste wie oben, Darstellung z. B. [`event_photo.dart`](../lib/ui/widgets/event_photo.dart). |

### EXIF: was konkret belegt ist

- [`server.js:70`](../backend/server.js#L70) verwendet Multer-Diskstorage; [`server.js:81`](../backend/server.js#L81) prüft nur angegebenen MIME. Der Handler schreibt/serviert Originalbytes, keine Bildneukodierung oder EXIF-/GPS-Entfernung.
- [`image-upload.test.js:178`](../backend/tests/unit/image-upload.test.js#L178) prüft unveränderte gespeicherte Bytes. Bestehende Größen-/Parserhärtung bleibt sinnvoll, beweist aber keine Metadatenbereinigung.
- **Statisch verifiziert:** Enthält eine Eingangsdatei EXIF/GPS, entfernt dieser Backendpfad sie nicht. **Nicht geprüft:** ob konkrete Kamera-/Picker-Versionen auf allen Plattformen Metadaten bereits clientseitig entfernen, oder ob aktuell produktive Dateien GPS enthalten.
- **Statisch nachvollziehbares Zusatzrisiko:** MIME wird vom Absender behauptet, Endung unverändert übernommen, statische Auslieferung wählt den Typ anhand des Dateinamens. `nosniff` allein korrigiert eine bereits als HTML ausgelieferte Datei nicht. Keine Live-HTML-Datei hochgeladen, keine Skriptausführung/Tokenentwendung ausprobiert.
- Öffentliche Binärdateien aus Chat-/Familienflows sind ein **Vertraulichkeits-Prüfpunkt**, nicht automatisch der Beweis, dass fremde Nutzer die zufälligen URLs kennen. Keine Verzeichnisauflistung oder bereits erfolgte Enumeration behauptet.

## 6. Serien-Follows

| Methode + Pfad; Backend-Beleg | Auth / Identität | Risiko / minimaler Fix | Flutter-Aufrufer |
| --- | --- | --- | --- |
| `POST /api/events/series/:seriesId/follow`; [`server.js:14829`](../backend/server.js#L14829) | G-W + E, keine Actorbindung; `body.userId`; Suspendierungsprüfung dieser behaupteten ID. | **F5, mittel:** fremde Serienabos anlegen; Suspendierungsprüfung ist keine Authentifizierung. V + UID, fremden Claim abweisen. | [`event_backend_service.dart:621`](../lib/logic/event_backend_service.dart#L621) |
| `DELETE /api/events/series/:seriesId/follow`; [`server.js:14854`](../backend/server.js#L14854) | G-W + E; freie Query-`userId`. | **F5:** fremde Abos entfernen. V, Löschbedingung aus UID. | [`event_backend_service.dart:639`](../lib/logic/event_backend_service.dart#L639) |
| `GET /api/events/series/:seriesId/follow`; [`server.js:14874`](../backend/server.js#L14874) | E, anonym ohne Header erlaubt; Query-`userId` für individuellen Status, zusätzlich Aggregatzahl. | **F5:** personenbezogenen Followstatus beliebiger UID abfragen. Personalisierten Status nur aus verifizierter UID, Fremdclaim abweisen; bewusst öffentlichen Followerzähler separat erhalten, keine blinde Gesamtsperre. | [`event_backend_service.dart:656`](../lib/logic/event_backend_service.dart#L656) |

[`server.js:14497`](../backend/server.js#L14497) nutzt gespeicherte Follows zur Benachrichtigung über neue Termine: Manipulation verändert echte Benachrichtigungsbeziehungen, nicht nur einen kosmetischen Zähler. [`events-series-follow.test.js:123`](../backend/tests/events-series-follow.test.js#L123) prüft vorhandenes Verhalten, aber gemeinsame Bearer mit frei erzeugten Nutzerkennungen belegen keine Token-A/B-Isolation.

## 7. Priorisierung und getrennte PRs

Die Bezeichnung „mittlere Auditbereiche“ ist keine vorab feststehende Severity jedes Befunds. Fehlender Middleware-Name allein ist ebenfalls kein Sicherheitsbefund.

| ID | Einstufung / Vertrauen | Beleg und Auswirkung | Priorität / klein reviewbarer PR |
| --- | --- | --- | --- |
| F1 | **HIGH, 10/10** | `server.js:14682`: Chatdaten in öffentlicher Eventdetailantwort umgehen separaten Chatschutz. | **Launch-Blocker 1:** nur öffentliche Detailprojektion/Chat-Nebenausgabe + Tests, keine Sperre öffentlicher Events. |
| F2 | **HIGH, 10/10** | `server.js:13716`, `:13776`, `:13822` sowie Interaktionen: fremde Actor-/Creatoridentität. | **Launch-Blocker 2:** zunächst FoodFeed-Creator-CRUD; danach eigener PR für Rating/Kommentare/Reservierung/Abschluss/Report. Beide brauchen A/B-Identitätstests und verifizierten Client. |
| F3 | **MEDIUM, 10/10** | `server.js:14947`, `:15025`, `:15089`: fremde Community-Erstellung/Löschung/Interessen. | Eigener Community-Actor-PR; öffentliche Discovery/Attendees und bereits sichere Flagroute erhalten. |
| F4 | **MEDIUM, 9/10** | `server.js:70`, `:13107`, `:13109`: Originalmetadaten und ungeprüfte aktive Inhalte öffentlich auslieferbar. | Eigener Medien-PR: Dekodierung, Metadatenstrip, kanonische Endung, Serving-/EXIF-Tests. Private Chat-/Familienmedien ggf. separater Storage-/Zugriffs-PR nach UX-/Lifecycle-Abgleich. |
| F5 | **MEDIUM, 10/10** | `server.js:14829`, `:14854`, `:14874`: fremde Follows ändern/lesen. | Eigener Serien-Follow-PR, personalisierten Status vom öffentlichen Count abgrenzen. |
| F6 | **MEDIUM, 9/10** | `server.js:13985`: individuelle Reservierungen fremder Nutzer lesbar; `:13680`/`:13897` ohne Publikationsfilter. | Eigener FoodFeed-Leseprojektion-PR; private Reservierungsanteile schützen, öffentliche Aggregate erhalten. Die reale Existenz unveröffentlichter Rezepte vor Bewertung der Reichweite prüfen. |
| F7 | **MEDIUM, 9/10** | `server.js:7533`, `:7566`, `:7582`: Referral-Fälschung, Namens-/UID-Ausgabe, fremdes Claim-Löschen. | Eigener Legacy-Referral-PR. Zuerst Nutzung/gewünschte Stilllegung bestätigen; keine Coin-Neuentwicklung. |
| F8 | **MEDIUM, 9/10** | `server.js:8555`, `:8559`: globale Familienalbum-Metadaten und freie Familienzuordnung. | Eigener Familienalbum-PR oder bestätigte Stilllegung; nicht mit Binär-Upload verwechseln. |
| — | **Kein nachgewiesener zusätzlicher Handlungsbedarf im geprüften Authaspekt** | ADM-Foodreports; Community-Flag; verifizierte Event-Erstellung/-Löschung und geprüfte Teilnahmeaktionen. Öffentliche Feed-/Discovery-/Countansichten sind nicht allein wegen fehlendem Login ein Befund. | Bestehende Schutzwirkung erhalten. Datenminimierung bleibt gesonderter Prüfpunkt, keine pauschale „alles sicher“-Zertifizierung. |

Fix-Reihenfolge als Vorschlag: F1 → F2-Creator-CRUD → F2-Interaktionen → F3 → F4 → F5/F6 → F7/F8. F7/F8 können nach Nutzungsentscheidung vorgezogen werden. Kein Sammel-PR; keine Umsetzung ohne Nutzerprüfung dieses Inventars.

Zu jedem später freigegebenen PR: A ohne Token → 401 für nutzergebundene Aktionen; Token A mit Claim B → 403 ohne Seiteneffekt; A darf eigene Aktion ausführen; vorhandene private Sichtbarkeit/Hostrollen respektieren; öffentliche erlaubte Projektionen bleiben erreichbar. Medien zusätzlich echte EXIF/GPS-Testdatei und MIME-/Endungsabweichung prüfen; keine Produktions-Exploitfixtures ablegen.

## 8. Verifiziert / vermutet / nicht geprüft

### Verifiziert (statisch)

- Routenregistrierungen, globale/lokale Middleware, Actorquellen, Datenbankbedingungen, Rückgabeprojektionen und die genannten Flutter-Aufrufstellen wurden inventarisiert.
- F1–F5 aus unabhängiger Read-only-Sicherheitsanalyse; ergänzende Inventarprüfung dokumentiert F6–F8 und ausdrücklich vorhandene sichere/öffentliche Gegenbeispiele.
- Aktiver Flutter-Referral-HTTP-Aufruf nicht gefunden; aktueller Home-Code entfernt alte lokale Referral-/Coin-Reste, keine aktive Coin-Auszahlung im geprüften Server-/Prisma-Umfang gefunden.
- `GET /photos` ist Album-Metadatenlogik, nicht Binärbild-/EXIF-Parsing. Multer-/Servingpfad ist davon unabhängig.
- Keine Änderungen an Authregeln, Daten, Geburtstags-/Gemini-Fluss, Limits, Provider-Tarifen, Entitlement, Consent oder Monetarisierung.

### Vermutet / vor jeweiligem Fix zu klären

- Reale Anzahl sensibler/unveröffentlichter Datensätze und Reichweite öffentlicher Metadaten. Öffentliche Attendee-/Kommentar-/Trust-Darstellung ist nicht automatisch ein belegter privater Datenbruch.
- Ob externe Altclients Referrals oder Demo-Alben noch verwenden und ob eine Stilllegung zulässig ist. Keine Ownerregistry oder neue Claimsemantik ohne Abgleich erfinden.
- EXIF-Vorkommen in realen Uploads; private Erwartungen an öffentliche Chat-/Familienbild-URLs; Volumen-/Enumeration-/Quota-Missbrauch ohne Last-/Runtimeprüfung nicht quantifiziert.
- Keine belegte Tokenentwendung, kein nachgewiesener Kontodiebstahl, keine Coin-/Geldauszahlung durch die dokumentierten Punkte.

### Nicht geprüft / bewusst nicht ausgeführt

- Keine Live-Requests zu den Audit-Routen, keine fremden Konten/Objekte, keine Produktionsdaten oder Secrets gelesen; keine Upload-/Lösch-/Claimversuche.
- Keine Tests, Builds, Analyze-, Prisma- oder Integrationsläufe: **für diese reine Dokumentationsaufgabe ist Code-Verifikation nicht nötig und wurde nicht durchgeführt**. Vorhandene Tests wurden nur als Quelltextevidenz ausgewertet.
- Kein aktuelles Render-Environment, keine DB-Inhalte, historische Uploads oder externe Clients geprüft. Gesamtes Backend außerhalb der fünf Bereiche nicht neu auditiert.
- Keine juristische Bewertung oder abschließende Launch-/Sicherheitsfreigabe. Keine Codeänderung, kein Fix-PR und kein Merge. Dieses Dokument wird gezielt committet/gepusht; anschließend Stopp zur Nutzerprüfung.
