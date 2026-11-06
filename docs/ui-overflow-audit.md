# UI-Overflow-Audit

## Umfang und Ergebnis

Basis: `origin/main` bei `2a52899`, separater Worktree, Branch
`fix/i18n-overflow-audit`. Keine Aenderungen am Haupt-Checkout.

Der statische Scan erfasste 119 Dart-Dateien unter `lib/ui`: Rows und
AppBar-Titel, feste Textdimensionen, Grids, Tabs, Chips, Buttons und Sheets.
211 durch AST-Heuristiken markierte Row-Kandidaten wurden gesichtet; solche
Treffer sind nicht automatisch Fehler, beispielsweise bei bereits begrenzten
Unterlayouts oder reinen Icon-Zeilen.

Die Regressionstests rendern echte Produktionswidgets, keine nachgebauten
Layoutkopien. Die Matrix umfasst 34 Szenarien in `tr`, `fr`, `ar`, jeweils
360 x 640 mit Android-Target und 390 x 844 mit iOS-Target sowie Textskalierung
1.3 und 1.5: **408 erfolgreiche Widget-Tests**.
Arabisch verwendet die echte Locale und RTL-Directionality. Zielplattform-
Varianten im Widget-Test ersetzen keinen nativen Simulator oder ein Geraet.

Uebersetzungen, Preise, Premium-/Beta-Kommunikation, Feature-Flags und
Berechtigungslogik bleiben unveraendert. Die drei ausdruecklich geschuetzten
Screens wurden nicht bearbeitet.

## Gefixte Stellen

Die folgenden Layouts sind in der Matrix abgedeckt. Die Problemspalte benennt
das Risikoszenario, nicht die Behauptung, dass jede einzelne Kombination zuvor
fehlerhaft war. Einige bereits deutsche, nicht lokalisierte Beschriftungen
ueberliefen ebenfalls bei grosser Schrift; deren Texte wurden nicht geaendert.
Zeilen beziehen sich auf diesen Stand.

