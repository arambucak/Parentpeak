# Parentpeak Marktplatz Backend

## Einwilligung fuer KI-Familienrezepte

Die Familien-Kueche fragt vor der ersten KI-Rezepterstellung transparent nach
Zustimmung. Kindesalter, lokale Dossier-/Kuechen-Allergien und bei einer
Gerichtsuche der Suchtext werden ueber `/ai/generate` an Google Gemini gesendet.
Dossier-Namen, Arzt- und Notfallangaben werden nicht automatisch uebernommen.
Die Gerichtsuche in Familien-Rezepten verwendet denselben Dialog und dieselbe
Service-Grenze. Die bestehende Fotoeinwilligung im Kuehlschrank-Feature ist ein
separater Zweck und ersetzt diese Zustimmung nicht.

`FamilyRecipeConsent` speichert eine versionierte Zustimmung pro Konto
(ohne Konto separat fuer den Gastmodus) in SharedPreferences. Beide Methoden
von `FamilyRecipeService` verweigern KI-Anfragen ohne passende Zustimmung und
initialisierten Kontext fuer denselben Kontostand. Eine fehlgeschlagene
Speicherbestaetigung aktiviert keine KI. Bei Ablehnung zeigt die Kueche
ausdruecklich lokale Inspiration aus dem vorhandenen, lokal nach Allergien und
Kindesalter gefilterten Rezeptbestand; die Gerichtsuche startet keine KI.
Weder die Ablehnung noch ein lokales Rezept verbraucht KI-Anfragen.

Die Kontotrennung der bisherigen globalen Dossiers, Einkaufslisten und To-dos
ist separat umgesetzt (siehe unten); diese Einwilligung migriert keine Daten.

Regressionen:

```bash
flutter test --no-pub test/family_recipe_consent_test.dart test/fallback_recipes_test.dart test/allergen_guard_test.dart test/localization_audit_verification_test.dart
```

## Lokale Kontotrennung der Familien-Zentrale

`FamilyHubStore` verwaltet Kind-Dossiers, aktive/erledigte Einkaeufe, haeufige
Artikel, To-dos und die zusaetzlichen Kuechen-Allergien in
`familyhub.accounts.v1`. Jeder Kontobereich besitzt einen geprueften
Eigentuemer-Umschlag. Der nicht angemeldete Modus hat einen eigenen leeren
Gastbereich; Gastdaten werden nie automatisch einem Konto zugeordnet.
Dies ist lokale Kontotrennung, keine Verschluesselung oder Geraetesynchronisierung.

Die bisherigen globalen Keys bleiben als unzugeordneter Altbestand erhalten.
Sie werden von den produktiven Verbrauchern nicht automatisch gelesen. Die
Familien-Zentrale bietet angemeldeten Nutzern eine ausdrueckliche
Eigentumsbestaetigung an, bevor sie diesen Bestand lokal uebernimmt. Daten und
Uebernahme-Eigentuemer werden in einem einzigen bestaetigten Schreibvorgang
gespeichert. Bei Fehlern bleibt die Uebernahme wiederholbar; nach Erfolg kann
kein zweites Konto denselben Altbestand beanspruchen. Originalkeys bleiben
als Backup erhalten, werden aber nach dem Claim nicht weiter benutzt.
Existierende Kontodaten bleiben erhalten; ID-Kollisionen werden durch neue
Legacy-IDs getrennt, nicht nach Namen zusammengefuehrt. Es findet kein Upload
und keine Profil-Veroeffentlichung statt.

Verifizierte Aufrufer:

- Dossiers: Familien-Zentrale, FamilyRecipeService, FridgeRecipeService,
  Ritual & Ruhe. AllergenGuard wertet die geladenen Dossiers lokal aus.
- Einkauf: Familien-Zentrale, Familien-Kueche, FridgeRecipeScreen.
- To-dos: Familien-Zentrale.
- Zusaetzliche Kuechen-Allergien: beide Rezeptservices; ein globaler Fallback
  wuerde die Dossier-Kontotrennung umgehen und ist deshalb entfernt.

Offene Verbraucherscreens werden bei Konto-/Logoutwechsel neu aufgebaut;
offene Dossier- und Einkaufsmodals blenden bisherige Kontoinhalte aus.
Verspaetete Writes bleiben an ihr Ausgangskonto gebunden und werden nach
Kontowechsel abgewiesen. Fehlende/defekte Dossierdaten leeren den Singleton,
statt alte Gesundheitsangaben als aktuellen Bestand weiterzugeben.

