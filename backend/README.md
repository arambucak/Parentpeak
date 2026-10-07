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
Anfrage. Der Wegweiser verwendet ausschliesslich den bestaetigten,
kontobezogenen Alleinerziehendenstatus des aktuell ausgewaehlten Landes;
unzugeordnete globale Altwerte werden nicht automatisch weitergegeben.

```bash
flutter test --no-pub test/benefit_guide_consent_test.dart test/family_recipe_consent_test.dart test/family_hub_account_test.dart test/localization_audit_verification_test.dart
```

## Familien-Geld: lokale Kontotrennung und Altbestands-Claim

Finanzwerte und beide Checklisten liegen im eigenen lokalen Envelope
`famgeld.accounts.v1`. Dessen `legacyOwner` ist unabhaengig vom
`familyhub.accounts.v1`-Owner: Ein bereits bestaetigter Zentralen-Claim gibt
Finanzdaten weder frei noch sperrt er ihren separaten Finanz-Claim.

Betroffene Aufrufer sind vollstaendig auf diesen Store umgestellt:

- `FamilienGeldScreen`: `famgeld.country`, `famgeld.amounts`,
  `famgeld.eligibility_done`, `famgeld.is_employee`, `famgeld.is_single_parent`,
  `famgeld.income_level`, `famgeld.monthly_savings_goal`, `famgeld.total_saved`.
- `BenefitGuideScreen` ueber `BenefitChecklistStore`:
  `benefitguide.checklist.<country>.v1`, weiterhin pro Land getrennt.
- `AntragshelferScreen`: `antragshelfer.<benefit>.docs`, weiterhin pro Leistung.

Die bisherigen Keys sind nur nach ausdruecklicher Eigentumsbestaetigung durch
ein angemeldetes Konto importierbar. Normales Lesen und Gastbetrieb lesen
keinen Altbestand. Der Claim schreibt Finanzdaten und Finanz-Owner atomar
nach positivem Speicher-Ack; negative oder geworfene Schreibfehler lassen ihn
wiederholbar. Die Originalkeys bleiben als Backup unveraendert. Auch
Checklisten frueherer, aktuell nicht mehr angezeigter Leistungen bleiben
erhalten. Ein weiterer Account darf den beanspruchten Altbestand nicht
erneut importieren. Die separaten KI-Consentkeys werden nicht mitmigriert.

Vorhandene Kontowerte haben Vorrang, gleichnamige Betragskategorien werden
bei gleichem Land zusammengefuehrt und beide Checklistentypen dedupliziert.
Bei bereits abweichendem Kontoland werden globale Altbetraege,
Einkommensstufe und Sparwerte nicht in die neue Waehrung uebernommen;
sie bleiben im unveraenderten Originalbackup erhalten. Der Claimdialog
erklaert dieses Verhalten. Die allgemeine Laender-/Waehrungstrennung
beim spaeteren Landwechsel ist im folgenden Abschnitt beschrieben.

Der Hauptscreen wird beim Kontowechsel neu erstellt. Offene Wegweiser- und
Antragshelfer-Routen entfernen den vorherigen Stateful-Inhalt; Controller,
Kindkontext, Eingaben, KI-Antworten und Haken bleiben damit nicht im aktiven
Screen-State. Alle Speicheroperationen verlangen den Ursprungsscope, auch
wartende Writes pruefen ihn erneut. Das ist lokale Kontotrennung, keine
Verschluesselung, Server-Synchronisierung oder Veroeffentlichung.

Typfehler/defekte Envelopes sind explizite Fehler ohne globalen Fallback.
Zahlenvalidierung, Dezimalkomma, transaktionaler UI-Zustand aller Finanzfelder
und laenderbezogene Waehrungswerte sind im folgenden Abschnitt beschrieben.

```bash
flutter test --no-pub --reporter expanded test/family_finance_account_test.dart test/family_finance_ui_test.dart test/benefit_guide_consent_test.dart test/family_hub_account_test.dart test/localization_audit_verification_test.dart
```

### Finanzpersistenz, Zahlen und laenderbezogene Waehrungswerte

Der Finanz-Envelope enthaelt unter `famgeld.countries.v1` pro Laendercode
die Betragskategorien, Sparwerte und Schnellcheck-Angaben. Die ausgewaehlte
Laenderkennung bleibt accountbezogen. Alte kontobezogene flache Werte werden
beim Lesen ihrem bisherigen Land zugeordnet und beim naechsten bestaetigten
Write in diese Struktur uebernommen. Fehlte eine Landauswahl, gilt das zuvor
im Screen verwendete DE-Default. Der globale Altbestand bleibt weiterhin nur
nach explizitem Eigentumsclaim importierbar; der separate Finanz-Owner und
die originalen Backupkeys bleiben erhalten.

