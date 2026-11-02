# Eltern-Netzwerk – Redesign-Konzept

Status: **Konzept, kein Code.** Grundlage ist `origin/main` bei `f6ae923` (nach #234).
Alle Zeilenangaben beziehen sich auf diesen Stand. Die Entscheidungen in Abschnitt 9
hat der Nutzer am 2026-11-03 bestätigt.

Kennzeichnung in diesem Dokument:

- **[V] verifiziert**: im Code an der genannten Stelle gelesen.
- **[A] vermutet**: plausibel abgeleitet, aber nicht durch Lauf oder Test belegt.
- **[N] nicht geprüft**: bewusst offen gelassen.

Es lief kein Test auf einem echten Gerät. Die Beobachtungen aus den Screenshots des
Nutzers wurden im Code nachvollzogen, nicht auf dem Gerät nachgestellt.

Feste Rahmenbedingungen (gelten für alle folgenden PRs):

- Keine Werbung, keine Monetarisierung. Die Free-Zusatzlimits aus
  `docs/MONETIZATION_ADS_PLAN.md` (z. B. „Eltern-Netzwerk 3 Kontakte/Monat") sind
  **nicht bestätigt** und werden **nicht** eingebaut.
- Login bleibt Pflicht.
- Kinderdaten (Namen, exakte Geburtsdaten, Besonderheiten) bleiben auf dem Gerät.
- Keine Kinderfotos, keine Kindernamen im Netzwerk.
- Nachrichten erst nach gegenseitigem Interesse.
- Jede Wisch-Geste hat eine gleichwertige Button-Alternative.

---

## 1. Ist-Analyse

### 1.1 Struktur des Screens

| Befund | Beleg | Status |
|---|---|---|
| Drei Tabs in dieser Reihenfolge: „Chats" (`network_tab_chats`), „Netzwerk" (`network_tab_network`), „Spielfreunde" (`network_copy_playmates`) | `lib/ui/eltern_netzwerk_screen.dart:460-466`, `:485-491` | [V] |
| FAB „Neuer Chat" nur im Chats-Tab, Farbe lila `0xFF7C3AED` | `eltern_netzwerk_screen.dart:467-483` | [V] |
| Netzwerk-Tab: Einladungs-Karte (Gradient lila), dann Karussell „Vielleicht kennst du", dann eingehende Anfragen, Freunde, gesendete Anfragen | `eltern_netzwerk_screen.dart:1894-2021`, `:2015-2020` | [V] |
| Spielfreunde-Tab: Statuspanel, eigener Profil-Kopf, „Familien in der Nähe", Liste der Match-Karten | `eltern_netzwerk_screen.dart:1228-1253`, `:1393-1550` | [V] |
| Die Datei hat 4395 Zeilen und enthält Chats, Netzwerk, Discovery, Wizard (`PlaymateProfileForm` ab `:2903`) und Layout (`PlaymateSetupLayout` ab `:2833`) | `wc -l`, `eltern_netzwerk_screen.dart:2833`, `:2903` | [V] |

### 1.2 Beobachtungen des Nutzers, belegt

**(a) Dieselben Familien erscheinen zweimal.** [V]

Beide Bereiche lesen dieselbe Liste `_matches`. Diese wird einmal über
`findMatchesWithFallback` geladen (`eltern_netzwerk_screen.dart:1351`, gesetzt in `:1370`).

- Netzwerk-Tab: `_suggestedParentsSection` ruft `selectPlaymateSuggestions(matches: _matches, …)` auf
  (`:2403-2409`). Das Ergebnis erscheint als horizontales Karussell (`:2455-2462`) mit
  Button „Verbinden" (`connect_btn`, `:2601`).
- Spielfreunde-Tab: `_discoveryView` rendert dieselbe Liste als vertikale Karten (`:1543-1548`)
  mit Button „Hallo sagen" (`network_say_hello`, `:1827`).
- **Beide Buttons tun dasselbe:** `FriendshipService.instance.sendRequest(...)`
  (`:2563` und `:1849`). Keiner der beiden ruft die Parent-Matching-Aktion `like` auf.
- Die Filter unterscheiden sich. Das Karussell blendet Freunde, „weggeklickte" und blockierte
  Familien aus (`lib/logic/playmate_suggestions.dart:38-44`). Die Liste filtert nur Blockierte
  (`eltern_netzwerk_screen.dart:1358-1362`). Eine im Karussell weggeklickte Familie bleibt also in der Liste.
- Der Kommentar über `_connectWithMatch` lautet „echte Aktion im Matching-Backend"
  (`:1842`). Tatsächlich wird eine Freundschaftsanfrage gesendet.

**(b) Zwei Hauptfarben konkurrieren.** [V]

| Farbe | Vorkommen in `eltern_netzwerk_screen.dart` | Wo |
|---|---|---|
| Lila `0xFF8B5CF6` | 34 | Schritt-Anzeige und Schritt-Titel im Wizard (`:3144`, `:3168`), Match-Karten-Icon (`:1648`), Profilkopf (`:1407-1410`), Anfragen-Karte (`:2047-2050`), Buttons-Rahmen (`:1830`, `:3355` u. a.) |
| Lila dunkel `0xFF7C3AED` | 15 | FAB (`:476`), „Verbinden" (`:2587`), „Hallo sagen" Textfarbe (`:1829`), Zähler (`:2133`) |
| Grün `0xFF16A34A` | 14 | Erfolg-Snackbars, „erledigt"-Punkte im Wizard (`:3142`), Match-Score-Badge (`:1680-1695`) |
| Türkis `0xFF0EA5A4` (nicht die Theme-Farbe) | 4 | u. a. `:913`, `:1022-1041`, `:1144` |
| Türkis `0xFF0E7F77` | 1 | Match-Gründe (`:1804`) |
| Theme-Primär (Türkis `0xFF0F766E`) | implizit | TabBar-Indikator (Default), Wizard-Button „Weiter" (`FilledButton` ohne Farbe, `:3224-3240`), `colorScheme.primary` z. B. `:1458`, `:1510`, `:3604` |

Das Projekt-Theme setzt **Türkis als Primärfarbe** (`lib/logic/theme_service.dart:61-66`, dunkel `:155-160`).
Der Screen überschreibt das an rund 50 Stellen mit Lila. Dadurch sind Tabs und „Weiter" türkis,
Schritt-Titel, FAB und Kontakt-Buttons lila. [V]

**(c) Avatare gemischt.** [V]

- Familien-Emoji 👪: Match-Karte (`:1652`), eigener Profilkopf (`:1415`), Wizard-Kopf (`:2868`).
- Initiale im Kreis: Karussell (`:2493-2507`), eingehende Anfragen (`:2055-2066`), Freundeskarte (`:2196-2212`).
- Zwei verschiedene Farbpaletten für Initialen: `_avatarColor` (`eltern_netzwerk_screen.dart:2644-2654`)
  und `UserAvatar` (`lib/ui/widgets/user_avatar.dart:23-29`). `UserAvatar` wird im Screen nicht genutzt.

**(d) „Gesendete Anfragen" zeigt „Familie" statt des Namens.** [V]

- Anzeige: `network_waiting_confirmation` = „{name} — wartet auf Bestätigung"
  (`eltern_netzwerk_screen.dart:2164-2168`, Text `lib/l10n/app_localizations_all.dart:2057`).
- `{name}` kommt vom Server: `GET /api/friendships/:uid` nimmt `UserProfile.displayName`
  und fällt auf `'Familie'` zurück (`backend/server.js:9767-9768`). Zusätzlich gibt es einen Client-Fallback
  in `lib/logic/friendship_service.dart:23-25`.
- Ursache: Die Freundschaft kennt nur das **Konto-Profil** (`UserProfile`). Der Name aus dem
  **Spielfreunde-Profil** (`ParentMatchingProfile.name`) wird nicht verwendet. Der Absender sichert vor dem
  Senden nur **seinen eigenen** Namen (`friendship_service.dart:163-172`). Hat die Zielfamilie nie einen
  Konto-Anzeigenamen gesetzt, sieht der Absender „Familie".

**(e) Statusbanner belegt Platz.** [V]

- `_profileStatusPanel()` steht oben in der Discovery-Ansicht, auch wenn das Profil aktiv ist
  (`eltern_netzwerk_screen.dart:1402`). Dann zeigt es „Profil vom Server als aktiv bestätigt."
  (`app_localizations_all.dart:1358`). Das ist eine technische Bestätigung ohne Handlungswert.
- Ist das Profil nicht aktiv, zeigt der Tab nur „Kein aktives Profil auf dem Server bestätigt. Lokale
  Entwürfe werden nicht automatisch veröffentlicht." (`:1359-1360`) plus „Bearbeiten" und „Löschen"
  (`eltern_netzwerk_screen.dart:1236-1253`). Es gibt keinen klaren Hauptschritt.
- Das Panel ist reiner Text mit 12 px Innenabstand, ohne Icon und Kartenstil
  (`lib/ui/widgets/playmate_profile_status.dart:46-66`).

**(f) `same_city` als Rohtext.** [V]

- Der Server liefert den Grund `same_city` (`backend/server.js:13463`).
- `networkMatchReasonLabel` sucht `network_copy_reason_same_city` und gibt bei fehlendem Key
  den **Rohcode** zurück (`eltern_netzwerk_screen.dart:50-54`).
- Es gibt nur sechs Reason-Keys (`nearby`, `shared_family_form`, `shared_interests`,
  `shared_languages`, `shared_values`, `similar_child_age`). `same_city` fehlt in allen Sprachen.

### 1.3 Weitere Befunde

| # | Befund | Beleg | Status |
|---|---|---|---|
| W1 | **Discovery-Kontakt umgeht das Prinzip „erst gegenseitig".** „Verbinden" und „Hallo sagen" erzeugen eine Freundschaft. Ist das Zielkonto öffentlich (`UserProfile.isPrivate = false`), wird sie **sofort** `accepted`, und der Freundes-Chat ist offen. Default ist privat (`DEFAULT TRUE`), also normalerweise `pending`. **Sofort-Fix:** PR #238 (`fix/friendship-discovery-pending`, Aufgabe 4 vom 2026-11-03): Der Client sendet bei Discovery-Kontakten `source: "discovery"`, der Server setzt dann immer `pending`. Ohne `source` (ältere App-Versionen, Einladungslink, QR) bleibt das alte Verhalten; ältere Apps bleiben bis zum Update ein Restrisiko. Endgültig gelöst wird W1 erst mit dem Match-Ablauf (c–e). | `backend/server.js:9680-9692`, `:5493`, Chat-Prüfung `areFriends` `:10651-10657` | [V] |
| W2 | Die Parent-Matching-Logik (`like`/`pass`, Mutual, Nachrichten nur nach Match) ist im Backend vorhanden, wird vom aktiven UI aber **nicht benutzt**. | Siehe 3.1; UI ruft nur `findMatchesWithFallback` am Matching-Service auf | [V] |
| W3 | Der Client-Service enthält Platzhalter, die leer zurückgeben: `fetchProfiles`, `fetchConnectedProfileIds`, `fetchMessages`, `sendMessage`, `streamMessages`. | `lib/logic/parent_matching_backend_service.dart:459-523` | [V] |
| W4 | `sendAction` setzt `connected = true`, sobald die Aktion **gespeichert** wurde, nicht wenn sie gegenseitig ist. `recordAction` wertet `connected`/`matchState` der Antwort nicht aus. | `parent_matching_backend_service.dart:525-545`, `:651-693` | [V] |
| W5 | `MatchConversationScreen` lädt Nicht-Freundes-Chats über den Platzhalter. Ein Parent-Matching-Chat bliebe leer. | `lib/ui/match_conversation_screen.dart:183`, `:239` | [V] |
| W6 | `ParentMatchingScreen` (älterer Screen, 1700+ Zeilen) wird nirgends instanziiert. Er enthält die einzige OTP-Verifizierungs-UI und harte deutsche Texte („Familien-Kontakt", „Familie"). | Keine Aufrufe von `ParentMatchingScreen(`; `lib/ui/parent_matching_screen.dart:238-243`, `:269-280`, `:1567-1591` | [V] |
| W7 | Folge von W6: Im aktiven UI wird `phoneVerified` nie gesetzt. `identityVerified` und `moderationChecked` setzt nur der Seed für Beispielprofile. | `backend/server.js:8601` (OTP), `:5065-5086` (Seed) | [V] |
| W8 | Match-Score „{score} % Match" als grünes Badge auf jeder Karte. Das ist eine Wertung von Familien. | `eltern_netzwerk_screen.dart:1680-1695` | [V] |
| W9 | Das Karussell hat kein Melden/Blockieren-Menü, nur ein „X". Die Match-Karte hat beides im Drei-Punkte-Menü. | Karussell `:2468-2640`; Karte `:1698-1738` | [V] |
| W10 | Wizard Schritt 1: Name und Ort werden erst beim Absenden in Schritt 5 geprüft. „Weiter" prüft nichts. | `_next` `:3010-3018`, `_submit` `:3031-3039` | [V] |
| W11 | Der Server verlangt zusätzlich `city` und `familyForm`. | `backend/server.js:8714-8721` | [V] |
| W12 | 0 `Semantics`-Widgets, 0 `semanticLabel`, 2 Tooltips im ganzen Screen. Emojis als Icons ohne Label. | `grep` in `eltern_netzwerk_screen.dart` | [V] |
| W13 | Kein „Reduzierte Bewegung" im ganzen `lib/`: keine Nutzung von `MediaQuery.disableAnimations`. | `grep` in `lib/` | [V] |
| W14 | Radien: 14 (16×), 16 (13×), 20 (10×), 12 (8×), 10 (7×), 18 (4×), 8, 6 (je 3×), 24, 11, 5, 2. Theme definiert Karten-Radius 24 und Button-Radius 16 (`theme_service.dart:71-78`, `:128-135`). | `grep BorderRadius.circular` | [V] |
| W15 | Schriftgrößen hart codiert: 12 (13×), 11 (12×), 10 (6×), dazu 13 bis 28. 10–11 px liegen unter einer gut lesbaren Mindestgröße. Das Theme hat eine vollständige `textTheme` (`theme_service.dart:88-108`). | `grep fontSize` | [V] |
| W16 | Drei Button-Stile für dieselbe Aktion: `FilledButton` lila r10 (Karussell `:2585-2598`), `OutlinedButton` lila r12 (Karte `:1824-1838`), `OutlinedButton` lila r10 Schrift 12 (Freund-Chat `:2240-2250`). Wizard nutzt `FilledButton` mit Theme-Farbe r14. | Zeilen wie angegeben | [V] |
| W17 | Bearbeiten/Löschen im Profilkopf sind `GestureDetector` mit 12-px-Text, also kleine Tippziele ohne Button-Semantik. | `eltern_netzwerk_screen.dart:1447-1485` | [V] |
| W18 | Discovery liefert bereits bewertete Profile erneut. Es gibt keine Paginierung, maximal 100 Kandidaten. | `backend/server.js:13499-13503` | [V] |

---

## 2. Zielbild

### 2.1 Struktur

Drei Bereiche als Tabs. Das eigene Profil liegt hinter dem Avatar oben rechts.

```
┌──────────────────────────────────────────┐
│  Eltern-Netzwerk                  (AK)   │  ← eigener Avatar: Profil, Sichtbarkeit,
├──────────────────────────────────────────┤     Einladen, Bearbeiten, Pausieren, Löschen
│  Entdecken  │  Matches (2)  │  Chats     │  ← eine Farbe für alle aktiven Elemente
└──────────────────────────────────────────┘
```

- **Entdecken**: eine Karte nach der anderen.
- **Matches**: neue Matches (beide interessiert), eingehendes Interesse, eigene offene Anfragen.
- **Chats**: nur bestehende Verbindungen.
- **Einladen per Link/QR** wandert ins Profilmenü und in den Leerzustand von Entdecken.
  Es ist kein eigener Tab-Inhalt mehr.
- Ohne Profil zeigen alle drei Tabs denselben ruhigen Einstieg „Profil anlegen" (Wizard).
  Ein Statustext nur dann, wenn wirklich etwas zu tun ist.

### 2.2 Entdecken – Karte

```
┌──────────────────────────────────────────┐
│                                    ⋮     │  ← Menü: Melden, Blockieren
│              ( A K )                     │  ← Initialen oder Illustration, kein Foto
│           Familie Aylin                  │
│        ca. 3 km · Neukölln               │  ← grobe Entfernung, Bezirk
│                                          │
│  Kinder   2–3 J · 5–6 J                  │  ← nur Altersspannen
│  Sprachen Deutsch · Türkçe               │
│  Werte    Natur · Ruhe                   │
│  Zeiten   Nachmittags · Wochenende       │
│                                          │
│  „Wir sind gern auf Spielplätzen …"      │  ← Bio, max. 3 Zeilen, „mehr" zum Aufklappen
│                                          │
│  Gemeinsam: Sprache · Kinderalter        │  ← Gründe statt Prozentwert
├──────────────────────────────────────────┤
│   [ Nicht jetzt ]      [ Interessiert ]  │  ← gleich groß, Sekundär + Primär
└──────────────────────────────────────────┘
          3 weitere Familien in der Nähe
```

- **Kein Prozent-Score.** Stattdessen bis zu drei „Gemeinsam"-Gründe (W8).
- **Entfernung** gerundet: „unter 1 km", „ca. 3 km", „in deiner Stadt". Nie Straße oder Koordinaten.
- **„Nicht jetzt"** → Aktion `pass`. Die Karte verschwindet leise, ohne Animation einer Ablehnung.
- **„Interessiert"** → Aktion `like`. Die Antwort enthält `connected`/`matchState`. Bei `matched` folgt der Match-Bildschirm.
- **Wischen** (nicht zum Start, später; Entscheidung 9.3): rechts = Interessiert, links = Nicht jetzt. Immer mit
  denselben Buttons. Wischen ist nie der einzige Weg.
- **Rückgängig** der letzten „Nicht jetzt"-Entscheidung als Snackbar-Aktion für einige Sekunden.
  Technisch ein neues `like` (siehe 3.1). [A] Ob das gewollt ist, ist Teil von 9.

### 2.3 Match-Bildschirm „Es passt"

Ruhig, ohne Konfetti, ohne Countdown.

```
┌──────────────────────────────────────────┐
│          (AK)   ♡   (MS)                 │
│                                          │
│      Ihr seid beide interessiert.        │
│  Ihr könnt euch jetzt Nachrichten schreiben.
│                                          │
│  Ideen für die erste Nachricht:          │
│  ○ Hallo! Wir sind oft am Spielplatz …   │  ← antippen = Text ins Eingabefeld
│  ○ Habt ihr Lust auf ein Treffen …       │
│  ○ Unsere Kinder sind ähnlich alt …      │
│                                          │
│        [ Nachricht schreiben ]           │
│            Später                        │
└──────────────────────────────────────────┘
```

- Die Vorschläge sind statische, lokalisierte Texte. Optional mit `{gemeinsamer Grund}` als
  Platzhalter. Keine KI (das Profil-Formular verspricht „Das Matching verwendet keine KI",
  `app_localizations_all.dart:1356`).
- Ein Treffen-Hinweis zur Sicherheit: „Erstes Treffen an einem öffentlichen Ort".
- „Später" führt zurück zu Entdecken. Das Match steht danach unter Matches → „Neu".

### 2.4 Matches

- **Neu**: gegenseitig, noch keine Nachricht. Antippen öffnet den Chat.
- ~~**Interesse an euch**~~: entfällt (Entscheidung 9.5). Eingehendes Interesse wird erst beim Match sichtbar.
- **Deine Anfragen**: eigene `like` ohne Antwort, mit Name statt „Familie" (1.2 d). Aktion „Zurückziehen".
- Kein Hinweis wie „wartet seit 5 Tagen" und keine Ablaufzeit.

### 2.5 Chats

- Bestehende Chat-Liste bleibt. Neue Einträge entstehen nur aus Matches oder aus Einladung per Link/QR (bewusste Verbindung).
- Im Chat oben: Menü mit Melden, Blockieren, Verbindung beenden.

### 2.6 Zustände

| Zustand | Inhalt |
|---|---|
| Laden | Skelett einer Karte (keine Spinner-Wand). Bei reduzierter Bewegung statisch. |
| Leer: keine Familien in der Nähe | Illustration, „Gerade sind keine weiteren Familien in deiner Nähe." + „Umkreis erweitern" + „Familien einladen". |
| Leer: alle angesehen | „Du hast alle Familien in deiner Nähe gesehen. Schau später wieder vorbei." Kein Druck. |
| Kein Profil | „Lege ein kurzes Profil an, damit andere Familien dich finden." + Wizard-Button. |
| Profil pausiert | „Dein Profil ist pausiert. Andere sehen dich gerade nicht." + „Fortsetzen". |
| Fehler Netz | „Keine Verbindung. Bitte prüfe dein Netz." + „Erneut versuchen" (Texte wie in #236). |
| Fehler Server | „Der Server ist gerade nicht erreichbar. Bitte versuche es später erneut." + Fehlercode-Zeile. |
| Nicht angemeldet | Login-Hinweis wie heute (`network_copy_login_required`). |

---

## 3. Backend-Wiederverwendung

### 3.1 Was vorhanden ist [V]

| Baustein | Beleg | Eignung |
|---|---|---|
| Aktionen `like`, `pass`, `favorite`, `contact`, `report`, `block` | `backend/server.js:5093` | ✅ „Interessiert" = `like`, „Nicht jetzt" = `pass` |
| `POST /parent-matching/actions` (+ Legacy `/api/parent-matching/record-action`) | `server.js:8954`, `:13554`, Logik `:8853-8952` | ✅ |
| Vorbedingungen: eigenes Profil (409), Ziel aktiv (404), nicht man selbst (403) | `server.js:8871-8894` | ✅ |
| Jede Aktion ist eine neue Zeile in `ParentMatchingAction`. Keine Eindeutigkeit, keine Überschreibung. Für Mutual zählt die **neueste** Aktion je Profil. | `server.js:8896-8904`; `getMutualConnectionProfileIds` ab `:5769` | ✅ „Rückgängig" = neue Aktion. ⚠️ Tabelle wächst. |
| **Mutual-Erkennung sofort in der Antwort**: `connected` und `matchState` (`matched` / `pending` / `none`) | `server.js:8906-8919` | ✅ Reicht für den Match-Bildschirm beim Auslöser |
| `GET /parent-matching/connections` → `{ profileIds }` (nur gegenseitige) | `server.js:8827-8850` | ✅ Basis für Matches/Neu |
| Nachrichten `GET/POST /parent-matching/messages`, SSE `/messages/stream`; **403 ohne Mutual** („Chat erst nach beidseitigem Match verfügbar") | `server.js:8956`, `:9048-9066`, `:9107-9131` | ✅ Erfüllt „Nachrichten erst nach gegenseitigem Interesse" |
| Discovery `GET /parent-matching/discover` (Legacy `/api/parent-matching/find`) | `server.js:13517-13548` | ✅ teilweise (siehe Lücken) |
| Scoring: Nähe ≤ 30, gleiche Stadt 18, Interessen 20, Kinderalter 15, Sprachen 15, Werte 15, Familienform 5; max. 100; absteigend sortiert; Standard-Umkreis 25 km | `server.js:13435-13497` | ✅ Reihenfolge der Karten |
| Ausschluss gesperrter Konten global, Blockierte nur in Richtung des Suchenden | `server.js:13505-13511`, Filter `:13443` | ⚠️ siehe Lücken |
| Profil-Mapping liefert gerundete Koordinaten (2 Nachkommastellen) und `approximateLocation`, keine Kindernamen, keine Geburtsdaten, nur Altersspannen | `mapParentMatchingProfileForClient` ab `server.js:5568` | ✅ |
| Verifizierungsfelder `phoneVerified`, `identityVerified`, `moderationChecked` im Schema (seit #237) und in der Antwort | `backend/prisma/schema.prisma` (`ParentMatchingProfile`), `server.js:5568ff.` | ✅ Anzeige möglich |
| OTP: `POST /parent-matching/verification/request-otp` und `/confirm-otp` setzt `phoneVerified` | `server.js:8515`, `:8558-8619`, `:8601` | ✅ Backend da, UI fehlt im aktiven Screen (W6) |
| Melden `POST /api/safety/report`, Blockieren `POST /api/safety/block`, Admin-Liste `/admin/reports`, Sperren `/admin/users/:userId/suspend` | `server.js:10249-10283`, `:10192`, `:10306`, `:10381` | ✅ |

### 3.2 Was fehlt

| # | Lücke | Wirkung | Status |
|---|---|---|---|
| L1 | Discovery schließt bereits mit `like`/`pass` bewertete Profile **nicht** aus (`ParentMatchingAction` wird nicht gelesen). | „Eine Karte nach der anderen" zeigt dieselben Familien erneut. Lösung: Ausschluss nach letzter Aktion, `pass` erst nach Abkühlzeit wieder zeigen (Wert offen). | [V] Code `server.js:13499-13513` |
| L2 | Keine Paginierung/Cursor, max. 100 Kandidaten aus `findMany` **vor** dem Scoring (`take: 100` ohne Sortierung). | Bei vielen Profilen fehlen gute Treffer zufällig. | [V] Code; Auswirkung [A] |
| L3 | Kein „Es passt"-Ereignis für die **andere** Seite: kein Push, kein Stream-Event bei Mutual. Nur der Auslöser bekommt `matched`. | Die andere Familie sieht das Match erst beim nächsten Laden von Matches. Für den Start vertretbar; Push als Folge. | [V] Kein Publish außer für Nachrichten (`server.js:9164-9179`) |
| L4 | Kein Endpunkt für „eingehendes Interesse" und „eigene offene `like`". `connections` liefert nur Mutual-IDs. | Matches → „Interesse an euch" und „Deine Anfragen" nicht baubar ohne neue Route. | [V] |
| L5 | Kein Match-Zeitpunkt, kein „gelesen"-Status. | „Neu" lässt sich nur clientseitig (lokal gespeichert) markieren. | [V] Kein Modell dafür im Schema |
| L6 | Blockieren ist in Discovery einseitig: Wer **mich** blockiert hat, sehe ich weiter. | Blockierte Person kann weiter `like` senden. Fix: `isBlockedBetween`-Logik (`server.js:9626`) auch in Discovery und Actions. | [V] |
| L7 | Aktionen `report`/`block` in `ParentMatchingAction` sind **nicht** mit `SafetyReport`/`SafetyBlock` verbunden. | Das UI muss die Safety-Routen nutzen (wie heute `BlockReportService`), nicht die Matching-Aktion. | [V] |
| L8 | Kein eigenes Rate-Limit für Aktionen, Anfragen, Nachrichten. Es gibt nur ein globales Schreib-Limit pro IP und Methode (Default 120 pro 15 min). | Massen-`like` möglich. | [V] `server.js:209-217`, `:4133-4155` |
| L9 | Kein Inhaltsfilter für Nachrichten (weder Parent-Matching noch Freundes-Chat). | Nur Melden hilft nachträglich. | [V] für die Handler; [N] ob ein Filter an anderer Stelle greift |
| L10 | Client-Service nutzt die Matching-Nachrichten nicht (Platzhalter, W3–W5). | Für Chats nach Match entweder Client-Methoden echt anbinden oder Match → Freundschaft überführen (Entscheidung im PR e). | [V] |
| L11 | `/api/parent-matching/profiles` (Legacy) schreibt `familyForm: null` in ein Pflichtfeld. | Folgeaufgabe aus #237, unabhängig vom Redesign. | [V] `server.js:13363-13425` |
| L12 | Keine Funktion „Profil pausieren" (nur `isActive` beim Löschen). | Zustand „pausiert" bräuchte eine Route. | [A] nicht vollständig gesucht |

### 3.3 Verhältnis zu Freundschaften

Heute laufen Discovery-Kontakte über Freundschaften (W1, 1.2 a). Im Zielbild gilt:

- **Fremde aus Entdecken** → nur über `like`/Mutual. Chat erst nach Match.
- **Bekannte per Link/QR** → wie heute über Freundschaft (bewusste Einladung).
- Für das Chat-Ziel nach einem Match gibt es zwei Wege (Entscheidung im PR e):
  1. Matching-Nachrichten (`/parent-matching/messages`) im Client anbinden. Sie sind serverseitig schon an Mutual gebunden.
  2. Bei Mutual serverseitig eine `accepted`-Freundschaft anlegen und den bestehenden Freundes-Chat nutzen. Dafür ist ein Backend-Eingriff nötig.
  **Entschieden (9.9): Weg 2.** Er nutzt die fertige Chat-UI mit Melden, Blockieren und Verlauf löschen und vermeidet zwei Chat-Systeme.

---

## 4. Sicherheit und Datenschutz

| Regel | Heute | Ziel |
|---|---|---|
| Nachrichten erst nach gegenseitigem Interesse | Matching-Nachrichten: ja (`server.js:9063-9066`). Discovery-Kontakt über Freundschaft: bei öffentlichem Konto **nein** (W1). | Discovery nur noch `like`. Freundschaft aus Discovery entfernen. |
| Melden/Blockieren überall | Match-Karte: ja. Karussell: nein (W9). Chat: ja (über Freundes-Chat). | Menü ⋮ auf jeder Karte, im Match-Bildschirm, in Matches und im Chat. |
| Nur grobe Entfernung | Server liefert gerundete Koordinaten und `distanceKm` als ganze Zahl (`server.js:13453-13457`). Wizard speichert `coarseCoordinate` (`eltern_netzwerk_screen.dart:3061-3062`). | Anzeige in Stufen („unter 1 km", „ca. 3 km", „bis 10 km"), keine Kartenansicht. |
| Keine Kindernamen/-fotos | Kinderdaten bleiben lokal; Server bekommt nur `childAges` (Text `app_localizations_all.dart:1356`). | Bleibt. Bio-Hinweis „keine Kindernamen" im Wizard beibehalten. |
| Fotos | Konto-Avatar-URL wird in Freundes-Karten angezeigt (`:2056-2058`). | Zum Start keine Fotos in Entdecken/Matches, nur Initialen oder Illustration; entschieden: keine Fotos (9.2). |
| Missbrauch / Rate-Limit | Nur globales IP-Limit (L8), OTP eigenes Limit (`server.js:8528-8534`). | Pro Nutzer: **50 „Interessiert" pro Tag** als Sicherheitslimit (9.7), serverseitig änderbar, nicht als Bezahlschranke. Kein Upsell-Hinweis. |
| Moderation | Meldungen → `SafetyReport` `pending`; Admin entscheidet und sperrt manuell. Keine Schwelle für automatisches Ausblenden. | Siehe 9.8: 1 Meldung → Admin-Warteschlange, für Meldende ausgeblendet; ab 3 Meldungen von verschiedenen Konten für alle vorläufig ausgeblendet, bis der Admin entscheidet. Umsetzung im Moderations-Paket (Abschnitt 8). |
| Blockieren | Discovery einseitig (L6). | Beidseitig in Discovery und Actions. |
| Verifizierung | `phoneVerified` nur über toten Screen erreichbar (W6, W7). | Badge „Telefon bestätigt" auf der Karte, wenn `true`. OTP-Schritt im Profil-Menü. Nicht Pflicht für „Interessiert", nur Badge (9.6). |

---

## 5. Designsystem

Grundlage ist das vorhandene `ThemeData` in `lib/logic/theme_service.dart`. **Kein zweites Theme.**
Neue Bausteine lesen Farben, Text und Formen aus `Theme.of(context)`.

### 5.1 Farben

- **Hauptfarbe**: `colorScheme.primary` = Türkis `0xFF0F766E` (hell) / `0xFF14B8A6` (dunkel) (`theme_service.dart:61-66`, `:155-160`).
  Für Tabs, Primär-Buttons, aktive Schritt-Punkte, Links.
- **Akzent**: `colorScheme.tertiary` = Amber `0xFFF59E0B` (hell) / `0xFFFBBF24` (dunkel). Nur sparsam: Badge „Neu", Hinweis-Icons.
  Entschieden (9.1): Amber als Akzent, kein Indigo.
- **Erfolg/Fehler**: `colorScheme.primary` bzw. `colorScheme.error`. Das harte Grün `0xFF16A34A` entfällt.
- Alle Literal-Farben aus 1.2 b entfallen. Eine Avatar-Palette (aus `UserAvatar`), an das Theme angepasst.

### 5.2 Typografie

- Nur `theme.textTheme`: `titleLarge` (Kartentitel), `titleMedium` (Abschnitte), `bodyMedium` (Text), `labelLarge` (Buttons), `labelMedium` (Chips).
- Keine Größe unter `labelMedium` für Inhalte. Keine `fontSize`-Literale im Screen.

### 5.3 Abstände und Radien

- Abstands-Raster 4/8/12/16/24. Seitenrand 16.
- Radien: Karten **24** (wie `cardTheme`), Buttons **16** (wie `elevatedButtonTheme`), Chips **12**, Eingaben 16 (wie `inputDecorationTheme`).
- Optional kleine Konstantenklasse (z. B. `NetworkSpacing`) nur im Netzwerk-Ordner, kein globales Token-System in diesem Projekt.

### 5.4 Komponenten (wiederverwendbar)

| Komponente | Zweck | Basis |
|---|---|---|
| `FamilyAvatar` | Initialen oder Illustration, feste Größen S/M/L, Semantik-Label | `UserAvatar` (`lib/ui/widgets/user_avatar.dart`) erweitern |
| `FamilyCard` | Entdecken-Karte, Match-Kachel, Anfrage-Zeile (Varianten) | neu, `Card` + `cardTheme` |
| `InfoChip` | Sprache, Wert, Zeit, Kinderalter | `Chip`/`ChipTheme` |
| `PrimaryAction` / `SecondaryAction` | „Interessiert" / „Nicht jetzt", gleiche Höhe ≥ 48 | `FilledButton` / `OutlinedButton` mit Theme-Formen |
| `NetworkEmptyState` | Leerzustände | `PlaymateDiscoveryEmptyState` (`lib/ui/widgets/playmate_discovery_empty_state.dart`) verallgemeinern |
| `NetworkBanner` | nur handlungsrelevante Hinweise (Profil fehlt/pausiert, Fehler) | ersetzt `PlaymateProfileStatusPanel` in der Discovery |
| `SafetyMenu` | ⋮ mit Melden/Blockieren | bestehende `showReportSheet` + `BlockReportService` |

---

## 6. Barrierefreiheit, Sprache, RTL

- **Button-Alternative**: Jede Geste (Wischen, Ziehen) hat dieselbe Aktion als Button. Wischen ist für Screenreader aus;
  dort nur Buttons und `Semantics(customSemanticsActions)`.
- **Semantik**: Karte als eine Einheit mit Label „Familie Aylin, ca. 3 Kilometer, Kinder 2 bis 3 Jahre …".
  Emojis/Icons mit `excludeSemantics` oder Label. Heute 0 Semantics (W12).
- **Tippziele** ≥ 48 × 48. Bearbeiten/Löschen als echte Buttons (W17).
- **Große Schrift**: Tests mit Textskalierung 2.0 bei 360×640. Karten scrollen innen statt zu überlaufen. Buttons umbrechen.
- **RTL**: `EdgeInsetsDirectional`, `AlignmentDirectional`. Wisch-Richtung folgt der Leserichtung oder ist richtungsneutral (Entscheidung 9.3).
  Test mit Arabisch.
- **Reduzierte Bewegung**: `MediaQuery.of(context).disableAnimations` respektieren. Dann keine Karten-Animation und kein Wisch-Flug, nur Überblenden. Heute im Projekt nicht genutzt (W13).
- **Sprachen**: Alle neuen Texte in de, en, tr, ku, fr, es, it, ar über `AppStringsManager`/`context.tr()`
  (`lib/l10n/app_localizations_all.dart`, `lib/l10n/localization_extension.dart`).
  Prüfung über bestehende Tests (`test/visible_text_spelling_test.dart`) und einen Test „nicht leer, nicht englisch-identisch" wie in #235.
  Fehlenden Key `network_copy_reason_same_city` ergänzen. Fallback auf Rohcode durch neutralen Text ersetzen.
- Kurdisch: neue Texte als „von Muttersprachler zu prüfen" markieren (wie in #235).

---

## 7. Ton

- „Nicht jetzt" statt „Nope", „Interessiert" statt „Like". Kein Herz-Zähler.
- Kein Prozent-Score (W8). Gemeinsamkeiten statt Wertung.
- Keine Countdowns, keine Ablaufzeiten, kein „wartet seit …", keine Erinnerung „Du hast noch nicht geantwortet".
- Kein Hinweis an die andere Seite bei „Nicht jetzt". Kein „Ghosting"-Vorwurf.
- Fehlertexte schlicht, ohne Fachbegriffe (Stil aus #236).
- Match-Bildschirm freundlich und ruhig: „Ihr seid beide interessiert." statt „It's a Match!!!".
- Leerzustand ohne Druck: „Schau später wieder vorbei."

---

## 8. PR-Aufteilung

| PR | Inhalt | Abhängig von | Risiko |
|---|---|---|---|
| **(f0) Sofort-Korrekturen** | `network_copy_reason_same_city` in 8 Sprachen, unbekannte Gründe ausblenden statt Rohcode; Pflichtfelder Name/Ort beim „Weiter" in Schritt 1 prüfen. Umgesetzt in PR #239. Zusätzlich W1-Sofort-Fix in PR #238. | – | gering |
| **(a) Designsystem-Komponenten** | `FamilyAvatar`, `FamilyCard`, `InfoChip`, Aktions-Buttons, `NetworkEmptyState`, `NetworkBanner`, `SafetyMenu`; nur Theme-Werte; Widget-Tests (360×640, 2× Text, RTL) | – | gering, keine Verhaltensänderung |
| **(b) Navigation** | Tabs Entdecken / Matches / Chats; Profil hinter Avatar; Einladen ins Profilmenü; Statusbanner nur bei Handlungsbedarf; doppeltes Karussell entfernen. Verhalten der Buttons noch unverändert. | a | mittel: Deep-Links `initialTab` (`eltern_netzwerk_screen.dart:69-70`) und `home_screen.dart:159`, `:685` anpassen |
| **(c) Entdecken-Karten** | Eine Karte nach der anderen; „Nicht jetzt" = `pass`, „Interessiert" = `like`; `recordAction` wertet `matchState` aus (W4); Backend: bewertete Profile ausschließen (L1), Blockieren beidseitig (L6) | a, b | **hoch**: ändert Kontaktweg von Freundschaft auf Matching. Backend-Änderung mit Tests gegen echtes Schema (Schema-Guard aus #237). |
| **(d) Match-Bildschirm und Matches** | „Es passt"-Ansicht mit Vorschlägen; Liste „Neu"; neue Route für eingehendes/ausgehendes Interesse (L4) | c | mittel |
| **(e) Chat-Anbindung** | Chat nach Match (Weg 1 oder 2 aus 3.3); Platzhalter im Client entfernen (W3, W5) | d | **hoch**: Datenschutz, Chat-Zugriff |
| **(m) Moderations-Paket** | Umsetzung von 9.8, in kleinen PRs: (m1) Admin sieht Profilname, Ort und Bio zur Meldung; (m2) Admin-Aktionen „Freigeben", „Profil deaktivieren", „Konto sperren" mit je einem Klick; (m3) Meldende sehen das gemeldete Profil nicht mehr, Zählung verschiedener Meldender, ab 3 vorläufig für alle ausgeblendet; (m4) Melden-Menü auf allen Karten (Karussell, Anfragen); (m5) Benachrichtigung des Admins bei neuer Meldung. Details siehe Bericht zur Moderation, Phase A. | – | mittel: Backend-Filter in Discovery, Tests gegen echtes Schema |
| **(f) Aufräumen** | toten `ParentMatchingScreen` entfernen, OTP-UI ins Profilmenü übernehmen (W6, W7); Legacy-`familyForm: null` (L11); Literal-Farben/-Größen entfernen | c | gering bis mittel |

Reihenfolge: f0 → a → b → m → (c + d + e) → f.
**Launch-Umfang (bestätigt, 9.11):** f0, a, b und das Moderations-Paket (m). Der
Match-Ablauf c bis e folgt danach als **zusammenhängendes Paket**. c allein wäre eine
Sackgasse: Ohne Match-Bildschirm und Chat gäbe es nach gegenseitigem Interesse keinen
Weg zum Gespräch. c, d und e können als einzelne PRs reviewt, sollten aber gemeinsam
freigeschaltet werden (z. B. hinter einem internen Schalter, nicht über die
Monetarisierungs-Flags).

Risiken quer:

- **Übergang bestehender Kontakte** [A]: Heutige Discovery-Anfragen sind Freundschaften. Sie bleiben gültig und erscheinen unter Chats. Keine Migration nötig, aber in (c) zu bestätigen.
- **Zwei Wege zur Verbindung** (Einladung = Freundschaft, Entdecken = Match) müssen im UI klar unterscheidbar sein.
- **Leere Discovery** bei wenigen Nutzern zum Start: Leerzustand mit Einladen ist wichtig.
- **Moderation** muss vor breiter Öffnung stehen (Abschnitt 4).
- `eltern_netzwerk_screen.dart` ist sehr groß. (a) und (b) sollten Teile in eigene Dateien verschieben, um spätere Konflikte zu verringern (#236 ist bereits im Konflikt mit dem Stand nach #234).

---

## 9. Entscheidungen (vom Nutzer bestätigt, 2026-11-03)

| # | Thema | Entscheidung |
|---|---|---|
| 1 | Akzentfarbe | Amber aus dem Theme (`tertiary`) neben Türkis (`primary`). Kein zweites Theme. |
| 2 | Fotos | Nur Initialen und Illustrationen, keine Fotos (auch keine Elternfotos) in Entdecken und Matches. Kinderfotos bleiben ausgeschlossen. |
| 3 | Wischen | Zum Start nur Buttons. Wischen kommt später, immer mit Button-Alternative. |
| 4 | Rückgängig bei „Nicht jetzt" | Ja, kurz per Snackbar. |
| 5 | Eingehendes Interesse | Erst beim Match sichtbar, keine Liste „Interesse an euch". |
| 6 | Verifizierung | Telefon-Bestätigung nur als Badge, nicht Pflicht. |
| 7 | Sicherheitslimit | 50 „Interessiert" pro Tag, serverseitig änderbar. Reines Sicherheitslimit ohne Upsell, kein Tarif-Limit. |
| 8 | Moderation | Der Nutzer moderiert allein als Admin. 1 Meldung legt ein Profil in seine Warteschlange. Wer meldet, sieht das Profil nicht mehr. Für alle anderen vorläufig ausgeblendet erst ab 3 Meldungen von verschiedenen Konten, bis der Admin entschieden hat. |
| 9 | Chat nach Match | Der Server legt beim Match eine Freundschaft an; Chat über die vorhandene Oberfläche (Weg 2 in 3.3). |
| 10 | Wiederanzeige nach „Nicht jetzt" | Nach 30 Tagen. |
| 11 | Launch-Umfang | f0, a, b plus Moderations-Paket. Der Match-Ablauf (c bis e) folgt danach als zusammenhängendes Paket (Begründung in Abschnitt 8). |

Folgen für die Umsetzung [A]:

- 9.5 und 9.10: Discovery muss `pass` mit Zeitstempel kennen und nach 30 Tagen wieder
  zulassen; `like` ohne Gegenseite bleibt für die andere Seite unsichtbar (L1, L4).
- 9.7: Limit als Konfigurationswert im Backend (z. B. Umgebungsvariable mit Default 50),
  Antwort bei Überschreitung neutral formuliert („Für heute ist Schluss, morgen geht es
  weiter"), ohne Hinweis auf Tarife.
- 9.8: braucht Zählung verschiedener Meldender, einen Ausblende-Status am Profil und
  einen Filter in Discovery (heute nicht vorhanden, siehe Abschnitt 4).
- 9.9: Freundschaft beim Match serverseitig anlegen ersetzt den W1-Sofort-Fix (#238)
  für Discovery-Kontakte.

---

## Anhang: Nicht geprüft

- Verhalten auf einem echten Gerät (kein Gerätetest).
- Laufzeitverhalten von Discovery mit vielen Profilen (L2), nur aus dem Code abgeleitet.
- Ob außerhalb der genannten Handler ein Nachrichtenfilter greift (L9).
- Ob eine Pausieren-Funktion an anderer Stelle existiert (L12).
- Inhalte der Screens Kinder-Dossier und Profil bearbeiten im Hinblick auf dieses Redesign (nicht Teil des Umfangs).