```bash
flutter test --no-pub test/family_hub_account_test.dart test/kind_dossier_identity_test.dart test/kind_dossier_uexam_test.dart test/family_recipe_consent_test.dart test/localization_audit_verification_test.dart
```

### Bestaetigte Persistenz und Fehlerbehandlung

Dossier-, Einkaufs- und To-do-Mutationen lesen innerhalb derselben Write-Queue
den aktuellen Kontostand, wenden die Aenderung an und veroeffentlichen den neuen
RAM-/UI-Zustand erst nach Speicherbestaetigung. Auch unabhaengige
Service-Instanzen verlieren deshalb keine konkurrierenden Add-/Toggle-Aktionen.
To-dos werden nicht mehr fire-and-forget als erfolgreich behandelt.
Speicherfehler bleiben sichtbar; Eingaben werden bei Fehlern nicht geleert.
SharedPreferences-Caches werden nach negativem Ack oder Plattformfehler neu
geladen. Unbekannte Untersuchungs-/Artikel-/To-do-IDs werden explizit als Fehler
gemeldet statt erfolgsgleich ignoriert.

Falsche Typen in To-do-Daten und ungueltige vorhandene Geburts-/Einkaufsdaten
werden abgewiesen. Fehlende Legacy-Geburtsdaten koennen weiterhin bewusst aus
dem vorhandenen Monatsalter migriert werden. Beide Rezeptservices brechen bei
defektem Gesundheits-/Profilkontext ab, statt fehlende Allergien vorzutäuschen.

```bash
flutter test --no-pub test/family_hub_persistence_test.dart test/family_hub_account_test.dart test/kind_dossier_uexam_test.dart test/family_recipe_consent_test.dart test/localization_audit_verification_test.dart
```

### Geburtsdatum und Altersanzeige

Der lokale Profilimport uebernimmt fuer neue Dossiers das genaue Geburtsdatum,
nicht ein aus dem Monatsalter neu geschaetztes Datum. Bereits vorhandene Dossiers
bleiben beim Abgleich unveraendert. Karten zeigen vollendete Lebensjahre aus dem
taggenauen Monatsalter; vor dem Geburtstag wird nicht aufgerundet. Alle zwoelf
U-Untersuchungen bleiben absichtlich auch fuer rueckwirkende Eintraege verfuegbar.

```bash
flutter test --no-pub test/family_hub_age_test.dart test/child_age_calculation_test.dart test/kind_dossier_identity_test.dart test/kind_dossier_uexam_test.dart
```

### UI-Lifecycle, Datumsanzeige und Teilen

Einkaufs-/To-do-Schreibcallbacks pruefen den aktiven Kontokontext und mounted,
bevor sie UI oder Eingabecontroller aktualisieren. Das Dossier-Editformular hat
einen eigenen StatefulWidget-Lifecycle und gibt alle dreizehn Textcontroller
erst beim tatsaechlichen Entfernen des Formularwidgets frei, nicht bereits beim
Start der Schliessanimation. Auch nach manuellem Schliessen waehrend eines Saves
wird kein veralteter Navigationskontext benutzt.

Erledigte Untersuchungen zeigen das Datum mit MaterialLocalizations der aktiven
App-Locale; Kurdisch verwendet den vorhandenen Plattform-Locale-Fallback. Neue
unbenannte Profilkinder erhalten einen lokalisierten Anzeigenamen (de/en/tr/ku).
Ihre lokale Import-ID bleibt beim Sprachwechsel stabil, damit kein weiteres
generisches Dossier entsteht. Bestehende Kind-Fallback-Dossiers bleiben gemaess
dem bisherigen Namensabgleich unveraendert, auch wenn ein historisch geschaetztes
Geburtsdatum vom Profil abweicht. Dies ersetzt nicht den dokumentierten
Namensabgleich fuer benannte Kinder.

Beim Wiederoeffnen eines Einkaufsartikels wird doneAt explizit geloescht,
einschliesslich Persistenz. Erneutes Erledigen setzt ein neues Datum; die
Sieben-Tage-Bereinigung erfasst weiterhin ausschliesslich erledigte Artikel.
Die Share-Anfrage enthaelt den echten Share-Button-Rect als iPad-Anker und
zeigt Plattformfehler sichtbar an. Es werden nur aktive Einkaeufe geteilt.

