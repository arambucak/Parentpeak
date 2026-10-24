# Parentpeak: Monetarisierung, Werbung und Launch-Vorbereitung

**Status:** Finalisierter Produktentscheidungs- und Inventarplan, keine Implementierungsfreigabe
**Erstellt:** 24. Oktober 2026
**Wichtig:** Dieser Plan schaltet weder Werbung noch Zahlungen frei. Bestehende Monetarisierungs- und Ad-Flags bleiben unverändert. Vor Implementierung und vor jedem Livegang ist deine ausdrückliche Freigabe erforderlich.

### Bestätigte Produktentscheidungen

Diese Vorgaben sind vom Nutzer bestätigt. Sie sind **keine Freigabe zur Implementierung oder zum Livegang**:

- **Anbieter-Paket:** entfällt, Produktentscheidung getroffen. Es ist kein Tarif und kein Entitlement und wurde laut Nutzer auch von der Website entfernt. Es darf in Tarif-/Entitlement-Matrix und Website nicht wieder eingeführt werden.
- **Free:** 0 €, dauerhaft kostenlos. Das Event-Veröffentlichen bleibt kostenlos. Das Free-Limit beträgt 3 Event-Detailansichten pro Woche.
- **Premium:** 3,99 €/Monat bzw. 34,99 €/Jahr, mit 30 Tagen kostenlosem Test; Premium ist komplett werbefrei.
- Bestätigte aktive Probe- und Kulanzzeiträume sind werbefrei, sofern der Status serverseitig bestätigt ist.
- **Werbung:** direkte, manuell geprüfte Sponsor-Platzierungen; kontextuell, nicht personalisiert; ausschließlich in der öffentlichen Event-Entdeckung. Andere Flächen sind ausgeschlossen.
- Bei Ablehnung oder Widerruf des Werbe-Consents erscheint keine Werbung; die App bleibt nutzbar.
- Keine Werbung in sensiblen Flows, insbesondere KI-Beratung, Melden/Blockieren, Datenexport und Kontolöschung.
- Store-Zielgruppe: Eltern/Erwachsene, nicht als Kinder-App.
- Alle nutzersichtbaren App- und Website-Texte sind in den acht Launch-Sprachen `de`, `en`, `tr`, `ku`, `fr`, `es`, `it`, `ar` vollständig und idiomatisch zu übersetzen; keine leeren oder englisch-identischen Strings, Platzhalter erhalten und Arabisch/RTL prüfen.
- Statische Website-Rechtstexte erhalten Sprachpfade, z. B. `/de/privacy` und `/en/privacy`.

## 1. Tatsächlicher Git- und Arbeitsstand

Der Plan wird auf einem eigenen Branch direkt von `origin/main` gepflegt:

- Aktiver Branch: `feat/monetization-ads-plan`, `HEAD b7df6ff5e49ce6e2fe07a116d04005b57373a06f`.
- `origin` wurde gefetcht; `origin/main` ist `b7df6ff5e49ce6e2fe07a116d04005b57373a06f`.
- Die zuvor vorhandenen lokalen Änderungen im Checkout `backup/local-unsynced-2026-10-21` (`e15c78e071df43887f1714ca3ca9a30d38a6389d`) wurden gemeinsam und unverändert gesichert: `stash@{0}` mit Hash `61f28f56fb13b6201fcc56e9a5fa1b980ef2f3d1`, Nachricht `preserve local work before monetization plan branch setup`. Sie wurden nicht in diesen Branch übernommen.
- 17 als `prunable` markierte, verwaiste Worktree-Registrierungen wurden mit `git worktree prune` entfernt. Die fünf bestehenden, sauberen Zusatz-Worktrees blieben unangetastet: `pp-fix-ai-consent`, `pp-fix-event-discovery`, `pp-fix-event-photo-web`, `pp-fix-moderation-token` und `pp-launch-integration`.
- In diesem Branch wird nur dieses Plan-Dokument geändert; Feature-Code, Ad-Slots und Entitlement-Logik bleiben unverändert.

