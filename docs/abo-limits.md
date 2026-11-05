# Kontogebundene Free-Kontingente

## Rollout: vorbereitet, nicht aktiviert

Der einzige Schalter fuer diese Kontingente ist die Backend-Umgebungsvariable
`PP_ABO_LIMITS_ENABLED`. Standard: **`false`**. Nur die Werte `true` und `false`
sind erlaubt; ein Tippfehler verhindert den Backend-Start.

**Dieser PR aktiviert weder Kontingente noch Kauefe.** Der Besitzer entscheidet
nach Review und Bereitstellung ueber eine Aktivierung.

1. Backend-Abhaengigkeiten und Prisma-Client fuer das neue Schema bereitstellen:
   `cd backend && npm ci && npx prisma generate`.
2. Auf der vorgesehenen Datenbank die Migrationen mit
   `cd backend && npx prisma migrate deploy` anwenden. Neu ist
   `20261105210000_feature_quotas`.
3. Die neue App mit Feature-Protokoll, Gates und Sprachtexten bereitstellen.
   Bei aktivierten Kontingenten sind alte KI-Clients ohne explizites
   `feature` nicht mehr kompatibel: der Proxy lehnt sie ab. Bei deaktiviertem
   Schalter bleiben die bisherigen Prompts erhalten.
4. Erst nach Besitzerfreigabe `PP_ABO_LIMITS_ENABLED=true` setzen und das Backend
   neu starten. Das ist hier bewusst **nicht** erfolgt.
5. Mit einem Free- und einem serverseitig bestaetigten Premium-Konto die Grenzen,
   einen zweiten Client und die UTC-Uebergaenge in einer Staging-Umgebung pruefen.

Die lokalen Werte in `MonetizationConfig`, das Beta-Flag
`PP_BETA_FREE_ACCESS` und eine lokale `isPremium`-Angabe koennen die
Serverkontingente nicht deaktivieren oder Premium freischalten.

Rollback: Backend-Schalter auf `false` zurueckstellen und neu starten.
Migration und Kontodaten bleiben bestehen; nicht durch Tabellenloeschung
zurueckrollen. Die dauerhafte Free-Version bleibt auch bei Beta AUS erhalten.

## Was zaehlt?

| Feature | Free | Zaehleinheit | Kostenloses Wiederverwenden |
|---|---|---|---|
| KI-Beratung | 3/Tag | Zugelassene Chat-Proxy-Anfrage | Lokaler Verlauf |
| Familien-Kueche | 1/Tag | Neuer Vorschlag, vor KI oder lokalem Fallback reserviert | Server-Tagesrezept, gespeicherte und Community-Rezepte |
| Events | 3/Woche | Neue Event-ID beim Oeffnen der Details | Dieselbe ID innerhalb derselben UTC-Woche |
| Community | 3/Monat | Ausgehende Anfrage/Like an eine neue Ziel-UID | Wiederholung derselben UID im Monat, bestehende pending/accepted Kontakte, eingehende Annahmen |
| Familien-Geld | Nur Uebersicht | Persoenlicher Check erfordert Premium | Uebersicht und kuratierte Informationen |

Premium hebt die Produktkontingente auf. Allgemeine Infrastruktur-/Missbrauchs-
Limits des KI-Proxys bleiben davon getrennt bestehen.

Nicht speziell klassifizierte KI-Aufrufe verwenden konservativ das Chat-Budget,
statt einen beliebigen unbegrenzten Proxy-Zweck zuzulassen. Eigene Zwecke gibt es
fuer Rezepte, persoenliche Finanzen, Eventsuche und Zutaten-Fotoerkennung.

Reservierung geschieht vor KI-Ausfuehrung bzw. Rezeptauslieferung. Ein
Providerfehler erstattet einen bereits zugelassenen KI-Aufruf nicht automatisch.
Ein Rezept-Fallback benutzt dieselbe Reservierung; ein zweiter Fallback kann
keinen weiteren Vorschlag freischalten. Gibt es keinen sicheren Vorschlag,
bleibt die Reservierung verbraucht. Das verhindert unbegrenzte Wiederholungen,
ist aber eine bewusst sichtbare Einschraenkung bei Provider-/Sicherheitsfehlern.

## Serverzeit und Reset

Zeitquelle ist PostgreSQL `SELECT CURRENT_TIMESTAMP`, nicht ein Clientdatum.
`quotaPeriod` in [feature_quota_store.js](../backend/feature_quota_store.js)
verwendet ausschliesslich UTC:

- Chat/Rezept: Tagesanfang `00:00:00 UTC`, Ende am naechsten Tagesanfang.
- Events: Montag `00:00:00 UTC`, Ende am folgenden Montag. Berechnung:
  `(getUTCDay() + 6) % 7` Tage vom UTC-Tagesanfang abziehen.
- Kontakte: erster Kalendertag des Monats `00:00:00 UTC`, Ende am ersten Tag
  des Folgemonats; inklusive Jahreswechsel und Schaltjahr.

Es gibt keinen Cronjob und keinen Geraete-Reset. Der Schluessel
`(userId, feature, periodStart)` waehlt ab jeder Grenze einen neuen Bucket.
Die Periode einer Reservierung basiert auf dem Start ihrer DB-Transaktion.
Die Statusantwort liefert `serverTime`, `periodStart` und `resetsAt`.

