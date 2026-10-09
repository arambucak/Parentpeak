# Client-Datenschutz und Sprachumfang

Diese Dokumentation beschreibt die jeweiligen Client-Grenzen und offenen
Einschraenkungen. Sie ist keine allgemeine Datenschutz-, Rechts- oder
Launchfreigabe. Testbefehle werden vom Projekt-Root ausgefuehrt.

## Kinder, Onboarding und gemeinsame Einstellungen: Kontogrenze

`ProfileAccountStore` speichert Kinder, Onboarding-Abschluss/Familienname,
Elternrollen, Altersgruppen, Prioritaeten, Feiertagsland/-region, Kachelreihenfolge,
gemeinsamen Standort und Events-Stadt in `profile.accounts.v1`. Jeder Datensatz
hat einen eigenen `account.<encoded-UID>`-Owner; neue Gastdaten liegen separat.
Logout loescht keine fremden Kontodaten, sondern invalidiert die aktuelle
Session. Leser und laufende Dialoge/Syncs verwenden Scope und Sessiongeneration:
Auch Logout und erneutes Login derselben UID machen alte Ergebnisse ungueltig.

Die bisherigen globalen Keys werden nicht automatisch gelesen, zugeordnet oder
geloescht. Sie bleiben als ignorierter lokaler Altbestand erhalten. Profil und
Onboarding bieten getrennte ausdrueckliche Claims fuer Kinder, Onboarding/
Einstellungen und Standort. Der Dialog nennt die reine lokale Zuordnung;
ein Claim sendet keine HTTP-Anfrage und veroeffentlicht kein Matching-Profil.
Owner-Marker und uebernommene Werte werden zusammen gespeichert. Parallele Claims,
Kontowechsel, ein bereits beanspruchter Bereich oder vorhandene kontobezogene
Werte verhindern Ueberschreiben/Vermischen. Bei Konflikten bleibt der Altbestand
erhalten; dieser PR bietet keine Zusammenfuehrung. Die bislang fachlich
ungenutzten Mehrfachrollen/Altersgruppen bleiben fuer die lokale Wiederherstellung
erhalten; ihre weitergehende Verwendung ist Backlog.

Kinderlisten werden nicht an den Onboarding-Endpunkt gesendet. Der bestehende
minimale Sync umfasst nur UID, Abschluss, Familienname, Elternrolle und
Prioritaeten. AuthGate wartet auf einen kontobezogenen Status und zeigt bei
Speicher-/Serverfehlern einen Fehler mit Retry statt stillschweigendem Erfolg.
Fehlt ein lokaler Abschluss und ist der Server offline, bleibt der Gate-Check
sichtbar blockiert. Nach lokal erfolgreichem Abschluss darf die App weiter;
ein gescheiterter anschliessender Sync wird ausdruecklich gemeldet.

`GET /api/onboarding/:userId`, `POST /api/onboarding` und jede Variante von
`POST /api/profile` verlangen jetzt ein verifiziertes Firebase-ID-Token mit
passender UID (fehlend/ungueltig: 401, fremde UID: 403). Das gilt auch ohne
`avatarUrl`, bei Datenbankfehlern und ohne Firebase-Admin-Konfiguration; ein
gemeinsames Backend-Token ersetzt den Owner-Nachweis nicht. Bewusste oeffentliche
Anzeigenamen-/Avatar-Lesezugriffe ueber `GET /api/profile/:userId` bleiben bestehen.
Client-HTTP-Guards pruefen die Session auch nach Token-Aufloesung und vor 401-Retry.

Keine Schema-Migration. Der geaenderte Backend-Tree verlangt vor Pages-Freigabe
einen freigegebenen Render-Rollout. Dieser Nachweis ist keine Produktionsfreigabe.
Die lokale Kontozuordnung ist keine Verschluesselung.

## Ungefaehrer Standort im Onboarding

`LocationService` verwendet den bestehenden `roundCoordinate`-Helper mit zwei
Nachkommastellen: GPS, manuelle Geocoding-Ergebnisse und direkt ausgewaehlte
Koordinaten werden vor dem Schreiben ins Account-Envelope gerundet. Auch der
GPS-Reverse-Geocoding-Aufruf an OpenStreetMap Nominatim verwendet nur gerundete
Koordinaten. Der Onboarding-Hinweis in de/en/tr/ku nennt die ungefaehre
Speicherung und Nominatim als Empfaenger von Koordinaten bzw. Ortseingaben.
Die Genauigkeit ist ungefaehr Kilometeraufloesung, keine Anonymisierung.
Bereits vorhandene praezise Account-/Legacy-Standorte werden durch diesen
Change nicht nachtraeglich migriert; bei erneuter Standortwahl werden sie
gerundet ersetzt. Keine Backend-Aenderung.

