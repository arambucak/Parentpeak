# FREE/PREMIUM-Limits: Ist-Analyse

Stand: 05.11.2026. Untersucht: `origin/main`, Commit `4aa2758`, auf eigenem Branch
`audit/abo-limits` im isolierten Worktree `/Users/aram/Parentpeak-abo-audit`.
Der parallel bearbeitete Checkout `/Users/aram/Parentpeak-1` wurde nicht veraendert.
Keine App-/Backendlogik und keine der ausgeschlossenen Dateien wurden geaendert.
Dies ist eine Analyse, **keine Aktivierung und keine Freigabe fuer den Abo-Start**.

## Kurzurteil

**Keines der fuenf Website-Versprechen wird aktuell als entsprechende
FREE/PREMIUM-Regel vollstaendig durchgesetzt.**

Das Abschalten der Monetarisierung ist im Quellcode ausdruecklich als
Beta-Verhalten dokumentiert und daher nicht allein ein Bug. Unabhaengig davon
existieren Implementierungsluecken: Nur Flags umzulegen reicht nicht.
Insbesondere sind die 3 KI-Fragen/Tag nicht mit dem aktiven Chat verdrahtet,
der Rezept-Zaehler fehlt, und fuer Community sowie persoenlichen Finanzcheck
existiert keine wirksame Abo-Pruefung.

**Beta bedeutet trotzdem nicht technisch grenzenlos:** Der aktive Chat,
KI-Rezepte und der Leistungs-Wegweiser teilen ein lokales Budget von
**50 KI-Anfragen/Tag**, auch fuer Premium. Der Backend-Proxy hat weitere,
nicht abonnementbezogene Kosten-/Missbrauchsgrenzen.

## 1. Uebersicht

Die Spalte "durchgesetzt?" bezieht sich auf das konkrete Website-Versprechen,
nicht auf irgendein existierendes Rate-Limit.