Logout/Login, Neuinstallation, andere Geraete und eine geaenderte Geraetezeit
aendern den UID-Bucket nicht. Alte Buckets/Belege bleiben gespeichert; dieser PR
fuegt keinen automatischen Retention-Job hinzu. Konto-Loeschung des zugehoerigen
`User` entfernt Buckets und Rezeptbelege ueber Foreign-Key-Cascades.

## Technische Durchsetzung

- Firebase-Verifikation liefert die UID. Body-UIDs und lokale Premium-Angaben
  sind keine Autoritaet.
- `UserEntitlement` wird mit DB-Zeit ausgewertet. Premium braucht bestaetigte,
  aktuelle, nicht widerrufene Serverdaten; active/trial/grace sind zulaessig.
  Abgelaufenes oder fehlendes Premium wird zu **Free**, nicht zu App-Ausschluss.
- PostgreSQL-Transaktion, Bucket-Zeilensperre `FOR UPDATE`, eindeutiger
  Item-Schluessel und Zaehler-Inkrement verhindern Overspending.
  Kontakt-/Matching-Erstellung und Kontingentverbrauch teilen dieselbe
  Transaktion; ein fehlgeschlagener Kontakt-Write rollt den Zaehler zurueck.
- KI: `/ai/generate` belastet Chat, prueft Finance-Premium bzw. verbraucht einen
  UID-gebundenen, einmaligen Rezept-KI-Beleg. Der Beleg laeuft an UTC-Mitternacht
  ab; Rezeptresultate koennen nicht nachtraeglich ersetzt werden.
- Rezepte: Reservierung, immutable Resultat und Tagesrezept unter `/usage/recipes`.
  Alle produktiven KI-/Fallback-Pfade reservieren; der Client darf bei
  Verifikationsfehlern nicht lokal unbegrenzt freigeben.
- Events: `/usage/events/view`, `/events/item/:id` und `/api/events/:id`
  verwenden dieselbe Community-ID. Entdecken-IDs kommen aus dem Backend
  (normalisierte URL/Datum/Titel), nicht aus frei gewaehlt wechselnden Client-IDs.
  Die Detail-Screens gaten beide Arten von Events.
- Kontakte: Friendship-Request und kanonischer/Legacy-Matching-Action-Handler.
  Bei aktivierten Kontingenten ist ein fluechtiger In-Memory-Write-Fallback
  untersagt.
- Finanzen: Einstieg, Detailroute, lokaler Schnellcheck, Agent und Proxy.
- App-Einstieg: keine globale Trial-Ende-Paywall mehr. Normale Anmeldung,
  Onboarding und Feature-Gates bleiben erhalten.

Die acht Launch-Sprachen de/en/tr/ku/fr/es/it/ar bieten warme Kontingenthinweise,
permanente-Free-Erklaerung und Retry bei Verifikationsfehlern. Der Premium-Button
informiert nur: Er simuliert keinen Kauf und schaltet kein lokales Premium frei.

## Grenzen der Zusicherung

Kontingente schuetzen Produktoperationen, nicht die Semantik jedes KI-Textes.
Ein allgemeiner Chat ist keine beweisbar dichte Inhaltsgrenze gegen Fragen
nach einem Rezept oder einer Leistung. Fuer guenstigere Spezialzwecke ersetzt
der Server beliebige Client-Prompts durch eingeschraenkte eigene Prompts.
Bereits im Feed gelieferte Event-Vorschauen und oeffentliche Veranstalterseiten
werden nicht nachtraeglich verborgen. Der Umfang ist das Oeffnen neuer Details.

Die Unit-Tests verwenden transaktionale DB-Doubles. Sie pruefen Parallelaufrufe,
Grenzen, Rollback, Belege, echte extrahierte Express-Handler und UID-Trennung,
ersetzen aber **keinen** Migration-/Lock-Test auf einem echten PostgreSQL-
Staging-System. Ein PostgreSQL-Server war in dieser Arbeitsumgebung nicht
installiert; keine Produktionsdatenbank wurde fuer Tests verwendet.

## Validierung

- Backend, unter dem unterstuetzten Node 24:
  `cd backend && API_BASE=http://127.0.0.1:9 node --test tests/unit/*.test.js`.
  Lokal mit isoliertem Node-24-Runtime via `npm exec --package=node@24`.
- Prisma: `cd backend && npx prisma generate` (Schema und lokaler Client).
- Flutter: `flutter test --no-pub`, einschliesslich
  `supported_languages_test.dart` und `visible_text_spelling_test.dart`.
- Beta wirklich AUS:
  `flutter test --no-pub --dart-define=PP_BETA_FREE_ACCESS=false test/auth_gate_login_test.dart`.
  Der Widget-Test restauriert ein abgelaufenes, nicht-Premium-Konto und prueft,
  dass es ins normale Onboarding statt in die globale Paywall gelangt.
- `flutter analyze --no-pub`: erlaubte unveraenderte Baseline sind 9 Infos,
  keine Fehler/Warnungen, Exit 1.
- `bash scripts/sync_guard.sh check`; kein `fix`, kein Wechsel auf main.

Ergebnis dieser Implementierung: Backend **1142 bestanden** (Node 24),
Flutter **1847 bestanden / 1 bestehender Skip**, Beta-AUS-Widgettests
**2 bestanden**, Quoten-/Sprach-/Rechtschreibtests zusammen **44 bestanden**.
Prisma-Generierung und Sync-Guard erfolgreich. Analyzer unveraendert
**9 Infos / 0 Fehler / 0 Warnungen, Exit 1**. `git diff --check` erfolgreich.