Das Datei-/Zeileninventar wurde im vorherigen Checkout (`e15c78e`) erhoben. Es ist eine Orientierung, keine Behauptung über den aktuellen `b7df6ff`-Baum; Pfade, Zeilennummern und Änderungen aus dem gesicherten Stash sind vor der ersten Umsetzungs-PR auf deren Basis erneut zu prüfen.

## 2. Verbleibende Voraussetzungen vor Implementierung

Die Produktentscheidungen zu Tarif, Free-Limit, Werbeart, Platzierung, Personalisierung, Ablehnung/Widerruf, Zielgruppe und Launch-Sprachen sind getroffen und stehen oben verbindlich. Sie werden nicht erneut als offene Fragen geführt.

Vor einer Consent-Implementierung sind die konkrete Consent-Versionierung, Speicherung, Widerrufsverarbeitung, Aufbewahrungsdauer und Rechtsgrundlage mit den tatsächlichen Datenflüssen abzugleichen. Das ist Umsetzungs-/Rechtsprüfung, keine offene Produktwahl zwischen personalisierten und nicht-personalisierten Ads: Personalisierung ist ausgeschlossen. Die erste Umsetzungs-PR und jeder Livegang benötigen weiterhin eine ausdrückliche Freigabe; es gibt keine automatische Freigabe durch diesen Plan.

### Datenschutzarmer Default in einem Satz

Wenn Werbung nach deiner ausdrücklichen Freigabe überhaupt startet: ausschließlich manuell geprüfte und klar gekennzeichnete Direkt-Sponsor-Karten in der öffentlichen Event-Entdeckung, nur kontextuell, nicht personalisiert und nach Ablehnung/Widerruf vollständig ausgeblendet. Kein externes Ad-Netzwerk oder Tracking im geplanten Umfang. Dies ist keine Rechtsfreigabe; vor Veröffentlichung sind Store- und Rechtsprüfung erforderlich.

## 3. Entitlement-/Abo-Logik und Flächenregeln

### Vorgeschlagene Quelle der Wahrheit

- Das Backend ermittelt den wirksamen Zugang aus serverseitig verifizierten Apple-/Google-Store-Transaktionen bzw. einem verifizierten Abonnementdatensatz, einschließlich Ablauf, Kündigung, Rückerstattung/Widerruf, Probe-/Kulanzzeit und Wiederherstellung.
- Ein Clientwert, lokaler Cache, Promo-Code oder Query-Parameter darf allein keine werbefreie Berechtigung ausstellen. Der Client zeigt Werbung erst, wenn Backend-Entitlement und Consent beide eindeutig vorliegen. Bei Netzwerkfehlern, unbekanntem Status oder noch laufender Initialisierung werden keine Ads angefordert.
- „Premium“/„Free“ wird durch einen zentralen Backend-Endpunkt mit explizitem, prüfbarem Status bereitgestellt. Serverseitige Berechtigungsprüfung für geschützte Funktionen bleibt davon getrennt; Login bleibt Pflicht.
- Der Server beantwortet mindestens: verifizierter Abo-Status, Produkt/Entitlement, Gültigkeitszeitraum und ob Werbung zulässig ist. Keine Geburtsdaten oder Kinderdaten in Werbe- oder Consent-Payloads.
- Es wird kein stiller Offline-Fallback auf „Free = Ads anzeigen“ eingeführt. Das wäre sowohl für zahlende Nutzer als auch für Consent-Widerrufe falsch.

### Vom Nutzer vorgegebene Tarif-/Feature-Matrix

Diese Angaben sind Produktanforderungen für die spätere Umsetzung, nicht Live-Schaltung:

| Free — 0 €, für immer kostenlos | Premium — 3,99 €/Monat oder 34,99 €/Jahr |
|---|---|
| Maximal 3 Event-Detailansichten pro Woche | Alle Events unbegrenzt |
| Verschenkmarkt unbegrenzt | Push-Alerts für neue Events |
| KI-Beratung: 3 Fragen/Tag | KI-Beratung unbegrenzt |
| Familienkalender | Rezepte unbegrenzt + Mealplan |
| Eltern-Netzwerk: 3 Kontakte/Monat | Eltern-Netzwerk unbegrenzt + Radar |
| Familien-Geld Übersicht | Familien-Geld: „Was steht MIR zu?“ |
| 1 Rezept/Tag | Kalender-Sync (Apple/Google) |
| — | Komplett werbefrei |
| — | Alles aus Free inklusive |