Ein Landwechsel schreibt zuerst die Auswahl bestaetigt und laedt danach nur
die Werte des Ziel-Landes. Ein neues Land startet ohne uebernommene Zahlen;
Rueckwechsel/Wiederoeffnen erhaelt die urspruenglichen Werte. Es gibt keinerlei
automatische Waehrungsumrechnung, auch nicht zwischen zwei EUR-Laendern.

Zahlenfelder behalten Eingabetext als Entwurf, aber Berechnungen und Teilen
verwenden nur bestaetigte Werte. Schnellcheck-Abschluss und Auswahl werden
ebenfalls erst nach Speicher-Ack aktiv. Fehlgeschlagene Writes sind sichtbar;
die vorige bestaetigte Zahl bleibt erhalten. Die Tastaturbestaetigung kann
dieselbe Eingabe erneut speichern. Einzelne Kategorien werden innerhalb der
Store-Writequeue zusammengefuehrt, damit schnelle unabhaengige Feldwrites
nichts ueberschreiben und ein fehlgeschlagener Entwurf nicht durch ein anderes
Feld versehentlich mitgespeichert wird.

Gueltig sind nichtnegative endliche Betraege bis 9.007.199.254.740.991
(technische sichere Integergrenze fuer Web/native, keine fachliche
Anspruchsgrenze). Freie Eingaben erlauben hoechstens zwei Nachkommastellen
mit Punkt oder Komma; Gruppierung, Exponenten, negative Werte, NaN/Infinity
und unvollstaendige/ungueltige Zahlen zeigen einen Feldfehler statt still 0.
Ein bewusst leeres Feld entspricht weiterhin 0. JSON-Typen, Zahlenbereiche,
Einkommensstufen 0/1/2 und bekannte Laendercodes werden vor Writes und beim
Lesen geprueft. Defekte Daten werden nicht geloescht oder leer umgedeutet.
Antragshelfer-Dokumentindizes muessen innerhalb der vorhandenen Liste liegen;
Ladefehler bleiben sichtbar, mounted-/Scope-Pruefungen sind weiterhin aktiv.
Beide Checklistentypen setzen Haken erst nach bestaetigtem Write.

`CountryFinanceConfig.formatAmount`, die bestehenden Disclaimer und der
AT-Familienbonus-Hinweis sind unveraendert. Die locale-neutrale Ganzzahl-
Anzeige ist keine Eingabevalidierung; Eingabecontroller behalten Dezimalwerte.

```bash
flutter test --no-pub --reporter expanded test/finance_persistence_test.dart test/finance_persistence_ui_test.dart test/family_finance_account_test.dart test/family_finance_ui_test.dart test/benefit_guide_consent_test.dart test/localization_audit_verification_test.dart
```

### Finanz-Meilensteine: Chronologie und geschaetzte Termine

`FinanceMilestoneTimeline` sortiert eine Kopie der Landes-Meilensteine nach
typischem Alter. Karten, Teilen, Sparziel und Fuenfjahresempfehlung verwenden
dieselbe geburtsdatumsbasierte Zeitachse statt gerundeter Lebensjahre.
Der geschaetzte Zieltermin ist das Geburtsdatum plus Meilensteinalter;
Kalenderjahr und Restzeit stammen aus diesem Termin, nicht aus einem
aufgerundeten Alter. Ein Meilenstein bleibt bis zum Tag vor diesem Geburtstag
sichtbar und wird ab dem Geburtstag nicht mehr als zukuenftig gezaehlt.

Die Restzeit wird in ungefaehren Kalendermonaten angezeigt; ein angebrochener
Restmonat zaehlt als ein Planungsmonat. Das Sparziel waehlt den zeitlich
naechsten Termin ueber alle Kinder und berechnet die Rate aus dem noch
fehlenden Betrag und dieser Restzeit. Die Fuenfjahressumme enthaelt Termine
nach heute bis einschliesslich des Tages in fuenf Jahren, auch noch im
aktuellen Kalenderjahr. Ohne Kinderprofil werden die Karten ebenfalls
chronologisch gezeigt, aber ohne erfundenen Geburtstag oder Kalendertermin.

Das sind typische Kosten-/Altersannahmen, keine echten Einschulungs- oder
Rechtstermine. Datum und Sparprognose sind ausdruecklich als Schaetzung
gekennzeichnet; die bestehenden Disclaimer bleiben erhalten. Der 29. Februar
wird in Nichtschaltjahren wie in den vorhandenen Altershelfern auf Maerz
normalisiert, ohne eine rechtliche Geburtstagsregel zu behaupten.
Der Wegweiser verwendet nur vollendete Lebensjahre mit dem bestehenden
tagkorrigierten `ChildProfile.monthsBetween`; Geburtsdaten werden fuer diese
Berechnung lokal genutzt und nicht neu an die KI uebertragen.
Amtliche Betraege, Leistungsfilter, Betragformatierung und AT-Hinweis bleiben
unveraendert und sind nicht durch diesen Fix auf Aktualitaet freigegeben.

