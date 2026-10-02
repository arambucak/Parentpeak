# Qualitäts-Audit: Modul „Kalender"

**Datum:** 2026-10-03
**Modul:** Familienkalender (`lib/ui/calendar_screen.dart` + abhängige Dateien)
**Umfang:** Monats-Grid, Filter-Chips, Schnelleingabe (NLP), Termin-Erstellung/-Editieren, Feiertags-Integration, Tages-Detailansicht, i18n, Tests.

---

## 1. Zusammenfassung

Das Kalender-Modul wurde vollständig geprüft und überarbeitet. Schwerpunkte waren Korrektheit (Datums-/Zeitberechnung, Recurrence), Robustheit der Schnelleingabe, Datensicherheit beim Editieren, Vermeidung von Doppel-Submits sowie durchgängige Lokalisierung.

Die wichtigste strukturelle Änderung: Die bislang in der UI-Datei eingebettete, nicht testbare Logik (NLP-Parsing, Recurrence-Expansion, Grid-Berechnung) wurde in eine reine, UI-unabhängige Klasse `CalendarLogic` (`lib/logic/calendar_logic.dart`) extrahiert und mit Unit-Tests abgesichert.

**Ergebnis:**
- `flutter analyze` für das Kalender-Modul: **0 Hinweise**.
- Tests: **51 Tests grün** (34 Logik, 2 i18n, 4 Avatar, 11 HolidayService).

---

## 2. Gefundene Mängel und Behebung

### 2.1 Monats-Grid & Monatsnavigation
| Befund | Status |
|---|---|
| Monatswechsel (`_changeMonth`) und Datumsbereiche waren schaltjahr-/jahreswechselsicher (Dart normalisiert Monatsüberläufe korrekt). | OK, bestätigt |
| Grid füllte nur führende Vortage, **nicht** die nachlaufenden Tage → unvollständige letzte Wochenzeile. | **Behoben** — `CalendarLogic.daysInMonthGrid` liefert jetzt immer volle 7er-Wochen (Montag–Sonntag) inkl. Folgemonats-Tagen. |
| Wochentags-Offset-Berechnung (`weekday % 7`). | **Vereinfacht** auf `(weekday + 6) % 7` (Montag = 0). |

### 2.2 Event-Indikatoren
| Befund | Status |
|---|---|
| `_countEventsForDay` (Grid-Punkte) und `_eventsForSelectedDay` (Tagesliste) nutzen identische Filter (Tag + Person) → konsistent. | OK, bestätigt |

### 2.3 Schnelleingabe / NLP (`_parseQuickInput` → `CalendarLogic.parseQuickInput`)
| Befund | Status |
|---|---|
| Ungültige Uhrzeit (z. B. `25:99`) wurde still auf einen falschen Tag/Zeit normalisiert statt abgelehnt. | **Behoben** — Bounds-Check 0–23 h / 0–59 min, Rückgabe `isValid=false` + Fehlercode `time_out_of_range`. |
| Unplausibles Datum (z. B. `31.02.`, `10.13.`) wurde still normalisiert. | **Behoben** — Plausibilitätsprüfung (Monat 1–12, Tag ≤ letzter Monatstag, Jahr 1970–3000), Fehlercode `date_invalid`. |
| Leere / titel-lose Eingabe. | **Behoben** — saubere Fallbacks (`empty`, `no_title`); leere Eingabe wird still ignoriert, sonstige Fehler zeigen lokalisierte SnackBar. |
| Priorität Datum vor Wochentag. | OK, beibehalten und getestet. |
| Mehr Geburtstags-Keywords (DE/EN/TR/KU). | **Ergänzt** |

### 2.4 Filter-Chips & Personen
| Befund | Status |
|---|---|
| Filter „Alle/Eltern/Kindergarten/Geburtstag", `+ Person`-Button, Umbenennen/Löschen von Custom-Personen funktionieren; UI und State/Service synchron. | OK, bestätigt |
| Personen-Chips zeigten keine Avatare (Inkonsistenz zur restlichen App). | **Behoben** — siehe 2.7 |

### 2.5 Formular-Validierung & Termin-Erstellung
| Befund | Status |
|---|---|
| Leerer Titel führte zu stillem `return` ohne Feedback. | **Behoben** — Validierung erst beim Absenden; Fehlertext am Titelfeld, verschwindet sofort bei Eingabe (`onChanged`). |
| **Kein Doppel-Submit-Schutz**: Save-Button blieb während des asynchronen Backend-Calls tappbar → mehrfache identische Events möglich. | **Behoben** — `isSaving`-Flag deaktiviert den Button und zeigt einen Spinner, bis der Vorgang abgeschlossen ist. |
| **Datenverlust beim Editieren**: `_editEvent` löschte das Event sofort und persistierte, bevor das Sheet geöffnet wurde → Abbrechen = Event weg. Zudem gingen alle Felder außer Titel/Person verloren. | **Behoben** — `_openAddSheet(editing:)` befüllt **alle** Felder; das Original bleibt erhalten und wird erst beim tatsächlichen Speichern via `_removeEventEverywhere` (inkl. Serien-Instanzen `id_*`) ersetzt. |
| Backend-Fehler verwarf das Event komplett (kein Offline-Fallback beim Anlegen). | **Behoben** — Event wird bei Backend-Fehler lokal gehalten und persistiert (offline-first), Sync-Hinweis bleibt sichtbar. |