Premium soll 30 Tage kostenlos testbar sein. Der Testzeitraum und serverseitig bestätigte aktive Kulanzzeiträume sind werbefrei. Bei abgebrochener oder verfallener Testphase richtet sich der Status nach der verifizierten Store-Information.

**Limit-Verhalten:** Das bestehende Limit von 3 Event-Detailansichten pro Woche bleibt unverändert. Später wird ausschließlich der Wortlaut auf den Free-Tarifkarten an diese Definition angeglichen; Zähl- und Limit-Logik werden dafür nicht geändert. Event-Veröffentlichen bleibt kostenlos.

### Vorgeschlagene Flächenmatrix

| Zustand/Fläche | Verhalten |
|---|---|
| Free ohne werbefreies Entitlement, gültiger Consent, öffentliche Event-Entdeckung | Ausschließlich dort klar als „Anzeige“/„Gesponsert“ markierte, manuell geprüfte, kontextuelle Sponsor-Karte; keine Personalisierung |
| Premium oder serverseitig bestätigte aktive Probe-/Kulanzzeit | Keine Ads |
| Consent abgelehnt/widerrufen, noch nicht geladen oder nicht eindeutig | Keine Ads oder Sponsor-Platzierungen |
| Login, Registrierung, Onboarding, Paywall, Kauf/Wiederherstellung | Keine Ads |
| KI-Beratung, Chat/DM, KI-Eingaben/-Antworten und andere sensible Inhalte | Keine Ads, keine Kontextsignale an Werbedienste |
| Melden, Blockieren, Moderation, Sicherheits- und Hilfeflüsse | Keine Ads |
| Datenexport, Kontolöschung, Rechtliches, Consent-Verwaltung, Support | Keine Ads |
| Kinderdossier/-profil, Geburtsdatum/-alter, Familien-/Gesundheits-/Finanzdaten, private Gruppen | Keine Ads und kein Targeting |
| Event-Erstellung, Bearbeitung, Veröffentlichung, Teilnahme oder sensible Event-Details | Keine Ads; Event-Veröffentlichen bleibt kostenlos |
| Sonstige Feeds, Startseite, Event-Details, statische Website-/Rechtstextseiten | Keine Ads; einzige freigegebene Fläche ist die öffentliche Event-Entdeckung |

Diese Produktmatrix ist verbindlich für die Planung. Die technische Umsetzung und der Livegang bleiben bis zu deiner ausdrücklichen Freigabe gesperrt.

### Vorhandener technischer Zustand (wichtig)

Im Checkout existieren zwei konkurrierende Client-Pfade (`EntitlementService` und `PremiumService`) sowie ein vorhandenes Ad-Platzhalter-Widget. `PremiumService` liest lokal gespeicherte Werte; `EntitlementService` leitet den Tier aus dem Auth-Profil ab. Das darf nicht als produktionsreife, serverseitige Abo-Verifikation interpretiert werden.

Außerdem werden im vorhandenen Auth-Code `isPremium` als Client-Query übermittelt und in den aktuellen Entitlement-Routen Hinweise vom Client angenommen; diese Routen verwenden im gezeigten Pfad ein In-Memory-Entitlement. Diese Konstruktion ist kein belastbarer Store-Nachweis und muss vor Nutzung für Ads ersetzt bzw. auf eine verifizierte Quelle umgestellt werden. Die vorhandene Prisma-User-Tabelle hat zwar Premium-Felder, belegt aber allein weder Store-Verifikation noch eine konsistente aktuelle Billing-Quelle.

## 4. Consent, Store- und Rechtsthemen

### Consent-Modell und Werbe-SDK

