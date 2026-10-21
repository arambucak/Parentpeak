# ParentPeak — Pre-Launch QA-Checkliste

Zweck: Vor dem öffentlichen Launch manuell auf echten Geräten prüfen, dass die
App funktioniert, keine falschen Infos zeigt und sich elternfreundlich verhält.
Diese Liste ergänzt die automatischen Tests (die laufen in der CI) — sie deckt
genau das ab, was Tests NICHT können: echtes Verhalten auf echten Geräten.

**So nutzt du die Liste:** Jede Zeile auf mindestens einem echten iPhone, einem
echten Android-Gerät und im Browser (Chrome + Safari) durchgehen. Haken setzen,
wenn ok. Bei Fehlern: kurze Notiz + Screenshot in die Fehlertabelle unten.

Legende: `[ ]` offen · `[x]` ok · `[!]` Problem gefunden

---

## 0. Testgeräte & Setup

Mindestens je ein Gerät pro Zeile testen. Trage die konkreten Geräte ein.

| Plattform | Gerät / Version | Getestet von | Datum |
|---|---|---|---|
| iPhone (aktuell) | | | |
| iPhone (älter, kleines Display) | | | |
| Android (aktuell) | | | |
| Android (älter) | | | |
| Web — Chrome (Desktop) | | | |
| Web — Safari (iPhone) | | | |

- [ ] App gegen den **Produktions-Build** getestet (nicht Debug), auf dem
      Release-SHA, der auch veröffentlicht wird.
- [ ] Backend zeigt auf Produktion (`parentpeak.onrender.com`), nicht lokal.
- [ ] Mit einem **frischen Konto** getestet (kein Entwickler-Altzustand).

---

## 1. Erststart, Onboarding & Konto

- [ ] Kalt-Start: App startet ohne Absturz; Splash zeigt das **neue** Logo.
- [ ] Onboarding-Sprachauswahl zeigt **nur die 8 fertigen Sprachen**
      (DE, EN, TR, KU, FR, ES, IT, AR) — keine halb-englischen.
- [ ] Registrierung mit E-Mail/Passwort funktioniert.
- [ ] Google Sign-In funktioniert (iOS + Android + Web).
- [ ] Abmelden und erneut anmelden funktioniert; Daten sind wieder da.
- [ ] Ohne Anmeldung und nach Logout erscheint der Login-Screen, nicht die Haupt-App.
- [ ] Kind-Profil anlegen (Alter) → Tipps/Impulse passen danach zum Alter.
- [ ] App killen und neu öffnen → bleibt angemeldet, Zustand erhalten.

---

## 2. Sprache & Lokalisierung (Vertrauen in Vollständigkeit)

Für **jede** der 8 Sprachen einmal durchschalten und Startscreen + 2–3 Kacheln
stichprobenartig ansehen.

- [ ] DE, EN, TR, KU, FR, ES, IT, AR: **keine** rohen Schlüssel sichtbar
      (z.B. `event_ai_verify_hint` als Text) und **kein** unerwartetes Englisch.
- [ ] Sprachwechsel wirkt sofort auf dem ganzen Screen.
- [ ] **AR (RTL):** Layout spiegelt korrekt (Icons, Pfeile, Textausrichtung);
      nichts überlappt oder läuft aus dem Rand.
- [ ] Kurdisch: Ala-Rengin-Flagge wird korrekt angezeigt (kein kaputtes Emoji).
- [ ] Zahlen/Datum/Preise sehen in jeder Sprache plausibel aus.

> Hinweis: Für AR vor breiter Vermarktung zusätzlich einen Muttersprachler
> drüberschauen lassen (RTL-Feinheiten, Tonfall).

---

## 3. Events & Aktivitäten (GESCHÄFTSKRITISCH — hier besonders gründlich)

Das ist die Kachel, bei der falsche Infos am meisten schaden. Mit einem echten
Standort testen (GPS erlauben) und mit einer manuell eingegebenen Stadt.