### 2.6 Feiertage & Wiederkehrende Events
| Befund | Status |
|---|---|
| **Recurrence-Approximation**: Monatlich = 30 Tage, Jährlich = 365 Tage → Termine driften über die Zeit. | **Behoben** — `CalendarLogic.expandRecurrenceStarts` rechnet kalendergenau (`DateTime(year, month±n, day)`), klemmt nicht existierende Tage (z. B. 31. im Februar) auf den letzten Monatstag und behandelt den 29.02. in Nicht-Schaltjahren korrekt. |
| Feiertage (`HolidayService`) werden korrekt berechnet und sind durch Tests abgedeckt (DE/AT/CH/TR/GB, Schulferien). | OK, bestätigt |
| „Schulferien"-Label im Tages-Detail war hartkodiert deutsch. | **Behoben** — lokalisiert (`calendar_school_holiday`). |

> **Hinweis / offener Punkt:** Feiertags- und Schulferien-**Daten** sind im `HolidayService` fest für 2026 (alle Länder) und 2027 (nur DE) hinterlegt. Danach liefert der Service keine Einträge mehr. Die Feiertags-**Namen** sind landessprachlich fest (nicht übersetzt). Beides ist bewusst außerhalb des Fix-Scopes belassen (Datenpflege/Design-Entscheidung) — siehe Abschnitt 5.

### 2.7 UI/UX, Performance & i18n
| Befund | Status |
|---|---|
| Einheitliches `UserAvatar`-Widget nicht im Kalender genutzt. | **Behoben** — in `_EventCard` am Personen-Badge eingebunden (`radius: 10`). |
| **i18n-Lücke**: `calendar_*`-Keys (Personen-/Feiertags-Verwaltung) existierten nur in 4 Sprachen (de/en/ku/tr); zahlreiche UI-Labels im Add-Sheet waren hartkodiert deutsch. | **Behoben** — ~95 Kalender-Keys jetzt in allen 16 Picker-Sprachen; alle Add-Sheet-Labels, Badges, Dialoge und Snackbars über `AppStringsManager` lokalisiert. |
| **Datums-/Zeitformate** waren überall fest auf Locale `'de'` → selbst bei anderer App-Sprache deutsche Formate. | **Behoben** — alle `DateFormat`-Aufrufe nutzen `CalendarLogic.localeTag(appSprache)`; `intl`-Locale-Daten werden beim App-Start via `ensureDateFormattingInitialized()` initialisiert (`ku`→`en`, `ckb`→`ar` gemappt). |
| 4 generische, vom Kalender genutzte Keys (`delete_action`, `rename`, `rename_person`, `finance_save`) fehlten in 12 Sprachen. | **Behoben** — in allen Sprachen ergänzt. |

---

## 3. Geänderte / neue Dateien

**Geändert**
- `lib/ui/calendar_screen.dart` — NLP/Recurrence/Grid auf `CalendarLogic` umgestellt; Edit-Flow, Doppel-Submit-Schutz, Validierung, UserAvatar, durchgängige Lokalisierung, `value`→`initialValue`-Migration.
- `lib/l10n/app_localizations_all.dart` — ~95 Kalender-Keys in alle 28 Sprachblöcke (16 Picker-Sprachen kuratiert bzw. befüllt).
- `lib/main.dart` — `CalendarLogic.ensureDateFormattingInitialized()` beim App-Start.

**Neu**
- `lib/logic/calendar_logic.dart` — reine, testbare Kalender-Logik.
- `test/calendar_logic_test.dart` — 34 Unit-Tests.
- `test/calendar_i18n_test.dart` — 2 Vollständigkeits-/Platzhalter-Tests.
- `test/calendar_user_avatar_test.dart` — 4 Widget-Tests.

---

## 4. Verifikation

```
flutter analyze --no-pub lib/ui/calendar_screen.dart lib/logic/calendar_logic.dart
→ No issues found!

flutter test test/calendar_logic_test.dart test/calendar_i18n_test.dart \
             test/calendar_service_test.dart test/calendar_user_avatar_test.dart
→ All tests passed! (51 Tests)
```

Projektweites `flutter analyze` zeigt ausschließlich **vorbestehende** `info`-Hinweise in anderen Modulen (BuildContext-across-async-gaps, deprecated Radio-APIs u. a.) — keine davon im Kalender-Modul und keine durch dieses Audit eingeführt.

---

## 5. Offene Punkte / Empfehlungen (außerhalb des Fix-Scopes)

1. **Feiertags-/Schulferien-Daten dynamisch berechnen** statt hartkodiert — bewegliche Feste (Ostern etc.) und Jahre > 2027 werden sonst nicht abgedeckt. Empfehlung: Berechnung (z. B. Gauß'sche Osterformel) oder jährliche Datenpflege.
2. **Feiertagsnamen lokalisieren** — aktuell landessprachlich fix; ein Mapping über i18n-Keys würde die Anzeige an die App-Sprache anpassen.
3. **Doppeltes Datenmodell** — `lib/models/family_calendar_event.dart` (`FamilyCalendarEvent`) wird vom Screen nicht genutzt (der Screen hat ein eigenes privates `_CalendarEvent` mit zusätzlichen Feldern). Konsolidieren oder entfernen, um Wartungsrisiko zu vermeiden.
4. **Sprach-Picker vs. String-Datensatz** — `allStrings` enthält 28 Sprachen, der Picker nur 16. Klären, ob die 12 zusätzlichen (ru, uk, hr, sr, fi, da, el, sw, am, ha, so, ti) in den Picker sollen oder entfernt werden.
5. **Vollständiger Widget-Test des `CalendarScreen`** derzeit nicht sinnvoll umsetzbar, da der Screen harte Abhängigkeiten (Firebase, `BackendServiceFactory`, `NotificationService`, `FamilyMatchProfile`) im Feld-Initialisierer hat. Empfehlung: Dependency Injection, um den Screen pumpbar und testbar zu machen.