- Getrennte und verständliche Zwecke: notwendige App-Verarbeitung und optionale kontextuelle Sponsor-/Werbeverarbeitung. Personalisierte Werbung ist ausgeschlossen. Keine vorausgewählten optionalen Zwecke, kein Nudging/„Dark Pattern“ und eine Ablehnung mit vergleichbarem Aufwand wie Zustimmung.
- Vor Consent keine Sponsor-Platzierung und kein Request, der Daten für Werbezwecke übermittelt. Widerruf muss jederzeit erreichbar sein und ab dann zuverlässig neue Werbeverarbeitung unterbinden.
- Kein Tracking von/an Kindern und keine Verwendung von Kinderprofilen, exaktem Geburtsdatum, abgeschlossenen Alter, KI-Eingaben, Gesundheits-/Finanzangaben oder präzisem/abgeleitetem Standort für Werbung. Das exakte Geburtsdatum verbleibt ausschließlich im eigenen Backend; Gemini erhält weiterhin nur das abgeschlossene Alter. Diese Grenzen gelten unabhängig vom Ad-Anbieter.
- Vor einer Änderung der beschlossenen Direkt-Sponsoring-Architektur oder bei Einsatz eines externen Dienstleisters sind Datenflüsse, Auftrags-/Drittlandtransfer, Einwilligungsintegration, Datenlöschung, Alters-/Familienregeln sowie plattformspezifische Freigabe erneut zu prüfen. Apple ATT ist relevant, wenn eine konkrete Implementierung „Tracking“ im Sinne der Apple-Regeln ausführt; es ist kein Ersatz für DSGVO-/Consent-Pflichten. Keine ATT-Abfrage für ein Produkt versprechen, das nicht trackt.
- Google-Play-„Families“- und Anzeigenregeln sind anhand der tatsächlichen Zielgruppe/Store-Angaben und des konkreten Ad-SDK zu prüfen. Eine App für Eltern ist nicht automatisch eine Kinder-App; zugleich machen Familienfunktionen und gespeicherte Kinderdaten SDK- und Zielgruppenprüfung besonders wichtig.
- Öffentliche Referenzen für die spätere Prüfung: [Apple App Tracking Transparency](https://developer.apple.com/documentation/apptrackingtransparency) und [Google Play Families Policy](https://support.google.com/googleplay/android-developer/answer/9893335).

### Dokumente und Store-Angaben, die vor Livegang konsistent sein müssen

1. **Datenschutzerklärung (Web und App-Verlinkung):** Werbeanbieter/Sponsoren und ihre Rollen, Datenarten, Zwecke, Rechtsgrundlagen, Einwilligung/Widerruf, Empfänger, SDK-/Cookie-/Gerätezugriffe, Speicher-/Löschfristen, Drittlandtransfers, Kontakt und Rechte ergänzen. Die jetzigen pauschalen Aussagen „keine Werbung“, „kein Tracking“ bzw. „kein Profiling“ dürfen erst nach geprüftem tatsächlichem Verhalten angepasst werden; keine unzutreffende Aussage stehen lassen.
2. **Nutzungsbedingungen:** Sponsor-/Werbekennzeichnung, Abgrenzung redaktioneller Inhalte, Verantwortlichkeit für Sponsor-Inhalte, verfügbare Werbeflächen, Abonnement- und Kündigungsbedingungen sowie die kostenlose Event-Veröffentlichung widerspruchsfrei regeln. Keine AGB-Formulierung als Ersatz für Einwilligung verwenden.
3. **KI-Nutzungshinweis:** Die Werbeänderung allein ändert nicht die KI-Verarbeitung. Den Hinweis konsistent lassen/prüfen und ausdrücklich festhalten, dass Werbeanbieter keinen Zugriff auf KI-Inhalte erhalten. Bestehende Regel beibehalten: Gemini bekommt nur das abgeschlossene Alter, nie das exakte Geburtsdatum.
4. **Impressum und weitere Rechtstexte:** Betreiber-/Kontaktangaben und Links auf der Website sowie in der App konsistent halten. Werbeverträge oder Sponsor-Disclosure ergänzen, falls erforderlich.
5. **Apple App-Store-Datenschutzlabels und Google Play Data Safety:** Nach Auswahl und Audit des SDKs tatsächliche Datenerhebung, Verknüpfung, Weitergabe, Tracking, Löschmöglichkeit und Zwecke deklarieren. Store-Angaben nicht aus einer geplanten Architektur ableiten, sondern aus dem ausgelieferten Binärverhalten.
6. **ATT und Google Families:** ATT nur dann einführen, wenn eine konkrete Funktion Tracking erfordert; für das empfohlene nicht-trackende Startmodell ist kein IDFA-Tracking vorgesehen. Google-Zielgruppenangaben, Families-Regeln und zulässige SDK-Version anhand finaler Store-Einstufung prüfen und dokumentieren.

Dies ist ein technischer Plan und keine Rechtsberatung. Rechtstexte, Rechtsgrundlagen, Store-Einstufungen und die konkrete Ad-SDK-Zulässigkeit sind vor Veröffentlichung fachlich/juristisch zu prüfen.

### „Rechtliches“ in der App

Die bestehende Rechtliches-Sektion im Profil enthält bereits Datenschutz, Nutzungsbedingungen, Impressum, KI-Nutzungshinweis, Datenexport, Open-Source-Lizenzen, blockierte Kontakte und Support. Die Consent-Verwaltung muss dort als eigener, klar benannter und dauerhaft erreichbarer Eintrag erscheinen; der Anzeigenstatus und ein Link zum Ändern/Widerrufen dürfen nicht in einem separaten, schwer auffindbaren Werbe-Menü verschwinden. Website, Profil-Sektion und `LegalInfoScreen` müssen dieselben Dokumentversionen/Links und Bezeichnungen verwenden.

## 5. Datei-/Ordner-Inventar für die Umsetzung

| Bereich | Vorhandene Stelle (Datei:Zeile) | Geplante Zuständigkeit — noch nicht umgesetzt |
|---|---|---|
| App-Einstieg / Initialisierung | `lib/main.dart:29-39,157-160` | Vor Anzeige von Slots Auth, Entitlement und Consent laden; Initialisierungszustand so führen, dass unbekannt niemals „Free mit Ads“ bedeutet. |
| Monetarisierungs-Flags | `lib/config/monetization_config.dart:5-42,100-110` | Ein zentraler, standardmäßig ausgeschalteter Launch-Schalter; keine Live-Keys/Secrets. Sponsor-Konfiguration ohne externes Ad-Netzwerk. |
| Bestehender Ad-Slot | `lib/ui/widgets/native_ad_slot.dart:13-37` | Vorhandenes Widget als Integrationspunkt prüfen/weiterverwenden; Kennzeichnung, Consent-Gate, Entitlement-Gate und sichere Lade-/Fehlerzustände. Im vorherigen Checkout war diese Datei lokal geändert und ist im Stash gesichert; Stand auf `b7df6ff` erneut prüfen. |
| Aktueller Ad-Einbau | `lib/ui/events_activities_screen.dart:675-678` | Einzige gefundene tatsächliche Slot-Position: Event-Aktivitäten-Feed. Nur bei expliziter Freigabe beibehalten; zuerst Kontext-/Sensitivitätsprüfung und Flächenmatrix anwenden. |
| Client-Premium-Service | `lib/services/premium_service.dart:19-82,88-96` | Lokalen Tier nicht als Autorität nutzen. Auf serverbestätigtes Ad-Free-Entitlement vereinheitlichen; bestehende Limit-Logik nicht unbeabsichtigt ändern. |
| Entitlement-Service | `lib/logic/entitlement_service.dart:10-57` | Mit `PremiumService`/Auth-Tier auf eine klare Schnittstelle abstimmen und vom Backend-Status speisen; Nutzungslimits separat regressionsprüfen. |
| Auth-Modell und Refresh | `lib/logic/auth_service.dart:71-136,880-909` | Bestehenden `ParentUser`/Backend-Aufruf an signierte/verifizierte Backend-Entitlements anbinden; vom Client gesendetes Premium-Flag nicht als Nachweis verwenden. |
| Backend-User-Schema | `backend/prisma/schema.prisma:13-38` | Verifizierbare Subscription-/Store-Transaktions- und Consent-Referenzen nur nach Datenmodellentscheidung ergänzen; Migration und Löschung/Export abdecken. Vorhandene boolesche Felder allein reichen nicht. |
| Backend-Entitlement-Routen | `backend/server.js:4844-4900,5550-5582` | Vorhandene In-Memory-/Hint-basierte Status- und Aktivierungslogik durch authentifizierte, persistente, Store-verifizierte Quelle ersetzen; Ads nur über serverseitige Entscheidung zulassen. |
| Backend-Authentifizierung / Accountrechte | `backend/server.js:2294-2315,5477-5550` | Vorhandene Auth-/Owner-Patterns für Consent, Entitlement, Export und Löschung beachten; neue Daten in Account-Export/-Löschung einbeziehen. |
| Datenschutz- und Rechts-UI | `lib/ui/profile_safety_screen.dart:762-850,1186-1235,1276-1310,1469-1633` | Consent-Einstellungen mit „ändern/widerrufen“ in die bestehende Sektion integrieren; die bereits vorhandenen Einträge für Datenschutz, AGB, Impressum, KI, Export, Lizenzen, Blockierte Kontakte und Support konsistent halten. |
| Bestehender Legal-Info-Screen | `lib/ui/legal_info_screen.dart:8-131,191-335` | Dokumentlinks und Werbe-/Consent-Informationen konsistent mit Profil und Website halten; kein zweites, abweichendes Consent-Menü bauen. |
| Datenschutz-Einstellungen | `lib/ui/privacy_settings_screen.dart:3-20` | Vorhandenen Datenschutz-Einstieg prüfen; dort darf der Werbe-Consent nicht mit dem bestehenden Familien-Privatsphäre-Modus verwechselt werden. |
| Profilnavigation | `lib/ui/family_profile_screen.dart:1318-1360` | Bestehende Privacy-/Legal-Navigation nutzen und Rechtezugriff unverändert schützen. |
| App-Lokalisierungsdaten | `lib/l10n/app_localizations_all.dart:6-14,227-292,5461,23216-23255` | Neue Labels, Buttons, Erklärungen, Ablehnung/Widerruf und Statusmeldungen in der bestehenden String-Struktur ergänzen; Schlüssel in allen acht Launch-Sprachen vollständig und idiomatisch pflegen. |
| App-Lokalisierungsauflösung | `lib/l10n/app_localizations.dart:17-31,164` | Vorhandene Übersetzungsauflösung/Fallbacks berücksichtigen; für neue Consent-/Ad-Texte keine stillen englischen Fallbacks oder Schlüssel als UI-Text zulassen. |
| Sprachen / RTL | `lib/l10n/supported_languages.dart:24-151` | Launch-Zielsprachen dieses Auftrags: `de`, `en`, `tr`, `ku`, `fr`, `es`, `it`, `ar`. Aktuell sind darüber hinaus weitere Sprachen registriert; arabische RTL-Darstellung separat prüfen. |
| Statische Web-Datenschutzerklärung | `web/privacy/index.html:1-180` | Werbeverarbeitung und Consent erst nach Faktenprüfung aktualisieren; lokalisierte Sprachpfade wie `/de/privacy` und `/en/privacy` verwenden. Die zuvor geprüfte Datei war deutsch und enthielt Aussagen „keine Werbung/kein Tracking“. |
| Statische Web-Nutzungsbedingungen | `web/terms/index.html:1-160` | Werbe-/Sponsor- und Abo-Bedingungen konsistent ergänzen und in den acht Launch-Sprachen bereitstellen. Die zuvor geprüfte Datei war deutsch; das abgeschaffte Anbieter-Paket darf nicht wieder auftauchen. |
| Flutter-Web-App / Domain | `web/index.html:1`, `web/CNAME:1` | Flutter-Web-Lokalisierung für App-Flows prüfen; `parentpeak.de`-Routen, Datenschutz-/AGB-Links und statische Rechtsseiten sprachübergreifend konsistent halten. |
| API-Link-Konfiguration | `lib/config/api_config.dart:23-27,416-426,581-589` | Lokalisierte Datenschutz-/AGB-Sprachpfade zentral konfigurieren, statt unterschiedliche Link-Strings in Screens einzubauen. |
| Vorhandene Tests | `test/supported_languages_test.dart:1`, `test/localization_audit_verification_test.dart:1`, `backend/tests/events.test.js:1`, `backend/tests/gemeinsam-satt.test.js:1`, `backend/tests/parent-matching.test.js:1`, `backend/tests/treasures.test.js:1` | Tests ergänzen für Consent-Zustände, Ad-Sperrflächen, serverseitige Entitlements, Export/Löschung und alle acht Strings/RTL. Im vorher geprüften Checkout `e15c78e` wurde kein `backend/tests/unit/*.test.js`-Treffer gefunden; auf dem freigegebenen Basis-Branch erneut prüfen, ohne pauschal Integrationstests zu starten. |

**Hinweis zur Website:** Das Verzeichnis `web/` enthält die Flutter-Web-App und statische Privacy-/Terms-Seiten. Für die statischen Rechtstexte sind Sprachpfade pro Sprache beschlossen; die konkrete Dateiaufteilung soll auf der bestehenden Web-Struktur aufbauen. Für alle nutzersichtbaren App- und Website-Texte gelten die acht Launch-Sprachen und die vollständigen Übersetzungs-/RTL-Anforderungen oben. Der Nutzer hat bestätigt, dass das Anbieter-Paket von der Website entfernt wurde.

## 6. Vorschlag für reviewbare PRs

Alle PRs erhalten eigene Branches und bleiben unveröffentlicht; keine PR wird gemergt und kein Live-Flag eingeschaltet, bis du die jeweilige Freigabe gibst. Die beschlossene Umsetzung verwendet manuell gepflegte Sponsor-Platzierungen, kein externes Ad-Netzwerk.

1. **Entitlement-Quelle vereinheitlichen:** Backend-Statusmodell und persistente, authentifizierte Store-Verifikation; Client-Integration für „werbefrei/Ads nicht erlaubt“; keine Anzeigeänderung, Flags bleiben aus. Den konkreten Store-Transaktions-/Verifikationsfluss anhand der bestehenden Plattformbibliotheken spezifizieren.
2. **Consent-Modell und Verwaltung:** Versioniertes Consent-Modell, sichere Defaults, Ablehnung/Widerruf, Consent-Eintrag im bestehenden Rechtliches-Bereich und notwendiger Export/Löschpfad. Noch keine Ad-SDK-Aufrufe.
3. **App-Ad-Integration hinter ausgeschaltetem Flag:** Ausschließlich die öffentliche Event-Entdeckung, klare Werbekennzeichnung, abgestimmte Frequenz sowie Consent- und Entitlement-Gates; Tests für alle verbotenen Flächen. Keine Ads in sensiblen Flows oder anderen Screens.
4. **Website-Flächen und Sprachstruktur:** Statische Rechtstexte über die beschlossenen Sprachpfade und sämtliche nutzersichtbaren Website-Texte in allen acht Launch-Sprachen; keine Werbeplätze außerhalb der öffentlichen Event-Entdeckung und keine Tracking-Skripte.
5. **Vollständige App-Übersetzungen:** Alle nutzersichtbaren Texte, Fehler- und Statuszustände in App und Website in `de`, `en`, `tr`, `ku`, `fr`, `es`, `it`, `ar`, idiomatisch und ohne leere bzw. englisch-identische Strings; Platzhalter erhalten; Arabisch/RTL visuell prüfen.
6. **Rechtstexte und Store-Metadaten:** Datenschutz, AGB, KI-Hinweis und Stores erst nach tatsächlich festgelegtem Datenfluss finalisieren; App-Store-Labels/Data Safety sowie Familien-/ATT-Prüfung dokumentieren. Veröffentlichung dieser Dokumente nur nach fachlicher/juristischer Freigabe.

PR 4/5/6 können bei Bedarf als kleinere getrennte PRs je Oberfläche/Sprache/Rechtstext aufgeteilt werden. Übersetzungen dürfen nicht nachträglich als unreviewte Restaufgabe in einen Livegang geraten. Store-/Länderanforderungen und rechtliche Prüfung sind vor Veröffentlichung zu bestätigen.

## 7. Verifikation je Umsetzung/PR

Diese Aufgabe änderte ausschließlich dieses Dokument. Deshalb waren Builds und Tests nicht erforderlich und wurden nicht ausgeführt. Für spätere Code-PRs gelten mindestens die vom Auftrag vorgegebenen Prüfungen:

- `flutter analyze --no-pub` — Ergebnis dokumentieren und die bekannte Baseline von 9 Infos nicht als neue Regression ausgeben.
- `flutter test` — Ergebnis dokumentieren.
- `cd backend && API_BASE=http://127.0.0.1:9 node --test tests/unit/*.test.js` — Ergebnis dokumentieren; keine pauschalen Integrationstests starten.
- Zusätzlich gezielte Tests für Consent „zustimmen/ablehnen/widerrufen/noch nicht geladen“, verifizierte und abgelaufene Abos, Offline-Fail-Closed, kostenlose Event-Veröffentlichung, Ad-Ausschlussflächen, Export/Löschung, alle acht Sprachwerte/Platzhalter und Arabisch-RTL.
- PR-Beschreibung trennt ausdrücklich **verifiziert**, **vermutet** und **nicht geprüft**; enthält Zusammenfassung und exakte Testbefehle mit Resultat. Kein Merge ohne deine Freigabe.

## 8. Verifiziert / vermutet / nicht geprüft

### Verifiziert

- Git-Stand nach Einrichtung: Branch `feat/monetization-ads-plan`, `HEAD` und gefetchtes `origin/main` auf `b7df6ff5e49ce6e2fe07a116d04005b57373a06f`; Plan-Dokument ist die einzige Änderung dieses Branches.
- Die früheren lokalen Änderungen wurden vollständig in `stash@{0}` (`61f28f56fb13b6201fcc56e9a5fa1b980ef2f3d1`) auf dem Backup-Branch gesichert. Die 17 prunable Worktree-Registrierungen wurden entfernt; fünf saubere zusätzliche Worktrees blieben.
- Die Produktvorgaben in Abschnitt 1, einschließlich Abschaffung des Anbieter-Pakets auf der Website, wurden vom Nutzer ausdrücklich mitgeteilt. Sie sind bestätigte Produktentscheidungen, keine unabhängige Prüfung der Website.
- Code-Inventar und technische Entitlement-Beobachtungen wurden im vorherigen Checkout `e15c78e` erfasst und deshalb im Dokument ausdrücklich als vor der Umsetzung auf `b7df6ff` erneut zu prüfende Orientierung markiert.
- Die angefragten Build-/Testbefehle wurden für diese Doku-Aufgabe nicht ausgeführt; sie waren nicht erforderlich.

### Vermutet / vorgeschlagen

- Manuell verwaltete, kontextuelle Sponsor-Karten ohne externes Ad-SDK begrenzen voraussichtlich Drittanbieter-Datenflüsse; konkrete rechtliche Wirkung ist von der tatsächlichen Umsetzung abhängig.
- Die öffentliche Event-Entdeckung ist die bestätigte Produktfläche. Format, Häufigkeit, redaktionelle Prüfschritte und endgültige Werbekennzeichnung müssen in der Umsetzung spezifiziert und vor Livegang geprüft werden.

### Nicht geprüft

- Tatsächliche Deploy-/Produktionskonfiguration von Render, GitHub Pages, Store-Produkten oder Feature-Flags.
- Zustand verwaister Worktree-Verzeichnisse, die Git als fehlend/prunable markiert hatte; geprüft und entfernt wurden nur deren Git-Registrierungen, keine Nutzdateien.
- Vollständige Laufzeit-Datenflüsse, aktuell verwendete Store-Receipt-Verifikation, Store-Zielgruppeneinstufung und konkrete Ad-SDK-Kompatibilität.
- Rechtliche Zulässigkeit, Datenschutzerklärungen/AGB in ihrer Wirksamkeit, Rechtsgrundlagen und Länderanforderungen.
- Tatsächliche Entfernung des Anbieter-Pakets von der veröffentlichten Website sowie die implementierte Übersetzung und RTL-Darstellung; diese Änderungen sind nicht Teil dieser Doku-Aufgabe.
- Laufende Tests, Builds oder visuelle RTL-Prüfungen.