### KI-Vorschläge
- [ ] KI-Suche liefert Events für den eigenen Ort (nicht für eine andere Stadt).
- [ ] Jede KI-Karte trägt den Hinweis **„KI-Vorschlag — bitte beim
      Veranstalter bestätigen"**.
- [ ] **Verschiedene** Events antippen → jede Detailseite zeigt **andere**
      Infos/Adresse (nicht immer dieselbe). *(War der gemeldete Bug.)*
- [ ] Kein Event mit einem Datum **in der Vergangenheit** erscheint.
- [ ] Bei einem Event mit **unklarer Adresse**: Hinweis „Adresse nicht auf der
      Karte bestätigt" ist sichtbar.
- [ ] „In Maps öffnen" öffnet die **richtige** Adresse des jeweiligen Events.
- [ ] „Website öffnen" / „Online suchen" führt zu etwas Sinnvollem.
- [ ] Entfernungsanzeige (km) ist plausibel für Events mit bestätigter Adresse.

### Community-Events (von Eltern eingetragen)
- [ ] Eigenes Community-Event anlegen (mit Standort-Picker) → erscheint im Feed.
- [ ] Teilnehmer/Interesse anzeigen funktioniert.
- [ ] Event melden (Flag) funktioniert.
- [ ] Eigenes Event bearbeiten und löschen funktioniert.

### Filter & leere Zustände
- [ ] Filter: Umkreis, Alter, „nur kostenlos", Zeitfenster (heute/Wochenende).
- [ ] Wenn nichts gefunden wird: freundlicher Leer-Zustand (kein Spinner, der
      ewig dreht; kein kontextloser Fehler).
- [ ] KI nicht erreichbar (z.B. Flugmodus kurz testen) → dezenter, erneut
      versuchbarer Hinweis statt stummer Leere oder Absturz.

---

## 4. KI-Elternberatung (Chat)

- [ ] Frage stellen → Antwort kommt (Streaming läuft, kein Hänger).
- [ ] Antwort folgt dem 3-Teile-Muster (Bedürfnis → GfK-Satz → Schritte) und
      klingt warm, nicht belehrend.
- [ ] Antwort kommt in der **aktuell gewählten Sprache**.
- [ ] KI nicht erreichbar → sinnvoller Fallback-Text, kein Absturz, kein roher
      Fehler.
- [ ] Bei sensiblen/akuten Themen: verantwortungsvoller Hinweis statt Diagnose.

---

## 5. Weitere Kacheln (je einmal durchspielen)

- [ ] **Familien-Küche:** Rezept generieren (1 Tap); Fallback-Rezept bei
      KI-Ausfall; Rezept → Einkaufsliste; „Hat es geschmeckt?"-Bewertung.
- [ ] **Impulse & Entwicklung:** Tagesimpuls lädt; Entwicklungs-Check
      durchführbar; KI-Bericht + PDF-Export funktioniert und ist lesbar.
- [ ] **Familien-Zentrale:** Einkaufsliste (Menge inline, Auto-Emoji,
      Erledigt-Bereich); To-do; Kind-Dossier speichern.
