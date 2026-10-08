# Client-Datenschutz und Sprachumfang

Diese Dokumentation beschreibt die jeweiligen Client-Grenzen und offenen
Einschraenkungen. Sie ist keine allgemeine Datenschutz-, Rechts- oder
Launchfreigabe. Testbefehle werden vom Projekt-Root ausgefuehrt.

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
