# Werbe-Consent-Modell — Design (Phase A)

**Stand:** Analyse von `feat/ads-consent-model` auf `origin/main` bei `0c6e5a590a647a10de5a368435dd803a03e9621f`
**Status:** Design zur Prüfung; keine Implementierungsfreigabe
**Scope:** Versionierte, freiwillige Einwilligung und jederzeit erreichbare Verwaltung bzw. Widerruf. Keine Ad-Slots, Ad-SDK-Aufrufe, Paywall oder Aktivierung von Werbung/Monetarisierung.

## 1. Bestehendes Consent-Muster

### `AccountAiConsent` und Consent-Dialog

- [`lib/logic/account_ai_consent.dart:11-134`](../lib/logic/account_ai_consent.dart) ist der gemeinsame Client-Baustein. Der Scope wird aus der UID gebildet; ohne angemeldeten User verwendet der bestehende Helfer jedoch den Fallback `guest` (`:52-58`). Ein Ads-Consent muss deshalb zusätzlich eine angemeldete, verifizierte Identität verlangen und darf nie an den Guest-Scope gebunden werden. `hasConsent()` akzeptiert nur den gespeicherten positiven Wert für genau den aktuellen Scope (`:64-69`).
- Der Schlüssel enthält den fachlichen Prefix und den Account-Scope (`:58`). Bestehende Scopes wie `weekly_reflection.ai_consent.v1` und `chat.ai_consent.v1` zeigen die Versionierung im Schlüssel (`lib/logic/weekly_reflection_ai_service.dart:14-18`, `lib/logic/chat_ai_consent.dart:3-7`). Ein fehlender Schlüssel ist keine Zustimmung.
- `grant()` und `revoke()` werden serialisiert (`:30-49`). `block()` erhöht zuerst die In-Memory-Revision und sperrt den Account unmittelbar; danach persistiert `revoke()` den negativen Zustand (`:103-130`). Scope- und Revisionsprüfungen verhindern, dass ein Accountwechsel oder ein paralleler Widerruf eine bereits gestartete Operation weiter autorisiert (`:72-101,132-136`).
- [`lib/ui/widgets/account_ai_consent_dialog.dart:6-55`](../lib/ui/widgets/account_ai_consent_dialog.dart) bietet eine zustimmungsfreie Voreinstellung: Abbrechen oder Schließen speichert keine Zustimmung; erst die explizite positive Aktion ruft `grant()` auf. Die lokalen UI-Strings werden über `context.tr()` bezogen.
- [`lib/ui/wochenrueckblick_screen.dart:441-454,939-944`](../lib/ui/wochenrueckblick_screen.dart) zeigt ein konkretes Widerrufsmuster. Der Dialog selbst und die zugehörigen Aktionen sind in [`test/weekly_reflection_consent_test.dart:615-677`](../test/weekly_reflection_consent_test.dart) bereits für alle acht Launch-Sprachen und Dialog-RTL geprüft.

Das übernehmbare Muster ist: ein eigener, versionierter Scope, account-bound identity guards, kein implizites Opt-in, explizite Ablehnung, Revision-/Race-Schutz, lokalisierter Dialog und ein einfach erreichbarer Widerruf. Die heutige `AccountAiConsent`-Persistenz liegt allerdings in `SharedPreferences`; sie synchronisiert daher weder Kontostatus noch Widerruf automatisch zwischen Geräten. Außerdem speichert sie keine belastbare serverseitige Entscheidungszeit.

### Server-seitiges Vergleichsmuster

- [`backend/prisma/schema.prisma:586-593`](../backend/prisma/schema.prisma) hält für `AiMemorySettings` den aktuellen Zustand, die Consent-Version und eine Revision pro User.
- Die owner-gebundenen Settings-Routen in [`backend/server.js:4351-4383`](../backend/server.js) prüfen Version und Status bei jeder geschützten KI-Aktion, aktualisieren den Datensatz beim Ein-/Ausschalten und erzeugen bei jeder Änderung eine neue Revision.
- [`backend/ai_memory_policy.js:1-5`](../backend/ai_memory_policy.js) behandelt Einwilligung nur dann als gültig, wenn enabled, Version und Revision zusammenpassen.

## 2. Rechtliches-Menü und Verwaltungs-Einstieg

