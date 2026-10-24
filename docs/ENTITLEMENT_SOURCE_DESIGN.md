# Entitlement-Quelle der Wahrheit — Design (Phase A)

**Stand:** Analyse des Branches `feat/entitlement-source-of-truth` auf `7ccdada6d6e2aea331e9e549ff268daca21ee0dc`
**Status:** Vorschlag zur Prüfung; keine Implementierungsfreigabe
**Scope der folgenden PR:** Eine persistente, serverseitig verifizierte Quelle für Free/Premium und das Abo-Entitlement. Kein Consent, keine Ad-Integration, keine Paywall-UI und keine Aktivierung von Werbung oder Monetarisierung.

## 1. Client-Ist-Zustand

### `EntitlementService`

- [`lib/logic/entitlement_service.dart:20-57`](../lib/logic/entitlement_service.dart) hält einen eigenen `SubscriptionTier` (aus `lib/config/feature_flags.dart:28-31`) und startet mit `free`.
- `initialize()` ruft `_refreshTierFromAuth()` auf (`:43-46`). Ohne angemeldeten Nutzer wird `free` gesetzt; andernfalls wird `premium` gesetzt, wenn `ParentUser.isPremium` **oder** `ParentUser.hasFullAccess` true ist (`:50-59`).
- `hasFullAccess` bedeutet nicht zwingend ein bezahltes Premium-Abo: [`lib/logic/auth_service.dart:108-119`](../lib/logic/auth_service.dart) gewährt es auch aufgrund des Beta-Schalters bzw. eines lokal berechneten Probezeitraums. Das Vermischen von „voller Zugriff“ und „bezahltes Premium“ lässt UI-Zugang und Werbe-Entitlement nicht zuverlässig unterscheiden.
- Der Service wird beim App-Start initialisiert (`lib/main.dart:151-158`) und vom Home-Bereich für Feature-Zugriff abgefragt (`lib/ui/home_screen.dart:389,925-934`). Eine Repository-Suche fand keinen Aufruf von `EntitlementService.refreshEntitlements()` außerhalb seiner eigenen Klasse; Auth-Refreshes synchronisieren den Service daher nicht sichtbar.
- Er enthält außerdem lokale Usage-Zähler und Limits (`:25-27,113-181`). Insbesondere die 3 KI-Fragen/Tag sind laut [Monetarisierungsplan](./MONETIZATION_ADS_PLAN.md) noch nicht als Produktregel bestätigt und dürfen in dieser PR nicht geändert werden.

### `PremiumService`

- [`lib/services/premium_service.dart:19-82`](../lib/services/premium_service.dart) ist eine zweite, unabhängige Tier-Quelle mit eigenem `PremiumTier` (`free`, `premium`, `provider`; `:6-10`).
- Er startet lokal mit `free`, liest dann `premium.tier`, `premium.expires_at` und `premium.promo_code` aus `SharedPreferences` (`:23-33,83-98`). Bei `MonetizationConfig.enabled == false` meldet `isPremium` jedoch für jeden Aufrufer `true` (`:35-48`), unabhängig von Authentifizierung oder Backend.
- Ist der Monetarisierungsschalter an, leitet er Premium ausschließlich aus lokalem Tier/Ablauf ab. `activatePremium()` schreibt lokal einen Tier und ein Ablaufdatum (`:102-110`); `redeemPromoCode()` akzeptiert hardcodierte Promo-Codes im Client (`:113-159`).
- Er steuert `shouldShowAds` sowie Events-, KI- und Rezept-Limits anhand eigener Flags und des lokalen `isPremium` (`:59-79`). Aufrufer sind u. a. `EventsLimitService` (`lib/services/events_limit_service.dart:36`), `DevelopmentReportLimitService` (`lib/services/development_report_limit_service.dart:36-37`), `PremiumGate` (`lib/ui/widgets/premium_gate.dart:30,313`), `AntragshelferScreen` (`lib/ui/antragshelfer_screen.dart:162,441,632`), Impulse-Screen (`lib/ui/entwicklung_impulse_screen.dart:1918,1938`) und der vorhandene Ad-Platzhalter (`lib/ui/widgets/native_ad_slot.dart:22,34`). Der Ad-Platzhalter bleibt in diesem Schritt unberührt und Werbung bleibt aus.
- `ProviderPackageService` liest weiterhin ein lokales Provider-Flag und fragt `PremiumService.isProvider` ab (`lib/services/provider_package_service.dart:41-73`). Der Anbieter-Tarif ist laut Produktentscheidung abgeschafft. Dieser Altpfad ist kein Bestandteil des neuen Free/Premium-Entitlement und darf ihn nicht wieder einführen; seine separate Bereinigung ist nicht Teil der hier beschriebenen Entitlement-Quelle.