- [ ] **Familien-Geld:** Länderauswahl; Leistungs-Wegweiser lädt; KI-Ausfall
      zeigt lokalen Fallback-Hinweis (kein falscher „Anspruch").
- [ ] **Eltern-Netzwerk:** Profil-Wizard; Standort-Picker; ParentCoins zählen.
- [ ] **Verschenkmarkt:** Artikel einstellen (Foto); Kategorien/Zustand in der
      gewählten Sprache; Übergabe-Flow.
- [ ] **Ruhe & Rituale / Spielidee:** Abendritual, ruhiger Timer, Shuffle-Button
      funktioniert (auch im Web).

---

## 6. Kinder- & Minderjährigen-Daten (Store-kritisch + DSGVO)

Die App speichert sensible Kind-Daten (Alter, Allergien, Arzt,
U-Untersuchungen). Grundregel laut Projekt: sensible Daten bleiben lokal,
Kind-Namen/Geburtstage gehen NICHT an die KI.

**Produktentscheidung 2026-10-21 — KI-Memory, Variante A:** Das Profilfeld
`AiMemoryService.birthDate` geht bewusst nur an das eigene Backend
(`POST /ai/children`, `PUT /ai/children/:id`) und wird dort in
`AiChildProfile.birthDate` gespeichert. Dies ist eine ausdrückliche Ausnahme
von der lokalen Speicherung, damit das Backend das Alter tagesaktuell berechnen
kann. Kein Dritt-Dienst-Leck dieses Profilfelds an Gemini; kein Code-Fix nötig.
Verifiziert: [createChild/updateChild](../lib/logic/ai_memory_service.dart),
[Prisma-Modell](../backend/prisma/schema.prisma) und
[Backend-Routen](../backend/server.js).

Der clientseitige Tipp-Prompt nutzt nur volle Lebensjahre aus
[`ChatContextPolicy.completedAge`](../lib/logic/chat_context_policy.dart).
Auch der serverseitig ergänzte Memory-Kontext berechnet nur volle Lebensjahre
über [`completedYears`/`buildMemoryContext`](../backend/ai_memory_policy.js);
das strukturierte Geburtsdatum wird nicht in den Gemini-Kontext übernommen.
Diese Aussage betrifft diesen Profil-Datenweg, nicht beliebige Freitext-Eingaben.
Variante B (nur Alter ans Backend, Geburtsdatum ausschließlich lokal) wurde
bewusst verworfen: Die dafür vorgesehene DB-/Datenmigration ist für den Launch
nicht erforderlich. Der Audit-Punkt „birthDate ans eigene Backend“ ist damit
als bewusste Entscheidung abgeschlossen; Einwilligung und Löschung bleiben
weiterhin zu prüfen.

- [ ] Kind-Dossier-Daten (Allergien, Arzt, Größen) bleiben **lokal** — kein
      Upload ins Backend (ggf. mit Netzwerk-Mitschnitt stichprobenartig prüfen).
- [ ] Beim KI-Chat / Entwicklungs-Check wird **kein Klarname und kein exaktes
      Geburtsdatum** des Kindes an Gemini gesendet (nur grobe Altersangabe).
- [ ] Entwicklungs-Check-Einwilligung nennt den KI-Empfänger (Google Gemini)
      ausdrücklich, bevor etwas gesendet wird.
- [ ] Keine Werbung / kein Tracking von Kinderdaten (Apple „Kids"/DSGVO).
- [ ] Konto-/Datenlöschung entfernt auch die Kind-Profile vollständig.

---

## 7. Community-Moderation & Missbrauchsschutz (Apple verlangt dies)

Bei nutzergenerierten Inhalten (Verschenkmarkt, Community-Events, Netzwerk)
verlangt Apple einen funktionierenden Melde- UND Blockier-Mechanismus — sonst
Ablehnung im Review.

- [ ] Inhalt **melden** (Event, Verschenk-Artikel, Profil) funktioniert und
      landet nachweislich beim Admin (Admin-Moderation-Screen zeigt den Report).
- [ ] Bei Netzwerk-/Tokenfehlern erscheint in allen 8 Launch-Sprachen ein
      neutraler Wiederholen-Hinweis statt einer Meldebestätigung. Nach erneutem
      Senden mit Serverbestätigung erscheint die Danke-Meldung. Fehlgeschlagene
      Verschenkmarkt-Meldungen werden nicht als „gemeldet“ markiert.
- [ ] Rezept posten, löschen und darauf reagieren: Bei Netzwerk-/Tokenfehlern
      erscheint ein Fehlerhinweis; keine Erfolgsanzeige oder lokale Erfolgsänderung.
- [ ] Nutzer **blockieren / Inhalt verbergen** ist möglich.
- [ ] Admin kann anstößige Inhalte/Nutzer entfernen (Moderations-Flow testen).
- [ ] Wochenimpuls-Community: Normales Konto darf trotz mitgeschickter interner
      `moderatorEmail`/`reviewerEmail` weder Meldungen/Verifizierungsanfragen
      lesen noch freigeben oder Beiträge global ausblenden. Ein interner Moderator
      mit bestätigter Firebase-E-Mail darf dies; ohne gültigen ID-Token wird
      abgelehnt. Fachstimmen-Badge und eigener Verifizierungsstatus lassen sich
      nicht über fremde Nutzer-IDs/E-Mail-Adressen übernehmen.
- [ ] Nach dem Melden/Blocken verschwindet der Inhalt für den meldenden Nutzer
      zeitnah.
- [ ] Es gibt einen sichtbaren Kontakt-/Support-Weg (E-Mail) für Beschwerden.

---

## 8. Standort-Privatsphäre & Sicherheit beim Vernetzen

Fremde treffen sich über die App — Standortdaten brauchen klare Grenzen.

- [ ] Der an KI/Backend gesendete Standort ist **grob gerundet** (~1 km), nicht
      metergenau.
- [ ] Ein anderer Elternteil sieht im Netzwerk/Verschenkmarkt **nicht** meinen
      exakten Wohnort (nur Umkreis/Stadtteil).
- [ ] Standort-Freigabe ist widerrufbar; danach wird kein genauer Ort mehr
      genutzt.
- [ ] Einladungs-/Kontaktaufnahme offenbart keine privaten Daten ungewollt.

---

## 9. Web-spezifisch (bekannte Risikozone)

Im Browser (Chrome Desktop **und** Safari auf iPhone) prüfen:

- [ ] App lädt auf `parentpeak.de` ohne weiße Seite / JS-Fehler in der Konsole.
- [ ] **Keine Abstürze** durch Platform-/Benachrichtigungs-Code (Notifications
      sind im Web bewusst deaktiviert — darf nicht crashen).
- [ ] Buttons/Tap-Flächen reagieren (GestureDetector-Fälle, Shuffle-Buttons).
- [ ] Nach einem Deploy: Hard-Refresh (Cmd+Shift+R) zeigt den neuen Stand.
- [ ] Favicon und Titel korrekt (neues Logo).
- [ ] Login/Logout funktioniert auch im Web.
- [ ] Event erstellen: Foto auswählen, Vorschau sehen, ersetzen und entfernen
      funktioniert ohne Dateisystem-/`Image.file`-Fehler. Veröffentlichen lädt
      das ausgewählte Bild hoch und übernimmt dessen URL. Bei Uploadfehler bleibt
      das Formular offen; erneutes Veröffentlichen versucht den Upload erneut.

---

## 10. Berechtigungen, Netzwerk & Robustheit

- [ ] Standort-Berechtigung: Ablehnen → App funktioniert weiter (manuelle Stadt).
      Erlauben → GPS-Ort wird genutzt.
- [ ] Kamera/Foto (Verschenkmarkt, Rezept-Foto): Berechtigungsdialog erscheint,
      Ablehnen stürzt nicht ab.
- [ ] Offline/schlechtes Netz: Kacheln zeigen Fallbacks oder klare Hinweise,
      keine Abstürze, keine ewig drehenden Spinner.
- [ ] Benachrichtigungen (nur nativ): Opt-in-Dialog erscheint; eine Erinnerung
      kommt tatsächlich an.
- [ ] Hintergrund → Vordergrund: App übersteht Wiederaufnahme ohne Datenverlust.

---

## 11. Performance & Ressourcen

- [ ] Kaltstart bis bedienbarer Home-Screen fühlt sich zügig an (grob < 3–4 s).
- [ ] Langer Events-Feed scrollt flüssig, keine spürbaren Ruckler.
- [ ] KI-Aufrufe blockieren die UI nicht (restliche App bleibt bedienbar).
- [ ] Kein auffälliger Akku-/Datenverbrauch bei normaler Nutzung.
- [ ] Auf einem **älteren/langsameren Gerät** noch benutzbar (nicht nur Top-Modell).

---

## 12. Barrierefreiheit (Accessibility)

Eure Coding-Regeln verlangen Accessibility-Konformität.

- [ ] Screenreader (VoiceOver iOS / TalkBack Android) liest die Hauptflüsse
      sinnvoll vor (Home, Events, Chat).
- [ ] Interaktive Elemente haben sprechende Labels (nicht nur „Button").
- [ ] Textkontraste ausreichend; nichts nur über Farbe allein kommuniziert.
- [ ] Große Systemschrift (Dynamic Type / Font-Scale) bricht das Layout nicht.
- [ ] Tap-Flächen groß genug (nicht zu klein/zu dicht beieinander).

> Hinweis: Volle WCAG-Konformität erfordert manuelle Tests mit assistiven
> Technologien und eine Experten-Prüfung — diese Liste ist ein Grund-Check.

---

## 13. Deep Links & Einladungen

- [ ] Event-Einladungslink öffnet das richtige Event in der App.
- [ ] Netzwerk-/Freundschafts-Einladung (ParentCoins) funktioniert und zählt.
- [ ] Einladungslink bei **nicht installierter** App führt sinnvoll weiter
      (Store/Web), ohne ins Leere zu laufen.
- [ ] Abgelaufener/ungültiger Link zeigt eine klare Meldung, keinen Absturz.

---

## 14. Update & Migration (betrifft bestehende Beta-Tester)

- [ ] Nutzer mit **älterer App-Version** aktualisiert → lokale Daten
      (SharedPreferences: Listen, Kind-Profil, Einstellungen) bleiben erhalten.
- [ ] Keine Daten-Dubletten oder kaputten Zustände nach dem Update.
- [ ] Falls Datenformat sich geändert hat: Migration greift sauber.

---

## 15. Konsistenz App ↔ Website ↔ Preise

- [ ] Kein toter „Auf Premium upgraden"-Button, der ins Leere führt (Premium
      ist in der App aktuell nicht aktiv — Website-Versprechen vs. App-Realität).
- [ ] Features, die die Website bewirbt, existieren in der App auch wirklich.
- [ ] Sprach-Angabe konsistent (Website sagt „8 Sprachen", App bietet 8 an).
- [ ] Links von der Website (App öffnen, Datenschutz, Impressum) funktionieren.

---

## 16. Datenschutz & Rechtliches (vor Launch zwingend)

- [ ] Datenschutzerklärung, Nutzungsbedingungen, Impressum sind in der App
      erreichbar und laden.
- [ ] „Meine Daten exportieren" funktioniert.
- [ ] Konto löschen funktioniert und entfernt die Daten.
- [ ] KI-Einwilligung (Gemini) wird transparent abgefragt, bevor Daten gesendet
      werden; ohne Zustimmung keine Übertragung.
- [ ] Keine sensiblen Daten landen ungewollt im Backend (nur was nötig ist).

> Hinweis: Die inhaltlich-juristische Abnahme (Texte korrekt für den Markt)
> gehört zusätzlich geprüft — das ist keine reine Geräte-QA.

---

## 17. Store-Vorbereitung (kein Geräte-Test, aber vor Einreichung nötig)

- [ ] App-Icon in allen Größen korrekt (iOS/Android), kein Alpha-Rand bei iOS.
- [ ] Store-Screenshots aktuell (neues Branding, echte Screens).
- [ ] Store-Texte (Beschreibung, Keywords) final.
- [ ] Alterseinstufung / Content-Rating ausgefüllt.
- [ ] Datenschutz-Angaben im Store (App Privacy / Data Safety) ausgefüllt und
      stimmen mit dem echten Datenverhalten überein.
- [ ] Versionsnummer & Build-Nummer gesetzt und konsistent.
- [ ] Signierung (iOS Provisioning / Android Keystore) vorhanden und korrekt.

---

## 18. Abschluss-Gate

- [ ] Alle `[!]`-Punkte entweder behoben oder bewusst als „bekannt, kein
      Launch-Blocker" dokumentiert (mit Begründung).
- [ ] Letzter voller Smoke-Test auf dem finalen Release-Build.
- [ ] Entscheidung dokumentiert: wer gibt den Launch frei, Datum, Version.

---

### Gefundene Probleme (laufende Liste)

| # | Plattform | Bereich | Beschreibung | Schwere | Status |
|---|---|---|---|---|---|
| | | | | | |
