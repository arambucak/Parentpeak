# ParentPeak — Pre-Launch QA-Checkliste

Zweck: Vor dem öffentlichen Launch manuell auf echten Geräten prüfen, dass die
App funktioniert, keine falschen Infos zeigt und sich elternfreundlich verhält.
Diese Liste ergänzt die automatischen Tests (die laufen in der CI) — sie deckt
genau das ab, was Tests NICHT können: echtes Verhalten auf echten Geräten.

**So nutzt du die Liste:** Jede Zeile auf mindestens einem echten iPhone, einem
echten Android-Gerät und im Browser (Chrome + Safari) durchgehen. Haken setzen,
wenn ok. Bei Fehlern: kurze Notiz + Screenshot in die Fehlertabelle unten.

Legende: `[ ]` offen · `[x]` ok · `[!]` Problem gefunden

---

## 0. Testgeräte & Setup

Mindestens je ein Gerät pro Zeile testen. Trage die konkreten Geräte ein.

| Plattform | Gerät / Version | Getestet von | Datum |
|---|---|---|---|
| iPhone (aktuell) | | | |
| iPhone (älter, kleines Display) | | | |
| Android (aktuell) | | | |
| Android (älter) | | | |
| Web — Chrome (Desktop) | | | |
| Web — Safari (iPhone) | | | |

- [ ] App gegen den **Produktions-Build** getestet (nicht Debug), auf dem
      Release-SHA, der auch veröffentlicht wird.
- [ ] Backend zeigt auf Produktion (`parentpeak.onrender.com`), nicht lokal.
- [ ] Mit einem **frischen Konto** getestet (kein Entwickler-Altzustand).

### Backend-Rechte: zusätzlicher Mehrkonto-Test

Die verbleibende Backend-Härtung wird in getrennten Risikogruppen umgesetzt.
Automatisierte Handler-Tests ersetzen weder reale Firebase-Token noch einen
Mehrkonto-Test gegen das tatsächlich ausgerollte Backend.

- [ ] Alte Referral-APIs: Record/Pending/Claim liefern nach vorgelagerten
      Guards 410 `referral_retired`, keine Nutzerdaten, keinen Claim-Erfolg.
      Pending ist auch ohne Token nicht mehr auslesbar; weder DB-Zugriff
      noch Memory-Fallback. Globale Auth-/Rate-Grenzen bleiben aktiv.
      Bestehende Freundes-/Eventeinladungslinks und Codes separat unverändert
      testen. Historische Referral-Daten sind NICHT automatisch gelöscht.
- [ ] Familien-Anfragen: Konto A sieht nur eigene ein- und ausgehende Anfragen;
      A kann keine bereits angenommene Beziehung erzeugen. Nur Empfänger B
      nimmt an; ein unbeteiligtes Konto C kann weder ändern noch löschen.
- [ ] Private Events: Nur der gespeicherte Veranstalter kann ein Event löschen,
      eigene Einladungs-Codes laden oder die angenommenen Einladungen einsehen.
- [ ] Neue Bild-Uploads: Firebase ist Pflicht, Shared-/Gasttoken reicht nicht.
      JPEG/PNG/WebP/GIF werden wirklich dekodiert, ohne EXIF/GPS/Geräteprofile
      neu kodiert und mit serverbestimmter Endung veröffentlicht. Kamera-
      Orientierung, Transparenz und GIF/WebP-Animation auf Geräten prüfen.
      Originale liegen während der Verarbeitung nur im nicht öffentlichen
      temporären Ordner; abgewiesene/abgebrochene Uploads hinterlassen dort
      keine Dateien. 10-MiB-Eingabelimit bleibt; maximal 40 Mio. dekodierte
      Pixel (bei Animation über alle Frames), 10 s Decoderzeit, 10 MiB Ausgabe.
- [ ] Bildauslieferung: HTML/SVG/temporäre Dateien und Unterpfade werden nicht
      als Uploadbilder ausgeliefert; erlaubte Bildtypen bekommen `nosniff`
      und eine restriktive CSP. Öffentliche Eventbilder bleiben erreichbar.
      Bestehende Altbilder sind NICHT nachträglich metadatenbereinigt.
      Private Chat-/Familienmedienrechte und Altdateibereinigung bleiben
      separat offen; zufällige öffentliche URLs sind kein Zugriffsschutz.
- [ ] Native und Web-Eventfotos senden Firebase ohne statischen Fallback und
      korrekten Bild-MIME. Rezept-/Gruppenfoto-Aufrufer behalten ihre bereits
      verifizierten Clients. Decoder-/Speicher-/Authfehler dürfen keinen
      erfolgreichen Foto-Upload oder stilles Publizieren ohne Foto vortäuschen.
- [ ] Serien-Follows: Folgen, Entfolgen und persönlicher Status benötigen
      Firebase; fremde Body-/Query-`userId`-Claims werden vor Datenzugriff
      abgewiesen. A verändert/liest nur das eigene Abo; B bleibt unverändert.
      Ohne Token und ohne Nutzerclaim bleibt der Followerzähler öffentlich,
      ohne individuellen Statuszugriff (`following: false`).