### Widersprüche und Synchronisierung

1. Ohne Login kann `EntitlementService` `free` melden, während `PremiumService` bei derzeit deaktivierter Monetarisierung `isPremium == true` meldet.
2. Ein aktiver Beta-/Trial-Zugang wird durch `EntitlementService` als `premium` klassifiziert, obwohl der Serverstatus `isPremium == false` und lediglich `hasFullAccess == true` liefern kann.
3. Nach einer Serverantwort kann `AuthService.refreshEntitlements()` ein früher gespeichertes Premium nicht zurücknehmen: `isPremium: current.isPremium || serverPremium` (`lib/logic/auth_service.dart:1020-1033`). Bei Ablauf oder Widerruf kann so ein persistiertes Client-Flag weiter Premium melden.
4. `AuthService.refreshEntitlements()` aktualisiert `ParentUser`, ruft aber nicht den zweiten Tier-Service zum Refresh auf. Nach einem Auth-/Abo-Wechsel können Home-Feature-Gates und `PremiumService` unterschiedliche oder veraltete Zustände sehen.
5. Zwei Client-Typen, lokaler Speicher, Auth-Profil und serverseitige Vollzugriffs-/Trial-Werte sind mehrere konkurrierende Quellen. Keiner der Client-Caches eignet sich als Berechtigungsnachweis.

## 2. Backend-Ist-Zustand

- Die Statusroute [`backend/server.js:7697-7713`](../backend/server.js) verlangt inzwischen `requireVerifiedUser`. Diese Middleware validiert den Firebase-ID-Token und bindet Aktionen an `req.firebaseUid` (`:3878-3899`); der Pfad-User muss zum Token-User passen.
- Der aktuelle Client sendet beim Status-GET **kein** `isPremium` mehr; `AuthService.refreshEntitlements()` sendet nur `registeredAt` (`lib/logic/auth_service.dart:999-1023`). Der Route-Kommentar hält ausdrücklich fest, dass ein früherer `isPremium`-Query-Hinweis ignoriert wird (`server.js:7703-7712`).
- Das ist eine sinnvolle Auth-/Owner-Verbesserung, aber noch kein Store-Nachweis: `ensureEntitlement()` (`server.js:6974-7003`) speichert den Datensatz in `const userEntitlements = new Map()` (`:6078`), nicht in Prisma. Neustart/mehrere Render-Instanzen können diesen Status verlieren bzw. voneinander abweichen.
- `registeredAt` kommt für die Trial-Berechnung weiterhin aus dem Client-Query und wird durch `ensureEntitlement()` in den In-Memory-Datensatz übernommen. `buildEntitlementStatus()` berechnet Trial-Zugang aus diesem Datum und `BETA_FREE_ACCESS`, dessen Default derzeit aktiv ist (`server.js:7006-7030`). Das ist nicht gleichbedeutend mit einem vom App Store oder Google Play verifizierten Test-Abo.
- Die Aktivierungsroute ist ebenfalls authentifiziert und owner-gebunden (`server.js:7715-7722`), weist Selbstaktivierung aber standardmäßig zurück. Wenn `ALLOW_SELF_SERVICE_PREMIUM=1` gesetzt ist, setzt die Route trotzdem `isPremium: true` über einen Request ohne Store-Beleg und schreibt das Ergebnis in dieselbe In-Memory-Map (`:7724-7739`). `AuthService.activatePremium()` sendet ebenfalls keinen Store-Receipt bzw. keine signierte Transaktion (`lib/logic/auth_service.dart:936-995`). Ein Konfigurationsschalter ist daher keine Zahlungsprüfung.
- Prisma hat in `User` zwar `trialExpiresAt`, `isPremium` und `premiumExpiresAt` (`backend/prisma/schema.prisma:16-36`), die Entitlement-Routen lesen/schreiben diese Felder aber nicht. Der vorhandene `PaymentTransaction` ist an ein Event gebunden und benötigt `eventId` sowie eine Stripe-Payment-Intent-ID (`schema.prisma:379-416`); er bildet kein App-Store-/Play-Abo ab. Backend-Abhängigkeiten enthalten Stripe, aber in `pubspec.yaml`/`backend/package.json` wurde keine Apple-/Google-Subscription- oder Receipt-Validierungsbibliothek gefunden.
- Der Datenexport nimmt die drei alten User-Felder explizit auf (`server.js:7465-7505`). Kontolöschung löscht den User in Prisma (`:7455`), entfernt zusätzlich die In-Memory-Entitlement-Daten (`:7107`) und wird über `/account/delete-data` ausgelöst (`:7633-7674`). Eine neue Tabelle muss in beide Abläufe konsistent aufgenommen werden.