## Wiederhergestellte Session und Benachrichtigungen

Firebase-Auto-Login laedt den Nutzer neu und fordert einen frischen ID-Token
an. UID, Token-Owner, Ablaufzeit und E-Mail-Verifizierung muessen passen;
ein vorhandener lokaler Session-Owner muss dieselbe UID haben. Ohne bisherigen
Owner darf eine valide Firebase-Session erstmalig zugeordnet werden.
Mismatch, abgelehnter Refresh oder nicht verifizierte Session fuehren zum
Logout statt einer stillen Uebernahme. Bei nicht erreichbarer Verifizierung
wird ebenfalls eine neue Anmeldung verlangt; dies ist kein Offline-Auto-Login.
Firebase-Abmeldung/UID-Wechsel invalidieren die lokale Session. Der bestehende
Debug-only lokale Auth-Fallback bleibt unveraendert.

FCM-Registrierung und Refresh binden sich an den aktuellen Owner und eine
Sessiongeneration statt an die UID des ersten Listeners. Beim Wechsel wird
der bisherige Token mit der Ursprungs-Credential deregistriert, auf dem Geraet
invalidiert und fuer das neue Konto neu gebunden. Logout hebt lokale
Erinnerungen auf; spaete Registrierungsantworten werden bereinigt.
Auch bei Backend-Abmeldefehlern wird die Geraete-Invalidierung versucht und
der Fehler protokolliert. Clientseitige FCM-Anzeige/Navigation akzeptiert nur
Push-Daten mit passender `accountUserId`. Bereits vom Betriebssystem/Provider
zugestellte Pushes koennen nicht rueckwirkend verhindert werden; reale
Geraete-QA bleibt erforderlich. Web-FCM ist deaktiviert.

Die Token-Routen verlangen serverseitig einen passenden verifizierten
Firebase-Owner. Eine bereits fremd gebundene Token-Zuordnung darf nicht
ueberschrieben werden. Der Backend-Tree aendert sich; vor einem Merge und
Deploy sind Backup und ausdrueckliche Rollout-Freigabe erforderlich.

## Kontobezogener Datenexport

Der lokale Anteil des Profil-Exports wird aus den validierten Owner-Envelopes
und ausdruecklich kontobezogenen Schluesseln zusammengestellt. Andere
Account-Envelopes, Gast-/Legacy-Keys ohne Claim und globale SharedPreferences
werden nicht exportiert. Ein Kontowechsel waehrend des Sammelns oder des
Serverabrufs bricht den Export ab. Ohne angemeldetes Konto wird der Export
vor dem Lesen lokaler Daten verweigert; der Profil-Handler zeigt einen
Anmeldehinweis in de/en/tr/ku statt einen Gast-Export zu erstellen.
Das JSON wird weiterhin in die
Zwischenablage kopiert; Zwischenablagen koennen synchronisiert oder laenger
verfuegbar bleiben. Ein expliziter Download-/Teilen-Flow bleibt eine separate
UX-Verbesserung.

Der Serverexport ist nicht vollstaendig: KI-Memory-Einstellungen samt
Consent-Version/-Revision, KI-Kindprofile und Memory-Eintraege, Familien-
Mitgliedschaften, Familienanfragen und familiengebundene Todos/
Einkaufslisten/Mahlzeiten, Event-Serien-Follows sowie die per SQL verwalteten
`OnboardingProfile`-Stammdaten sind in der aktuellen Exportabfrage nicht
enthalten. Diese Servermodelle muessen vor einer vollstaendigen Art.-20-
Abdeckung separat bewertet und ergaenzt werden.

```bash
flutter test --no-pub test/profile_account_store_test.dart test/profile_account_http_guard_test.dart test/onboarding_account_sync_test.dart test/profile_claim_widget_test.dart test/profile_onboarding_lifecycle_widget_test.dart test/location_account_lifecycle_test.dart test/onboarding_test.dart test/calendar_service_test.dart test/event_filter_ui_test.dart test/localization_audit_verification_test.dart
cd backend && node --test tests/unit/*.test.js
```

## Kuehlschrank-Foto: kontobezogener Client-Consent

`FridgePhotoConsent` nutzt den gemeinsamen geprueften Schreib-Ack unter
`fridge.ai_photo_consent.v1.<Kontobereich>`. Der alte globale Key
`fridge.ai_photo_consent` wird weder uebernommen noch geloescht und gilt nicht
als Zustimmung. Die Texte de/en/tr/ku nennen Google Gemini, nicht anonymisierte
Foto-Inhalte sowie Zutaten/Kindesalter/Allergien fuer das anschliessende Rezept.
Dies ist keine Freigabe zum Veroeffentlichen und kein Versprechen zur
Speicherdauer beim Provider.