- [ ] Serien-Client: Kein statischer Tokenfallback, kein Erfolg bei fehlendem
      Token, Netz-/Serverfehler. Unverfügbarer Status bleibt `null`, nicht
      fälschlich `false`; abgelaufener Token kann einmal erneuert werden.
      Gesperrte Konten dürfen nicht neu folgen, aber weiterhin entfolgen;
      Ausfall der Sperrprüfung verhindert neue Abos. Folgen bleibt idempotent,
      Teilnahme am Einzeltermin erzeugt kein Serienabo.
- [ ] Community-Discovery: Erstellen, Löschen und Interesse benötigen einen
      verifizierten Firebase-Token auch ohne globale Auth-Guards. Fremde
      Body-/Query-Nutzerclaims (bei Erstellen/Löschen auch `creatorId`) werden
      vor Datenzugriff abgewiesen. Creator, Tageslimit und Interesse gehören
      dem Token-Konto; nur der gespeicherte Creator darf löschen.
- [ ] Community-Client: Ohne Firebase oder Backend kein Shared-Token-Fallback
      und kein lokaler Scheinerfolg; fehlgeschlagenes Erstellen verbraucht
      keinen lokalen Tageszähler. Interesse/Löschen verändern lokale Daten
      erst nach erfolgreicher Serverantwort. Discovery und bestehende
      öffentliche Teilnehmerdarstellung bleiben erreichbar. Keine neue
      Aussage zur Datenschutzfreigabe dieser Teilnehmerdaten ableiten.
      Der Interesse-Button zeigt bei 401/403/Serverfehler keinen aktiven
      Erfolgszustand, meldet den Fehler lokalisiert und bleibt erneut bedienbar.
- [ ] FoodFeed-Rezept-CRUD: Erstellen, Bearbeiten und Löschen verlangen einen
      verifizierten Firebase-Token, auch bei ausgeschalteten globalen Guards.
      Token A mit Nutzer-/Creatorclaim B wird vor Rezeptzugriff abgewiesen;
      A kann fremde oder eigentümerlose Rezepte nicht ändern/löschen.
      Öffentliche Rezeptliste und Details bleiben ohne Token erreichbar.
- [ ] FoodFeed-Veröffentlichung: Nach Moderations-Rücknahme liefern Details,
      Kommentare und Reservierungsübersicht auch mit bekannter Rezept-ID 404
      wie bei einem fehlenden Rezept, anonym ebenso wie für Creator/fremdes
      Konto. Keine View-Erhöhung oder zugehörige Datenausgabe. Veröffentlichte
      Rezepte, Kommentare und Reservierungszahlen bleiben öffentlich;
      persönliche Reservierungen weiterhin nur für das verifizierte Konto.
- [ ] FoodFeed-Familienclaim: Kein Claim (oder `null`) bedeutet keine
      Familienzuordnung. Eine angegebene Familie muss dem vorhandenen
      serverseitigen privaten Account-Familienkontext entsprechen; fremde,
      Demo- oder widersprüchliche Claims werden abgewiesen. Der gespeicherte
      Creator, nicht Familienmitgliedschaft, entscheidet über Bearbeiten/Löschen.
      Alt-Rezepte werden nicht automatisch einer anderen Familie zugeordnet.
      Aktuelle Flutter-CRUD-Aufrufe verwenden Firebase ohne statischen
      Tokenfallback; Authfehler dürfen keinen lokalen Erfolg anzeigen.
- [ ] FoodFeed-Interaktionen: Bewertung, Kommentar, Reservierung, Stornierung,
      Abholbestätigung und Meldung verlangen lokal einen verifizierten
      Firebase-Token (kein Shared-Token-Fallback). Ohne Token: 401; Token A mit
      Body-/Query-Nutzerclaim B: 403 ohne Datenzugriff. Bei Meldungen gilt das
      auch für `reportedById`, selbst neben einem passenden `userId`.
- [ ] FoodFeed-Reservierungen: A kann nur die eigene Reservierung lesen,
      ändern, stornieren und abschließen; die Reservierung von B bleibt
      unverändert. Ohne offene eigene Reservierung ist kein Abschluss möglich.
      Ohne Token und ohne Nutzerclaim bleiben nur die öffentlichen Summen
      erreichbar (`myReservation: null`); fremde Query-IDs geben keine
      individuellen Reservierungsdaten frei. Öffentliche Kommentare und
      Rezept-Lesezugriffe bleiben erreichbar; Report-Adminrechte unveraendert.
- [ ] FoodFeed-Fehlerfälle: Abgelaufener Token, Verifikationsausfall,
      Datenbankausfall oder Netzfehler werden als Fehler angezeigt, nicht als
      lokal erfolgreiche Interaktion. Doppelte eigene Meldungen bleiben
      gesperrt; die bestehende Auto-Moderation wird weiterhin ausgeführt.