**Kurz:** Der GET-Endpunkt ist authentifiziert, und der frühere Client-Flag-Hinweis wird nicht mehr angenommen. Der Berechtigungsnachweis ist dennoch nicht persistent, nicht aus Store-Transaktionen abgeleitet und nicht über Render-Instanzen konsistent. Die Authentifizierung des Requesters allein beweist keinen Kauf.

## 3. Bestehende Limits, die unverändert bleiben müssen

- Bestätigtes Eventlimit: [`lib/config/monetization_config.dart:49`](../lib/config/monetization_config.dart) setzt `freeEventsPerWeek = 3`.
- [`lib/services/events_limit_service.dart:12-27,36-73,78-98`](../lib/services/events_limit_service.dart) zählt lokale Event-Detailansichten in `SharedPreferences`, setzt die Woche am Montag zurück und verwendet `PremiumService.shouldLimitEvents` als Tier-Gate. Der Aufrufer `lib/ui/events_activities_screen.dart:1874-1898` prüft das Limit und registriert eine Detailansicht. Es gibt im untersuchten Flow keine serverseitige Ereigniszählung.
- **Nicht ändern:** Zählpunkt, Wochenbeginn/Reset, lokaler Counter, Grenzwert 3, Event-Erstellungs-/Veröffentlichungsfluss oder Limit-Flag. Bestehendes Verhalten durch gezielte Regressionstests absichern.
- Die Tarifkartenformulierung darf später in einer separaten freigegebenen Änderung an „3 Event-Detailansichten pro Woche“ angepasst werden; die Zähllogik bleibt davon unberührt.
- Die im Plan als **noch zu bestätigen** markierten Free-Zusatzlimits (KI 3/Tag, Netzwerk 3/Monat, 1 Rezept/Tag) sind keine bestätigten Produktvorgaben und bleiben außerhalb dieser PR unverändert. Insbesondere `EntitlementService` enthält bereits eine lokale KI-3/Tag-Konstante (`entitlement_service.dart:25-27,147-176`), die dadurch nicht automatisch freigegeben wird.

## 4. Zielentwurf zur Prüfung

### Eine Client-Schnittstelle

Die App bekommt nach Freigabe genau einen zentralen Client-Entitlement-Facade (vorzugsweise bestehender `EntitlementService`, nach Anpassung; `PremiumService` wird anschließend nur noch delegieren oder als Teil der Migration entfernt). Kein Screen entscheidet selbst aus SharedPreferences, `ParentUser.isPremium`, Promo-Code oder einer Query-Antwort über Premium.

Vorgeschlagener Snapshot:

```text
EntitlementSnapshot
  state: loading | verified | unavailable
  tier: free | premium       // nur bei state == verified
  access: none | trial | active | grace | expired
  validFrom: UTC timestamp?
  validUntil: UTC timestamp?
  verifiedAt: UTC timestamp?
  adsEligibleByEntitlement: bool
```

- Beim Start, Accountwechsel, Rückkehr in die App und erfolgreicher Kaufwiederherstellung wird der Snapshot über den authentifizierten Backend-Client geladen. Client sendet keine `isPremium`-Behauptung. Eine Kauf-Transaktion könnte später als Prüfbeleg an einen separaten Verifikationspfad gesendet werden; sie ist selbst keine Autorität.
- `state == unavailable` bleibt bei Netzwerk-/Server-/Tokenfehlern sichtbar und darf nicht aus alten lokalen Daten zu `verified free` oder `verified premium` umgedeutet werden. Kein success-shaped Fallback. `adsEligibleByEntitlement` ist bei `loading`/`unavailable` immer `false`; Premium-Funktionen werden bei unbekanntem Status nicht freigeschaltet und die UI kann eine erneute Prüfung anbieten, ohne den Nutzer fälschlich als Free oder Premium auszugeben.
- `tier == free` darf nur aus einer erfolgreichen Backend-Abfrage stammen, die eine vollständige Datenbankabfrage ohne aktives, verifiziertes Entitlement abgeschlossen hat. `tier == premium` darf nur aus einem gültigen serverseitig verifizierten Store-Status stammen.
- Aktiver Store-Testzeitraum bzw. verifizierter Grace-Zeitraum gilt als Premium/werbefrei gemäß Produktentscheidung. Ein beta-/allgemeiner Zugang zu Funktionen ist separat als `access`/Beta-Override auszuweisen und darf nicht zum gekauften Premium-Tier umetikettiert werden.
- `adsEligibleByEntitlement` beschreibt ausschließlich die Abo-Seite (verifiziertes Free ohne werbefreies Entitlement und nur wenn der serverseitige, standardmäßig ausgeschaltete Ads-Eligibility-Schalter freigegeben ist). Es aktiviert keine Werbung. Eine tatsächliche Anzeige erfordert zusätzlich ein späteres, separat freizugebendes Ad-/Consent-System; beides ist ausdrücklich nicht Bestandteil dieser PR.

### Authentifizierter Backend-Vertrag

Empfehlung: einen nutzergebundenen `GET /entitlements/me` mit `requireVerifiedUser` verwenden; die Identität ausschließlich aus `req.firebaseUid` beziehen. Der bestehende owner-gebundene Pfad kann während einer kompatiblen Migration als Alias dienen, aber niemals eine User-ID oder einen Tier vom Client autorisieren lassen.

Bei erfolgreicher Datenbank-/Verifikationsprüfung liefert der Endpoint mindestens `state`, `tier`, `access`, `validFrom`, `validUntil`, `verifiedAt` und `adsEligibleByEntitlement`. Kein Geburtsdatum, keine Kinderdaten und keine Receipt-/Token-Geheimnisse in der Antwort. Datenbank-/Verifikationsausfälle liefern einen expliziten Nicht-2xx-Fehler; der Client setzt dann `unavailable`, nicht Free.

### Prisma-Datenmodell und Migration

**Migration erforderlich.** Das bestehende `User.isPremium`/Expiry-Feld ist nicht mit einer verifizierten Abo-Quelle verbunden; `PaymentTransaction` ist Event-/Stripe-zentriert. Entitlement-Zustand gehört in persistente, referenzierte Tabellen:

1. Eine `SubscriptionTransaction`-/Store-Nachweistabelle für vom Provider verifizierte Transaktionsereignisse: `userId` (FK auf `User.id`, `onDelete: Cascade`), `store` (`app_store`/`play`), Produkt-ID, Provider-Transaktions-ID bzw. Original-Transaktions-ID (eindeutige Idempotenzschlüssel je Store), normalisierter Status, `validFrom`, `validUntil`, `verifiedAt`, Provider-Umgebung und übliche `createdAt`/`updatedAt`. Nur verifizierte Ergebnisse werden persistiert. Keine Klartext-Receipts, privaten Schlüssel, Service-Account-Schlüssel oder Refresh-Tokens speichern.
2. Daraus abgeleiteter aktueller Tier: entweder beim Lesen aus den validierten Transaktionen berechnen oder als transaktional aktualisierter `UserEntitlement`-Snapshot (maximal eine Zeile pro User) speichern. In beiden Fällen gibt es genau eine Regel: nur aktive, verifizierte Transaktion ohne Revocation/Refund und innerhalb des Gültigkeitszeitraums ist Premium; sonst bei erfolgreicher Datenlage Free. Eine fehlgeschlagene Provider-/DB-Prüfung ergibt `unavailable`, nicht Free.
3. Derzeitige `User`-Legacy-Felder nicht zusätzlich als zweite Autorität weiterführen. Ein Backfill darf sie nicht blind zu verifiziertem Premium erklären. Bestehende aktive Abos müssten anhand verlässlicher Provider-/Zahlungsnachweise einzeln migriert bzw. revalidiert werden; `PaymentTransaction`-Eventzahlungen sind kein Abo-Nachweis.

Die Migration ergänzt Prisma-Schema, SQL-Migrationsdatei, FK/Unique-Indizes und gegebenenfalls kontrollierte Backfill-Logik. Account-Export (`server.js:7465-7505`) erhält einen nutzerverständlichen Export der aktiven/letzten Entitlement-Metadaten (Store, Produkt, Status, Laufzeit, letzter Prüfzeitpunkt), aber keine geheimen Belege. Kontolöschung (`:7280-7455`) muss Entitlement-/Transaktionszeilen mit der bestätigten Aufbewahrungsregel löschen oder aus dem User-FK kaskadieren lassen; Aufbewahrungspflichten und mögliche Anonymisierung sind vor Umsetzung fachlich zu klären.

## 5. Sicherheits-/Produktgrenzen

- Login bleibt Pflicht. Die bestehende Firebase-ID-Token-Verifikation und Owner-Bindung wird wiederverwendet; es entsteht kein Gast- oder ungebundener Entitlement-Zugriff.
- Kein Client-Flag, lokales Promo-Codeset, `registeredAt`-Queryparameter, Beta-Schalter oder `User.isPremium` aus dem Client ist Kaufautorität. Ein Trial, das vom Store kommt, wird nur aus verifizierten Providerdaten akzeptiert.
- Exaktes Geburtsdatum verbleibt ausschließlich im eigenen Backend. Gemini erhält ausschließlich das abgeschlossene Alter. Entitlement-/Store-Payloads enthalten keine Kinderdaten; Werbe-/Consent-Daten werden in dieser PR nicht eingeführt.
- `MonetizationConfig.enabled`/Ads-Schalter und bestehende Event-Limit-Flags bleiben ausgeschaltet bzw. unverändert. Keine Ad-Slot-, Consent-, Paywall- oder Pricing-Änderung.
- Free-Zusatzlimits, die der Nutzer noch nicht bestätigt hat, bleiben unverändert und werden nicht als Teil des Designs implementiert.

## 6. Offene technische Voraussetzung vor Phase B

Der aktuelle Checkout enthält Flutter-Stripe und Backend-Stripe, aber keine erkennbare Apple App Store-/Google Play-Abonnement-Verifikation. Die vorhandene Stripe-Integration betrifft Event-Payments und reicht nicht als Store-Abo-Nachweis.

Vor Implementierung muss der Nutzer den Verifikationsweg bestätigen: native Apple-/Google-Store-Abos mit serverseitiger Prüfung (einschließlich Provider-Notifications/Statusabgleich) oder ein anderer ausdrücklich gewählter Billing-Anbieter. Native Prüfungen können neue Bibliotheken und geschützte Anbieterzugänge erfordern (z. B. Apple Sign/Server-API-Schlüssel bzw. Google Play Developer API Service-Account-Konfiguration). Ob diese Abhängigkeiten/Anbieterzugänge gewünscht und verfügbar sind, ist offen. Falls erforderlich, gehören Secrets ausschließlich in den genehmigten Secret-Store/Deployment-Konfiguration, niemals in Quellcode, Client, Logs oder dieses Dokument. Es wurden keine Secrets angefragt oder hinzugefügt.