`FridgeRecipeService` prueft diese Zustimmung vor dem Kontextladen,
vor/nach dem Bildlesen, vor HTTP und nach der Antwort. Der Service liest das
`XFile` selbst. Beide KI-Einstiegspunkte und HTTP-Auth-Retries binden sich an
den urspruenglichen Consent-/Zentralen-Kontobereich. Ablehnung/fehlender Ack
blockiert die Anfrage; spaete Antworten bei Kontowechsel werden verworfen.
Der eigenstaendige Familienrezept-Consent ersetzt diesen Consent nicht.
Diese Grenze ist clientseitig; der allgemeine Backend-KI-Endpunkt wird damit
nicht zu einer serverseitigen Foto-Consent-Pruefung.

```bash
flutter test --no-pub test/fridge_photo_consent_test.dart test/family_hub_account_test.dart test/family_hub_persistence_test.dart test/localization_audit_verification_test.dart
```

## Empfaengerhinweis fuer Entwicklungsberichte

Der aktive Entwicklungsbericht-Dialog benennt Google Gemini in de/en/tr/ku
ausdruecklich als KI-Empfaenger. Nicht abgedeckte UI-Sprachen verwenden den
englischen Hinweis. Die Berichtsantworten gehen ueber `/ai/generate` an den
Backend-Proxy; der Kindname wird im Prompt durch `[KIND]` ersetzt und erst lokal
wieder eingesetzt.

`DevelopmentReportConsent` speichert eine neue, ausdrueckliche Zustimmung unter
`dev.ai_report_consent.v1.account.<encoded-user-id>`; Gastmodus ist separat
unter `.guest`. Der globale Legacy-Key bleibt erhalten, gibt aber keine
KI-Verarbeitung frei. Nur ein positiver Schreib-Ack aktiviert den Bericht;
Fehler und Kontowechsel im Dialog zeigen einen lokalisierten Hinweis.

`DevelopmentReportService` prueft Zustimmung und Ursprungskonto vor und nach
dem KI-Aufruf. Sein HTTP-Guard greift auch bei Token-Aufloesung und 401-Retry;
Widerruf oder Kontowechsel verwerfen Ergebnisse. Der Screen invalidiert
laufende Requests auch bei Wechsel weg vom und zurueck zum gleichen Konto.
Neue Berichte/Historien und zugehoerige Score-Snapshots liegen kontobezogen;
unzugeordnete Legacy-Berichte werden nicht automatisch einem Konto zugewiesen
und bleiben unveraendert lokal erhalten. Antworten und lokale Kindprofile
werden durch diesen begrenzten Consent-Fix nicht insgesamt migriert.
Report-Limit und Score-Speicherung pruefen den Ursprung vor weiteren Writes.

Bereits abgesandte Anfragen werden nicht rueckgaengig gemacht. Die lokale
Consent-Grenze ist keine unabhaengige Backend-Sperre fuer fremde Clients und
keine Rechts-/Launchfreigabe. Bestehende Aussagen zur Speicherung ersetzen
keinen Nachweis der realen Provider-Aufbewahrung.

```bash
flutter test --no-pub test/development_report_consent_test.dart test/development_checkin_store_test.dart test/development_pdf_i18n_test.dart test/gemini_ai_service_test.dart test/localization_audit_verification_test.dart
```

## Sprachumfang von Eltern-Wissen

Die aktive FAQ-Datenbank enthaelt 32 Eintraege, ueberwiegend auf Deutsch;
die Suche arbeitet mit deutschen Fragen, Tags und Kategorien. Themenkarten
starten passende deutsche Suchbegriffe. Eine einzelne tuerkische Tagesantwort
ist keine vollstaendige FAQ-Uebersetzung.

Fuer jede nichtdeutsche App-Sprache zeigt das aktive Widget einen nicht
wegklickbaren Hinweis, auch bei Suchtreffern und leerer Suche. In de/en/tr/ku
ist der Hinweis selbst lokalisiert; andere Sprachen erhalten ihn auf Englisch
mit einer zusaetzlichen Erklaerung fuer fehlende UI-Uebersetzungen.
Themenkarten skalieren mit vergroesserter Schrift, und die Tagesimpuls-
Ueberschrift kann umbrechen; Widgettests decken 200/300 Prozent Textgroesse ab.
Vollstaendige FAQ-Uebersetzungen und lokalisierte Suche bleiben bewusst
Post-Launch-Arbeit. Dieser Hinweis behauptet keine globale Erklaerung aller
anderen Sprach-Fallbacks der App oder abgeschlossene sprachliche Release-QA.

```bash
flutter test --no-pub test/eltern_wissen_language_notice_test.dart test/eltern_wissen_search_test.dart test/localization_audit_verification_test.dart
```
