# ParentPeak — Projekt-Kontext für KI-Assistenten

## Was ist ParentPeak?
Eine Flutter-App für Eltern. Ziel: Die BESTE Familien-App — modern, kreativ, elternfreundlich, international. Besser als FamilyWall, besser als alle Konkurrenten.

## Technischer Stack
- **Frontend:** Flutter (Dart), iOS + Android + Web
- **Backend:** Node.js/Express + Prisma + PostgreSQL auf Render (`https://parentpeak.onrender.com`)
- **KI:** Google Gemini 3.1 Pro Preview (`gemini-3.1-pro-preview`) via `google_generative_ai` Package
- **Auth:** Firebase Authentication (Email/Password + Google Sign-In)
- **Datenbank:** PostgreSQL auf Render (Prisma ORM)
- **Web-Deploy:** GitHub Pages via GitHub Actions (`parentpeak.de`)
- **State:** Lokal (SharedPreferences) + Backend-Sync wo nötig

## .env Datei (NICHT im Git)
Die `.env` Datei enthält alle API-Keys und Tokens. Sie liegt lokal im Projekt-Root.
Felder: BACKEND_BASE_URL, BACKEND_API_TOKEN, GEMINI_API_KEY, GEMINI_MODEL_NAME

## Render
Backend läuft auf Render. API-Key und DATABASE_URL sind als Environment Variables dort konfiguriert.

## Firebase Projekt
- Projekt-ID: `parentpeak-prod-2026`
- Web-App registriert mit authDomain: `parentpeak-prod-2026.firebaseapp.com`

## App-Architektur (Home-Screen)

### Layout (von oben nach unten):
1. **Kontext-Card** — Tageszeit-basiert (Morgens/Nachmittags/Abends/Nachts), personalisiert nach Kind-Alter
2. **Chat-Zeile** — "Was beschäftigt dich?" → 1 Tap → KI-Elternberatung
3. **Events-Teaser** — "Events in deiner Nähe → Alle"
4. **Feature-Grid** (2x2) — Alle Kacheln

### Feature-Kacheln:
| Kachel | Screen | Feature-ID |
|--------|--------|-----------|
| Impulse & Entwicklung | EntwicklungImpulseScreen | impulse_entwicklung |
| Kalender | CalendarScreen | kalender |
| Events & Aktivitäten | EventsActivitiesScreen | events_aktivitaeten |
| Familien-Küche | FamilienKuecheScreen | gemeinsam_satt |
| Eltern-Netzwerk | ElternNetzwerkScreen | eltern_match |
| KI Elternberatung | ChatScreen | ki_elternberatung |
| Familien-Zentrale | FamilienZentraleScreen | organisation |
| Familien-Geld | FamilienGeldScreen | finanzen_budget |
| Verschenkmarkt | TreasureHandoverScreen | verschenkmarkt |

## Wichtige Features im Detail

### KI-Chatbot (ChatScreen)
- Gemini 3.1 Pro mit pädagogischem System-Prompt (GfK nach Rosenberg + Jesper Juul)
- 3-Teile Antwortstruktur: Bedürfnis → GfK-Satz → Handlungsschritte
- Stream-basiert (generateContentStream)

### Familien-Küche (FamilienKuecheScreen)
- 1-Tap Rezept-Generator via Gemini
- Altersbasiert, saisonal, allergienfrei
- "Hat es geschmeckt?" Bewertung → Kinder-Hits Liste
- Rezept → Einkaufsliste Verknüpfung (mit Zutaten-Auswahl-Sheet)
- 10 Fallback-Rezepte (Fleisch/Fisch/Vegetarisch gemischt)

### Events & Aktivitäten (EventsActivitiesScreen)
- KI-Agent sucht lokale Events via Gemini (standortbezogen, saisonal)
- Community-Events (Eltern tragen selbst ein)
- Backend: GET/POST /api/events, flag, interest
- Event-Detail Seite mit Maps-Link + Website-Link
- "Bekannte Gesichter" (wer ist dabei?)
- LocationPickerWidget (GPS + Suche + OpenStreetMap Karte)

### Eltern-Netzwerk (ElternNetzwerkScreen)
- Spielfreunde-Profil: 5-Schritt Wizard
- ParentCoins (1 Einladung = 1 Coin, 5 = Premium)
- LocationPickerWidget für Standort
- Kurdistan Ala-Rengin Flagge (CustomPainter)

### Familien-Zentrale (FamilienZentraleScreen)
- Einkaufsliste: Menge inline ("3x Milch"), Auto-Emoji, Erledigt-Bereich 7 Tage, Häufig-gekauft
- To-do: Simpel, 3 Sekunden
- Kind-Dossier: Größen, Allergien, Arzt, U-Untersuchungen (auto nach Alter), Notfall-Info

### Familien-Geld (FamilienGeldScreen)
- Country-Selector: DE, AT, CH, TR, GB, Generic
- Monats-Schnellcheck (Fixkosten)
- Leistungs-Wegweiser (Kindergeld, KiZ, Wohngeld, BuT etc.)
- Meilenstein-Vorschau (Schulstart, Fahrrad, Smartphone — nach Kind-Alter)

### Impulse & Entwicklung (EntwicklungImpulseScreen)
- 3 Tabs: Tagesimpuls | Entwicklung | Wissen
- Eltern-Wissen: 30 GfK-basierte FAQ + Fuzzy-Search + personalisierter Impuls
- Entwicklungs-Check: 220+ Fragen, 8 Altersgruppen, KI-Bericht, PDF

### Spielidee (in Kontext-Card)
- 22 Aktivitäten (Baby/Kleinkind/Schulkind)
- Mit Dauer + Materialien
- Shuffle-Buttons (TextButton für Web-Kompatibilität)

## Bekannte Einschränkungen / Entscheidungen

### Web-Kompatibilität:
- KEIN `dart:io Platform` verwenden → crasht auf Web
- `GestureDetector` braucht `behavior: HitTestBehavior.opaque` für Web
- Besser: `TextButton` / `FilledButton` statt custom InkWell/GestureDetector
- NotificationService komplett deaktiviert auf Web (`kIsWeb` Guard in main.dart)
- `flutter_local_notifications` crasht auf Web (dart:io intern)

### Gemini API:
- KEIN `GenerationConfig` verwenden (verursacht Fehler bei Preview-Modellen)
- `systemInstruction` für JSON-Output nutzen
- Immer Fallback-Daten bereitstellen wenn Gemini ausfällt

### Feature-Flags:
- Alle Features auf Phase 1 + Free Tier (App ist komplett kostenlos für Beta)
- Premium/Paywall kommt später

### Lokalisierung:
- 27 Sprachen im Picker
- Hauptsprachen: DE, EN, TR, KU
- Kurdisch: Ala-Rengin Flagge als CustomPainter (kein Emoji)

## Coding-Stil
- Sauber, modern, null Fehler
- Immer `flutter analyze --no-pub` vor Push
- Alle Daten lokal in SharedPreferences (sensible Daten NIE zum Backend)
- Backend-Calls mit try/catch + Fallback
- Elternfreundlich: Warm, einladend, nicht technisch
- GfK-Philosophie: Keine Bewertung, keine Strafen, bedürfnisorientiert

## Git-Workflow
- Branch: `main`
- Push zu: `github.com/fatihbucak56-beep/Parentpeak`
- GitHub Actions deployed automatisch zu `parentpeak.de`
- Prisma DB Push: Nutze die DATABASE_URL aus den Render Environment Variables