- [ ] Event-Chat: Veranstalter und bestätigte Teilnehmer können lesen/senden.
      Offene, abgelehnte und zurückgezogene Teilnahmen gewähren keinen Zugang;
      manipulierte Nutzer-/Veranstalter-IDs ändern daran nichts.
- [ ] Öffentliche Eventdetails (`GET /api/events/:id`) bleiben ohne Token
      erreichbar, enthalten aber weder `chat` noch Chatnachrichten — auch nicht
      für Veranstalter oder bestätigte Teilnehmer. Nachrichten werden nur über
      `GET /events/:id/chat/messages` mit verifiziertem Token und bestehender
      Chatberechtigung geladen. Private Eventdetails bleiben geschützt.
- [ ] Nachrichten löschen: eigener Autor oder Veranstalter bzw. konfigurierter
      UID-Admin. Meldungen erstellen: berechtigter Chat-Teilnehmer; Meldungen
      einsehen: Veranstalter bzw. UID-Admin.
- [ ] Datenbankausfall: Event-Chat meldet Nichtverfügbarkeit, keine privaten
      Cache-Daten und keine nur scheinbar gespeicherten Nachrichten/Meldungen.
- [ ] Matching: kein Zugriff auf fremden Familienkontext; Like/Profil gehören
      dem Token-Konto. Ein gegenseitiger Kontakt benötigt die Aktionen beider
      Konten; alte Client-Fallbacks übertragen ebenfalls den Firebase-Token.
- [ ] Bestehende Matching-Kontakte: Alt-Likes mit fremdem oder nicht
      verifizierbar zugeordnetem Familienkontext werden nicht als gegenseitige
      Einwilligung übernommen. Betroffene Konten müssen erneut selbst zustimmen;
      keine automatische Migration fremder Zustimmung.
- [ ] Zahlungen ausschließlich im Provider-Testmodus prüfen: zahlendes Konto
      und Veranstalter dürfen verschieden sein. Preis/Währung stammen vom
      gespeicherten Server-Auftrag; manipulierte Beträge und clientseitige
      Erfolgsmeldungen dürfen keine bezahlte Transaktion erzeugen.
- [ ] Produktentscheidung: Events veröffentlichen bleibt kostenlos, ohne
      Veröffentlichungsgebühr oder Zahlungszwang für kostenlose Angebote.
      Provider-Checkout betrifft nur gespeicherte kostenpflichtige Events;
      Teilnehmerpreis und Veröffentlichungsgebühr nicht verwechseln.
- [ ] Dieselbe Event-Zahlung mehrfach bestätigen bzw. denselben signierten
      Webhook erneut zustellen: keine doppelte Transaktion oder Erstattung.
- [ ] Zahlung fremden Kontos lesen/bestätigen und Veranstalter-Filter
      manipulieren: Zugriff verweigert. Erstattung nur mit berechtigtem
      Veranstalterkonto und tatsächlich vom Provider bestätigter Erstattung.
- [ ] Historische Transaktionen ohne verifizierbare Konto-/Auftragsbindung
      nicht durch geratenes Eigentum freischalten. Support-Abgleich und
      gegebenenfalls Erstattung im Provider-Dashboard separat organisieren.
- [ ] Signierter Stripe-Webhook funktioniert auch bei erzwungener Firebase-
      Authentifizierung; fehlende/falsche Signaturen und benachbarte
      Payment-Pfade ohne Firebase-Token werden abgewiesen.
- [ ] Event-Zahlung auf echtem Android/iPhone mit Stripe-Testdaten prüfen.
      Der bestehende native PaymentSheet bietet auf Web/Desktop keinen
      Zahlungsablauf; PayPal bleibt ausdrücklich nicht verfügbar. Diese
      Plattformen nicht als zahlungsfähig freigeben.
- [ ] Deployment-Secrets anhand [backend/.env.example](../backend/.env.example)
      konfigurieren: echte Schlüssel ausschließlich im Secret-Store, Firebase
      Admin verfügbar, UID-Adminliste geprüft, produktive In-Memory-Fallbacks
      deaktiviert, Mail-Zustellung und DB-TLS mit echtem Zertifikat verifiziert.

**Noch nicht durch diese Risikogruppen geschlossen:** separate mittlere
Findings zu FoodFeed, Community-Erstellung/-Interesse, Referral, Foto-Metadaten
und Serien-Follows. Sie benötigen eigene Freigabe/Fixes; dies ist ausdrücklich
keine pauschale Sicherheitsfreigabe für sämtliche Backend-Routen. Öffentliche
Listings, Login-/Recovery-Endpunkte und der signierte Stripe-Webhook dürfen
nicht durch eine pauschale Nutzer-Authentifizierung unbrauchbar werden.

---

## 1. Erststart, Onboarding & Konto

- [ ] Kalt-Start: App startet ohne Absturz; Splash zeigt das **neue** Logo.
- [ ] Onboarding-Sprachauswahl zeigt **nur die 8 fertigen Sprachen**
      (DE, EN, TR, KU, FR, ES, IT, AR) — keine halb-englischen.