| Limit | Durchgesetzt? | Reset korrekt? | Wo im Code | Luecke |
|---|---|---|---|---|
| Events: 3/Woche | Nein aktuell; nach Flag-Aktivierung nur teilweise clientseitig | Montag lokal berechnet; vor blockierender UI-Pruefung kein Reset | [Flags](../lib/config/monetization_config.dart#L44), [Service](../lib/services/events_limit_service.dart#L62), [UI](../lib/ui/events_activities_screen.dart#L1872) | Beta aus; nur KI-Detailpfad; Community-Details umgehen ihn; kein Serverkontingent; lokale Daten loeschbar |
| KI-Beratung: 3 Fragen/Tag | Nein; aktive Ersatzgrenze ist 50/Tag, clientseitig | Lokaler Tageswechsel fuer 50; manipulierbar in beide Datumsrichtungen | [3er-Regel](../lib/logic/entitlement_service.dart#L115), [aktiver Chat](../lib/ui/chat_screen.dart#L729), [50er-Limiter](../lib/services/ai_rate_limiter.dart#L23) | 3er-Pruefung/Tracking ohne produktive Aufrufer; gemeinsam mit Rezepten/Finanz-KI; kein Server-3er-Limit; Premium weiterhin bei 50 geblockt |
| Community: 3 Kontakte/Monat | Nein, weder im Client noch als Server-Abo-Regel | Kein Monatszaehler und kein Monatsreset | [Konfiguration](../lib/config/monetization_config.dart#L70), [Client](../lib/logic/friendship_service.dart#L163), [Server](../backend/server.js#L9765) | Flag und Zahl ohne Verbraucher; Freundesanfragen, Matching und Annahmen ohne Monatskontingent |
| Rezepte: 1/Tag | Nein; nur gemeinsames 50er-KI-Budget | Nur Tagesreset des gemeinsamen KI-Budgets; kein Rezeptreset | [Konfiguration](../lib/config/monetization_config.dart#L62), [Generator](../lib/logic/family_recipe_service.dart#L191), [Rezeptsuche](../lib/logic/family_recipe_service.dart#L311) | Kein eigener Rezeptzaehler; Flag nicht am Generator; lokale Fallbacks liefern weiter Rezepte; Premium bleibt im 50er-Budget |
| Familien-Geld: Free nur Uebersicht; persoenlicher Check Premium | Nein, weder Client-Gate noch Server-Abo-Gate | Nicht anwendbar: Feature-Berechtigung, kein Zeitkontingent | [Flag](../lib/config/monetization_config.dart#L78), [persoenlicher Wegweiser](../lib/ui/familien_geld_screen.dart#L988), [Agent](../lib/logic/benefit_guide_agent.dart#L33) | Premium-only-Flag ohne Verbraucher; persoenlicher Wegweiser und Quick-Check erreichbar |
| Zusaetzlich: Entwicklungsbericht 1/Jahr | Aktuell nein; nach Master-Flag teilweise clientseitig | Kalenderjahr lokal; blockierende UI prueft veralteten Stand | [Service](../lib/services/development_report_limit_service.dart#L36), [UI](../lib/ui/entwicklung_impulse_screen.dart#L1132) | Kein Serverlimit; nur lokal UID-getrennt; kein Limit-Service-Reload bei Kontowechsel; Tracking auch waehrend Beta |

## 2. Beta und Bestimmung von Free/Premium

### Drei verschiedene Mechanismen, nicht ein einheitlicher Schalter

1. [MonetizationConfig](../lib/config/monetization_config.dart#L11):
   `enabled = false`, `premiumEnabled = false`; Events-, Chat-, Rezept-,
   Netzwerk- und Finanzcheck-Schalter ebenfalls `false`. Kommentare nennen
   ausdruecklich "Fuer Beta" und "Nach Beta". Diese Abschaltung ist beabsichtigt.
   Die Getter in [PremiumService](../lib/services/premium_service.dart#L31)
   begrenzen Events/Chat/Rezepte nur mit Master-Flag UND jeweiligem Flag UND
   `!isPremium`.
2. [AccessConfig](../lib/config/access_config.dart#L4):
   `PP_BETA_FREE_ACCESS` ist ein Dart-Build-Define mit Standard `true`.
   [ParentUser.hasFullAccess](../lib/logic/auth_service.dart#L124) gibt dann
   pauschal `true` zurueck. Der [App-Einstieg](../lib/main.dart#L775) laesst
   Nutzer dadurch an der allgemeinen Paywall vorbei.
   Der [Web-Build](../.github/workflows/deploy-web-pages.yml#L90) verwendet
   ebenfalls standardmaessig `true`. Die gezielte GitHub-Variablenabfrage
   ergab keine gesetzten `PP_BETA_FREE_ACCESS`-/`PP_PUBLIC_LAUNCH_DATE`-Variablen.
   Damit gilt fuer diesen Workflow der Beta-Default; ein konkreter installierter
   App-Build oder die laufende Backendkonfiguration wurde nicht ausgelesen.
3. [FeatureFlagService](../lib/config/feature_flags.dart#L74):
   Alle registrierten Features sind aktuell `phase1` und `availableInFreeTier: true`.
   Das ist grundsaetzlicher Feature-Zugang, keine Mengenbegrenzung.
   `freeTierLimit` ist nur Metadaten/Anzeigetext.

Beta-Vollzugriff ist **nicht** dasselbe wie `EntitlementService.isPremium`.
Der Server kann korrekt `free` liefern, waehrend Beta Zugang zur App erlaubt.

### Vertrauensquelle fuer den eigentlichen Abo-Tier

- [GET /entitlements/me](../backend/server.js#L7662) verlangt einen verifizierten
  Nutzer und liest dessen dauerhaften DB-Datensatz
  [UserEntitlement](../backend/prisma/schema.prisma#L48).
- [readEntitlementSnapshot](../backend/entitlement_store.js#L42) legt fehlende
  Datensaetze als `free`/`none` an. Kein automatischer Beta-Premium- oder
  30-Tage-Trial-Eintrag.
- [buildEntitlementSnapshot](../backend/entitlement_store.js#L9) akzeptiert
  Premium nur mit `active`/`trial`/`grace`, Verifikation, begonnenem und noch
  nicht abgelaufenem Zeitraum sowie ohne Widerruf. Zeitbasis ist Serverzeit,
  `new Date()`. Abgelaufene/widerrufene Zustaende werden normalisiert.
- [EntitlementService.refreshEntitlements](../lib/logic/entitlement_service.dart#L146)
  uebernimmt nur den Backend-Snapshot. Fehler bleiben `unavailable`, nicht
  automatisch Free/Premium. [PremiumService](../lib/services/premium_service.dart#L14)
  ist nur eine Fassade darauf. Lokale alte Premium-/Promo-Daten zaehlen nicht.
- [Premium-Aktivierungsroute](../backend/server.js#L7673) liefert `410`:
  Store-Verifikation ist noch nicht implementiert. Auch
  [AuthService.activatePremium](../lib/logic/auth_service.dart#L1010) aktiviert
  nichts. Ein freigegebener, funktionierender Premium-Kauf ist hier nicht belegt.
- [Client-Parsing](../lib/logic/entitlement_service.dart#L66) prueft
  Premium-Zeitraeume zusaetzlich mit Geraetezeit. Der spaetere
  [isPremium-Getter](../lib/logic/entitlement_service.dart#L36) prueft aber nicht
  erneut `validUntil`: Ein geladener Snapshot bleibt bis zum naechsten Refresh
  Premium, selbst wenn seine Laufzeit inzwischen endet. Refresh erfolgt beim
  [App-/Account-Einstieg](../lib/main.dart#L645), nicht pro kostenpflichtiger
  Aktion. Es gibt hier keinen Ablauf-Timer.

### Zusaetzliches Startproblem nach der Beta

Nur `PP_BETA_FREE_ACCESS=false` zu setzen erzeugt noch kein Freemium-Produkt:
[ParentUser.hasFullAccess](../lib/logic/auth_service.dart#L124) faellt nach dem
lokal berechneten Trial auf `false`, und [main](../lib/main.dart#L775) zeigt dann
eine allgemeine Paywall statt dauerhaft nutzbarer Free-Features.
Zudem ignoriert dieser Getter den eigentlichen Entitlement-Snapshot.
Trial/App-Zugang, Abo-Tier und Feature-Kontingente muessen fuer den Launch
zusammenpassen; Flags allein loesen das nicht.

## 3. Events: echte Aufrufpfade und Wochenreset

[EventsLimitService](../lib/services/events_limit_service.dart#L16) speichert
`events_limit.view_count` und `events_limit.week_start` in SharedPreferences,
ohne UID. Es zaehlt **Detailoeffnungen**, nicht entdeckte eindeutige Events.
Dasselbe Event erneut zu oeffnen verbraucht erneut eine Nutzung.

Der [Wochenreset](../lib/services/events_limit_service.dart#L78) berechnet mit
`DateTime.now()` und `DateTime(year, month, day - weekday + 1)` Montag 00:00
in der lokalen Geraetezeitzone. Reset nur, wenn die aktuelle Woche nach der
gespeicherten liegt, nicht bei Rueckstellung.

**Reale Reset-Luecke:** `isLimitReached` selbst prueft keinen Wochenwechsel.
[_showAiDetails](../lib/ui/events_activities_screen.dart#L1872) blockiert zuerst
damit und erreicht erst danach `recordEventView()`, wo der Reset stattfindet.
Wer bei laufender App das Limit der Vorwoche erreicht hat, kann in der neuen
Woche weiterhin blockiert bleiben, bis `initialize()` erneut laeuft.
Auch `remaining` kann veraltet sein.

**Abdeckungsluecke:** [Community-Feed-Details](../lib/ui/events_activities_screen.dart#L847)
oeffnen `EventDetailScreen` direkt; nur der KI-Pfad geht durch `_showAiDetails`.
Die Suche in [EventDiscoveryAgent](../lib/logic/event_discovery_agent.dart#L39)
prueft das Wochenkontingent nicht und kann mehr als drei Treffer liefern.
Der [Backend-Detailendpunkt](../backend/server.js#L15443) prueft
Event-/Teilnahmeberechtigungen, aber kein Abo-Wochenkontingent.
Der Rueckgabewert von [recordEventView](../lib/ui/events_activities_screen.dart#L1898)
wird ausserdem weder abgewartet noch ausgewertet.

## 4. KI-Beratung: 3 vorbereitet, 50 tatsaechlich aktiv

Die [3er-Regel](../lib/logic/entitlement_service.dart#L277) existiert in
`checkAccess('ki_elternberatung')`. Fuer die produktiven Aufrufer von
`checkAccess()` und `recordUsage()` wurden jedoch keine Verwendungen ausserhalb
des Services gefunden. [Home](../lib/ui/home_screen.dart#L388) verwendet nur
`canAccessSync()`, das **keine Mengenlimits** prueft.

Der aktive [Chat](../lib/ui/chat_screen.dart#L729) verwendet stattdessen
`AIRateLimiter.initialize()` und `canMakeRequest()`, und zaehlt nach erfolgreicher
Antwort bei [normalen Fragen](../lib/ui/chat_screen.dart#L777) sowie
[Tipp-Erweiterungen](../lib/ui/chat_screen.dart#L715).
Der [echte Standard](../lib/services/ai_rate_limiter.dart#L23) ist **50**, nicht
3 und auch nicht 25 wie im veralteten Klassenkommentar.
`setDailyLimit()` hat keinen produktiven Aufrufer; Premium wird nicht geprueft.

**Tagesreset:** [initialize](../lib/services/ai_rate_limiter.dart#L30) und
[_ensureTodayReset](../lib/services/ai_rate_limiter.dart#L96) vergleichen eine
lokale Datumszeichenfolge aus `DateTime.now()`. Jede Datumsabweichung setzt
zurueck, auch beim Zurueckstellen des Geraets. SharedPreferences sind nicht
kontogetrennt.

Die vorbereitete [Entitlement-Tagesregel](../lib/logic/entitlement_service.dart#L313)
verwendet lokale Tages-Schluessel
`entitlement.usage.<feature>.<YYYYMMDD>`, ebenfalls ohne UID.
Es gibt keinen Timer: Ein neuer Tag liest einen neuen Zaehler.
Bei Rueckkehr auf einen schon benutzten Tag lebt dessen alter Zaehler wieder auf.
Ein unbenutztes anderes Datum hat hingegen einen leeren Zaehler.

Pruefung und nachtraegliches Aufzeichnen der KI-Nutzung sind keine atomare
Reservierung. Parallele Aufrufe verschiedener Screens koennen den Restplatz
gleichzeitig als frei sehen. App-Abbruch vor dem lokalen Tracking kann eine
bereits serverseitig ausgefuehrte Anfrage ungezaehlt lassen.

Die alte [ChatScreenGemini](../lib/ui/chat_screen_gemini.dart#L51) hat gar keinen
lokalen Limiter; fuer diesen Screen wurde aber kein produktiver Aufrufer gefunden.
Das ist ein ungeschuetzter Altpfad, **kein nachgewiesener aktuell erreichbarer
UI-Umgehungsweg**. Entscheidend ist ohnehin der unlimitierte gemeinsame
[GeminiAIService](../lib/logic/gemini_ai_service.dart#L85).

### Was der Server wirklich begrenzt

[POST /ai/generate](../backend/server.js#L4610) liest keine Entitlements und
keinen Feature-Kontingentzaehler. Client-Anfragen enthalten auch keinen
dedizierten Quotentyp fuer Chat/Rezept/Finanzen.

- Standard **30 Anfragen/15 Minuten**, Schluessel Firebase-UID, sonst IP:
  [Konfiguration](../backend/server.js#L218),
  [Pruefung](../backend/server.js#L4617).
- Die [Implementierung](../backend/server.js#L244) ist trotz Kommentar kein
  echtes Sliding-Window: Fenster ab erster Anfrage, Reset wenn
  `Date.now() - start > windowMs`.
- Global **2000 Proxy-Anfragen pro UTC-Tag**, konfigurierbar, `0` deaktiviert:
  [Budget](../backend/server.js#L232),
  [UTC-Reset](../backend/server.js#L257).
- Beide Zustandscontainer leben nur im Prozessspeicher. Neustart oder mehrere
  Instanzen teilen kein dauerhaftes Budget.
- Beide gelten auch fuer Premium. Das globale Budget zaehlt Proxy-Anfragen,
  nicht sicher jede interne Gemini-Anfrage; weitere Aufrufe wie der
  [KI-Healthcheck](../backend/server.js#L4513) sind kein Free-Tageskontingent.

Diese Schutzgrenzen sind sinnvoll und sollten nicht mit dem Free-Produktlimit
verwechselt werden. Produktionswerte der Backend-Umgebungsvariablen wurden
nicht verifiziert.

## 5. Rezepte: kein eigenstaendiges 1/Tag-Limit

[generateRecipe](../lib/logic/family_recipe_service.dart#L191) und
[generateRecipeFor](../lib/logic/family_recipe_service.dart#L311) pruefen nur
das gemeinsame 50er-KI-Budget. Es gibt keinen eigenen Rezeptverbrauch,
keine Nutzung von `freeRecipesPerDay`, keinen wirksamen Anschluss von
`shouldLimitRecipes` an diese Generatoren.
Das [PremiumGate](../lib/ui/widgets/premium_gate.dart#L43) liefert fuer Chat
und Rezepte ausdruecklich noch `false` mit TODO.

Der [Kuechen-Screen](../lib/ui/familien_kueche_screen.dart#L86) generiert bei
erneutem Aufruf wieder; sein Tagesrezept ist keine technische Tagesquote.
Bei nicht erteilter KI-Einwilligung liefert er ein
[lokales Rezept](../lib/logic/family_recipe_service.dart#L172).
Bei erschoepftem KI-Budget liefert `generateRecipe()` ebenfalls ein lokales
Fallback statt eines Abo-Gates; `generateRecipeFor()` wirft dagegen eine
Rate-Limit-Exception. Das ist unterschiedlich, aber kein 1-Rezept-Limit.

Auch [Kuehlschrank-Fotoanalyse](../lib/logic/fridge_recipe_service.dart#L102)
und [Kuehlschrank-Rezeptgenerierung](../lib/logic/fridge_recipe_service.dart#L174)
verbrauchen denselben KI-Zaehler. Eine Fotoanalyse ist schon eine Nutzung,
auch bevor ein Rezept vorliegt. Rezepte, Chat und Finanz-Wegweiser beeinflussen
dadurch gegenseitig ihre Verfuegbarkeit.

Ob "1 Rezept" kuenftig nur eine neue KI-Generierung, auch lokale Vorschlaege
oder sogar Community-/gespeicherte Rezeptansichten meint, muss fachlich
festgelegt werden. Aktuell gibt es fuer keine dieser Lesarten eine vollstaendige
1/Tag-Durchsetzung. Lokale Sicherheits-Fallbacks sind nicht pauschal als Bug
einzustufen.

## 6. Community: kein 3-Kontakte-/Monatsmechanismus

`networkLimitEnabled` und `freeNetworkContactsPerMonth` existieren nur als
[Definitionen](../lib/config/monetization_config.dart#L70).

Die aktuelle [Netzwerk-UI](../lib/ui/eltern_netzwerk_screen.dart#L2612) sendet
ueber [FriendshipService.sendRequest](../lib/logic/friendship_service.dart#L163)
an `/api/friendships/request`. Weder Client noch
[Serverhandler](../backend/server.js#L9765) pruefen ein Monatskontingent.
Auch [Matching-Aktionen](../backend/server.js#L8943), deren
[Client](../lib/logic/parent_matching_backend_service.dart#L716), automatische
[Match-Freundschaften](../backend/server.js#L8924) und
[Annahmen](../backend/server.js#L9800) haben kein Abo-Monatslimit.
Auth, Blockierungen und Freundschaftsstatus sind andere Regeln.

**Kein monatlicher Reset vorhanden**: kein Verbrauchszaehler und keine
Monatsgrenze zu berechnen. Der allgemeine Schreib-Rate-Limiter ist keine
3-Kontakte-Quote.

ParentCoins wurden absichtlich entfernt. Die vorhandene
[Regression](../test/network_no_parentcoins_test.dart#L10) verbietet ihre
Wiedereinfuehrung. Das fehlende Kontaktlimit darf nicht mit einem angeblich
noch wirksamen Coin-System erklaert werden.
Vor einer Implementierung muss klar sein, ob "Kontakt" eine neue eindeutige
Kontaktanfrage oder erst eine bestaetigte Verbindung bedeutet und ob eingehende
Annahmen, bekannte Freunde und Familienkreis darunter fallen.

## 7. Familien-Geld: persoenlicher Check nicht Premium-only

`financeCheckPremiumOnly` ist nur eine
[Konfigurationsdefinition](../lib/config/monetization_config.dart#L78).
Der [Leistungen-Tab](../lib/ui/familien_geld_screen.dart#L930) zeigt den
persoenlichen KI-Wegweiser und den
[Eligibility-Quick-Check](../lib/ui/familien_geld_screen.dart#L1700) ohne Abo-Gate.
Der [Wegweiser-Einstieg](../lib/ui/familien_geld_screen.dart#L988) navigiert direkt.

[BenefitGuideAgent.guide](../lib/logic/benefit_guide_agent.dart#L33) verlangt
Einwilligung und das gemeinsame lokale KI-Budget, aber kein Premium.
Seine KI geht ueber den gleichen Serverproxy ohne Abo-Pruefung.
Die [Antrags-Textvorlage](../lib/ui/antragshelfer_screen.dart#L831) verwendet
den gemeinsamen Gemini-Service sogar ohne AIRateLimiter.
Das ist nicht automatisch Teil desselben Produktversprechens, zeigt aber,
dass persoenliche Finanzfunktionen nicht zentral nach Abo klassifiziert sind.

Ein Zeitreset ist fuer diesen Feature-Lock nicht erforderlich. Beim Launch
muss Uebersicht frei bleiben und nur die definierte persoenliche Pruefung
zuverlaessig Premium verlangen.

## 8. Entwicklungsberichte: zusaetzliches Jahreslimit

[DevelopmentReportLimitService](../lib/services/development_report_limit_service.dart#L59)
speichert lokal nach UID, sofern beim Aufruf angemeldet, sonst in ungescopten
Schluesseln. Der [Reset](../lib/services/development_report_limit_service.dart#L104)
vergleicht `DateTime.now().year`: **Kalenderjahr**, nicht zwoelf Monate seit
dem letzten Bericht; jede Jahresabweichung setzt zurueck.

- Der Master-Monetarisierungsschalter ist aktuell aus, also kein Free-Limit.
- Die [UI-Vorpruefung](../lib/ui/entwicklung_impulse_screen.dart#L1133) verwendet
  `isLimitReached` ohne Jahresreset. Bei offener App kann der erste Bericht
  im neuen Jahr blockiert bleiben, bevor `recordReportCreated()` den Reset erreicht.
- `initialize()` laeuft beim [App-Start](../lib/main.dart#L160); in den
  Login-/Logout-Pfaden wurde kein erneutes Initialisieren gefunden.
  Der Singleton behaelt den vorigen Kontostand, waehrend `_persist()` die
  aktuelle UID verwendet: lokale UID-Schluessel allein garantieren deshalb
  keine Kontotrennung im laufenden Prozess.
- [Tracking](../lib/services/development_report_limit_service.dart#L82)
  zaehlt auch waehrend Beta und bei Premium. Ein spaeteres Einschalten kann
  dadurch bereits vorhandenen Beta-Verbrauch gegen Free anrechnen.
- [DevelopmentReportService.generate](../lib/logic/development_report_service.dart#L30)
  selbst hat keine Quotenpruefung; das Jahreslimit liegt in der UI.
  Die UI speichert den Bericht vor dem nachtraeglichen Tracking und ignoriert
  dessen boolesche Ablehnung.

## 9. Umgehbarkeit und Reset-Zusammenfassung

| Veraenderung | Tatsaechliche Wirkung |
|---|---|
| Normales Logout/Login auf demselben Geraet | [Logout](../lib/logic/auth_service.dart#L844) verwirft Entitlements und den lokalen Session-Owner, nicht pauschal SharedPreferences. KI-/Event-/Entitlement-Verbrauch bleibt; kein belegter einfacher Reset durch Logout allein. |
| Anderes Konto auf demselben Geraet | KI, Events und vorbereitete Entitlement-Tagesquote teilen lokale Schluessel. Konten beeinflussen einander statt sauber getrennt zu sein. Entwicklungsberichte haben UID-Schluessel, aber veralteten Singleton-Zustand. |
| Appdaten loeschen / Browser-Storage leeren | Loescht die lokalen Quoten. Neuinstallation kann sie ebenfalls loeschen; Wiederherstellung aus Plattform-Backups ist plattformabhaengig. Keine dieser Quoten ist serverseitig dauerhaft gespeichert. |
| Zweites Geraet / anderer Browser | Eigene lokale Quoten fuer dasselbe Konto. Server-KI-Abusegrenze kann dennoch weiter greifen; kein dauerhaftes konto-weites Free-Kontingent. |
| Geraetedatum oder Zeitzone aendern | KI: Datumsabweichung in beide Richtungen setzt zurueck. Entitlement: unbenutzter Tages-Key ist leer. Events: erst spaetere Woche setzt zurueck; Rueckstellung nach Zukunftssprung kann dagegen bis zur gespeicherten Woche blockieren. Bericht: anderes Jahr setzt zurueck, sofern Resetpfad erreicht. |
| App bleibt ueber Wochen-/Jahreswechsel offen | Events und Berichte koennen vor dem Reset geblockt werden, weil ihre blockierenden Getter keinen Reset ausfuehren. |
| Backendneustart / mehrere Instanzen | Prozesslokale KI-Abuse-/Tagesbudgets werden nicht dauerhaft bzw. instanzuebergreifend geteilt. Entitlements selbst sind dagegen DB-persistent. |

Der Server-Tier ist damit deutlich robuster als die lokalen Verbrauchsregeln.
Premium hebt die lokalen Events-/Berichts-Gates bei aktivierter Monetarisierung
auf, **nicht** das gemeinsame 50er-KI-Limit und nicht die Server-Kostengrenzen.
Sinnvolle Missbrauchsgrenzen fuer Premium sind von beworbenen Produktkontingenten
zu unterscheiden.

## 10. Validierung und Grenze der Aussage

Keine Produktionskonten, Secrets, echten KI-Generierungen oder schreibenden
Produktions-API-Aufrufe verwendet.

Ausgefuehrt im Audit-Worktree:

1. `flutter analyze --no-pub`: zunaechst fehlende Paketkonfiguration im neuen
   Worktree. Nach `flutter pub get` erneut ausgefuehrt:
   **Exit 1, neun vorbestehende Info-Diagnosen, null Fehler/Warnings.**
   Der Appcode und alle versionierten Abhaengigkeitsdateien sind unveraendert.
   Daher kann "sauber" im Sinne von Exit 0 nicht ehrlich zugesichert werden.
   Keine fremden Lintstellen fuer diesen Analyseauftrag korrigiert.
2. `flutter test --no-pub test/entitlement_service_test.dart test/network_no_parentcoins_test.dart`:
   **10 Tests bestanden**.
3. `cd backend && NODE_PATH=/Users/aram/Parentpeak-1/backend/node_modules API_BASE=http://127.0.0.1:9 node --test tests/unit/ai-rate-limit.test.js tests/unit/entitlement-source.test.js tests/unit/recipes-entitlements-scope.test.js`:
   **33 Tests bestanden**. Abhaengigkeiten nur aus dem vorhandenen Checkout,
   Produktionsaufrufe ausgeschlossen; lokale Fixtures/Mock-DBs.
4. Zusaetzlicher temporaerer Flutter-Test ausserhalb des Repositorys:
   **3 Tests bestanden** gegen die unveraenderten echten Services:
   - Verifizierter Premium-Snapshot, 50 Nutzungen erlaubt, 51. lokal blockiert.
   - Gespeicherter Vortag UND gespeicherter Folgetag mit erschoepfter KI-Quote
     werden beim Initialisieren am aktuellen Tag jeweils auf null gesetzt.
   - Vorbereitete Entitlement-Pruefung blockiert nach 3 Nutzungen, aber
     `canAccessSync()` erlaubt weiterhin; Logout/Refresh behaelt den Zaehler,
     geleerte lokale Daten setzen ihn zurueck.
   Der Test war nur ein Nachweis, keine Aenderung an Produktivlogik.
5. `gh variable list --repo arambucak/Parentpeak --json name,value --jq '.[] | select(.name == "PP_BETA_FREE_ACCESS" or .name == "PP_PUBLIC_LAUNCH_DATE")'`:
   **Erfolgreich, keine passenden Repositoryvariablen gesetzt**.

Vorhandene Entitlement-Tests pruefen unter anderem den deaktivierten
Event-Schalter und den Montag-Reset beim Initialisieren. Sie beweisen **nicht**,
dass ein aktivierter Free-Nutzer beim vierten Event ueber alle Einstiegspfade
gesperrt wird. Kein aktiviertes End-to-End-Abo-System wurde vorgetaeuscht.

Die neun Analyze-Infos liegen bei:
[Admin-Moderation](../lib/ui/admin_moderation_screen.dart#L78) (78, 84, 90),
[Entwicklungs-Screen](../lib/ui/entwicklung_impulse_screen.dart#L1645) (1645),
[Kueche](../lib/ui/familien_kueche_screen.dart#L1045) (1045, 1120, 1121, 1128, 1130).

## 11. Entscheidung vor den Fixes

**Noch nichts scharfgeschaltet.** Fuer eine spaetere Umsetzung reicht
Vorbereitung nicht: benoetigt werden dauerhafte, atomare serverseitige
Kontingente mit einer festgelegten Server-Zeitzone, konsistente Clientanzeigen
und Schutz aller relevanten Einstiegspfade.

Vor der Implementierung festlegen:

- Events: Detailoeffnungen oder eindeutige entdeckte Events? Community ebenfalls?
- Kontakte: neue eindeutige Anfragen oder bestaetigte Verbindungen?
- Rezepte: KI-Generierungen oder auch lokale/gespeicherte/Community-Rezepte?
- Einheitliche Zeitbasis und genaue Wochen-/Monatsgrenzen.
- Abgrenzung von Trial, dauerhaftem Free-Tier, verifiziertem Premium und
  weiterhin sinnvollen Kosten-/Missbrauchsgrenzen.

Abnahme muss die **4. Frage**, das **4. Event**, den **4. Monatskontakt**,
das **2. Tagesrezept** und den **persoenlichen Finanzcheck fuer Free** konkret
testen, dazu Premium, alle Resetgrenzen, parallele Anfragen, Kontowechsel,
Neuinstallation/zweites Geraet und Serverneustart. Erst nach Freigabe werden
die Regeln wirklich aktiviert und anhand dieser Ergebnisse abgenommen.