## 7. Geplante Verifikation nach Freigabe (nicht in Phase A ausgeführt)

- `flutter analyze --no-pub` — gegen die bestätigte Baseline von 9 Infos prüfen.
- `flutter test`.
- `cd backend && API_BASE=http://127.0.0.1:9 node --test tests/unit/*.test.js` — keine pauschalen Integrationstests.
- Gezielt: Auth-/Owner-Bindung; keine Client-`isPremium`-Autorität; verified active/trial/grace, expired/refunded/revoked; unbekannt/offline/DB-Ausfall; parallele Backend-Instanz-/Persistenzfälle; Export/Löschung; Regression der 3 Event-Detailansichten/Woche (Montag-Reset, Zählpunkt und bestehende Flags unverändert).
- Der bestehende Backend-Test [`backend/tests/unit/recipes-entitlements-scope.test.js`](../backend/tests/unit/recipes-entitlements-scope.test.js) prüft aktuell Routen-/Self-Activation-Verhalten; er ist nach Designfreigabe gezielt zu erweitern oder durch neue Unit-Tests zu ergänzen.

## 8. Verifiziert / vermutet / nicht geprüft

### Verifiziert auf `7ccdada`

- Arbeitsbaum war sauber; der neue Branch `feat/entitlement-source-of-truth` wurde direkt von `origin/main` bei SHA `7ccdada6d6e2aea331e9e549ff268daca21ee0dc` erstellt.
- Entitlement- und Premium-Service haben getrennte Zustände, Tier-Typen, Initialisierung und Aufrufer; `PremiumService` nutzt lokale Preferences und kann mit abgeschalteter Monetarisierung Premium für alle melden.
- Status-GET ist mit Firebase-ID-Token authentifiziert und owner-gebunden; `isPremium` wird vom aktuellen Refresh nicht mitgesendet und die Route ignoriert den alten Query-Hint.
- Backend-Entitlement liegt im aktuellen Routepfad in einer Node.js-Map und ist nicht in Prisma gespeichert. Selbstaktivierung wird standardmäßig blockiert, kann aber bei `ALLOW_SELF_SERVICE_PREMIUM=1` ohne Store-Beleg den Map-Status auf Premium setzen.
- User-Legacyfelder und Event-zentrierte Stripe-Transaktionen existieren; die untersuchten Manifestdateien zeigen keine Store-Abonnement-Verifikationsbibliothek.
- Bestätigtes Eventlimit 3/Woche ist Client-seitig gespeichert und an das Premium-Limit-Flag gebunden. Der Planteil zu nicht bestätigten Free-Zusatzlimits wurde berücksichtigt.

### Vermutet / vorgeschlagen

- Eine persistente, provider-verifizierte Subscription-/Entitlement-Quelle plus `unknown/unavailable`-Clientstatus ist der zuverlässigste Weg, Free/Premium/Aboablauf klar zu trennen.
- Eine getrennte Transaktionshistorie oder ein Snapshot ist je nach gewünschter Auditierbarkeit und Provider-Sync-Architektur zu wählen; beide müssen dieselbe eindeutige serverseitige Autoritätsregel abbilden.

### Nicht geprüft

- Tatsächliche Produktionswerte von Render-Umgebungsflags, vorhandene App-Store-/Google-Play-Verträge, Developer-Zugänge oder manuelle Entitlement-Prozesse.
- Live-Datenqualität in `User.isPremium`, `trialExpiresAt` und `premiumExpiresAt` sowie mögliche aktive Zahlungen außerhalb der sichtbaren Integration.
- Ob Apple-/Google-Server-API-Credentials, Provider-Notifications oder zusätzliche Pakete vorhanden/verfügbar sind; es wurden weder Secrets abgerufen noch angefragt.
- Tests/Builds wurden in Phase A nicht ausgeführt; es wurde nur dieses Design-Dokument neu angelegt.