- Der dauerhaft sichtbare Abschnitt **„Rechtliches"** in [`lib/ui/profile_safety_screen.dart:776-865`](../lib/ui/profile_safety_screen.dart) enthält bereits Datenschutz, Nutzungsbedingungen, Impressum, KI-Nutzungshinweis, Datenexport, Open-Source-Lizenzen, blockierte Kontakte und Kontakt/Support. Die Kontolöschung liegt separat im Account-Bereich (`:880-892`).
- Empfehlung: Einen eigenen, gleichrangigen Eintrag **„Werbe- und Sponsor-Einwilligung"** direkt im bestehenden Rechtliches-Abschnitt ergänzen, in der Nähe des Datenschutz-Eintrags. Der Eintrag öffnet eine Consent-Verwaltung, in der Status und Version verständlich angezeigt und Zustimmung bzw. Ablehnung jederzeit geändert werden können. Widerruf ist dort direkt erreichbar, nicht in einem Werbe-Untermenü versteckt.
- [`lib/ui/legal_info_screen.dart:6-20,192-260`](../lib/ui/legal_info_screen.dart) ist eine ergänzende Legal-Info-/Compliance-Seite mit Datenschutz-/AGB-Links und Support; sie ist nicht der primäre Einstellungsort. Eine zweite, abweichende Consent-Bedienung dort sollte vermieden werden.
- [`lib/ui/privacy_settings_screen.dart:3-165`](../lib/ui/privacy_settings_screen.dart) verwaltet derzeit den Familienprofil-Privatsphäre-Modus und hängt an der Familienprofil-Navigation ([`lib/ui/family_profile_screen.dart:1315-1328`](../lib/ui/family_profile_screen.dart)). Dieser Modus ist keine Werbeeinwilligung und sollte nicht mit ihr vermischt werden.

## 3. Vorgeschlagenes Consent-Verhalten

- Eigener Scope und explizite Version, z. B. `ads.consent.v1`. Die Version gehört in den gespeicherten Status und wird bei jeder zukünftigen Änderung der Zwecke oder Datenflüsse erhöht; eine alte Version gilt dann nicht automatisch als Zustimmung zur neuen Verarbeitung.
- Zustand kennt mindestens **unbekannt/keine Entscheidung**, **abgelehnt** und **erteilt**. Standard ist unbekannt bzw. abgelehnt für die Verarbeitung: keine vorausgewählte Checkbox, keine Zustimmung durch Weiterbenutzung und keine automatische Übernahme früherer KI-Einwilligungen.
- Die UI bietet „Ablehnen" und „Zustimmen" gleichwertig und gleich sichtbar an. Schließen/Zurück ist ebenfalls keine Zustimmung. Die Einwilligung ist freiwillig und kann ohne Nachteil für die übrige App widerrufen werden.
- Ein Widerruf blockiert die lokale Werbeverarbeitung sofort, erhöht die Revision und persistiert den negativen Status. Laufende, noch nicht gesendete Ad-/Sponsor-Aufrufe werden abgebrochen. Bereits an einen Anbieter übertragene Daten kann ein Widerruf nicht rückwirkend zurückholen; dies muss transparent erklärt werden.
- Vor erteilter, aktueller Zustimmung darf es keinen Request mit Daten geben, der der Werbeauslieferung oder Sponsor-Messung dient. Eine authentifizierte Anfrage, die ausschließlich die Consent-Einstellung liest oder die ausdrückliche Auswahl speichert, ist davon zu unterscheiden und darf keine Event-, Standort-, Kinder-, Profil- oder KI-Daten enthalten.

## 4. Verhältnis zum B1-Entitlement

Consent ist eine eigenständige Verarbeitungserlaubnis und verändert weder Abo-Tier noch Entitlement-Snapshot. Eine spätere Anzeige darf konzeptionell nur versucht werden, wenn **alle** Bedingungen gelten:

```text
Monetarisierung/Ad-Flag ausdrücklich aktiviert
AND Entitlement state == verified
AND Entitlement tier == free
AND gültiger Consent für ads.consent.v1 == erteilt
AND Platzierung liegt in der öffentlichen Event-Entdeckung
```

Premium, aktive bestätigte Probe-/Kulanzzeiträume, fehlender/abgelehnter/abgelaufener Consent, `loading`, `unavailable`, Netzwerk-/Serverfehler oder unbekannte Werte bedeuten **keine Ads und keinen Werbe-Request**. Das ist unabhängig davon, dass B1 `adsEligibleByEntitlement` derzeit immer `false` liefert (`backend/entitlement_store.js:31-52`; Client-Facade [`lib/logic/entitlement_service.dart:34-40,102-110`](../lib/logic/entitlement_service.dart)). In einem späteren Schritt müssen Consent und Entitlement separat geprüft werden; keines darf das andere ersetzen.

## 5. Speicherungsempfehlung und offene Rechtsfragen

**Empfehlung für die Prüfung:** Serverseitiger, authentifizierter aktueller Consent-Snapshot pro User, mit lokalem sofortigem Sperren während des Widerrufs. Anders als bei einem rein lokalen `AccountAiConsent` gilt damit eine Ablehnung/ein Widerruf kontoweit und kann nach erfolgreicher Synchronisierung auf weiteren Geräten durchgesetzt werden. Bei Offline-/Token-/Serverfehlern ist die lokale Sperre geschlossen; eine positive Offline-Cache-Kopie darf keine Werbung freigeben.