```bash
flutter test --no-pub test/family_hub_shopping_ui_test.dart test/family_hub_editor_i18n_test.dart test/family_hub_age_test.dart test/family_hub_account_test.dart test/family_hub_persistence_test.dart test/localization_audit_verification_test.dart
```

## Familien-Geld: Einwilligung fuer den persoenlichen KI-Wegweiser

Der Flutter-Wegweiser verlangt vor der ersten persoenlichen Anfrage eine
ausdrueckliche Einwilligung. Der Hinweis nennt Freitext, ausgewaehlte Situation,
Land, Kinderalter und Elternstatus sowie die Verarbeitung ueber den
ParentPeak-Server durch Google Gemini, gegebenenfalls mit Websuche. Die
Kontaktredaktion im gemeinsamen KI-Client ist keine vollstaendige
Anonymisierung. Ohne Zustimmung wird keine Wegweiser-KI-Anfrage gestartet;
allgemeine kuratierte Leistungsinformationen bleiben verfuegbar.

Die lokale Freigabe liegt unter `famgeld.ai_guide_consent.v1.<account scope>`
und ist fuer jedes Konto beziehungsweise den Gastbereich getrennt. Bestehende
Rezeptfreigaben unter `familykueche.ai_recipe_consent.v1` werden durch die
gemeinsame Implementierung unveraendert erhalten, geben aber den Finanzwegweiser
nicht frei. Eine Freigabe gilt erst nach positiv bestaetigtem Speicherwrite.

Sowohl UI als auch Agent pruefen den Ursprungskontext vor dem Request und nach
asynchronen Schritten. Kontowechsel oder fehlende Zustimmung duerfen nicht als
erfolgreicher allgemeiner KI-Fallback erscheinen. Bereits gestartete Requests
lassen sich dadurch nicht rueckgaengig machen; ihre Antworten werden jedoch
nicht im neuen Kontokontext angezeigt. Dies ist ein Client-Vertrag, kein
serverseitiger Consentnachweis fuer den allgemeinen KI-Endpunkt.

Defekter Profil-/Wegweiserkontext wird sichtbar gemeldet und blockiert die
Anfrage. Der noch globale Alleinerziehendenstatus des Geldscreens wird bis zur
separaten Kontomigration nicht automatisch weitergegeben. Die Finanzspeicher
und alten Checklisten sind mit diesem PR noch nicht migriert.

```bash
flutter test --no-pub test/benefit_guide_consent_test.dart test/family_recipe_consent_test.dart test/family_hub_account_test.dart test/localization_audit_verification_test.dart
```

## Installation

1. **Node.js installieren** (falls nicht vorhanden)
   - https://nodejs.org/ (Version 16+)

2. **Dependencies installieren:**
   ```bash
   cd backend
   npm install
   ```

3. **Backend starten:**
   ```bash
   npm start
   ```

Das Backend läuft dann auf: **http://localhost:3000**

## Datenbank-Migrationen (Prisma)

Das Schema wird über versionierte Prisma-Migrationen (`backend/prisma/migrations`)
gepflegt. In Produktion werden Migrationen mit `prisma migrate deploy` angewandt
(niemals `prisma db push` oder `migrate dev` gegen Produktion).

**Automatisch beim Deploy (empfohlen):**
`render.yaml` enthält `preDeployCommand: npm run migrate:deploy`. Render wendet
ausstehende Migrationen damit einmal pro Deploy an (nach Build, vor dem
Umschalten auf die neue Instanz). Die `DATABASE_URL` kommt aus dem Render-Service-
Environment. Hinweis: Damit Render einen geänderten `preDeployCommand` übernimmt,
muss der Blueprint im Render-Dashboard einmalig neu gesynct werden.

**Einmalig manuell (schnellster Weg, z. B. für eine sofort nötige Migration):**
Im Render-Dashboard den Service `parentpeak-backend` öffnen → Tab **Shell**:

```bash
cd backend && npx prisma migrate deploy
```

Die `DATABASE_URL` ist in der Render-Shell automatisch gesetzt.

**Verifikation nach der Migration:**

```bash
BACKEND_BASE_URL=https://parentpeak.onrender.com \
  bash scripts/verify_event_age_groups.sh
```

Prüft Health, dass `GET /api/events` ohne Schemafehler mit HTTP 200 antwortet und
dass Events ein `ageGroups`-Feld tragen. Optional mit Auth
(`FIREBASE_ID_TOKEN` + `HOSTER_ID`) wird zusätzlich ein Create-Roundtrip geprüft,
der bestätigt, dass gesendete `ageGroups` persistiert werden.