- [ ] Registrierung mit E-Mail/Passwort funktioniert.
- [ ] Google Sign-In funktioniert (iOS + Android + Web).
- [ ] Abmelden und erneut anmelden funktioniert; Daten sind wieder da.
- [ ] Ohne Anmeldung und nach Logout erscheint der Login-Screen, nicht die Haupt-App.
- [ ] Kind-Profil anlegen (Alter) → Tipps/Impulse passen danach zum Alter.
- [ ] App killen und neu öffnen → bleibt angemeldet, Zustand erhalten.

---

## 2. Sprache & Lokalisierung (Vertrauen in Vollständigkeit)

Für **jede** der 8 Sprachen einmal durchschalten und Startscreen + 2–3 Kacheln
stichprobenartig ansehen.

- [ ] DE, EN, TR, KU, FR, ES, IT, AR: **keine** rohen Schlüssel sichtbar
      (z.B. `event_ai_verify_hint` als Text) und **kein** unerwartetes Englisch.
- [ ] Sprachwechsel wirkt sofort auf dem ganzen Screen.
- [ ] **AR (RTL):** Layout spiegelt korrekt (Icons, Pfeile, Textausrichtung);
      nichts überlappt oder läuft aus dem Rand.
- [ ] Kurdisch: Ala-Rengin-Flagge wird korrekt angezeigt (kein kaputtes Emoji).
- [ ] Zahlen/Datum/Preise sehen in jeder Sprache plausibel aus.

> Hinweis: Für AR vor breiter Vermarktung zusätzlich einen Muttersprachler
> drüberschauen lassen (RTL-Feinheiten, Tonfall).

Automatischer H3-Regressionsschutz: Die acht Launch-Kataloge werden auf leere
Werte, fehlende Quellschlüssel und unveränderte Platzhalter geprüft. Ein
AST-basierter Quellscan prüft Übersetzungsaufrufe (einschließlich bedingter
Schlüssel) und im Code referenzierte Katalogschlüssel gegen DE und EN, inklusive
Legacy-Katalog und CamelCase-Aliassen. Für FR/ES/IT/AR sind englisch-identische
Werte nur nach einzeln geprüfter Ausnahmeliste erlaubt (z.B. „Sport“, „Photos“,
Einheiten und offizielle Leistungsnamen wie „Child Benefit“).

- [ ] FR/ES/IT/AR: Kalender, Event-Teilnahme/Ortswahl, Wissen und Premium sowie
      italienische Familien-/Küchen-/Finanz-Texte muttersprachlich gegenlesen.
- [ ] Verschenkmarkt-Detail: Zustand, Abholgebiet, Bewertung, Größe/Alter und
      Aufrufe sind in allen acht Sprachen sichtbar, mit eingesetzten Werten.
- [ ] Einkaufslisten-Leerzustand und Wiederholen-Buttons zeigen übersetzten Text.
- [ ] AR: diese Texte zusätzlich bei großer Schrift und schmalem Display prüfen.

Die automatischen Prüfungen ersetzen weder sprachliche Freigabe noch Geräte-QA.

---

## 3. Events & Aktivitäten (GESCHÄFTSKRITISCH — hier besonders gründlich)

Das ist die Kachel, bei der falsche Infos am meisten schaden. Mit einem echten
Standort testen (GPS erlauben) und mit einer manuell eingegebenen Stadt.

### KI-Vorschläge
- [ ] KI-Suche liefert Events für den eigenen Ort (nicht für eine andere Stadt).
- [ ] Jede KI-Karte trägt den Hinweis **„KI-Vorschlag — bitte beim
      Veranstalter bestätigen"**.
- [ ] **Verschiedene** Events antippen → jede Detailseite zeigt **andere**
      Infos/Adresse (nicht immer dieselbe). *(War der gemeldete Bug.)*
- [ ] Kein Event mit einem Datum **in der Vergangenheit** erscheint.
- [ ] Auch ein Wiederholungs-Hinweis darf ein ausdrücklich vergangenes Datum
      nicht retten. Undatierte Dauerangebote bleiben ohne erfundenen Folgetermin.
- [ ] Bei einem Event mit **unklarer Adresse**: Hinweis „Adresse nicht auf der
      Karte bestätigt" ist sichtbar.
- [ ] Eine reine Stadt-/Stadtteil-Verortung gilt nicht als bestätigter
      Veranstaltungsort. Fehlende Ortsangaben werden nicht durch die Suchstadt
      als scheinbar bestätigte Adresse ersetzt.
- [ ] Fehlende Event-Quellen werden nicht durch beliebige andere Suchtreffer
      ersetzt. Vorhandene Veranstalterlinks stichprobenartig auf Zugehörigkeit
      und Aktualität prüfen: Geocoding beweist nicht, dass das Event stattfindet.
- [ ] „In Maps öffnen" öffnet die **richtige** Adresse des jeweiligen Events.
- [ ] „Website öffnen" / „Online suchen" führt zu etwas Sinnvollem.
- [ ] Entfernungsanzeige (km) ist plausibel für Events mit bestätigter Adresse.