```bash
flutter test --no-pub --reporter expanded test/finance_milestone_timeline_test.dart test/finance_milestone_ui_test.dart test/finance_persistence_test.dart test/finance_persistence_ui_test.dart test/family_finance_account_test.dart test/family_finance_ui_test.dart test/benefit_guide_consent_test.dart test/finance_links_i18n_test.dart test/country_finance_format_test.dart test/localization_audit_verification_test.dart
```

### Familien-Geld: Einzelpruefung amtlicher Leistungsdaten

Pruefdatum: **06.10.2026**. Das ist das Abrufdatum, kein gemeinsamer
Geltungsstichtag und keine Aktualitaetsfreigabe aller Daten. Die folgenden
Einzelangaben wurden vor Aenderung gegen die genannten amtlichen Quellen
geprueft. Kurztexte ersetzen keine vollstaendige Anspruchspruefung.
DE-Betrags-/Voraussetzungstexte sind auch in de/en/tr/ku angepasst.

| Angabe / gepruefter Umfang | Amtliche Quelle |
| --- | --- |
| DE Kinderbetreuung: 80% der beguenstigten Kosten, hoechstens 4.800 EUR je Kind/Jahr; Haushaltskind unter 14 oder gesetzliche Behinderungsausnahme, Rechnung/Kontozahlung; Unterricht, Sport/Freizeit ausgeschlossen | [§10 Abs.1 Nr.5 EStG](https://www.gesetze-im-internet.de/estg/__10.html) |
| DE Kindergeld: 259 EUR unveraendert; keine pauschale Zahlung fuer alle Kinder bis 25. Kurztext zu Minderjaehrigen/Versorgung/Haushalt/Wohnsitz korrigiert; Detaillink ersetzt | [BA Anspruch, Hoehe, Dauer](https://www.arbeitsagentur.de/familie-und-kinder/infos-rund-um-kindergeld/kindergeld-anspruch-hoehe-dauer), [§66 EStG](https://www.gesetze-im-internet.de/estg/__66.html) |
| DE KiZ: bis 297 EUR/Kind/Monat; Haushaltskind unter 25, Kindergeld und individuelle Einkommens-/Vermoegens-/Bedarfspruefung; Detaillink ersetzt | [BA KiZ](https://www.arbeitsagentur.de/familie-und-kinder/kinderzuschlag-verstehen/kinderzuschlag-anspruch-hoehe-dauer), [§6a BKGG](https://www.gesetze-im-internet.de/bkgg_1996/__6a.html) |
| DE Wohngeld: Haushaltsgroesse, beruecksichtigte Miete/Belastung und Gesamteinkommen statt pauschaler Einkommensgrenze; kein Betrag erfunden | [§4 WoGG](https://www.gesetze-im-internet.de/wogg/__4.html) |
| DE Elterngeld: Basis 300-1.800 / Plus 150-900 EUR/Monat ohne Zuschlaege; unterschiedliche Bezugszeiten, gemeinsamer Haushalt/eigene Betreuung/keine volle Erwerbstaetigkeit; keine pauschale Unter-14-Monate-Grenze fuer alle Modelle | [Familienportal Hoehe](https://familienportal.de/familienportal/familienleistungen/elterngeld/faq/wie-viel-elterngeld-kann-ich-bekommen--124616), [§1 BEEG](https://www.gesetze-im-internet.de/beeg/__1.html), [§4 BEEG](https://www.gesetze-im-internet.de/beeg/__4.html) |
| DE Unterhaltsvorschuss: 227 / 299 / 394 EUR monatlich fuer 0-5 / 6-11 / 12-17 Jahre. Quelle nennt Gueltigkeit ab 01.01.2025, kein pauschales 2026-Siegel. Fehlender/unregelmaessiger/unzureichender Unterhalt; Zusatzbedingungen ab 12; Detaillink ersetzt | [Familienportal Hoehe](https://familienportal.de/familienportal/familienleistungen/unterhaltsvorschuss/wieviel-unterhaltsvorschuss-kann-ich-fuer-mein-kind-bekommen--125264), [§1 UhVorschG](https://www.gesetze-im-internet.de/uhvorschg/__1.html) |
| DE Pflegegeld: 347 / 599 / 800 / 990 EUR/Monat fuer Pflegegrade 2 / 3 / 4 / 5; geeignete haeusliche Pflege selbst sicherstellen | [§37 SGB XI](https://www.gesetze-im-internet.de/sgb_11/__37.html) |
| DE Pflege-Antragshelfer: grundsaetzlich 25 Arbeitstage Entscheidung, gesetzliche Ausnahmen; Widerspruch grundsaetzlich ein Monat ab Bekanntgabe, im Ausland drei Monate. Rechtsbehelfsbelehrung pruefen | [§18c SGB XI](https://www.gesetze-im-internet.de/sgb_11/__18c.html), [§84 SGG](https://www.gesetze-im-internet.de/sgg/__84.html) |
| AT Familienbeihilfe: Grundbetraege 138,40 / 148 / 171,80 / 200,40 EUR ab 0 / 3 / 10 / 19 Jahren ohne Zuschlaege; Quelle nennt 2025-2027; Detaillink ergaenzt | [Bundeskanzleramt Betraege](https://www.bundeskanzleramt.gv.at/agenda/familie/familienbeihilfe/basisinformation-zur-familienbeihilfe/familienbeihilfenbetraege.html) |
| AT Kinderabsetzbetrag: 70,90 EUR/Kind/Monat fuer 2026, mit Familienbeihilfe ausgezahlt, kein gesonderter Antrag; Detaillink ergaenzt | [Bundeskanzleramt Kinderabsetzbetrag](https://www.bundeskanzleramt.gv.at/agenda/familie/finanzielle-entlastung-von-familien/familiensteuerentlastung/kinderabsetzbetrag.html) |
| AT KBG: Konto 17,65-41,14 EUR/Tag; einkommensabhaengig 80% der Letzteinkuenfte, max. 80,12 EUR/Tag. Keine unzutreffende gemeinsame Monatsspanne; gepruefter Basislink ergaenzt | [Konto](https://www.bundeskanzleramt.gv.at/agenda/familie/kinderbetreuungsgeld/basisinformationen-kinderbetreuungsgeld/kinderbetreuungsgeld-konto-pauschalsystem.html), [Einkommensabhaengig](https://www.bundeskanzleramt.gv.at/agenda/familie/kinderbetreuungsgeld/basisinformationen-kinderbetreuungsgeld/einkommensabhaengiges-kinderbetreuungsgeld.html), [Basislink](https://www.bundeskanzleramt.gv.at/agenda/familie/kinderbetreuungsgeld/basisinformationen-kinderbetreuungsgeld.html) |
| CH Kinder-/Ausbildungszulage: Mindestbetraege 215 / 268 CHF monatlich, kantonal ggf. hoeher; keine unbelegte Obergrenze. Nachobligatorische Ausbildung fruehestens ab 15 bis laengstens 25, Monatsgrenzen pruefen; Links ergaenzt | [BSV Leistungen und Voraussetzungen](https://www.bsv.admin.ch/de/familienzulagen-leistungen-und-voraussetzungen) |
| TR neues Dogum-Yardimi-Programm fuer Geburten ab 01.01.2025: erstes Kind 5.000 TRY einmalig, zweites 1.500 TRY/Monat, drittes+ 5.000 TRY/Monat; laufende Zahlungen ab Antrag bis einschliesslich 60. Monat; Staatsangehoerigkeit/Wohnsitz kurz benannt; Link ergaenzt | [Ministeriums-FAQ](https://www.aile.gov.tr/sss/sosyal-yardimlar-genel-mudurlugu/yeni-dogum-yardimi/), [Zahlungsbeginn](https://www.aile.gov.tr/sss/sosyal-yardimlar-genel-mudurlugu/yeni-dogum-yardimi/q-0005/) |
| TR SED: individuelle soziale/wirtschaftliche Pruefung, Il Mudurlugu/Sosyal Hizmet Merkezi statt pauschaler SYDV-/Armutsgrenzenregel; Link ergaenzt | [Ministeriums-FAQ SED](https://www.aile.gov.tr/sss/cocuk-hizmetleri-genel-mudurlugu/sed-hizmeti/) |
| GB Child Benefit: 27.05 / 17.90 GBP/Woche fuer erstes/einziges bzw. weitere Kinder | [GOV.UK Hoehe](https://www.gov.uk/child-benefit/what-youll-get) |
| GB UC Child Element: 303.94 GBP/Monat je Kind, zusaetzlich 47.94 GBP fuer erstes Kind vor 06.04.2017; Leistungsanrechnung und weitere Regeln nicht vollstaendig abgebildet | [GOV.UK Universal Credit](https://www.gov.uk/universal-credit/what-youll-get) |
| GB Tax-Free Childcare: 2 GBP je 8 GBP Einzahlung; max. 500 GBP/3 Monate bzw. 2.000/Jahr, bei behindertem Kind 1.000/3 Monate bzw. 4.000/Jahr | [GOV.UK Tax-Free Childcare](https://www.gov.uk/tax-free-childcare) |

**Rechenbeispiel, keine amtliche Steuerersparnis:** Der DE-Steuerhelper wendet
80%/4.800 EUR auf eingetragene Jahreskosten an, als Illustration fuer **ein**
Kind. Das gemeinsame Kostenfeld kennt keine Verteilung je Kind und keine
Einzelfallbedingungen. Der angenommene Grenzsteuersatz von 30% ist kein
gesetzlicher Pauschalsatz. Weder Kinderzahlmultiplikation noch Anspruchs- oder
Steuerpruefung wird behauptet. Betragformatierung und AT-Familienbonus-Hinweis
sind unveraendert.

**Ehrliche Orientierung:** Alle Landesleistungen bleiben unabhaengig von
Schnellcheckantworten sichtbar. Die Einkommensbaender sind keine gesetzlichen
Grenzen. Erwerbstaetigkeit/Alleinerziehung bleiben lokal gespeichert, ergeben
keine Anspruchsentscheidung. Der Guide-Prompt bezeichnet die kuratierten Daten
nicht mehr als vollstaendige Wahrheit. Disclaimer bleiben in allen Tabs,
ohne pauschales "Stand 2026".

**Unveraendert / keine Verifikationsfreigabe:**

- TR `Cocuk Parasi`: kein eindeutig zuordenbares allgemeines monatliches
  Programm amtlich belegt. Nutzerentscheidung: **nicht verifizierbar,
  unveraendert gelassen**, nicht in ein anderes Programm umbenannt.
- Wohngeld-Rechnerlink: Abruf lieferte HTTP 403, Inhalt nicht verifizierbar;
  unveraendert gelassen, nicht als toter Link klassifiziert.
- BuT: 195 EUR Schulbedarf/Jahr (130+65) und 15 EUR/Monat soziale Teilhabe
  bestaetigt, unveraendert: [Familienportal](https://familienportal.de/familienportal/familienleistungen/bildung-und-teilhabe).
  Die knappe Leistungs-/Empfaengerliste ist nicht als vollstaendig geprueft.
- Alle sonstigen Antragshelfer-Dokumentlisten, Zustell-/Verfahrensdetails,
  Online-Antragslinks und Zeitangaben sind **nicht vollstaendig amtlich
  verifiziert, unveraendert gelassen**: Kindergeld 4-6 Wochen/Steuer-ID
  2-3 Wochen/10-Minuten-Antrag/automatische Zahlung bis 25; KiZ 4-8 Wochen/
  2-Minuten-Lotse; Wohngeld 3-8 Wochen/12 Monate/2 Monate Vorlauf/10-Monats-
  Erinnerung; BuT 2-6 Wochen/Schuljahr oder 6 Monate; Elterngeld 4-8 Wochen/
  pauschale 12-14 bzw. 24-28 Monate; Unterhaltsvorschuss 4-6 Wochen/
  jaehrlicher Pruefbogen; Pflege Telefonantrag/Rueckwirkung/2-Wochen-Tagebuch/
  automatische Weiterzahlung; Eingliederungshilfe 4-12 Wochen/pauschale
  Zustaendigkeiten/4-Wochen-Widerspruch. Die verifizierte Pflegefrist wird
  **nicht** pauschal auf andere Verfahren uebertragen.
- KiZ-Bewilligung/Betrachtungszeitraum 6 Monate ist auf der BA-Quelle
  bestaetigt; daraus folgt keine Freigabe der restlichen Dokumentlisten.
- Weitere gesetzliche Ausnahmen, Auslands-/Wohnsitz-/Erwerbsbedingungen,
  Einkommensgrenzen, kantonale Saetze und vollstaendige Bezugsdauern:
  nicht vollstaendig verifiziert, keine neuen Regeln eingefuehrt.
- Monatskategorien und Meilensteinkosten bleiben **Schaetzwerte**, keine
  amtlichen Leistungsbetraege. AT-Familienbonus-Hinweis nicht neu verifiziert.

### Verschenkmarkt: Foto-KI-Einwilligung

Kameraaufnahme und Analyse-Retry verwenden denselben
`TreasurePhotoAnalysisService`. Vor der ersten Analyse erscheint ein
transparenter Dialog in de/en/tr/ku: Bildbytes gehen ueber das ParentPeak-
Backend an Google Gemini; Bildinhalte werden nicht anonymisiert. Nur
Gegenstandsfotos ohne Personen, private Dokumente oder erkennbare Adressen
verwenden. Ablehnung belaesst Foto und manuelle Anzeigenbearbeitung lokal;
Galerieauswahl startet weiterhin keine automatische KI-Analyse.

Die separate Zustimmung liegt unter
`treasure.ai_photo_consent.v1.account.<encoded-user-id>` in SharedPreferences.
Ein nicht angemeldeter Kontext ist getrennt unter `.guest`; er autorisiert
kein spaeteres Konto. Rezept-/Wegweiser-Consents und andere Versionen geben
die Treasure-Fotoanalyse nicht frei. Nur ein positiver Speicher-Ack aktiviert
die Analyse. Der Service prueft Zustimmung und Ursprungskontext vor dem
Lesen der Bildbytes, erneut vor dem HTTP-Aufruf und nach der Antwort.

JSON-Schema und Antwortsprache stehen im `systemInstruction`. Der Request
enthaelt Bildbytes und eine statische Gegenstandsaufgabe, keine lokalen
Kind-/Finanz-/Gesundheitsprofile. Bildpixel selbst bleiben unredigiert:
Promptregeln sind kein Ersatz fuer Bildanonymisierung. Ungueltige Antworten
oder KI-Ausfall zeigen einen lokalisierten Fehler und behalten Foto und
manuelle Eingaben; keine erfundene Bildanalyse als Fallback.

Kontobenachrichtigungen, neuere Kamera-/Analyseanfragen, Entfernen/Wechsel
des Fotos, Verwerfen und Dispose machen alte Ergebnisse ungueltig. Der
Service prueft auch den aktuellen Request nach dem Lesen und der Antwort.
Bereits abgesandte HTTP-Anfragen werden damit **nicht rueckgaengig gemacht**;
ihre Ergebnisse werden nicht in einen neuen Kontext uebernommen.

Consent veroeffentlicht weder Foto noch Anzeige. Firebase-Fotoveroeffentlichung
und weitere Persistenzfragen bleiben separate Audit-Fixes, keine
Gesamtfreigabe durch diesen Consent.

### Verschenkmarkt: lokale Kontotrennung und Altbestands-Claim

`TreasureAccountStore` speichert Entwurf, Reservierungs-, Blockierungs- und
Meldemarkierungen sowie den Discoverycache im separaten Envelope
`treasure.accounts.v1`, unter `account.<encoded-user-id>` beziehungsweise
`guest`. Das ist lokale Kontotrennung, keine Verschluesselung oder
geraeteuebergreifende Synchronisation. Zentralen-/Finanz-Owner und
Foto-KI-Einwilligungen werden weder wiederverwendet noch importiert.

Die bisherigen globalen Originalkeys bleiben unveraendert erhalten:
`treasure_upload_draft.v1`, `treasure_reserved_ids.v1`,
`treasure_blocked_listing_ids.v1`, `treasure_reported_listing_ids.v1`.
Ohne ausdrueckliche Eigentumsbestaetigung in einem angemeldeten Konto
werden sie nicht gelesen oder automatisch zugeordnet. Der eigene
`legacyOwner` wird mit dem Import atomisch gespeichert, nur nach positivem
Speicher-Ack. Vorhandene Kontoentwuerfe haben Vorrang, auch ein bewusst
verworfener Entwurf; Sicherheits-/Reservierungsmarkierungen werden
dedupliziert zusammengefuehrt. Ein Claim veroeffentlicht nichts.
Der globale `treasure_listings.v1`-Discoverycache ist kein Eigentumsbeleg
und wird nicht importiert; auch sein Original bleibt erhalten.

Upload- und Handover-Screen werden bei Kontowechsel neu aufgebaut:
Controller, ausgewaehlte Fotos, Auswahl und accountgebundene Caches werden
verworfen. Operationen behalten ihren Ursprungsscope, pruefen ihn nach
asynchronen Antworten und schreiben niemals in den neuen Kontokontext.
Dialogs/Sheets blenden Daten und Aktionen des vorherigen Kontos aus und
schliessen ihre eigene Route beim Kontowechsel.
Ein bereits gesendeter Backendaufruf oder Foto-Upload wird damit nicht
rueckgaengig gemacht. Fehler beim Laden, Claim oder Schreiben werden
sichtbar gemeldet; keine Speicherbestaetigung bei fehlendem Ack.

Betroffene Leser/Schreiber: `TreasureListingService` (Entwurf, Feedcache,
Reservierungen), `TreasureUploadScreen` (Restore, Autosave, Verwerfen,
Publish-Clear), `TreasureHandoverScreen` (Reservierungen, Sicherheitsflags,
Mine-/Uebergabeansichten). Andere direkte Leser der Originalkeys gibt es
im aktuellen Fluttercode nicht.

### Verschenkmarkt: ehrliche Persistenz und Foto-Teilfehler

Ohne aktiviertes Backend wird keine Reservierung bestaetigt oder lokal
vorgemerkt; es gibt keine Offline-Reservierungsqueue. Nach Server-Ack muss
auch der lokale Reservierungsmarker bestaetigt gespeichert sein.
Storno entfernt nach Server-Ack nur den zugehoerigen Marker. Scheitert der
lokale Ack nach einer bestaetigten Serveraktion, meldet die UI diesen
Teilerfolg ausdruecklich statt eine vollstaendige lokale Aktualisierung.

Ein Fotobatch liefert alle URLs oder einen Fehler, niemals eine teilweise
erfolgreiche Liste. Vor dem Anzeigenrequest werden bekannte Uploads bei
Fehler best-effort bereinigt; gescheiterte Bereinigung wird sichtbar
gemeldet. Nach bestaetigtem Create bleiben Anzeigenfotos erhalten, auch
wenn Feedcache oder Entwurfsloeschung scheitern. Bei unbestaetigtem Create
(etwa Timeout) bleiben Fotos ebenfalls erhalten: Der Server koennte die
Anzeige bereits erstellt haben. Die UI warnt vor oeffentlich erreichbaren
Fotos und sperrt blindes Wiederholen in derselben Screeninstanz.
Das ist keine serverseitige Idempotenz oder garantierte Rueckabwicklung;
vor einem erneuten Versuch sind die eigenen Anzeigen zu pruefen.

Web-Entwuerfe speichern Bildbytes als Base64 mit Name/MIME im
kontogetrennten lokalen Envelope statt temporaerer Blobpfade. Native
Entwuerfe behalten ihren Pfadvertrag. Browserquoten und Schreibfehler
werden sichtbar gemeldet, ohne eine Speicherbestaetigung. Nicht mehr
lesbare Legacybilder sind nicht rekonstruierbar: Texte bleiben erhalten,
fehlende Bilder werden gemeldet, kein automatisches Ueberschreiben.
Die lokalen Bilddaten sind nicht verschluesselt. Ein Entwurf oder dessen
Speichern veroeffentlicht nichts; erst Teilen laedt Fotos hoch.

Verbleibende UI-/Lifecyclefragen bleiben separate Auditpunkte.
Keine Deployment- oder Launchfreigabe.

### Verschenkmarkt: Kategorien und ungefaehre Reichweite

Auswahl, `TreasureListing`, lokaler Cache und HTTP verwenden die stabilen IDs
`vehicles`, `clothing`, `toys`, `books`, `equipment`, `other`. Uebersetzungen
finden nur fuer die Anzeige statt. Bekannte alte Labels in de/en/tr/ku werden
beim Lesen zugeordnet; unbekannte Kategorien bleiben `other`, nicht erfundene
Spielzeuge. Bereits auf dem Server als `other` verlorene Kategorien lassen sich
nicht ohne neue Nutzerangabe rekonstruieren; keine automatische DB-Umschreibung.

Der Upload-Slider waehlt ausdruecklich den **ungefaehren Veroeffentlichungsradius
1–25 km**, nicht eine Entfernung zum Betrachter. `shareRadiusKm` ist im Modell,
Draft und HTTP von der nullable Betrachterentfernung `distanceMeters` getrennt.
Alte 50–800-m-Draftwerte hatten effektiv immer 1 km Reichweite; Wiederherstellung
behaelt diesen wirksamen Wert, ohne den Altentwurf beim Laden umzuschreiben.

Treasure-Requests runden Positionen auf zwei Nachkommastellen. Discovery,
Sortierung und sichtbare Entfernung beruhen auf demselben groben Gitter fuer
Anbieter **und** Betrachter, nicht auf exakten Privatkoordinaten. Die numerische
Distanz wird auf Meter gerundet, ist aber ausdruecklich nur eine Schaetzung.
0 m bedeutet gegebenenfalls dieselbe Gitterzelle, nicht dieselbe Adresse.
Serverfilter verwenden inklusiv das Minimum aus Such- und Anzeigenradius
(weiterhin maximal 25 km); UI-Distanzfilter und Karten verwenden denselben
ungefaehren Wert. Auch bekannte Entfernungen aus dem Offlinecache werden
gegen den Anzeigenradius geprueft. Ohne berechenbare Entfernung wird kein Radius als Distanz
ausgegeben. Alte Cache-Distanzen ohne `distanceBasis: coarse-v1` sind nicht
vertrauenswuerdig und werden aus Positionen neu berechnet oder als unbekannt
angezeigt; Originaldaten werden dadurch nicht geloescht.

Geografische Discovery scannt passende Datensaetze in DB-Batches von 200,
filtert/sortiert zuerst und wendet erst dann Ergebnislimit/Offset an.
Das verhindert, dass aeltere nahe Angebote hinter einer ersten Seite ferner
Angebote verschwinden. Gesamter Scanaufwand waechst mit dem Datenbestand;
eine spaetere datenbankseitige Geo-Indexierung ist damit nicht ersetzt.
Nicht-geografische Abfragen behalten ihre DB-Pagination.
Ungueltige Koordinaten/Radien werden explizit abgewiesen, Nullkoordinaten sind
gueltig. Keine Standortpraezisierung oder globaler Marktmodus eingefuehrt.

### Verschenkmarkt: oeffentliche Detailprojektion

`GET /api/treasures` und `GET /api/treasures/:id` verwenden dieselbe
explizite `publicTreasure`-Projektion. Koordinaten werden auf zwei
Nachkommastellen gerundet; `approximateLocation` ist immer `true`.
Der Feed liefert eine ungefaehre Entfernung aus denselben grob gerundeten
Positionen, wie oben beschrieben. Die oeffentliche Projektion bleibt unveraendert;
alte gespeicherte Positionen werden nicht nachtraeglich praezisiert oder migriert.

Die oeffentliche Detailantwort liefert keine rohen `handovers`,
Interessenten-IDs, privaten Uebergabenotizen/-orte, individuellen
Bewertungsprofile oder zukuenftig hinzugefuegten internen DB-Felder.
Aggregierte Reservierungs-/Bewertungszahlen bleiben verfuegbar.
Eigene Angebote und private Uebergaben bleiben im bereits
kontogeschuetzten `GET /api/treasures/mine`; dessen Vertrag ist unveraendert.
Oeffentliche Anzeigen-/Foto-/Abholbereichsfelder bleiben absichtlich
sichtbar. In Titel, Beschreibung oder Ortslabel gehoeren keine privaten
Adressen/Kontaktdaten; die Projektion anonymisiert keinen Freitext.

Lokale, nicht mutierende Regressionen:
`node --test backend/tests/unit/treasure-public-view.test.js`.
Sie pruefen sowohl den Helper als auch die tatsaechlichen List-/Detailhandler
mit einem DB-Double. Die bestehende CI nimmt die Datei im Backend-Unit-Schritt
des `analyze`-Jobs auf; kein produktiver HTTP-Smoke erforderlich.

### Familien-Geld: lokalisierte Orientierung, Links und Sharing

Der Wegweiser uebernimmt die aktuelle UI-Sprache fuer Chips, Fallback und
KI-Antwort. JSON-Form und Ausgabesprache stehen im `systemInstruction`;
Freitext bleibt im sanitisierten Request-Prompt. Die vorhandene Konto-
Einwilligung und Kontextpruefung vor/nach KI-Verarbeitung bleiben erhalten.
`BenefitGuideResult.isFallback` kennzeichnet lokale kuratierte Orientierung
sichtbar als **nicht personalisiert**, auch bei unbrauchbarer KI-Antwort.

Die Linkgrenze ist bewusst konservativ: Nur Leistungs-IDs aus dem angefragten
Land bleiben im KI-Ergebnis. Namen stammen aus der lokalisierten Kuratierung;
URLs werden ausschliesslich durch die hinterlegte URL ersetzt. Ohne
kuratierten Link wird **kein** KI-Link ergaenzt. Grounding-Quellen bleiben
nur erhalten, wenn ihre HTTPS-URL exakt einer Landesleistungs-URL entspricht.
Host-Suffixe, Credentials, abweichende Ports und Redirect-Queryvarianten
erweitern die erlaubten Links nicht. Neue Leistungen oder zusaetzliche
amtliche Quellen brauchen zuerst eine kuratierte Aufnahme, keinen
automatischen Vertrauensbonus fuer KI-Ausgaben.

Alle drei Finanz-Screens benutzen `openFinanceLink`: gueltige HTTPS-Links
werden direkt gestartet (kein vorgeschalteter `canLaunchUrl`-False-Negative
auf Web). `false`, Plattformfehler und ungueltige URLs ergeben sichtbare
lokalisierte Fehler; nach Dispose wird keine UI angesprochen.
Die beiden Wegweiser-Taps und der Antragshelfer-Link haben `opaque`.
Finance-Share verwendet das Rechteck des Share-Buttons als iPad-Anker,
ohne Geraete-/Platform-Abfrage. Share-/Clipboard-Fehler sind sichtbar; eine
Kopierbestaetigung folgt erst nach erfolgreichem Clipboard-Aufruf.

`finance_content.dart` und `finance_content_keys.dart` verbinden vorhandene
kuratierte Quelltexte mit stabilen Keys in `app_localizations_all.dart`.
Alle acht Antragshelfer sind in de/en/tr/ku abgedeckt, einschliesslich
Dokumenten, Herkunftshinweisen, Schritten und statischen KI-Aufgaben.
Landesleistungen (auch Generic), TR/GB-Meilensteinnotizen und UI verwenden
dieselbe Lokalisierung. IDs, Dokumentindizes/Optionalitaet, Reihenfolge,
Zahlenwerte und URLs werden nicht geaendert; Checklisten bleiben kompatibel.
Andere Inhaltssprachen fallen wie bisher auf EN zurueck. Frei generierte
KI-Texte und externe/custom Daten werden nicht als neue Quellkeys behandelt.
Coverage-Tests verlangen fuer jeden kuratierten Antrags-/Non-DE-Text einen
Key in allen vier Sprachen; neue Rohdaten brauchen entsprechende Keys.

Die Uebersetzungen sind **keine Rechtspruefung**: unverifizierte
Antragsdetails bleiben unveraendert und erhalten einen sichtbaren
Pruefhinweis. `Cocuk Parasi`, Betragformatierung, AT-Familienbonus-Hinweis
und alle bestehenden Disclaimer bleiben erhalten. Kein vollstaendiges
Aktualitaets- oder Rechtsberatungsversprechen.

Wohngeld-Linkpruefung am 06.10.2026: Auch die gefundenen BMWSB-Kandidaten
`https://www.bmwsb.bund.de/DE/wohnen/wohngeld/wohngeldrechner/wohngeldrechner-2025_node.html`
und `https://www.bmwsb.bund.de/DE/themen/wohnen/wohngeld/wohngeldrechner/wohngeldrechner-node.html`
antworten beim Abruf mit HTTP 403. Kein inhaltlich bestaetigter Ersatz;
der bisher dokumentierte Link bleibt unveraendert, nicht als tot eingestuft.

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
