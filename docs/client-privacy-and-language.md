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