### Community-Events (von Eltern eingetragen)
- [ ] Eigenes Community-Event anlegen (mit Standort-Picker) → erscheint im Feed.
- [ ] Teilnehmer/Interesse anzeigen funktioniert.
- [ ] Event melden (Flag) funktioniert.
- [ ] Eigenes Event bearbeiten und löschen funktioniert.

### Filter & leere Zustände
- [ ] Filter: Umkreis, Alter, „nur kostenlos", Zeitfenster (heute/Wochenende).
- [ ] Wenn nichts gefunden wird: freundlicher Leer-Zustand (kein Spinner, der
      ewig dreht; kein kontextloser Fehler).
- [ ] KI nicht erreichbar (z.B. Flugmodus kurz testen) → dezenter, erneut
      versuchbarer Hinweis statt stummer Leere oder Absturz.

---

## 4. KI-Elternberatung (Chat)

- [ ] Frage stellen → Antwort kommt (Streaming läuft, kein Hänger).
- [ ] Antwort folgt dem 3-Teile-Muster (Bedürfnis → GfK-Satz → Schritte) und
      klingt warm, nicht belehrend.
- [ ] Antwort kommt in der **aktuell gewählten Sprache**.
- [ ] KI nicht erreichbar → sinnvoller Fallback-Text, kein Absturz, kein roher
      Fehler.
- [ ] Bei sensiblen/akuten Themen: verantwortungsvoller Hinweis statt Diagnose.

---

## 5. Weitere Kacheln (je einmal durchspielen)

- [ ] **Familien-Küche:** Rezept generieren (1 Tap); Fallback-Rezept bei
      KI-Ausfall; Rezept → Einkaufsliste; „Hat es geschmeckt?"-Bewertung.
- [ ] **Impulse & Entwicklung:** Tagesimpuls lädt; Entwicklungs-Check
      durchführbar; KI-Bericht + PDF-Export funktioniert und ist lesbar.
- [ ] **Familien-Zentrale:** Einkaufsliste (Menge inline, Auto-Emoji,
      Erledigt-Bereich); To-do; Kind-Dossier speichern.