| Stelle | Problem / betroffene Situation | Aenderung |
|---|---|---|
| [Home:888](../lib/ui/home_screen.dart#L888) | Feature-Ueberschrift konkurriert mit dem Alle-Link; lange Labels, schmaler Screen. | Ueberschrift `Expanded`, Abstand und opake Link-Treffflaeche. |
| [Home:951](../lib/ui/home_screen.dart#L951), [Home:1513](../lib/ui/home_screen.dart#L1513) | Fixes Seitenverhaeltnis und einzeilige kompakte Kacheln begrenzen lange Feature-Texte. | Schriftabhaengige Kachelhoehe; Titel bis vier, Untertitel bis drei Zeilen. |
| [Home:1094](../lib/ui/home_screen.dart#L1094) | Vier Schnellaktionen teilen sich eine Row ohne begrenzte Labelbreiten. | Gleichmaessige `Expanded`-Spalten und zentrierter Umbruch. |
| [Home:1305](../lib/ui/home_screen.dart#L1305) | Alle-Features-Sheet: fixe Grid-Proportionen reichen bei 1.3/1.5 nicht fuer Icon plus Label. | Schriftabhaengige Hoehe, bis vier Labelzeilen, opake Trefflaechen. |
| [Kontextkarte:575](../lib/ui/widgets/home/context_home_card.dart#L575), [777](../lib/ui/widgets/home/context_home_card.dart#L777), [916](../lib/ui/widgets/home/context_home_card.dart#L916) | Lange Namen sprengen Morgen-, Abend- und Nachtbegruessungen neben dem Emoji. | Begruessungen `Expanded`; frei umbrechender Text. |
| [Kontextkarte:840](../lib/ui/widgets/home/context_home_card.dart#L840) | Wochen-Link konkurriert mit Pfeil; fuenf Stimmungslabels sind horizontal unbegrenzt. | Linktext `Expanded`; [Stimmungen:1101](../lib/ui/widgets/home/context_home_card.dart#L1101) als gleich breite, umbrechende Aktionen. |
| [Schnellaktionen:81](../lib/ui/widgets/home/quick_actions_row.dart#L81) | Lange Labels und dreistellige Kalender-Badges bei grosser Schrift; Badge bislang rechts festgelegt. | `Expanded`, Umbruch, opake Trefferflaechen; wachsendes Badge und `PositionedDirectional`. |
| [Kalender:687](../lib/ui/calendar_screen.dart#L687) | Termin-Sheet-Titel laeuft gegen Schliessen-Icon; Vorlagen haben fixe 40 px Hoehe. | Titel `Expanded`, Vorlagenhoehe folgt der Schrift. Auch mit Tastatur getestet. |
| [Kalender:1429](../lib/ui/calendar_screen.dart#L1429) | Wochentag und Terminanzahl konkurrieren in einer Row. | `Wrap` statt Row/Spacer. |
| [Kalender:2039](../lib/ui/calendar_screen.dart#L2039) | Sieben Wochentagslabels sowie zweistellige Tage in kleinen Zellen. | Gleich breite, umbrechende Labels; skalierende Zellen; nur die Tageszahl wird bei Bedarf herunterskaliert. |
| [Kalender:2745](../lib/ui/calendar_screen.dart#L2745) | Start-/Ende-Label plus Uhrzeit ueberlaufen im Terminformular. | `Wrap` innerhalb der Zeitbuttons. |
| [Chat:1930](../lib/ui/chat_screen.dart#L1930) | Datenschutz-Footer im tatsaechlich freigegebenen Chat war horizontal unbegrenzt. | Seitliches Padding, `Flexible`, zentrierter Umbruch. Der AppBar-Fix aus #288 bleibt bestehen. |
| [Treffen:130](../lib/ui/meetup_screen.dart#L130) | Filter-/Ansichtsbereich verbraucht bei langen Texten zu viel feste vertikale Flaeche. | Gesamter Inhalt als lazy `CustomScrollView`; Filterkopf `Wrap`, Ansichtslabel `Expanded`. |
| [Treffen:354](../lib/ui/meetup_screen.dart#L354) | Kleine Grid-Karten lassen wenig Raum fuer grosse Schrift. | Mobile einspaltig, ab 500 px zweispaltig; skalierende Kartenhoehe. Der Feed-Leerzustand ist dynamisch getestet, gefuellte Server-Feeds bleiben eine Geraetepruefung. |
| [Event erstellen:58](../lib/ui/create_event_screen.dart#L58), [1054](../lib/ui/create_event_screen.dart#L1054) | Starre Datum-/Zeit-Controlhoehen schneiden mehrzeilige Uebersetzungen ab. | Natuerlich wachsende Controls, weiterhin schriftabhaengige Mindesthoehe; vorhandenes responsives Stapeln bleibt erhalten. Der bestehende 320-px-/2x-Schrift-Test bleibt gruen. |
| [Kueche:544](../lib/ui/familien_kueche_screen.dart#L544) | Rezept-Aufklapptext kollidiert mit Pfeil. | `Expanded` statt unbeschraenktem Text/Spacer. |
| [Kueche:705](../lib/ui/familien_kueche_screen.dart#L705) | Bewertungsfrage und beide Antwortchips ueberlaufen gemeinsam. | `Wrap` fuer Frage und Aktionen, ohne Inhaltskuerzung. |
| [Kueche:993](../lib/ui/familien_kueche_screen.dart#L993), [1010](../lib/ui/familien_kueche_screen.dart#L1010) | Speicher-Sheet: Titel kollidiert mit Schliessen; dekorierter Hintergrund verdeckt ListTile-Ink. | Titel `Expanded`; gleichfarbige `Material`-Oberflaeche statt verdeckendem Container. |
| [Entwicklung:489](../lib/ui/entwicklung_impulse_screen.dart#L489) | Offline-Label neben Icon; lange Uebersetzung und grosse Schrift. | Label `Expanded`. |
| [Entwicklung:2114](../lib/ui/entwicklung_impulse_screen.dart#L2114) | Stimmungsfrage und Antwortaktionen konkurrieren horizontal. | Frage und Aktionen untereinander, Antworten in `Wrap`. |
| [Expertenbibliothek:216](../lib/ui/widgets/expert_bibliothek_section.dart#L216) | Typ-Badge und Dauerangabe konkurrieren. | Header `Wrap` statt Row/Spacer. |
| [Marktplatz:589](../lib/ui/marketplace_screen.dart#L589), [645](../lib/ui/marketplace_screen.dart#L645), [685](../lib/ui/marketplace_screen.dart#L685) | Kategorie-Grid mit fixem Seitenverhaeltnis und langen Labels. | Beide Grids skalieren mit der Schrift; Kartenpadding, bis drei Labelzeilen, opake Trefferflaechen. |
| [Familien-Zentrale:315](../lib/ui/familien_zentrale_screen.dart#L315) | Lange Tabs und eigene fixe Icon-/Label-Column schneiden bei hoher Schrift ab. | Scrollbare, startausgerichtete Tabs; nativer Icon-/Text-Tab mit Badge. |
| [Familien-Geld:606](../lib/ui/familien_geld_screen.dart#L606), [637](../lib/ui/familien_geld_screen.dart#L637) | Flagge, Titel und Actions sowie lange Tab-Namen konkurrieren. | Titel `Flexible` mit Ellipse, Tabs scrollbar und startausgerichtet. |
| [Familien-Geld:1125](../lib/ui/familien_geld_screen.dart#L1125) | Leistungsname und Status-Badge konkurrieren; Badge selbst unbeschraenkt. | Name ueber dem Badge; Badge-Text `Flexible`. |
| [Familien-Geld:2040](../lib/ui/familien_geld_screen.dart#L2040) | Sparstand und Zielbetrag passen nicht nebeneinander. | `Wrap` mit vertikalem Abstand. Keine Aenderung an Premium-Gates. |
| [GemeinsamSatt:757](../lib/ui/gemeinsam_satt_screen.dart#L757) | Zweizeiliger AppBar-Kopf kollidiert mit Actions. | `Flexible`, pro Titelzeile maximal eine Zeile mit Ellipse. |
| [GemeinsamSatt:1123](../lib/ui/gemeinsam_satt_screen.dart#L1123) | Wochenkopf und Fehlerhinweis bleiben ausserhalb der Liste; hohe Schrift nimmt den Platz fuer Tage weg. | Gemeinsame scrollbare Liste; Wochenkopf `Wrap`, Reload-Button `Flexible`. |
| [GemeinsamSatt:1548](../lib/ui/gemeinsam_satt_screen.dart#L1548) | Hohe Leerzustandsinhalte passen nicht vertikal. | Leerzustand scrollbar. |
| [Rituale:939](../lib/ui/ritual_ruhe_screen.dart#L939) | Abendgeschichten-Titel laeuft neben dem Icon ueber. | Titel `Expanded`, freier Umbruch. |
| [Rituale:1185](../lib/ui/ritual_ruhe_screen.dart#L1185), [1256](../lib/ui/ritual_ruhe_screen.dart#L1256) | Plan-Editor ist schon ohne Tastatur zu hoch; Schritt-/Speichern-Buttons ueberlaufen. | Editor scrollbar mit Tastaturabstand; Footer `Wrap`. Abendzustand und anschliessender Morgen-Editor getestet. |
| [Rituale:1276](../lib/ui/ritual_ruhe_screen.dart#L1276) | Kinder-Leerzustand zu hoch fuer kleine Screens. | Scrollbarer Leerzustand. |
| [Login:801](../lib/ui/auth/login_screen.dart#L801) | Social-Login hat fixe 48 px und unbeschraenktes Label neben Icon. | Mindesthoehe statt fixer Hoehe; Label `Flexible` und zentriert. |
| [Familienprofil:1800](../lib/ui/family_profile_screen.dart#L1800) | Schutzstatus-Text neben Icon horizontal unbegrenzt. | Textspalte `Expanded`. |
| [Familienprofil:2101](../lib/ui/family_profile_screen.dart#L2101) | Aktives Mitglied mit langem Namen sprengt Chip/Row. | Chip und Name flexibel; Name bis zwei Zeilen. |
| [Familienprofil:2138](../lib/ui/family_profile_screen.dart#L2138) | Mitglieder-Grid mit fixem Seitenverhaeltnis. | Schriftabhaengige Hoehe; Name und Rolle bis zwei Zeilen. |
| [Kontakte:426](../lib/ui/contacts_screen.dart#L426), [450](../lib/ui/contacts_screen.dart#L450) | Feste aufklappende Hero-Hoehe schneidet grosse Texte ab; Hero-Titel unbegrenzt. | Natuerlich hoher Hero unter weiterhin gepinnter AppBar; Titelspalte `Expanded`. |
| [Kontakte:525](../lib/ui/contacts_screen.dart#L525) | Schnellwahlkarten mit fixem Seitenverhaeltnis ueberlaufen vertikal. | Schriftabhaengige Hoehe; Notrufnummern bleiben vollstaendig. |
| [Geraete:107](../lib/ui/device_management_screen.dart#L107), [124](../lib/ui/device_management_screen.dart#L124) | Fixer Hero, Titel und Statistik-Pills reichen bei hoher Schrift nicht. | Natuerlich hoher Hero, `Expanded`-Titel und `Wrap` fuer Statistik-Pills; AppBar bleibt gepinnt. |
| [Privatsphaere:40](../lib/ui/privacy_settings_screen.dart#L40), [193](../lib/ui/privacy_settings_screen.dart#L193) | Hero-Titel und Info-Pills horizontal unbegrenzt. | Titel `Expanded`, Pill-Text `Flexible`. |
| [Rechtliches:38](../lib/ui/legal_info_screen.dart#L38) | Hero-Titel neben Icon horizontal unbegrenzt. | Titel `Expanded`. |
| [Tischmoment:293](../lib/ui/tischmoment_screen.dart#L293) | Lokalitaets-/Datenschutzhinweis konkurriert mit Schloss-Icon. | Text `Flexible`, zentrierter Umbruch. |

Toolbar-Titel, begrenzte Kartenlabels und sehr lange Mitgliedernamen duerfen
weiterhin bewusst Ellipsen verwenden. Dies ist kein Anspruch, beliebige
Nutzereingaben vollstaendig in einer Kachel darzustellen. Mehrzeilige
Erklaerungen und Formularinhalte wurden nicht auf Einzeiligkeit reduziert.

## Nur dokumentiert: geschuetzte Screens

Diese Befunde sind **statische Risikostellen, keine dynamisch bestaetigten
Fehler**. Sie wurden wegen der parallelen Arbeit nicht geaendert:

| Stelle | Risiko |
|---|---|
| [Registrierung:212](../lib/ui/auth/register_screen.dart#L212) | Bereits-registriert-Text plus Login-Link als unbegrenzte Row-Geschwister. |
| [Registrierung:567](../lib/ui/auth/register_screen.dart#L567) | Fixe 52-px-Buttonhoehe mit 16-px-Text; Umbruch bei 1.5 kann abgeschnitten werden. |
| [Onboarding:115](../lib/ui/onboarding/onboarding_pages.dart#L115) | Drei Hinweis-Spalten mit eigenem Padding in einer Row; lange Labels. |
| [Onboarding:1044](../lib/ui/onboarding/onboarding_pages.dart#L1044) | Laenderchip mit Flagge und unbegrenztem Namen innerhalb eines Wrap. |
| [Profil & Schutz:508](../lib/ui/profile_safety_screen.dart#L508) | Name plus Bearbeiten-Icon. |
| [Profil & Schutz:646](../lib/ui/profile_safety_screen.dart#L646) | Kindername plus Alter. |
| [Profil & Schutz:1153](../lib/ui/profile_safety_screen.dart#L1153) | Sprachauswahl-Titel plus Schliessen-Icon. |
| [Profil & Schutz:1327](../lib/ui/profile_safety_screen.dart#L1327) | KI-Hinweis-Ueberschrift mit weiterem Row-Inhalt. |

## Testabdeckung und Grenzen

[Die neue Matrix](../test/i18n_overflow_audit_test.dart) prueft:

- Home und geoeffnetes Alle-Features-Sheet; Kontextkarte zu vier festen
  Tageszeiten, lange Namen, Abendstimmung und anschliessenden Wochen-Link.
- Chat nach erteilter Einwilligung, nicht bloss den Einwilligungsbildschirm.
- Kalender einschliesslich Termin-Sheet, Scrollen und 260 px Tastatur-Inset.
- Events, Evententdeckung, Treffen, beide Event-Erstellformulare.
- Kueche mit deterministischem bestehendem Tagesrezept, Bewertungsaktionen
  und geoeffnetem Speicher-Sheet; weitere Rezept-/Essensplan-Screens.
- Familien-Zentrale mit Kinderdaten, alle expliziten Tabs; Familien-Geld mit
  ausgewaehltem Land, allen Tabs und Scrollzustaenden.
- Rituale ohne und mit Kind, Abendgeschichte, Morgenplan-Editor und Tastatur.
- Entwicklung, Wochenrueckblick, Marktplatz, Familienprofil, Kontakte,
  Geraete, Login, Datenschutz und Rechtliches.
- Community-Einstieg und echte Swipe-Karte mit langen Familien-/Ortsnamen.
- Separate Schnellaktionen einschliesslich dreistelligem Badge.

Jeder Fall prueft `tester.takeException()` nach Aufbau und relevanten
Interaktionen. Vertikale Scrollbereiche werden in Mitte und Ende geprueft;
explizite TabController durchgeschaltet. Tab-Texte werden zusaetzlich auf
`RenderParagraph.didExceedMaxLines` geprueft. Firebase Core, Prefs und die
genutzten Backendantworten sind gemockt; keine echten Serverdaten erforderlich.
Die optionale Uhr der Kontextkarte dient deterministischen Tageszeit-Tests;
ohne Injektion bleibt `DateTime.now()` das Produktionsverhalten.

Nicht behauptet wird eine vollstaendige dynamische Pruefung aller 119 Dateien,
aller eingeloggten Community-/Freundeslisten, gefuellter Server-Feeds,
Adminpfade, Formularfehler, Push-/Berechtigungsdialoge oder beliebiger
Nutzereingaben. Ein statischer Scan und 408 erfolgreiche Layoutfaelle sind
kein Beweis fuer die Abwesenheit jedes denkbaren Text-Clippings. Die drei
Tabu-Screens bleiben ausdruecklich ausserhalb der neuen Widget-Matrix.

Eine Testabhaengigkeit wurde direkt deklariert:
`firebase_core_platform_interface`, fuer die offiziellen Firebase-Core-Mocks.
Sie war bereits transitiv installiert; keine Paketversion wurde angehoben.

## Validierung

Aus dem separaten Worktree:

| Befehl | Ergebnis |
|---|---|
| `flutter test --no-pub test/i18n_overflow_audit_test.dart` | 408 bestanden. |
| `flutter test --no-pub test/create_event_scan_date_test.dart test/i18n_overflow_audit_test.dart` | 419 bestanden; vorhandene Mindestgroessen-Regel erhalten. |
| `flutter test --no-pub` | 2304 bestanden, 1 bereits vorgesehener Skip; einschliesslich Sprach-/Rechtschreibtests. |
| `flutter analyze --no-pub` | Exit 1, unveraenderte Baseline: genau 8 Infos `use_build_context_synchronously`, keine neuen Diagnosen. |
| `bash scripts/sync_guard.sh check` | Exit 0; Branch basiert auf `origin/main`, offene Aenderungen erwartungsgemaess gemeldet. Kein `fix` ausgefuehrt. |
| `git diff --check` | Bestanden. |

Alle geaenderten Dart-Dateien wurden mit `dart format` formatiert.
Einige zuvor anders formatierte Screens haben dadurch groessere rein
formatierende Diff-Anteile; die fachlichen Layoutaenderungen sind oben benannt.

**Vor Release empfohlen:** echte iOS- und Android-Geraete bzw. Simulatoren,
Systemschrift auf Maximum, Arabisch/RTL, reale Schriftarten, Safe Areas,
Querformat, Tastatur sowie eingeloggte und datenreiche Community-/Event-
Zustaende. Native Textmetriken, Screenreader-Reihenfolge und sichtbare
Ellipse-Qualitaet lassen sich durch diese Widget-Tests nicht abschliessend
beurteilen.