> Resilienz: Fehlt die `ageGroups`-Spalte (Migration noch nicht angewandt),
> degradiert der Event-Feed sauber mit `ageGroups: []` statt zu crashen
> (`resilientEventFindMany` in `server.js`). Die Filterung wird aktiv, sobald die
> Migration die Spalte angelegt hat — ohne weitere Codeänderung.

### Optionales Erwachsenenalter im Eltern-Netzwerk

`ParentMatchingProfile.age` ist optional. Die Migration
`20261006000000_optional_parent_matching_age` entfernt nur die NOT-NULL-Bedingung;
vorhandene Altersangaben bleiben erhalten. Beide Profil-Endpunkte akzeptieren
fehlendes Alter, `null` oder `""` als keine Angabe, ohne einen Standardwert zu
erfinden. Ein angegebenes Alter muss ganzzahlig sein und innerhalb des bisherigen
Bereichs des jeweiligen Endpunkts liegen (16-99 bzw. 18-120).

Lokale Regressionstests ohne Datenbank oder Produktionszugriff:

```bash
node --test backend/tests/unit/parent-matching-age.test.js
```

Der CI-Job `analyze` fuehrt auch die isolierten Backend-Unit-Tests aus.
Eine Rueckkehr zu NOT NULL braucht eine explizite Entscheidung zum Umgang mit
Profilen ohne Altersangabe; diese duerfen nicht mit erfundenen Werten aufgefuellt werden.

### Spielfreunde-Profil loeschen

`DELETE /parent-matching/my-profile?userId=<Firebase-UID>` verlangt eine
verifizierte Firebase-UID, die mit `userId` uebereinstimmt. Die Route entfernt
alle Matching-Profile dieser UID, ohne das Konto oder andere Familien zu
loeschen. Bereits fehlende Profile werden idempotent mit `{"success": true}`
bestaetigt. Ein Datenbankfehler liefert HTTP 503 statt eines lokalen Scheinerfolgs.
Die App entfernt ihre lokale Kopie erst nach dieser expliziten Bestaetigung.

```bash
node --test backend/tests/unit/parent-matching-delete.test.js
flutter test --no-pub test/playmate_profile_delete_test.dart
```

### Datensparsame Spielfreunde-Veroeffentlichung

Die App veroeffentlicht nur Anzeigename, Ort/grobe Koordinaten, ungefaehre
Kinderalter, Sprachen, Familienform, Werte, gesuchte Aktivitaeten und die
oeffentliche Bio ueber `/parent-matching/my-profile`. Kindnamen, Geburtsdaten,
Kind-Geschlecht/-Freitext und Besonderheiten (auch Gesundheitsangaben) bleiben
in der lokalen Kopie. Der alte Spielfreunde-Upload wurde entfernt.

Vor jeder Veroeffentlichung bestaetigt der Nutzer einen transparenten Dialog.
Matching nutzt keine KI. Freitext in der Bio ist oeffentlich; der Dialog warnt
vor Kindnamen, Adresse und Gesundheitsdaten. Erst eine Serverantwort mit Profil-ID
und passender Eigentuemer-UID fuehrt zur lokalen Speicherung. Abbrechen oder
Backend-Fehler erzeugen kein neues lokal als aktiv dargestelltes Profil.
Beim Speichern wird nicht mehr automatisch GPS angefordert.

Ort und Koordinaten stammen ausschliesslich aus der Auswahl im Profil-Wizard;
ein abweichender appweiter Standort wird nicht uebernommen. Die lokale Profilkopie
speichert diese Koordinaten bereits grob gerundet, der Upload rundet erneut.
Alte Profile ohne Koordinaten verwenden nur ihren Ortstext. Beide Backend-
Profil-Endpunkte unterscheiden fehlende/null-Koordinaten von gueltigem `0,0`
und lehnen ungueltige, ausserhalb des Wertebereichs liegende oder unvollstaendige
Koordinatenpaare mit HTTP 400 ab.

Beim Bearbeiten wird der Wizard mit der bestehenden lokalen Kopie vorbelegt.
Abbrechen, eine abgelehnte Veroeffentlichung oder ein Backend-Fehler erhalten
die gespeicherte Kopie. Die App speichert auch Aenderungen erst nach dem
transparenten Dialog und der Serverbestaetigung. Unveraenderte Geburtsdaten,
lokale Freitexte und das urspruengliche Erstellungsdatum bleiben erhalten.
Die Kontozuordnung alter lokaler Profile und die Verifikation des Aktivstatus
beim App-Start sind noch separate offene Audit-Punkte.