Als eng begrenztes Modell kommen ein `AdsConsent`-Snapshot mit `userId`-FK/Cascade, `decision`, `consentVersion`, `consentRevision`, `consentedAt` (nullable), `withdrawnAt` (nullable) sowie `createdAt`/`updatedAt` in Betracht. Kein Ereignisprotokoll oder Geräte-Fingerprinting ohne gesonderte Notwendigkeit. Ein fehlender Datensatz bedeutet keine Einwilligung. Endpunkte verwenden ausschließlich die verifizierte Account-Identität, verlangen bei Erteilung die aktuelle Version und liefern keinen Werbe- oder Profildatensatz zurück. B1s Export-/Löschpfad in [`backend/server.js:7210-7390,7400-7505`](../backend/server.js) müsste die verständlichen Consent-Metadaten exportieren und den Datensatz bei Kontolöschung löschen; eine FK-Cascade allein ersetzt die explizite Exportprüfung nicht.

**Vor Umsetzung ausdrücklich zu bestätigen:** Rechtsgrundlage und genaue Zwecke der Sponsorverarbeitung; welche minimale Consent-Evidenz (Status, Version, Zeitpunkte/Revision) und Aufbewahrungsdauer benötigt werden; ob ein aktueller Snapshot ohne Historie ausreicht; und wie eine Kontolöschung mit einer eventuell erforderlichen Nachweisaufbewahrung vereinbar ist. Diese Empfehlung ist eine Architekturentscheidung, keine Rechtsfreigabe.

Geplante Platzierungen bleiben gemäß [`docs/MONETIZATION_ADS_PLAN.md:15-17,42,49-52,80-81`](./MONETIZATION_ADS_PLAN.md) manuell geprüfte, kontextuelle, nicht personalisierte Sponsor-Platzierungen ausschließlich in der öffentlichen Event-Entdeckung. Keine Tracking- oder Werbe-ID, keine personalisierten Ads, keine Kinderdaten/Geburtsdaten und keine KI-Inhalte in Consent- oder späteren Werbe-Payloads. Exaktes Geburtsdatum bleibt im eigenen Backend; Gemini erhält weiterhin nur das abgeschlossene Alter. Store-/Rechtsprüfung ist vor Livegang erforderlich; dieses Design schaltet keine Verarbeitung frei.

## 6. Lokalisierung und RTL

Alle neuen sichtbaren Texte für Dialog, Status, Ablehnung, Zustimmung, Fehler und Widerruf werden in `lib/l10n/app_localizations_all.dart` über das bestehende `AppStringsManager`-/`context.tr()`-Muster gepflegt. Die acht Launch-Sprachen sind `de`, `en`, `tr`, `ku`, `fr`, `es`, `it`, `ar` ([`lib/l10n/supported_languages.dart:28-112,141-159`](../lib/l10n/supported_languages.dart)); Arabisch muss mit RTL-Layout und langen/vergrößerten Texten geprüft werden. Als Testmuster dienen [`test/weekly_reflection_consent_test.dart:615-677`](../test/weekly_reflection_consent_test.dart): pro Sprache nicht-leere, nicht englisch-identische Texte und Widget-Tests auf kleinem Viewport, vergrößerte Textskalierung und RTL.

## 7. Verifiziert / vorgeschlagen / offen

### Verifiziert

- Client-Consent ist in `AccountAiConsent` nach angemeldetem Account gescoped, standardmäßig nicht erteilt, widerrufbar und gegen asynchrone Accountwechsel/Races geschützt.
- Der bestehende Legal-Bereich bietet einen direkten, stabilen Ort für eine gleichrangige Verwaltungskachel.
- Für KI-Memory existiert bereits ein serverseitiges Muster mit Version, Revision, owner-gebundenen Endpunkten und fail-closed Policy.
- B1 liefert eine explizite, getrennte Entitlement-State-/Tier-Schnittstelle und erzwingt derzeit `adsEligibleByEntitlement: false`.

### Vorgeschlagen, noch nicht implementiert

- Server-seitiger Consent-Snapshot zur geräteübergreifenden Durchsetzung; Client blockiert während Änderungen sofort lokal.
- `ads.consent.v1`, fehlender/alter/unbekannter Status = keine Zustimmung; Ablehnen und Zustimmen gleichrangig; direkter Verwaltungs-/Widerrufseintrag in „Rechtliches".
- Werbeverarbeitung nur bei Flag an, verifiziert Free, aktueller Consent und öffentlicher Event-Entdeckung. In dieser Phase bleibt das Flag aus.

### Vor Phase B zu bestätigen

- Rechtsgrundlage, Zweck-/Hinweistexte, erforderliche Aufbewahrung und ob ein aktueller Snapshot als Consent-Nachweis ausreicht.
- Serverseitige Speicherung und geräteübergreifender Widerruf als gewünschte Produktentscheidung.

**In Phase A wurde nur dieses Design-Dokument erstellt. Es wurden keine Codeänderungen, Builds oder Tests ausgeführt.**
