# ParentPeak - Audit Teil 2: appweite Bereiche

Stand: 8. Oktober 2026. Gepruefter main:
`e1b0931eaae5f6749cec27e0cae91eba0dfe53f8` (#166).
Auftrag: Inventur und erste Tiefenanalyse, **keine Fixes**.
Nur dieses Dokument wird versioniert. Der lokale, unversionierte
`AUDIT_PLAN.md` bleibt unveraendert; seine historischen Produktionsangaben
sind nicht automatisch der heutige Stand.

## 1. Vorgehen, Status und Grenzen

Pro Bereich: Tiefenanalyse entlang Datenschutz, Korrektheit, i18n, Web,
Qualitaet und Tests -> priorisierter Bericht -> Nutzerentscheidung ->
getrennte kleine Fix-PRs. Keine pauschale Launch-Freigabe aus gruener CI.
Baseline laut bestehendem Plan: 11 Analyzer-Infos; bekannte lokale
Events-Firebasefehler, volle CI als eigener Nachweis.

- **Schon auditiert:** abgegrenzter damaliger Kachel-/Fixumfang durch
  aktuellen Code und Tests/Commitgeschichte bestaetigt, nicht jedes
  denkbare angrenzende System.
- **Teilweise:** einzelne Pfade geprueft/gehaertet; Gesamtbereich nicht abgenommen.
- **Noch offen:** kein verifizierter vollstaendiger Audit dieses Bereichs.
- **P0:** vor oeffentlichem Launch klaeren/beheben, insbesondere Kontotrennung,
  Auth/Owner, Datenrechte und transparente sensible Verarbeitung.
- **P1:** vor Launch der betroffenen Plattform/Funktion abnehmen oder
  nachvollziehbar deaktivieren/einschraenken.
- **P2:** nach Launch vertretbar, nur wenn keine P0/P1-Basis betroffen ist.

Inventur ist keine zweite Tiefenanalyse aller Tabellenzeilen. Nur Abschnitt 4
untersucht Login/Onboarding/Profil samt direkt beteiligten Services und Routes.
Keine Requests an Produktion, Firebase, KI oder Paymentanbieter; keine
Dashboard-/Rule-/API-Key-Aenderungen, Installationen oder neuen Runtime-Tests.
Die Befunde beruhen auf Source, vorhandenen Tests und lokaler Gitgeschichte.
Es wurde kein Exploit gegen das Live-System ausprobiert.
Vorhandene Tests wurden hier gelesen, nicht als neu bestanden ausgegeben.

## 2. Inventur und priorisierte Landkarte

| Bereich | Status / verifizierter Umfang | Relevante Dateien / naechste Pruefung | Launch-Prioritaet |
|---|---|---|---|
| Zehn Feature-Kacheln | **Schon auditiert im damaligen Umfang**, #103-#155; Consent-Nachlauf #157/#161/#159. Nicht pauschal Backend/Auth freigegeben. | [Launch-Nachweise](LAUNCH_READINESS.md), [Client-Consent-Doku](docs/client-privacy-and-language.md), Konto-Codebelege in 2.1. | Bekannte Restgrenzen weiterhin P0/P1 laut Launch-Plan; nicht nochmals jede Kachel blind neu fixen. |
| Login / Registrierung | **Teilweise**, erste Tiefenanalyse in 4; UI-Validierung und Logout-FCM-Test vorhanden, Firebase-/Provider-End-to-End nicht belegt. | [Login](lib/ui/auth/login_screen.dart), [Register](lib/ui/auth/register_screen.dart), [AuthService](lib/logic/auth_service.dart), [Firebase-Konfiguration](lib/firebase_options.dart), [Login-Tests](test/tests/login_test.dart). | **P0/P1:** Eintrittspunkt, Verifizierung, native Google-Anmeldung, Sessionverlust. |
| Onboarding | **Teilweise**, erste Tiefenanalyse in 4; Tests pruefen vorwiegend Preferences, nicht den ganzen Wizard. | [Screen](lib/ui/onboarding/onboarding_screen.dart), [Pages](lib/ui/onboarding/onboarding_pages.dart), [Sync](lib/logic/onboarding_sync_service.dart), [Tests](test/onboarding_test.dart). | **P0:** Kontozuordnung, sensible Standortuebermittlung, serverseitiger Owner. |
| Profil / Schutz / Kinder / Einstellungen | **Teilweise**, erste Tiefenanalyse in 4; Kachel-Accounts sind nicht die Profil-Kinderliste. | [Profil](lib/ui/profile_safety_screen.dart), [UserProfileService](lib/logic/user_profile_service.dart), [FamilyMatchProfile](lib/models/family_profile_model.dart), [KindDossierService](lib/models/kind_dossier.dart). | **P0:** fremde lokale Daten, Export/Loeschung; **P1:** Rechtstexte, Avatar und Sprache. |
| App-Start / Shell / Navigation / Routing / Deep Links | **Teilweise:** aktuelle Init-Reihenfolge/AuthGate gelesen, kein Gesamt-Routing-Audit. #27 startup-fast-path weiterhin OPEN; nur Vorschlag, nicht aktueller Code. | [main](lib/main.dart), [Home](lib/ui/home_screen.dart), [BackendFactory](lib/logic/backend_service_factory.dart), [App-Flow-Test](integration_test/app_flow_test.dart). Pruefen: Auth vor Routen, Restore/Coldstart, eingeloggte/nicht eingeloggte Deep Links, Backstack, Init-Timeouts. | **P1** funktionierender Coldstart/Authgrenze; #27-Performanceoptimierung allein **P2**. |
| Backend-System / API-Gesamtautorisierung | **Teilweise:** einzelne Kachel-Routes und Release/Security-Dependencies geprueft; keine vollstaendige Endpoint-Owner-/Validation-Matrix. Neue konkrete Luecken in 4. | [server.js](backend/server.js), [Schema](backend/prisma/schema.prisma), [Backendunits](backend/tests/unit). Alle GET/POST/PATCH/DELETE: Auth, Owner, Rollen, Inputlimits, Rate-Limit, CORS, Fehler-/Stackleaks, Token-Exemptions. | **P0:** Source-Ausnahmen lassen reine userId nicht zur Berechtigung werden. |
| Firebase Firestore-/Storage-Rules / API-Key-Restriktionen | **Teilweise:** [Storage-Rules](storage.rules) vorhanden; kein Firestore-Ruleset in [firebase.json](firebase.json), keine Console-Abnahme. Tests lesen Rule-Text, kein Emulator-Negativnachweis. | [Rules](storage.rules), [Firebase-Config](firebase.json), [ImageUpload](lib/services/image_upload_service.dart), [Security-Tests](test/security_test.dart). Public read, Objekt-Owner, fremdes Overwrite/Delete, MIME/Groesse; Firestore-Nutzung/Deploy und Keyrestriktionen separat read-only belegen. API-Key ist nicht automatisch ein Secret. | **P0** fuer tatsaechlich aktive Datenspeicher; nicht aus fehlendem lokalen Firestore-File eine offene Live-DB behaupten. |
| Notifications / FCM | **Teilweise:** #115 echte Ritual-Erinnerungen, Web-Guards und Logout-Unregister existieren. Gesamter Permission-/Account-Lifecycle offen. | [NotificationService](lib/logic/notification_service.dart), [Logout-Test](test/auth_service_logout_test.dart), [Web-Serviceworker](web/firebase-messaging-sw.js). Inhalte auf Sperrbildschirm, Tokenwechsel, Zeitzonen/DST, Scheduling/Cancel, Kontowechsel. | **P0/P1** Datenschutz/Kontowechsel; neue Komfort-Schedules **P2**. |
| Premium / Entitlements / Stripe / Payments | **Teilweise:** source-gelesene Beta-Flags, keine komplette Payment-Abnahme. Mehrere Berechtigungssysteme vorhanden. | [AuthService](lib/logic/auth_service.dart), [Entitlements](lib/logic/entitlement_service.dart), [Premium](lib/services/premium_service.dart), [MonetizationConfig](lib/config/monetization_config.dart), [Paywall](lib/ui/auth/paywall_screen.dart), [PaymentService](lib/logic/payment_service.dart), [PaymentScreen](lib/ui/payment_screen.dart), [Stripe-Checkliste](docs/STRIPE_WEBHOOK_PRODUCTION_CHECKLIST.md). | **P0/P1 falls erreichbar:** serverseitige Berechtigung, Refund/Fehler/Webhook-Replay. Deaktivierte Abo-/Ads-Erweiterung **P2**, nicht allein aus Premium-Masterflag alle Zahlungen als tot erklaeren. |
| Globales Error-/Crash-Handling | **Teilweise:** Hooks und Release-Crashlytics-Aktivierung am Code verifiziert; PII-Negativnachweis fehlt. | [ErrorReportingService](lib/logic/error_reporting_service.dart), [main](lib/main.dart), [Crashlytics-Checkliste](docs/CRASHLYTICS_RELEASE_CHECKLIST.md). Exceptiontexte/Stack/Customkeys, Doppelmeldungen, Consent/Storedeklaration, Web-Degradation, Startup-Fehlerbildschirm. | **P0/P1:** rohe Reports werden ohne Sanitizer weitergereicht; kein bestimmter Live-PII-Leak behauptet. |
| Offline / Netzwerk / Wiederholung appweit | **Teilweise:** Kachel-Stores/-Fallbacks gehaertet, kein appweiter Offline-/Race-Testplan. | [BackendApiClient](lib/logic/backend_api_client.dart), [Factory](lib/logic/backend_service_factory.dart), [BackgroundSync](lib/logic/background_sync_manager.dart), [Backend-Fehlertests](test/backend_api_error_test.dart). Timeouts, 401-Refresh, stale results, Idempotenz, Abbruch, ehrlicher lokaler Status. | **P1** kein Datenverlust/falscher Erfolg; echter Hintergrundsync **P2** nur ohne heutiges Sync-Versprechen. BackgroundSync.initialize ist derzeit No-op. |
| Shared LanguageService / i18n | **Teilweise:** de/en/tr/ku-Keysatzpruefung vorhanden, viele Kacheltexte korrigiert; Gesamt-UI und AuthService nicht vollstaendig lokalisiert. | [LanguageService](lib/logic/language_service.dart), [Strings](lib/l10n/app_localizations_all.dart), [Locales](lib/l10n/supported_languages.dart), [i18n-Test](test/localization_audit_verification_test.dart), [Locale-Test](test/supported_languages_test.dart). Fehlende UI-Keys, RTL, Laufzeitwechsel, EN-Fallback. | **P1** versprochene Kernsprachen und Consenttexte; weitere Volluebersetzungen **P2** nach ehrlicher Umfangsentscheidung. |
| Shared KindDossier / Alter / Kalenderdaten | **Teilweise:** #111/#130/#137 Alters-/Accountgrenzen belegt; Profil-Freitext-Kinder und Onboarding sind eigene Modelle. | [KindDossier](lib/models/kind_dossier.dart), [FamilyProfile](lib/models/family_profile_model.dart), [Alters-Tests](test/child_age_calculation_test.dart), [Dossier-Altertests](test/family_hub_age_test.dart), [FamilyHubStore](lib/logic/family_hub_store.dart). Geburtstag/Zeitzone/Schaltjahr, alle Leser, kuenftige Daten. | **P0/P1** sensible Owner/Altersentscheidungen; Modellkonsolidierung **P2** ohne Verhaltensverlust. |
| Shared AIRateLimiter / Kostenlimits | **Teilweise:** bewusst geraetebezogen, Source vorhanden; nicht allein Backend-Missbrauchsschutz. | [AIRateLimiter](lib/services/ai_rate_limiter.dart), [GeminiService](lib/logic/gemini_ai_service.dart), [server.js](backend/server.js). Tageswechsel/Parallelrequests, Retryzaehlung, Serverlimits/Kosten, klare Fehler. | **P1** reale Backendlimits/Kosten; lokale UX-Politur **P2**. |
| Shared Geocoder / Standort | **Teilweise:** #107/#128 gerundete Pfade belegt; LocationService-Reverse ist ein anderer Pfad, siehe K04. | [Autocomplete](lib/logic/location_autocomplete_service.dart), [Geocoder](lib/logic/event_geocoder.dart), [LocationService](lib/services/location_service.dart), [Picker](lib/ui/widgets/location_picker_widget.dart), [Privacytest](test/location_search_privacy_test.dart). Externe Suchtexte/GPS/IP, Transparenz, Round-before-send. | **P0** exakte Koordinaten/fehlende Information. |
| Shared PrivacySanitizer / KI-Vertraege / Consent | **Teilweise:** Kachel-spezifische Consent-/Payloadtests existieren; Sanitizer ist heuristisch, keine Anonymisierungsgarantie. | [Sanitizer](lib/logic/privacy_sanitizer.dart), [Sanitizer-Tests](test/privacy_sanitizer_test.dart), [AccountConsent](lib/logic/account_ai_consent.dart), [GeminiService](lib/logic/gemini_ai_service.dart). Direkte/Proxy-Pfade, Datenkategorien, Redirect/Retry/Accountwechsel. | **P0/P1** aktive sensible Pfade; neue KI-Funktionen **P2**. |
| Accessibility / responsive UX | **Noch offen appweit:** einzelne Taps/Scrolls verbessert, kein Screenreader-/Kontrast-/200%-Text-Nachweis. | [Login](lib/ui/auth/login_screen.dart), [Onboarding](lib/ui/onboarding/onboarding_pages.dart), [Profil](lib/ui/profile_safety_screen.dart), [Theme](lib/logic/theme_service.dart), [Widgets](lib/ui/widgets). TalkBack/VoiceOver, Fokus, Labels, Skalierung, Darkmode, Tastatur. | **P1** Kernflows bedienbar; umfassende Designpolitur **P2**. |
| Store-Assets / Icon / Splash / Versionierung | **Teilweise:** Assets und Version 1.0.0+1 vorhanden, kein Store-/signierter Buildnachweis. | [pubspec](pubspec.yaml), [Android Manifest](android/app/src/main/AndroidManifest.xml), [iOS Info](ios/Runner/Info.plist), [LaunchScreen](ios/Runner/Base.lproj/LaunchScreen.storyboard), [Store-Matrix](docs/STORE_FIELD_MATRIX_2026-07-16.md), [Store-Notizen](docs/APP_STORE_RELEASE_NOTE_2026-07-16.md). Bundle IDs/Permissions, Support/Delete-URL, Bilder/Claims, Privacylabels, Version/Buildnummern. | **P1 vor Storelaunch**, Marketing-/ASO-Experimente **P2**. |
| Recht / Datenschutzerklaerung / KI-Disclosure / Support | **Teilweise:** Datenflussmatrix #166 vorhanden, keine Rechtsfreigabe. Konkrete Source-Widersprueche in W09. | [Privacy-HTML](web/privacy/index.html), [Terms](web/terms/index.html), [Profil](lib/ui/profile_safety_screen.dart), [APIConfig](lib/config/api_config.dart), [Launchplan](LAUNCH_READINESS.md). Anbieter/Region/Retention/Loeschfristen, E-Mail-Links, Sprachumfang. | **P0/P1:** keine unbelegten Konformitaetsversprechen; Rechtspruefung extern. |
| Geraeteverwaltung / Widerruf / Backup-QR / SecureStorage | **Teilweise:** Widgettest/Adapter vorhanden, kein Gesamt-Recovery-/Threatmodel. | [Devices](lib/ui/device_management_screen.dart), [QR](lib/ui/backup_qr_scan_screen.dart), [Revocation](lib/logic/revocation_service_impl.dart), [SecureStorage](lib/logic/secure_storage.dart), [Tests](test/device_management_widget_test.dart). Besitznachweis, QR-Inhalt, Replay, Sessionwiderruf, Keyrotation und Exportumfang. | **P0/P1 falls erreichbar**; keine angebliche Ende-zu-Ende-Sicherheit ohne Beleg. |
| Social ausserhalb Kachelgrenzen / Kontakte / Gruppen / Freundeschat | **Teilweise:** Eltern-Netzwerk-/Chat-Kachel prueft nicht automatisch jeden separaten Messenger. | [Contacts](lib/ui/contacts_screen.dart), [GroupChat](lib/ui/group_chat_screen.dart), [MatchChat](lib/ui/match_conversation_screen.dart), [Friendship](lib/logic/friendship_service.dart), [FriendChat](lib/logic/friend_chat_service.dart). Owner/Mitgliedschaft, Public/Private, Block/Report, Anhaenge. | **P0/P1** erreichbare personenbezogene Kommunikation; deaktivierte Altfeatures **P2**. |
| Moderation / Safety / Admin / Feedback | **Teilweise:** Services/Tests vorhanden, Gesamtrollen und PII in Feedback nicht abgenommen. | [Admin](lib/ui/admin_moderation_screen.dart), [AdminService](lib/logic/admin_moderation_service.dart), [BlockReport](lib/services/block_report_service.dart), [Safety](lib/ui/safety_guide_screen.dart), [Feedback](lib/ui/widgets/beta_feedback_widget.dart), [Moderationtests](test/moderation_test.dart). Serverrolle statt Clientflag, Appeals, Abuse, Reportretention. | **P0/P1** aktive Community, Abuse/privilegierte Zugriffe; UX-Erweiterung **P2**. |
| Fotos / Galerie ausserhalb bisheriger Upload-Kacheln | **Teilweise:** Shared Bytes-Upload und Verschenkmarkt-Tests belegt, eigene Galerie nicht voll auditiert. | [PhotosScreen](lib/ui/photos_screen.dart), [PhotoBackend](lib/logic/photo_backend_service.dart), [Upload](lib/services/image_upload_service.dart), [Upload-Tests](test/image_upload_content_type_test.dart). EXIF/Metadaten, Public URLs, Owner, Failed-upload-Orphans, Loeschung. | **P0/P1 falls aktiv**, neue Galeriefunktionen **P2**. |
| Release / Betrieb / Dependencies / Restore | **Teilweise, technische Rollouts belegt:** #163 Gate, #167 Patches, #168 Node-Pin; Restore-/Rollback-/physische QA offen. | [Launchplan](LAUNCH_READINESS.md), [Gate](scripts/pages_release_gate.cjs), [CI](.github/workflows/flutter-analyze.yml), [Pages](.github/workflows/deploy-web-pages.yml), [Runtimeguard](backend/node_runtime.cjs), [Operations](docs/APP_GO_LIVE_OPERATIONS_CHECKLIST.md). | **P0/P1** Backups/Restore/Stop, sechs bedingte Paketannahmen plus Prisma; optionale Dependency-/Altfeature-PRs **P2**, keine pauschalen Merges. |

### 2.1 Verifizierung der bereits auditierten Kontogrenzen

Die Gitgeschichte enthaelt #124 `e5eab4f`, #130 `95b5fb7`, #135 `18720d0`,
#142 `2820726`, #150 `537dbb7`. Die Schutzlogik ist im heutigen Code vorhanden:

| PR / Umfang | Echter Codebeleg | Vorhandener Testbeleg | Nicht damit abgedeckt |
|---|---|---|---|
| #124 Spielfreunde | [FamilyMatchProfile](lib/models/family_profile_model.dart): UID-Key, ownerUserId, Legacy nur ausdruecklich zuordnen. | [Profile-State](test/playmate_profile_state_test.dart) | `profile.children`, globales Onboarding, Export aller Keys. |
| #130 Zentrale / Dossiers / Einkauf / Allergien | [FamilyHubStore](lib/logic/family_hub_store.dart): account-/guest-Envelope, Scopeguards. | [Accounttest](test/family_hub_account_test.dart): A/B/Gast ohne Loeschung von A. | Eigene Profil-Kinderliste, globaler LocationService. |
| #135 Familien-Geld | [FamilyFinanceStore](lib/logic/family_finance_store.dart): Scope/Owner, laenderbezogene Werte. | [Accounttest](test/family_finance_account_test.dart) | Premium-/Onboarding-/Profil-Globals. |
| #142 Verschenkmarkt | [TreasureAccountStore](lib/logic/treasure_account_store.dart): Owner + Scopeguards. | [Storetest](test/treasure_account_store_test.dart), [UItest](test/treasure_account_ui_test.dart) | Globaler Export kann die ganze Envelope trotzdem lesen. |
| #150 KI-Chat | [ChatAccountStore](lib/logic/chat_account_store.dart): Scope, Generation/Ticket, Firebase-Identitaetsguard. | [Storetest](test/chat_account_test.dart), [UItest](test/chat_account_ui_test.dart) | AuthService ist kein umfassender Firebase-State-Synchronizer. |

Auch #111 ist am [Alters-Test](test/child_age_calculation_test.dart) und
der taggenauen Berechnung belegt; #128 am gerundeten
[Autocomplete](lib/logic/location_autocomplete_service.dart) und
[Standorttest](test/location_search_privacy_test.dart). Beide belegen
**nicht** automatisch andere Modelle/Geocoderpfade.

## 3. Empfohlene Reihenfolge vor Launch

1. **Account-/Auth-P0:** K01-K03, Session/Verifizierung und Loesch-Owner;
   keine fremden Kinder-/Finanz-/Entwurfsdaten in UI oder Export.
2. **Standort-/Rechts-P0:** K04 und W09, echte Privacy-/KI-/Storeinformationen,
   Crash-/Foto-Datenfluss; keine exakten GPS-Transfers ohne klare Information.
3. **Datenrechte-P1:** W03-W05, Export vollstaendig fuer eigenes Konto,
   providerpassende Reauth vor destruktiven Schritten, ehrliche Teilfehler.
4. **Backend-/Firebase-Gesamtmatrix P0:** alle erreichbaren Routes und Rules
   nach Account/Role/Input/Rate/CORS pruefen. Dieses Teil-Audit beweist keine
   globale Sicherheit; Rule-Emulator/Console-Keyrestriktionen separat abnehmen. Das vorhandene
   [Auth-Runbook](docs/AUTH_HARDENING_RUNBOOK.md) beschreibt den Zielzustand,
   beweist aber die heutigen Token-Exemptions nicht sicher.
5. **Login/Start/Notifications/Offline P1:** W01/W02/W06-W08/W10;
   signierte iOS/Android-QA, Browser-Reload/Google/Deep Links/Offline/Accountwechsel.
6. **Core-i18n/Accessibility/Store P1:** Kernsprachen, Consent-/Fehlertexte,
   TalkBack/VoiceOver/Textscale und richtige signierte Assets/Metadaten.
7. **Payment P0/P1, wenn erreichbar:** Zahlungsausfall/Refund/Entitlement/
   Webhooks. Falls wirklich abgeschaltet, schriftlich gated und dann spaeter.
8. **Betriebsfreigabe:** Restore-/Rollback-Probe, Monitoring/Stop,
   offene Restrisikoentscheidungen und Memory-Pflichtbasis laut Launchplan.

**Nach Launch vertretbar:** #27 als Performanceoptimierung nach funktionalem
Startup-Basistest; zusaetzliche Sprachen/Designpolitur, deaktivierte Abo-/Ads-
Funktionen, getrennt entschiedene Altfeatures/Dependency-PRs und vertiefte
Memory-Staging-Abnahme. Das verschiebt nicht Auth, Owner, Rechtspruefung,
Restore oder grundlegende Memory-Consent-/Loeschtests.

## 4. Erste Tiefenanalyse: Login, Onboarding, Profil

### 4.1 Tatsaechlicher Ablauf und Datenlage

- Email/Password benutzt im Release Firebase; lokales SHA-256-Debug-Login
  ist kein produktiver Ersatz. [AuthService](lib/logic/auth_service.dart)
  Zeilen 188-225, 227-432 und 923-967. MacOS wird in dieser Authinitialisierung
  bewusst ausgenommen; keine MacOS-Loginfreigabe aus iOS/Web ableiten.
- Registrierung validiert Mail und Passwort (>=8, Grossbuchstabe, Zahl),
  setzt Firebase displayName, sendet Verifizierung. Login prueft
  emailVerified und meldet unverifizierte Nutzer ab. Firebasefehler fuer
  Konto vorhanden, Credentials, Rate-Limit und Netzwerk sind gemappt.
- Web-LOCAL-Persistence und Firebase-ID-Token pro Request existieren.
  [Factory](lib/logic/backend_service_factory.dart) wartet bei Tokenabruf
  auf Restore; [ApiClient](lib/logic/backend_api_client.dart) wiederholt
  401 einmal mit Force-Refresh. Das ist kein AuthGate-State-Listener.
- Google: sichtbarer Button benutzt immer Web-Popup; Redirect-Result wird
  auf Web gelesen, aber Popup-Blockade startet keinen Redirect. Apple ist
  sichtbar als "coming soon", keine fertige Implementierung.
- **Onboarding legt kein vollstaendiges Kindprofil an.** Es erfasst
  Anzeigename, Rollen/Phasen, optional Alterskategorien, Land/Region,
  Prioritaeten und Standort. Kein Geburtsdatums-/Allergieformular;
  #111-Alterslogik dort nicht durch eine angebliche Geburtstagsberechnung ersetzen.
  [Screen](lib/ui/onboarding/onboarding_screen.dart), [Pages](lib/ui/onboarding/onboarding_pages.dart).
- Anzeigename geht zu Firebase **und** UserProfile; Onboarding-Abschluss,
  Familienname, Rolle/Prioritaeten gehen zum Backend; Alterskategorien,
  Region und Tileorder bleiben in Preferences. GPS geht auch extern,
  siehe K04. "Unkritisch" im Servicekommentar bedeutet nicht unpersoenlich.
- Profilkinder sind Name plus frei eingegebenes Alter in einem eigenen
  globalen `profile.children`-Stringarray. Keine Allergien/Geburtsdaten,
  keine automatische Verbindung zu FamilyMatchProfile/KindDossier.
- Export ist real: Server-JSON plus rohe lokale Preferences werden als JSON
  in die **Zwischenablage** kopiert, kein Datei-Download. Serverfehler werden
  angezeigt statt lokal-only-Erfolg behauptet. Umfangsprobleme K01/W05.
- Konto-Loeschung ist real implementiert: zwei Backendpfade, danach
  Firebase delete und Preferences.clear. Backend-Ownerpruefung existiert
  bei Export und beiden Loeschpfaden; nicht pauschal IDOR fuer diese Routes behaupten.
- Privacy/Terms oeffnen konfigurierte URLs; statische HTML-Inhalte sind
  vorhanden. EU-AI-Act-Zeile oeffnet einen echten lokalen Infobogen,
  kein externes Gesetz/Compliance-Zertifikat. Inhalt/Claims siehe W09.

### 4.2 Befunde - kritisch (Launch-P0)

**K01 - Lokaler Export umgeht alle bestehenden Kontogrenzen.**
Fundstelle: [Profil](lib/ui/profile_safety_screen.dart#L1400), Zeilen 1400-1440.
`prefs.getKeys()` und `prefs.get(key)` sammeln **alle** Keys, ohne Ownerfilter.
Die account-Envelopes enthalten absichtlich A und B, selbst wenn gerade B
angemeldet ist. Folge: B exportiert A-Dossiers/Finanzwerte/Entwuerfe/Profile
und Legacydaten in die Zwischenablage. Keine Backendluecke notwendig.
Repro fuer spaetere Tests: lokale A- und B-Envelopes synthetisch seed-en,
B anmelden, Export pruefen: ausschliesslich B plus explizit freigegebene
geraetebezogene Daten erlaubt. SecureStorage/Firebase-Token werden dadurch
nicht automatisch mitexportiert; nur Preferences sind hier direkt belegt.
Empfehlung: Exportvertrag/Allowlist mit den vorhandenen Stores, keine
pauschale Loeschung fremder Daten. Sicherheit **HIGH**, Konfidenz 10/10.

**K02 - Profilkinder und Onboarding nicht kontobezogen.**
Fundstellen: [Profil](lib/ui/profile_safety_screen.dart#L201), Zeilen 201-221;
[Onboarding](lib/ui/onboarding/onboarding_screen.dart#L34), Zeilen 34-47,
151-211; [AuthGate](lib/main.dart#L575), Zeilen 575-586.
Logout entfernt nicht diese Keys. A legt Kind/Onboarding an, B meldet sich
auf demselben Geraet an: B liest A-Kinder und uebernimmt `onboarding.completed`;
dadurch wird B-Serverstatus nicht mehr abgefragt, B-Wizard uebersprungen.
Anzeigename/Rollen/Alterskategorien sind ebenfalls global persistiert.
Empfehlung: Owner-/Legacyentscheidung nach bisherigem Muster, nicht
automatisch dem naechsten Login zuordnen. Geraeteinstellungen wie Sprache
nicht blind loeschen. Sicherheit **HIGH**, Konfidenz 10/10.

**K03 - Backend-Ownerluecken in Onboarding und Profil-Schreibfeldern.**
Fundstellen: [Server-Middleware](backend/server.js#L2375), Zeilen 2375-2412
und 2569-2579; [Onboarding-Routes](backend/server.js#L7683), Zeilen
7683-7744; [Profilroute](backend/server.js#L7794), Zeilen 7794-7846.
GET-Onboarding liest nach Pfad-userId ohne Token/Owner. POST-Onboarding
akzeptiert body-userId; beide Write-Middlewares lassen diesen Prefix auch
bei aktiviertem Write-Auth weiter. POST-Profil verlangt nur dann Ownerauth,
wenn **avatarUrl** vorkommt. Ohne dieses Feld koennen displayName, username,
searchable und isPrivate fuer eine fremde bekannte UID veraendert werden;
auch ein vorhandener Token bindet diese Mutation nicht an seinen Owner.
CORS/Rate-Limits sind keine Ownerpruefung. Konkrete Routechecks fehlen,
nicht nur eine unbekannte Dashboardkonfiguration. Keine Liveattacke ausgefuehrt.
Empfehlung: gemeinsame verifizierte UID-/Ownergrenze fuer private Routes;
bewusst oeffentliche Profilansichten gesondert definieren, nicht blind sperren.
Sicherheit **HIGH**, Konfidenz 10/10.

**K04 - Onboarding-GPS sendet ungerundete Koordinaten an Nominatim.**
Fundstellen: [Onboarding](lib/ui/onboarding/onboarding_screen.dart#L347),
Zeilen 347-421; [LocationService](lib/services/location_service.dart#L77),
Zeilen 77-87 und 147-160. Die GPS-Position wird direkt als `lat`/`lon` in
`/reverse` eingebaut. `LocationAccuracy.low` garantiert keine Rundung oder
Anonymisierung. #128 schuetzt den anderen Autocomplete-/Picker-Pfad.
Zusaetzlich fehlen `location_onboarding_explanation` und
`location_onboarding_privacy` im heutigen Strings-Katalog;
[getString](lib/l10n/app_localizations_all.dart#L27820) faellt auf den rohen
Key zurueck. Im relevanten Informationsdialog erscheint also kein echter
lokalisierter Datenschutztext fuer diese Keys.
Empfehlung: alle LocationService-Verbraucher erfassen, Empfaenger transparent
benennen, Round-before-send und Regression; kein exakter Transfer
als "bleibt lokal" bezeichnen. Sicherheit **HIGH**, Konfidenz 10/10.

### 4.3 Befunde - wichtig

| ID / Prioritaet | Verifizierter Befund / Auswirkung | Fundstelle | Empfehlung / fehlender Nachweis |
|---|---|---|---|
| W01 / P1 | **Google-Login verwendet auch auf iOS/Android signInWithPopup.** Das installierte FirebaseAuth-6.5.7-SDK dokumentiert diese API als Web-only (firebase_auth.dart 681-690); kein nativer Zweig im App-Code. Popup-blocked zeigt Hinweis, nicht Redirect; Redirect-Catch ignoriert alle Fehler. | [Login](lib/ui/auth/login_screen.dart#L35), 35-50 und 691-738 | Native Provider-/Credentialstrategie und Web-Popup/Redirect bewusst entscheiden; synthetische Fehler plus signierte Geraete abnehmen. Kein Google-Produktionslogin hier probiert. |
| W02 / P1 | **Verifizierung/Auto-Login nur punktuell:** initialize nimmt currentUser ohne emailVerified-Pruefung; AuthService hat keinen dauerhaften Firebase authState/idToken-Listener. Nach createUser kann sendEmailVerification fehlschlagen, Firebase-Session aber existieren; naechster Start kann Shell betreten. Auf Web liest initialize currentUser unmittelbar, obwohl Factory selbst Restore-Verzoegerung dokumentiert. | [AuthService](lib/logic/auth_service.dart#L188), 188-198, 265-318; [AuthGate](lib/main.dart#L547), 547-553, 667-704 | Einheitlicher Boot-/Session-/Verified-State, Providerregeln und 401/revoked/reload pruefen. Server-Tokenverify beweist keine email_verified-Policy. **Security MEDIUM**, 9/10; kein kompletter Auth-Bypass behauptet. |
| W03 / P0-P1 | **Destruktive Loeschung vor Reauth und falscher Providerpfad:** beide Backendloeschungen passieren vor Firebase.delete. Bei requires-recent-login sind Daten bereits weg, Passwortdialog kann abgebrochen werden. Google-Konto bekommt trotzdem EmailAuthProvider-Passwort-Reauth; reiner Google-Nutzer hat dafuer kein Passwort. | [AuthService](lib/logic/auth_service.dart#L708), 708-785; [Profil](lib/ui/profile_safety_screen.dart#L981), 981-1003 | Providerpassend vor dem ersten destruktiven Schritt reauthentifizieren; Abbruch/Firebase-/Backend-Teilfehler idempotent und ehrlich abnehmen. |
| W04 / P0-P1 | **Loeschung kann Teilfehler als Erfolg melden:** /api/account sammelt SQLfehler in deleted und liefert ok:true; Client ignoriert Payload und loescht Firebase. Preferences.clear-Fehler werden nur geloggt, Rueckgabe bleibt Erfolg. Bei fehlendem ApiClient wird Backendloeschung uebersprungen. | [Server](backend/server.js#L8370), 8370-8375, 8439; [AuthService](lib/logic/auth_service.dart#L722), 722-765 | Vollstaendigkeit/Fehlervertrag, keine erfolgsfoermige Teilbereinigung. Backendowner ist vorhanden, Problem ist Fehler-/Lifecyclevertrag. Stack-/DBdetails in deleted.error nicht an UI/Export weiterreichen. |
| W05 / P1 | **Serverexport unvollstaendig:** exportAccountDataByUserIdPrisma exportiert Primaermodelle, aber keine AiMemorySettings/AiChildProfile/AiMemoryItem und keine dynamischen OnboardingProfile/UserProfile/Friendship-/FriendChat-/Recipe-Daten. Diese existieren im heutigen Server; JSON ist daher kein belegter Voll-Export. | [Exportfunktion](backend/server.js#L5668), 5668-5753; [Memory-Schema](backend/prisma/schema.prisma#L570), [Socialschema](backend/server.js#L3872) | Tatsaechlich gespeicherte Daten-/Retentionmatrix, eigener Account inklusive Memory/Social oder explizit erklaerte Ausschluesse. Art.-20-Anspruch rechtlich extern pruefen; kein Rechtsurteil aus Source. |
| W06 / P1 | **Verifizierungslink erneut senden ist Erfolg ohne Versand:** Register meldet zuerst ab; resendVerificationEmail verwendet danach nur currentUser und ignoriert die Email. Bei null passiert nichts; Dialog setzt dennoch _resent=true. | [Register](lib/ui/auth/register_screen.dart#L68), 68-84, 649-663; [AuthService](lib/logic/auth_service.dart#L694), 694-705 | Echter autorisierter Resend mit Ergebnis, Cooldown/Fehleranzeige; kein unautorisierter Admin-Versand und keine gespeicherten Passwoerter als Shortcut. |
| W07 / P1 | **Onboarding-Abschluss zu frueh / kein persistenter Entwurf:** completed wird als erster Write gesetzt, bevor Stammdaten/Region/Standort/Order fertig sind; keine Save-Acknowledgement-Pruefung. Controllerdaten leben nur in RAM. Prozessabbruch/Writefehler kann "abgeschlossen" mit Teilzustand ergeben; frueher Abbruch verliert Eingaben. | [Onboarding](lib/ui/onboarding/onboarding_screen.dart#L151), 151-213 | Entwurf/Abbruchdefinition und atomarer Abschluss; mehrfaches Finish/mounted/accountwechsel pruefen. Keine Geburtsdatumsberechnung in diesem Wizard zu reparieren. |
| W08 / P1 | **Logout deckt Notifications nicht voll ab:** Unregister existiert best-effort, aber onTokenRefresh-Listener wird einmal mit erster userId angelegt; spaetere initFcm ersetzt diese Closure nicht. Ein Refresh kann nach A-Logout/B-Login wieder A registrieren: /devices/register-token uebernimmt body-userId ohne Abgleich mit firebaseUid. Geplante lokale Erinnerungen werden beim Logout nicht gecancelt. | [Notifications](lib/logic/notification_service.dart#L116), 116-169, 227-262; [Logout](lib/logic/auth_service.dart#L661), 661-690; [Tokenroute](backend/server.js#L11277), 11277-11318 | Dynamische Accountbindung/Listenerteardown plus Backend-Ownerpruefung, synthetischer Refresh nach Wechsel, Notification-Owner/Cancel-/Sperrbildschirmvertrag. **Security MEDIUM**, 9/10. Kein Live-Push getestet. |
| W09 / P0-P1 | **Rechtstexte existieren, sind aber nicht aktuelle Faktenfreigabe:** Privacy Juli 2026 behauptet lokale Kalender/Listen und ausschliesslich lokale Kinderprofile; aktueller Backendkalender und optionales Memory speichern Daten extern. Infobogen sagt pauschal keine externe Chatverlaufsspeicherung, ohne gespeicherte Memory-Zusammenfassungen zu erklaeren. "DSGVO-konform" und "EU AI Act" sind keine Compliance-Nachweise. | [Privacy](web/privacy/index.html#L88), 88-178; [Infobogen](lib/ui/profile_safety_screen.dart#L1197), 1197-1290; [Legaltiles](lib/ui/profile_safety_screen.dart#L700), 700-725 | Datenflussmatrix #166 gegen Privacy/Terms/Store/AI-Disclosure abgleichen; Memory ist nicht automatisch Vollchatverlauf, Unterschied ehrlich benennen. Keine Rechtsberatung. URL-Erreichbarkeit im Livebuild nicht hier geprueft. |
| W10 / P1 | **Fehler-/Recht-/Profiltexte weiterhin DE oder Rohkeys:** AuthService liefert deutsche Fehlermeldungen direkt; Avatar, Kindalter, Logout/AI-Bogen und Google/Apple-Labels teils hartcodiert. _profileCopy uebersetzt nur en/tr/ku, faellt fuer weitere Sprachen auf DE. Fehlende Standortkeys K04. | [Auth-Mapping](lib/logic/auth_service.dart#L1028), [Profil](lib/ui/profile_safety_screen.dart#L117), [Login](lib/ui/auth/login_screen.dart#L658), [Onboarding](lib/ui/onboarding/onboarding_screen.dart#L376) | Errorcodes lokal rendern; alle benutzten Keys gegen de/en/tr/ku samt Platzhaltern pruefen. Katalog-Keygleichheit allein findet fehlende Aufruferkeys nicht. |
| W11 / P1 | **Reset bestaetigt nicht Zustellung:** Backend antwortet absichtlich anti-enumeration 200 vor Mailgeneration/-Versand. sendEmail=false kann ohne expliziten Zustellfehler bleiben; Client startet bei 200 keinen Firebasefallback. | [Resetroute](backend/server.js#L11506), 11506-11542; [Client](lib/logic/auth_service.dart#L594), 594-617 | Generische Anforderungsbestaetigung beibehalten, Zustellfehler intern beobachten/retry; keine Kontoexistenz an Client leaken. Produktions-Mailzustellung nicht getestet. |
| W12 / P1 | **Testluecken in Kernflows:** vorhandener Login-Erfolgstest skipped; falsches Passwort mockt nur Result. Onboardingtests schreiben selbst Keys statt Wizard zu bedienen. Logouttest prueft FCM, nicht Profil-/Onboarding-/Export-/Google-Reauth. | [Login-Tests](test/tests/login_test.dart#L36), [Onboardingtest](test/onboarding_test.dart), [Logouttest](test/auth_service_logout_test.dart), [Avatartest](test/avatar_render_test.dart) | Emulator/Mocks fuer Auth/Owner/Loeschteilfehler + echte Geraete. Securitytest nur Rule-Substringpruefung, kein Berechtigungsnachweis. |
| W13 / P1 | **Credential-aehnliche Literale in skipped Login-Test:** reale wirkende Mail/Passwortkombination im Repo; Livegueltigkeit unbekannt. Securitytest scannt nur integration_test und erfasst diese Stelle unter test/tests nicht. | [Login-Test](test/tests/login_test.dart#L47), [Securitytest](test/security_test.dart#L40) | Werte nicht wiedergeben/benutzen. Verantwortlicher bestaetigt synthetisch oder rotiert falls real; synthetische Fixtures/Envsecrets und kompletter Scan in spaeterer PR. Kein Livecredential behauptet. |

### 4.4 Nice-to-have / klar getrennte Qualitaet

- **N01:** Gesten fuer Registerwechsel, Sprache und Profilaktionen haben
  teils kein `HitTestBehavior.opaque`; nicht automatisch jeder Tap kaputt,
  aber Vorgabe und vergroesserte Trefferflaechen nicht einheitlich.
  [Login](lib/ui/auth/login_screen.dart#L756),
  [Register](lib/ui/auth/register_screen.dart#L242),
  [Onboarding](lib/ui/onboarding/onboarding_screen.dart#L482),
  [Profil](lib/ui/profile_safety_screen.dart#L418).
  Opaque ersetzt nicht Semantics/Keyboard-Fokus.
- **N02:** Kindalter ist freier Text, `name|age` wird ohne Delimiterescaping
  gespeichert; Name mit `|` kann Darstellung verfaelschen. Keine konsistente
  Umbenenn-/Entfernen-/Geburtsdatumsverwaltung in diesem Profilformular.
  [Profil](lib/ui/profile_safety_screen.dart#L201), 201-295.
  Datenmodell/UX erst nach K02 entscheiden, nicht drei Kindstores blind vereinen.
- **N03:** AuthService-Kommentar behauptet lokale "Firebase-ready"-Architektur,
  aktueller Release nutzt bereits Firebase. APIClient und AuthService importieren
  dart:io; Platform.isMacOS ist aber durch !kIsWeb kurzgeschlossen.
  Deshalb **kein belegter Webcrash allein aus Import**; plattformneutrale
  Struktur/Kommentarbereinigung als spaeterer Qualitaetspunkt.
  [AuthService](lib/logic/auth_service.dart#L1), [APIClient](lib/logic/backend_api_client.dart#L1).
- **N04:** Crash-Hooks melden Flutterfehler doppelt (recordFlutterError und
  _reportAppError); genaue PII-Analyse bleibt eigener Auditbereich.
  [main](lib/main.dart#L82), [ErrorReportingService](lib/logic/error_reporting_service.dart).
  Nicht mit erfundenem konkretem Crashlytics-Leak vermengen.

### 4.5 Sechs Achsen - Abschluss der ersten Analyse

| Achse | Ergebnis |
|---|---|
| Datenschutz | Owner-Envelopes schuetzen Kacheln, globaler Export/Profil/Onboarding/GPS umgehen Teilgrenzen; Rechts-/Memorytexte nicht aktuell belegt. K01-K04, W05/W08/W09. |
| Korrektheit | Resend-No-op, Mobile-Google, Reauth-/Delete-Teilzustand, frueher Onboardingabschluss; Passwortregeln und #111-Alter bestehen. W01-W07. |
| i18n | UI oft context.tr, Serviceerrors/Profiltexte teils DE, zwei relevante Datenschutzkeys fehlen komplett. W10/K04. |
| Web | Kein belegter Platform-Zugriff auf Web; Popup vorhanden, Redirectresult gelesen, Redirectfallback fehlt; Persistenz/Tokenretry vorhanden, Restore/AuthGate unvollstaendig getestet. W01/W02. |
| Qualitaet / Accessibility | Formcontroller im Hauptflow disposed; einige Dialogcontroller/mounted-Fehlerpfade, Gesten/Labels/Skalierung noch gesondert abnehmen. Kein gemessener Kontrast-/Screenreader-Pass. |
| Tests | Gute Scopeguards/Storetests im alten Audit; keine vollstaendige Auth-/Onboarding-/Profil-/DSGVO-Regressionssuite. W12, 2.1. |

## 5. Entscheidungspunkte und weitere Arbeit

**Kein Befund ist bereits ein Fixauftrag.** Empfohlene erste Entscheidungen:

1. K01 Export: eigener Account plus welche ausdruecklich geraetebezogenen
   Einstellungen; kein Dump anderer Accounts/Legacydaten.
2. K02: Profil-/Onboarding-Owner und Legacy-Entwurfregel analog #124/#130;
   zu entscheiden, welche Einstellungen bewusst geraeteweit bleiben.
3. K03: private Ownerauth vor Client/Serverkompatibilitaet; bewusst
   oeffentliche Namens-/Avataransichten gesondert spezifizieren.
4. K04: rundungsbasierte externe Geocodierung mit transparenter Info,
   alle LocationService-Verbraucher und Ausweichpfade konsistent.
5. W03/W04: providerpassende Reauth vor destruktiver Loeschung,
   vollstaendiger serverseitiger Erfolgsvertrag und nachvollziehbare Teilfehler.

Danach weitere Berichte/Fixes nur einzeln freigeben. Bereits gemergte
Kontoschutz-Fixes nicht zurueckbauen. Keine Migration/Produktionsloeschung,
kein Test mit echten Kinddaten, keine Google-/Mail-/Zahlungsaktion allein
aus diesem Dokument. Rechts-/Store-, physische QA und Betriebsfreigabe
verbleiben beim Nutzer/externen Verantwortlichen.

## 6. Nachweis dieses Doku-Auftrags

- Basis-/Dateien-/Tests-/Commitgeschichte read-only untersucht.
- Backend-Autorisierung nur fuer direkt beteiligte Account/Profile/Onboarding/
  Authpfade traced; keine vollstaendige API-/Firebase-/Cloudkonfigfreigabe.
- Keine neuen Produktcode-/Dependency-/Rule-/Configaenderungen.
- Keine Live-Integrationstests aus dem [Integration-Guide](docs/INTEGRATION_TEST_GUIDE.md)
  ausgefuehrt: diese koennen Datensaetze schreiben und sind nicht read-only.
- Dokupruefungen und PR-CI werden im PR mit exaktem Ergebnis dokumentiert.
- `AUDIT_PLAN.md` und nutzerveraenderte `.gitignore` nicht gestaged.