```bash
flutter test --no-pub test/playmate_profile_publication_test.dart
flutter test --no-pub test/playmate_profile_location_test.dart
flutter test --no-pub test/playmate_profile_edit_test.dart
```

### Kontozuordnung und verifizierter Profilstatus

Lokale Spielfreunde-Profile werden pro Konto unter
`spielfreunde.profile.account.<URI-kodierte UID>` gespeichert. Der JSON-Umschlag
enthaelt dieselbe `ownerUserId` und das lokale `profile`; eine abweichende
Eigentuemer-UID wird nicht geladen. `FamilyMatchProfile.load()` verwendet zentral
das aktuelle AuthService-Konto. Ohne Anmeldung, ohne zugeordnetes Profil oder
waehrend eines Kontowechsels wird kein fremdes Profil als Fallback gelesen.

Der alte globale Key `spielfreunde.profile` bleibt ein unzugeordneter Entwurf.
Nur ein eigener Bestaetigungsdialog kann ihn dem aktuellen Konto zuordnen;
dies verschiebt ihn lokal, ueberschreibt kein vorhandenes Kontoprofil und
sendet keine HTTP-Anfrage. Erst die separate Veroeffentlichungsbestaetigung
erlaubt den Upload. Die Profil-Loeschung entfernt nach Server-Ack nur die lokale
Kopie des betreffenden Kontos, nicht andere Konten oder unzugeordnete Entwuerfe.

`GET /parent-matching/my-profile` verifiziert den Firebase-Token auch bei
Lesezugriffen und verlangt die passende Eigentuemer-UID. HTTP 404 bedeutet kein
aktives Profil; Datenbankfehler liefern HTTP 503 statt In-Memory-Fallback.
Auch der POST auf demselben Pfad verlangt die passende Firebase-UID.
Die App zeigt Aktivitaet erst nach einer Antwort mit Profil-ID und passender
Eigentuemer-UID. Auth-, Transport- und Parsingfehler zeigen einen ungeprueften
Status mit Wiederholen, niemals eine bestaetigte Sichtbarkeit.

Alle 13 produktiven `FamilyMatchProfile.load`-Aufrufer verwenden diese zentrale
Kontogrenze (keine zweite Legacy-Leselogik):

- `lib/ui/eltern_netzwerk_screen.dart`
- `lib/ui/calendar_screen.dart`
- `lib/ui/widgets/home/events_carousel_widget.dart`
- `lib/ui/widgets/home/context_home_card.dart`
- `lib/logic/family_recipe_service.dart`
- `lib/logic/fridge_recipe_service.dart`
- `lib/logic/eltern_wissen_service.dart`
- `lib/ui/tischmoment_screen.dart`
- `lib/ui/familien_zentrale_screen.dart`
- `lib/ui/familien_geld_screen.dart`
- `lib/ui/benefit_guide_screen.dart`
- `lib/ui/ritual_ruhe_screen.dart`
- `lib/ui/chat_screen.dart`

Alters-Caches der drei betroffenen Singleton-Services werden beim Neuladen
zurueckgesetzt. Die Profil-Lesepfade verwenden die bisherigen neutralen
Fallbacks, solange noch kein Entwurf uebernommen wurde. Andere eigenstaendige
Speicher (z.B. Kind-Dossiers, Kalender, Chats) werden durch diese Migration nicht
kontobezogen migriert; sie bleiben Teil ihrer jeweiligen Kachel-Audits.

```bash
flutter test --no-pub test/playmate_profile_state_test.dart
node --test backend/tests/unit/parent-matching-state.test.js
```

### Authentifizierte Discovery und echte Fehlerzustaende

`/parent-matching/discover` und der Adapter `/api/parent-matching/find` nutzen
denselben Handler mit verifizierter Firebase-UID und Eigentuemerpruefung.
Ein fehlendes eigenes aktives Profil liefert HTTP 404, Auth-Fehler 401/403
und Datenbank-/Safety-Filter-Fehler 503. Solche Fehler sind keine leeren
Trefferlisten. In-Memory-Demo-Fallbacks werden bei Discovery-Fehlern nicht mehr
ausgeliefert; Blocklisten und Sperrungen muessen vor dem Scoring verfuegbar sein.