- [ ] **Familien-Geld:** Länderauswahl; Leistungs-Wegweiser lädt; KI-Ausfall
      zeigt lokalen Fallback-Hinweis (kein falscher „Anspruch").
- [ ] **Eltern-Netzwerk:** Profil-Wizard; Standort-Picker; ParentCoins zählen.
- [ ] **Verschenkmarkt:** Artikel einstellen (Foto); Kategorien/Zustand in der
      gewählten Sprache; Übergabe-Flow.
- [ ] **Ruhe & Rituale / Spielidee:** Abendritual, ruhiger Timer, Shuffle-Button
      funktioniert (auch im Web).

---

## 6. Kinder- & Minderjährigen-Daten (Store-kritisch + DSGVO)

Die App speichert sensible Kind-Daten (Alter, Allergien, Arzt,
U-Untersuchungen). Grundregel laut Projekt: sensible Daten bleiben lokal,
Kind-Namen/Geburtstage gehen NICHT an die KI.

**Produktentscheidung 2026-10-21 — KI-Memory, Variante A:** Das Profilfeld
`AiMemoryService.birthDate` geht bewusst nur an das eigene Backend
(`POST /ai/children`, `PUT /ai/children/:id`) und wird dort in
`AiChildProfile.birthDate` gespeichert. Dies ist eine ausdrückliche Ausnahme
von der lokalen Speicherung, damit das Backend das Alter tagesaktuell berechnen
kann. Kein Dritt-Dienst-Leck dieses Profilfelds an Gemini; kein Code-Fix nötig.
Verifiziert: [createChild/updateChild](../lib/logic/ai_memory_service.dart),
[Prisma-Modell](../backend/prisma/schema.prisma) und
[Backend-Routen](../backend/server.js).

Der clientseitige Tipp-Prompt nutzt nur volle Lebensjahre aus
[`ChatContextPolicy.completedAge`](../lib/logic/chat_context_policy.dart).
Auch der serverseitig ergänzte Memory-Kontext berechnet nur volle Lebensjahre
über [`completedYears`/`buildMemoryContext`](../backend/ai_memory_policy.js);
das strukturierte Geburtsdatum wird nicht in den Gemini-Kontext übernommen.
Diese Aussage betrifft diesen Profil-Datenweg, nicht beliebige Freitext-Eingaben.
Variante B (nur Alter ans Backend, Geburtsdatum ausschließlich lokal) wurde
bewusst verworfen: Die dafür vorgesehene DB-/Datenmigration ist für den Launch
nicht erforderlich. Der Audit-Punkt „birthDate ans eigene Backend“ ist damit
als bewusste Entscheidung abgeschlossen; Einwilligung und Löschung bleiben
weiterhin zu prüfen.

- [ ] Kind-Dossier-Daten (Allergien, Arzt, Größen) bleiben **lokal** — kein
      Upload ins Backend (ggf. mit Netzwerk-Mitschnitt stichprobenartig prüfen).
- [ ] Beim KI-Chat / Entwicklungs-Check wird **kein Klarname und kein exaktes
      Geburtsdatum** des Kindes an Gemini gesendet (nur grobe Altersangabe).
- [ ] Entwicklungs-Check-Einwilligung nennt den KI-Empfänger (Google Gemini)
      ausdrücklich, bevor etwas gesendet wird.
- [ ] Keine Werbung / kein Tracking von Kinderdaten (Apple „Kids"/DSGVO).
- [ ] Konto-/Datenlöschung entfernt auch die Kind-Profile vollständig.

---

## 7. Community-Moderation & Missbrauchsschutz (Apple verlangt dies)

Bei nutzergenerierten Inhalten (Verschenkmarkt, Community-Events, Netzwerk)
verlangt Apple einen funktionierenden Melde- UND Blockier-Mechanismus — sonst
Ablehnung im Review.

- [ ] Inhalt **melden** (Event, Verschenk-Artikel, Profil) funktioniert und
      landet nachweislich beim Admin (Admin-Moderation-Screen zeigt den Report).
- [ ] Bei Netzwerk-/Tokenfehlern erscheint in allen 8 Launch-Sprachen ein
      neutraler Wiederholen-Hinweis statt einer Meldebestätigung. Nach erneutem
      Senden mit Serverbestätigung erscheint die Danke-Meldung. Fehlgeschlagene
      Verschenkmarkt-Meldungen werden nicht als „gemeldet“ markiert.
- [ ] Rezept posten, löschen und darauf reagieren: Bei Netzwerk-/Tokenfehlern
      erscheint ein Fehlerhinweis; keine Erfolgsanzeige oder lokale Erfolgsänderung.
- [ ] Nutzer **blockieren / Inhalt verbergen** ist möglich.
- [ ] Admin kann anstößige Inhalte/Nutzer entfernen (Moderations-Flow testen).
- [ ] Wochenimpuls-Community: Normales Konto darf trotz mitgeschickter interner
      `moderatorEmail`/`reviewerEmail` weder Meldungen/Verifizierungsanfragen
      lesen noch freigeben oder Beiträge global ausblenden. Ein interner Moderator
      mit bestätigter Firebase-E-Mail darf dies; ohne gültigen ID-Token wird
      abgelehnt. Fachstimmen-Badge und eigener Verifizierungsstatus lassen sich
      nicht über fremde Nutzer-IDs/E-Mail-Adressen übernehmen.
- [ ] Nach dem Melden/Blocken verschwindet der Inhalt für den meldenden Nutzer
      zeitnah.
- [ ] Es gibt einen sichtbaren Kontakt-/Support-Weg (E-Mail) für Beschwerden.

---

## 8. Standort-Privatsphäre & Sicherheit beim Vernetzen

Fremde treffen sich über die App — Standortdaten brauchen klare Grenzen.

- [ ] Der an KI/Backend gesendete Standort ist **grob gerundet** (~1 km), nicht
      metergenau.
- [ ] Ein anderer Elternteil sieht im Netzwerk/Verschenkmarkt **nicht** meinen
      exakten Wohnort (nur Umkreis/Stadtteil).
- [ ] Standort-Freigabe ist widerrufbar; danach wird kein genauer Ort mehr
      genutzt.
- [ ] Einladungs-/Kontaktaufnahme offenbart keine privaten Daten ungewollt.

---

## 9. Web-spezifisch (bekannte Risikozone)

Im Browser (Chrome Desktop **und** Safari auf iPhone) prüfen:

- [ ] App lädt auf `parentpeak.de` ohne weiße Seite / JS-Fehler in der Konsole.
- [ ] **Keine Abstürze** durch Platform-/Benachrichtigungs-Code (Notifications
      sind im Web bewusst deaktiviert — darf nicht crashen).
- [ ] Buttons/Tap-Flächen reagieren (GestureDetector-Fälle, Shuffle-Buttons).
- [ ] Nach einem Deploy: Hard-Refresh (Cmd+Shift+R) zeigt den neuen Stand.
- [ ] Favicon und Titel korrekt (neues Logo).
- [ ] Login/Logout funktioniert auch im Web.
- [ ] Event erstellen: Foto auswählen, Vorschau sehen, ersetzen und entfernen
      funktioniert ohne Dateisystem-/`Image.file`-Fehler. Veröffentlichen lädt
      das ausgewählte Bild hoch und übernimmt dessen URL. Bei Uploadfehler bleibt
      das Formular offen; erneutes Veröffentlichen versucht den Upload erneut.

---

## 10. Berechtigungen, Netzwerk & Robustheit

- [ ] Standort-Berechtigung: Ablehnen → App funktioniert weiter (manuelle Stadt).
      Erlauben → GPS-Ort wird genutzt.
- [ ] Kamera/Foto (Verschenkmarkt, Rezept-Foto): Berechtigungsdialog erscheint,
      Ablehnen stürzt nicht ab.
- [ ] Offline/schlechtes Netz: Kacheln zeigen Fallbacks oder klare Hinweise,
      keine Abstürze, keine ewig drehenden Spinner.
- [ ] Benachrichtigungen (nur nativ): Opt-in-Dialog erscheint; eine Erinnerung
      kommt tatsächlich an.
- [ ] Hintergrund → Vordergrund: App übersteht Wiederaufnahme ohne Datenverlust.

---

## 11. Performance & Ressourcen

- [ ] Kaltstart bis bedienbarer Home-Screen fühlt sich zügig an (grob < 3–4 s).
- [ ] Langer Events-Feed scrollt flüssig, keine spürbaren Ruckler.
- [ ] KI-Aufrufe blockieren die UI nicht (restliche App bleibt bedienbar).
- [ ] Kein auffälliger Akku-/Datenverbrauch bei normaler Nutzung.
- [ ] Auf einem **älteren/langsameren Gerät** noch benutzbar (nicht nur Top-Modell).

---

## 12. Barrierefreiheit (Accessibility)

Eure Coding-Regeln verlangen Accessibility-Konformität.

- [ ] Screenreader (VoiceOver iOS / TalkBack Android) liest die Hauptflüsse
      sinnvoll vor (Home, Events, Chat).
- [ ] Interaktive Elemente haben sprechende Labels (nicht nur „Button").
- [ ] Textkontraste ausreichend; nichts nur über Farbe allein kommuniziert.
- [ ] Große Systemschrift (Dynamic Type / Font-Scale) bricht das Layout nicht.
- [ ] Tap-Flächen groß genug (nicht zu klein/zu dicht beieinander).

> Hinweis: Volle WCAG-Konformität erfordert manuelle Tests mit assistiven
> Technologien und eine Experten-Prüfung — diese Liste ist ein Grund-Check.

---

## 13. Deep Links & Einladungen

- [ ] Event-Einladungslink öffnet das richtige Event in der App.
- [ ] Netzwerk-/Freundschafts-Einladung (ParentCoins) funktioniert und zählt.
- [ ] Einladungslink bei **nicht installierter** App führt sinnvoll weiter
      (Store/Web), ohne ins Leere zu laufen.
- [ ] Abgelaufener/ungültiger Link zeigt eine klare Meldung, keinen Absturz.

---

## 14. Update & Migration (betrifft bestehende Beta-Tester)

- [ ] Nutzer mit **älterer App-Version** aktualisiert → lokale Daten
      (SharedPreferences: Listen, Kind-Profil, Einstellungen) bleiben erhalten.
- [ ] Keine Daten-Dubletten oder kaputten Zustände nach dem Update.
- [ ] Falls Datenformat sich geändert hat: Migration greift sauber.

---

## 15. Konsistenz App ↔ Website ↔ Preise

- [ ] Kein toter „Auf Premium upgraden"-Button, der ins Leere führt (Premium
      ist in der App aktuell nicht aktiv — Website-Versprechen vs. App-Realität).
- [ ] Features, die die Website bewirbt, existieren in der App auch wirklich.
- [ ] Sprach-Angabe konsistent (Website sagt „8 Sprachen", App bietet 8 an).
- [ ] Links von der Website (App öffnen, Datenschutz, Impressum) funktionieren.

---

## 16. Datenschutz & Rechtliches (vor Launch zwingend)

- [ ] Datenschutzerklärung, Nutzungsbedingungen, Impressum sind in der App
      erreichbar und laden.
- [ ] „Meine Daten exportieren" funktioniert.
- [ ] Konto löschen funktioniert und entfernt die Daten.
- [ ] KI-Einwilligung (Gemini) wird transparent abgefragt, bevor Daten gesendet
      werden; ohne Zustimmung keine Übertragung.
- [ ] Keine sensiblen Daten landen ungewollt im Backend (nur was nötig ist).

> Hinweis: Die inhaltlich-juristische Abnahme (Texte korrekt für den Markt)
> gehört zusätzlich geprüft — das ist keine reine Geräte-QA.

### Wochenrückblick: lokale Nutzung und optionale KI

- Abschließen speichert den Rückblick nur lokal, getrennt nach Konto. Erst
  „KI-Feedback anfordern“ und die ausdrückliche, versionierte Zustimmung für
  Wochenrückblicke dieses Kontos erlauben den Versand von Stimmung und Antworten
  über das eigene Backend an Google Gemini. Chat-/Foto-/Memory-Zustimmung gilt
  dafür nicht. Die Login-Pflicht bleibt unverändert.
- Ablehnen oder Schließen des Dialogs sendet nichts. Bei Netzwerk-, Token- oder
  KI-Fehlern bleibt der lokale Rückblick erhalten; die UI zeigt einen neutralen
  Hinweis und erlaubt erneutes Anfordern, ohne rohe Providerfehler anzuzeigen.
- Widerrufen blockiert weitere Anfragen und verwirft noch ausstehende Antworten.
  Konto-Wechsel, erneute Anmeldung desselben Kontos nach einem Wechsel und
  Verlassen des Screens dürfen alte Ergebnisse nicht anzeigen oder speichern.
  Bereits an den Anbieter übertragene Daten werden dadurch nicht zurückgeholt.
- Alte, global gespeicherte Rückblicke bleiben unverändert erhalten und werden
  keinem Konto automatisch zugeschlagen. Produktentscheidung: explizite Übernahme
  nach Bestätigung der Eigentümerschaft. Sie erfolgt nur für ein Konto, ersetzt
  keine neuen Einträge derselben Woche und löst keinen KI-Aufruf aus. Ein
  unterbrochener Import bleibt nur für das bestätigte Konto wiederholbar.
- Datenexport enthält neue Rückblicke und Zustimmung nur für das aktuelle Konto.

**Vor Release manuell prüfen:** Ablehnen/Abbrechen, Wiederholen nach Offline-
Fehler, Widerruf während einer langsamen Anfrage, Kontowechsel, Import-Bestätigung
und Dialog-/Button-Layout in allen acht Launch-Sprachen einschließlich RTL.
Juristische Textprüfung und Anbieter-/Netzwerkprüfung sind dadurch nicht ersetzt.

**Abgrenzung:** Dies schließt ausschließlich den aktiven Wochenrückblick-Pfad.
Antragshelfer, Event-Discovery/Flyer und Community-KI sowie
eine allgemeine serverseitige Consent-Durchsetzung für `/ai/generate` bleiben
separat zu prüfen/härten. Die bestehende serverseitige Memory-Einwilligung bleibt
unverändert; dieser Client-Guard ist kein manipulationssicherer Backend-Nachweis.

### Ruhe & Rituale: optionale KI

- Ritualvorschlag und Gute-Nacht-Geschichte benötigen eine separate, versionierte
  Zustimmung pro Konto (`ritual.ai_consent.v1`). Rezept-, Foto- oder
  Wochenrückblick-Zustimmung gilt hier nicht. Ablehnen/Schließen startet keine
  Anfrage und zeigt einen lokalisierten Hinweis; lokale Rituale bleiben nutzbar.
- An Google Gemini gehen über das eigene Backend nur Alter in ganzen Jahren,
  Ritualart/Tageszeit und App-Sprache, keine Namen, Geburtsdaten oder lokalen
  Dankbarkeits-/Ritualeinträge. Im Screen sind genau diese zwei KI-Pfade vorhanden.
- Guards prüfen Zustimmung/Konto vor und nach Tokenabruf, beim 401-Retry und
  vor Verwendung einer Antwort. Verlassen des Screens oder Wechsel von Kind/
  Tagesabschnitt verwirft verspätete Ergebnisse. Bereits versendete Daten lassen
  sich damit nicht zurückholen. Es wird keine neue Widerrufs-Oberfläche ergänzt.
- [ ] Beide Buttons: Ablehnen, Schließen, Zustimmen und erneut Aufrufen auf
      echten Geräten sowie in Safari prüfen; nach Kontowechsel erneut zustimmen.
- [ ] Dialog und Hinweis in allen acht Launch-Sprachen, besonders AR/RTL und
      bei großer Schrift, sprachlich und visuell prüfen.

Die Absicherung betrifft ausschließlich die Ritual-KI im Client. Die allgemeine
serverseitige Consent-Durchsetzung und andere KI-Features sind nicht geändert.

**Launch-Scope:** Das bisher nur per Debug-Einstieg erreichbare Rezept-Experiment
wurde einschließlich Feed, KI-/Backend-Clients und exklusiven Hilfsmodellen
entfernt. Dafür ist kein Consent-Ausbau mehr vorgesehen. Die aktive
Familien-Küche mit ihren eigenen Rezept-, Planer- und Einkaufsfunktionen bleibt
erhalten. Es wurden keine Backend-Routen oder gespeicherten Nutzerdaten gelöscht.

---

## 17. Store-Vorbereitung (kein Geräte-Test, aber vor Einreichung nötig)

- [ ] App-Icon in allen Größen korrekt (iOS/Android), kein Alpha-Rand bei iOS.
- [ ] Store-Screenshots aktuell (neues Branding, echte Screens).
- [ ] Store-Texte (Beschreibung, Keywords) final.
- [ ] Alterseinstufung / Content-Rating ausgefüllt.
- [ ] Datenschutz-Angaben im Store (App Privacy / Data Safety) ausgefüllt und
      stimmen mit dem echten Datenverhalten überein.
- [ ] Versionsnummer & Build-Nummer gesetzt und konsistent.
- [ ] Signierung (iOS Provisioning / Android Keystore) vorhanden und korrekt.

---

## 18. Abschluss-Gate

- [ ] Alle `[!]`-Punkte entweder behoben oder bewusst als „bekannt, kein
      Launch-Blocker" dokumentiert (mit Begründung).
- [ ] Letzter voller Smoke-Test auf dem finalen Release-Build.
- [ ] Entscheidung dokumentiert: wer gibt den Launch frei, Datum, Version.

---

### Gefundene Probleme (laufende Liste)

| # | Plattform | Bereich | Beschreibung | Schwere | Status |
|---|---|---|---|---|---|
| | | | | | |