Die App verwendet den injizierten authentifizierten BackendApiClient statt
eines separaten Raw-HTTP-Clients. Nur ein gueltiges `matches`-Array ist ein
Suchergebnis. Der bestehende Radius-Fallback (10, 50, 100, 1200 km) wird nur
nach erfolgreichen leeren Antworten erweitert. HTTP-, Transport- und
Parsingfehler stoppen die Suche sofort, ohne globalen Empty-State.
Beide Matching-Oberflaechen zeigen explizite Fehler mit Wiederholen; Auth-Fehler
erhalten einen eigenen Hinweis. Alte Treffer bleiben intern erhalten, werden
bei einem Fehler aber nicht als aktuelle Suchergebnisse angezeigt.

```bash
flutter test --no-pub test/playmate_discovery_test.dart
node --test backend/tests/unit/parent-matching-discovery.test.js
```

### Spielfreunde-Vorschlaege ohne Legacy-Endpunkt

Der bisherige Client-Aufruf `/api/spielfreunde/profiles` hatte keinen
Server-Endpunkt. Die Vorschlagskarten im Netzwerk-Tab verwenden jetzt direkt
dieselben authentifizierten, servergeprueften Matching-Ergebnisse wie der
Spielfreunde-Tab. Es gibt keine zusaetzliche Legacy-Abfrage und keine
Demo-Familien. Bei Discovery-Fehlern erscheint auch hier Wiederholen statt
einer vermeintlich leeren Vorschlagsliste.

Vorschlaege setzen ein verifiziert aktives eigenes Profil voraus. Es werden
hoechstens sechs unterschiedliche Konten in Matching-Reihenfolge gezeigt;
eigene UID, bestehende Freunde, ausgeblendete und blockierte Konten werden
ausgeschlossen. Fehlende Eigentuemer werden geloggt und nicht als
Freundschaftsziel verwendet. Karten verwenden ausschliesslich oeffentlichen
Anzeigenamen, Ort und veroeffentlichte Altersgruppen, keine Kindnamen,
Geburtsdaten oder Gesundheitsdaten. Die veraltete, sonst ungenutzte
SpielfreundeBackendService-Klasse wurde entfernt.

```bash
flutter test --no-pub test/playmate_suggestions_test.dart
```

### Eltern-Netzwerk: zentrale UI-Uebersetzungen

Die Spielfreunde-Formularoptionen und restlichen UI-Texte werden zentral ueber
AppStringsManager/context.tr fuer de/en/tr/ku uebersetzt. Die gespeicherten
Optionscodes bleiben unveraendert; unbekannte individuelle Optionen behalten
ihren eigenen Text. Auch oeffentliche Altersgruppen werden nur fuer die Anzeige
uebersetzt. Der Einladen-Button im leeren Spielfreunde-Tab wechselt in den
Netzwerk-Tab mit Link-/QR-Einladung statt erneut denselben Tab auszuwaehlen.

```bash
flutter test --no-pub test/network_i18n_navigation_test.dart test/localization_audit_verification_test.dart
```

### Datensparsame Nominatim-Ortssuche

Der gemeinsame Standort-Picker (Eltern-Netzwerk, Events-Suche,
Community-Event-Erstellung) verwendet fuer GPS und Karten-Pin
LocationAutocompleteService.searchCoordinates. Vor der Nominatim-Anfrage
werden beide Werte mit dem bestehenden roundCoordinate-Helper auf zwei
Nachkommastellen gerundet (ungefaehr 1 km). Auch numerische Koordinatenpaare
ueber searchImmediate werden an dieser gemeinsamen HTTP-Grenze gerundet.
Normale Suchtexte, lokale Pin-/GPS-Koordinaten und die bestaetigte
PickedLocation bleiben unveraendert.

Ein Hinweis erklaert Nominatim-Ortssuche und OSM-Kartenkacheln. Die Rundung
ist keine Anonymisierung und rundet nicht die Kartenkachel-Anfragen; sie
reduziert gezielt die Genauigkeit der an Nominatim gesendeten Koordinaten.
Keine KI-Verarbeitung und keine neue Datenbankmigration.

```bash
flutter test --no-pub test/location_search_privacy_test.dart test/event_geocoder_test.dart test/localization_audit_verification_test.dart
```

## Produktions-Hardening

Für produktionsnahe Nutzung setze folgende Umgebungsvariablen vor dem Start:

- `BACKEND_API_TOKEN`: Erwarteter Bearer-Token für Schreibzugriffe
- `GEMINI_API_KEY`: Server-seitiger Gemini-Schlüssel für `/ai/generate` (nie im Client-Build)
- `FIREBASE_REQUIRE_AUTH=1`: Verifiziert Firebase-ID-Tokens für Client-Schreibzugriffe
- `REQUIRE_AUTH_FOR_WRITES=1`: Aktiviert Auth-Pflicht für `POST/PUT/PATCH/DELETE`
- `CORS_ALLOWED_ORIGINS`: Kommagetrennte Origin-Allowlist
- `WRITE_RATE_LIMIT_WINDOW_MS`: Zeitfenster für Write-Rate-Limit (ms)
- `WRITE_RATE_LIMIT_MAX`: Max. Schreibanfragen pro Fenster und Client
- `INTERNAL_MODERATOR_EMAILS`: explizite interne Moderations-/Review-Accounts (kommagetrennt)
- `INTERNAL_MODERATOR_DOMAINS`: erlaubte interne Domains für Moderation und Fachverifizierung
- `WEEKLY_IMPULSE_SCHEMA_PATH`: optionaler absoluter Pfad zur `weekly_impulse_schema_year3.json` (nur noetig bei abweichendem Deploy-Arbeitsverzeichnis)
- `STRIPE_WEBHOOK_SECRET`: Stripe Endpoint Signing Secret (`whsec_...`)
- `STRIPE_WEBHOOK_TOLERANCE_SEC`: erlaubte Zeitabweichung fuer Stripe Signaturen
- `ALLOW_CLIENT_PROVIDER_EVENTS=0`: deaktiviert clientseitige Provider-Statusupdates

Beispiel:

```bash
export BACKEND_API_TOKEN="..."
export GEMINI_API_KEY="..."
export FIREBASE_REQUIRE_AUTH=1
export REQUIRE_AUTH_FOR_WRITES=1
export CORS_ALLOWED_ORIGINS="https://parentpeak.de,https://www.parentpeak.de"
export INTERNAL_MODERATOR_EMAILS="lead@parentpeak.de,ops@parentpeak.de"
export INTERNAL_MODERATOR_DOMAINS="parentpeak.de,parentpeak.com"
export WEEKLY_IMPULSE_SCHEMA_PATH="/opt/render/project/src/backend/weekly_impulse_schema_year3.json"
export STRIPE_WEBHOOK_SECRET="whsec_..."
export STRIPE_WEBHOOK_TOLERANCE_SEC=300
export ALLOW_CLIENT_PROVIDER_EVENTS=0
node server.js
```

## Wochenimpuls Community, Moderation und Fachverifizierung

Der Wochenimpuls-Bereich besitzt jetzt drei produktionsrelevante Ebenen:

- Community-Posts, Likes und Kommentare
- Moderations-Reports mit globalem Ausblenden/Wiederfreigeben
- Fachverifizierung für paedagogische Stimmen

Wichtige Endpunkte:

- `GET /api/weekly-impulse`
- `POST /api/weekly-impulse/community/posts`
- `POST /api/weekly-impulse/community/posts/:postId/report`
- `GET /api/weekly-impulse/community/reports`
- `POST /api/weekly-impulse/community/reports/:reportId/resolve`
- `POST /api/weekly-impulse/community/posts/:postId/moderation-visibility`
- `GET /api/weekly-impulse/community/verification-status`
- `POST /api/weekly-impulse/community/verification-requests`
- `GET /api/weekly-impulse/community/verification-requests`
- `POST /api/weekly-impulse/community/verification-requests/:requestId/approve`

Sicherheitsmodell:

- Normale Community-Aktionen bleiben fuer App-Nutzer:innen offen.
- Moderations- und Verifizierungs-Review-Endpunkte verlangen jetzt serverseitig eine interne E-Mail (`INTERNAL_MODERATOR_EMAILS` oder `INTERNAL_MODERATOR_DOMAINS`).
- UI-Sichtbarkeit allein reicht also nicht mehr aus, um diese Endpunkte zu nutzen.

Empfohlener Go-Live-Check:

1. Setze `INTERNAL_MODERATOR_EMAILS` und/oder `INTERNAL_MODERATOR_DOMAINS` im Hosting.
2. Pruefe mit einem internen Account, dass das Moderationspanel Reports laden kann.
3. Pruefe mit einem normalen Account, dass Moderations- oder Freigabe-Endpunkte `403` liefern.
4. Erzeuge testweise eine Fachverifizierungsanfrage und gib sie mit internem Account frei.

## Stripe Webhook (Produktion)

Sichere Stripe-Integration laeuft ueber:

```bash
POST /payments/stripe/webhook
```

Wichtig:
- Dieser Endpoint erwartet `application/json` Raw Body und den Header `Stripe-Signature`.
- Die Signatur wird serverseitig gegen `STRIPE_WEBHOOK_SECRET` geprueft.
- `completed` und `refunded` werden nur aus verifizierten Provider-Events akzeptiert.
- Der Legacy-Dev-Pfad `POST /payments/provider-events` sollte in Produktion deaktiviert sein (`ALLOW_CLIENT_PROVIDER_EVENTS=0`).

Empfohlene Stripe Event-Abos fuer den Endpoint:
- `payment_intent.succeeded`
- `payment_intent.payment_failed`
- `charge.refunded`

## Post-Deploy Smoke Checks

1. Health pruefen:

```bash
curl -i https://api.example.com/health
```

2. Client-Provider-Events muessen in Produktion geblockt sein:

```bash
curl -i -X POST https://api.example.com/payments/provider-events \
   -H "Content-Type: application/json" \
   -d '{"provider":"stripe","providerTransactionRef":"pi_test","status":"completed","verified":true}'
```

Erwartung: `403`.

Automatisiert (empfohlen):

```bash
BACKEND_BASE_URL=https://api.example.com \
STRIPE_WEBHOOK_SECRET=whsec_... \
bash scripts/stripe_webhook_smoke_test.sh
```

Kombiniert (Security + Stripe in einem Lauf):

```bash
BACKEND_BASE_URL=https://api.example.com \
BACKEND_API_TOKEN=... \
STRIPE_WEBHOOK_SECRET=whsec_... \
bash scripts/release_smoke_suite.sh
```

Wochenimpuls-Community und Fachverifizierung gezielt pruefen:

```bash
BACKEND_BASE_URL=https://api.example.com \
INTERNAL_REVIEWER_EMAIL=lead@parentpeak.de \
INTERNAL_REVIEWER_NAME="Lead Review" \
bash scripts/weekly_impulse_community_smoke_test.sh
```

Oder im Gesamtlauf aktivieren:

```bash
BACKEND_BASE_URL=https://api.example.com \
RUN_BACKEND_SECURITY_SMOKE=1 \
RUN_STRIPE_WEBHOOK_SMOKE=0 \
RUN_WEEKLY_IMPULSE_COMMUNITY_SMOKE=1 \
INTERNAL_REVIEWER_EMAIL=lead@parentpeak.de \
bash scripts/release_smoke_suite.sh
```

Schneller Smoke-Test gegen eine laufende Instanz:

```bash
BACKEND_BASE_URL=https://api.example.com \
BACKEND_API_TOKEN=... \
bash scripts/backend_security_smoke_test.sh
```

## API Endpoints

### 📋 Alle Anbieter abrufen
```
GET /api/providers
```

### 🔍 Nach Kategorie filtern
```
GET /api/providers/category/{category}
```

### 👤 Einzelnen Anbieter abrufen
```
GET /api/providers/{id}
```

### 🔎 Suchen
```
GET /api/search?q={suchtext}
```

### 📊 Alle Kategorien
```
GET /api/categories
```

### ⭐ Bewertung hinzufügen
```
POST /api/providers/{id}/review
Body: { "rating": 5, "comment": "...", "parentName": "..." }
```

### 🎯 Erweiterte Filter
```
POST /api/providers/filter
Body: { 
  "categories": ["Mathe", "Deutsch"],
  "maxPrice": 30,
  "minRating": 4.5
}
```

### 💚 Health Check
```
GET /health
```

## Testdaten

Die `providers.json` enthält 10 Beispiel-Anbieter:
- 6 Nachhilfelehrer (Mathe, Deutsch, Englisch, etc.)
- 4 Betreuer/Nannys (Kleinkinder, Schulkinder, Fahrdienste, etc.)

## Für Flutter-App konfigurieren

In der Flutter-App, update die Backend-URL:
```dart
const String backendUrl = 'http://192.168.x.x:3000';  // IP des Computers
```

## Optional: Für extern erreichbar machen

Um die App auf dem physischen Handy zu testen:
1. Finde deine Computer-IP: `ipconfig` (Windows) oder `ifconfig` (Mac/Linux)
2. Starte Backend mit: `npm start`
3. In der Flutter-App: `http://{DEINE_IP}:3000`
