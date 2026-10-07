# ParentPeak: Weg zum sicheren Launch

Stand: 7. Oktober 2026. Gepruefter Checkout: `/Users/aram/Parentpeak-1`,
`main` und GitHub-`main`: `cfae2a2786736be6aa7f6e1ebccaed5defe00df1`.

Das [Kachel-Audit](AUDIT_PLAN.md#gesamt-abschluss-des-kachel-audits--7-oktober-2026)
ist abgeschlossen: zehn Kacheln, 53 Fix-PRs #103-#155. **Das ist keine
Produktions-, Datenschutz- oder Rechtsfreigabe.** Dieses Dokument ist eine
belegbasierte Release-Checkliste, keine solche Freigabe.

## 0. Was belegt ist und was nicht

Statusbegriffe:

- **Belegt:** direkt am aktuellen Repo oder einem konkreten CI-Lauf geprueft.
- **Offen:** eine konkrete Luecke im geprueften Stand.
- **Nicht nachgewiesen:** externe Konfiguration, Produktionszustand oder
  manuelle QA, fuer die hier kein belastbarer Nachweis vorliegt.
- Ein leeres Kontrollkaestchen ist ein Abnahmeschritt, kein bestandener Test.

| Bereich | Verifizierter Stand |
|---|---|
| Gemergter Code / CI | `analyze: SUCCESS` auch fuer den Merge-SHA: [Run 37651530250](https://github.com/arambucak/Parentpeak/actions/runs/37651530250), volle Fluttertests, Backendunits, Analyzer-/Baselinepruefung. |
| Physische Apple-/Android-Abnahme | Nicht nachgewiesen. `apple-prepare`, `ios-smoke-build`, `macos-smoke-build` sind in diesem Lauf **SKIPPED**. |
| Web-Auslieferung | **Bereits erfolgt:** Pages-`build` und `deploy` fuer `cfae2a2` sind erfolgreich: [Run 37651530082](https://github.com/arambucak/Parentpeak/actions/runs/37651530082). Das beweist weder die aktuell sichtbare Custom-Domain-Version noch einen passenden Render-/DB-Stand. |
| #151-Produktionsmigration | **Schema-Mismatch behoben:** nach ausdruecklicher Nutzerfreigabe am 7. Oktober 2026 um 22:37:53 MESZ erfolgreich gegen die Render-DB angewandt. Beide nullable TEXT-Spalten, erfolgreicher Migrationseintrag und keine ausstehenden Migrationen unmittelbar read-only bestaetigt (Abschnitt 0.2). |
| Backup vor Migration | Nutzer bestaetigt: PITR 3 Tage aktiv, vollstaendiger Render-Export `completed`, Sicherungspunkt 7. Oktober 2026, 22:32 Uhr (als MESZ gefuehrt). Kein unabhaengiger Restore-Test nachgewiesen. |
| Laufende Render-Version | Im freigegebenen Dashboard **belegt**: Service `Parentpeak`, Live-Deploy `dep-db373js9v7es73cfm83g`, SHA `cfae2a2786736be6aa7f6e1ebccaed5defe00df1`. `/health` liefert weiterhin keine Commit-ID. Dashboard-Pre-Deploy ist leer, entgegen dem Blueprint. |
| Audit-Testnachweise | Lokaler Abschlussplan: 134 gezielte Tests, 29 Chrome-Tests, Web-JS-Release gruen; volle lokale Suite 902 bestanden / 1 Skip / nur 12 bekannte Events-Firebasefehler; Analyzer 11 Infos. Nicht als neu ausgefuehrte Tests dieses Dokumentationsauftrags ausgeben. |

Fuer dieses Dokument wurden Repo-Dateien, GitHub-Metadaten/Logs und das
freigegebene Render-Dashboard gelesen. Der vorhandene Read-only-Diagnoseworkflow
wurde ausgefuehrt; er liest ausschliesslich Schema-/Migrationsmetadaten.
Dieser Dokumentations-PR aendert keinen Produktivcode. Die spaeter gesondert
freigegebene Produktionsmigration ist in Abschnitt 0.2 dokumentiert.
Kein Deployment, keine Store-Einreichung und keine KI-Testanfrage ausgefuehrt.

### 0.1 Historische Erstdiagnose am 7. Oktober (vor Konsolidierung)

- [Render-Service](https://dashboard.render.com/web/srv-d8q0p5j6sc1c73auvfa0):
  Anzeigename `Parentpeak` (nicht der Blueprint-Name `parentpeak-backend`),
  URL `https://parentpeak.onrender.com`, Repository `arambucak/Parentpeak`,
  Branch `main`. Der [aktuelle Live-Deploy](https://dashboard.render.com/web/srv-d8q0p5j6sc1c73auvfa0/deploys/dep-db373js9v7es73cfm83g)
  zeigt `Deploy succeeded|Live`, SHA `cfae2a2`, 7. Oktober 18:22:39 GMT+2,
  Trigger `Auto-Deploy`; Build-/Live-Logs ebenfalls vorhanden.
- `git merge-base --is-ancestor d9a7627 cfae2a2` ist erfolgreich:
  der aktuelle Render-Code enthaelt #151. Die fruehere Hypothese eines
  alten Render-Codes ist damit widerlegt, nicht bloss unbelegt.
- [Dashboard-Settings](https://dashboard.render.com/web/srv-d8q0p5j6sc1c73auvfa0/settings)
  direkt gelesen: Root `backend`, Build `npm install`, Start `npm start`,
  Auto-Deploy `On Commit`, **Pre-Deploy Command leer**. Der Migrationsbefehl
  aus `render.yaml` ist also aktuell nicht wirksam eingerichtet.
  `prisma generate` im Build generiert nur den Client, nicht das DB-Schema.
- Der vorhandene `prisma-migrate-diagnose.yml` wurde auf `main` gestartet,
  [Run 37668027342](https://github.com/arambucak/Parentpeak/actions/runs/37668027342),
  erfolgreich, 7. Oktober ca. 20:36 GMT+2. Das gepruefte Script fuehrt nur
  SELECTs aus. Die Migrationsliste enthaelt **keinen** #151-Eintrag.
  Das gilt fuer das GitHub-Secret-Ziel; Gleichheit mit dem Service-Ziel ist
  nicht bewiesen. Auch manuell hinzugefuegte Spalten werden so nicht ausgeschlossen.
- Die Render-Web-Shell konnte geoeffnet werden, nahm automatisierte Eingaben
  aber nicht verlaesslich an. **Keine direkte erfolgreiche DB-SELECT-Abfrage
  im Render-Service behaupten.** Die beiden SQL-Nachweise aus Abschnitt 1.2
  und der administrative DB-Zielvergleich bleiben zwingend.
- Daraus folgt: **kein vorsorglicher Web-Rollback auf aelteren Code**.
  Zuerst Zielgleichheit und Spalten pruefen. Falls sie fehlen, nach expliziter
  Freigabe Backup/Restore-Nachweis -> additive Migration -> Schema-Nachweis ->
  Runtime-Checks. Der passende Backend-Code ist bereits live; ein erneuter
  Deploy ist nicht allein wegen eines vermeintlich alten SHA erforderlich.
  Fuer zukuenftige Releases Migrations-/Backend-Gate und den fehlenden
  Pre-Deploy-Schritt getrennt vorbereiten; nichts davon hier umstellen.

Die Fehleranalyse fuer ein **altes Backend** bleibt nur ein Vergleichsszenario,
nicht die Beschreibung des jetzt belegten Render-Codes. Falls die aktuelle
Render-DB die Spalten nicht hat, ist stattdessen ein neuer Prisma-Client auf
altem Schema zu untersuchen: insbesondere Settings-/Memory-Zugriffe koennen
scheitern. Ein erfolgreicher statischer Healthcheck schliesst das nicht aus.
Eine Nutzerzahl oder Live-Fehlerquote wurde nicht ermittelt.
Diese Erstdiagnose ist durch die direkte DB-Pruefung und Konsolidierung
aus Abschnitt 0.2 ergaenzt; die Schemaluecke ist nicht mehr offen.

### 0.2 Freigegebene Konsolidierung und verbleibende Abnahme

- Direkte psql-SELECTs gegen die Render-DB bestaetigten vor der Migration:
  beide Consent-Spalten fehlen und kein #151-Migrationseintrag vorhanden.
- `prisma migrate status` gegen genau dieses Ziel, read-only: 12 Repo-
  Migrationen, genau zwei ausstehend: `20261006000000_optional_parent_matching_age`
  und `20261007000000_ai_memory_consent`. Erstere lockert `age` auf nullable;
  letztere fuegt nur nullable TEXT-Spalten hinzu. Beide wurden freigegeben.
- Backup laut Nutzer: PITR 3 Tage und Render-Export `completed`;
  Sicherungspunkt 7. Oktober, 22:32 Uhr. Kein Restore-Test behauptet.
- `prisma migrate deploy` genau einmal ausgefuehrt: Beginn 22:37:47 MESZ,
  beide Migrationen erfolgreich, Exit 0. Erfolgreiche `finished_at`-Werte:
  Altersmigration `2026-10-07T20:37:52.761214Z`, Consentmigration
  `2026-10-07T20:37:53.776619Z`; beide `rolled_back_at` leer, je ein Schritt.
- Unmittelbare Read-only-SELECTs: `consentRevision` und `consentVersion`
  jeweils `text` / nullable `YES`; `ParentMatchingProfile.age` nullable `YES`.
  Anschliessend read-only `prisma migrate status`: 12 Migrationen,
  `Database schema is up to date!`, Exit 0. Pruefung beendet 22:37:59 MESZ.
- DB-Zugangsdaten nur intern verwendet; keine Werte ins Dokument/Repo
  uebernommen. Keine weitere Migration, kein Deploy, kein Merge und keine
  Render-Einstellungsaenderung nach dieser Freigabe.

**Funktionale Abnahme bleibt offen:** Schema-Nachweis ist kein erfolgreicher
authentifizierter Backend-GET oder vollstaendiger Opt-in-Test.
Nach der Migration ausgefuehrte Live-GETs: `/health` HTTP 200 mit
`status: OK`; `/ai/settings` ohne Token HTTP 401 mit Firebase-ID-Token-
Hinweis. Erreichbarkeit und Auth-Gate sind damit bestaetigt, nicht die
authentifizierte Prisma-Abfrage. Kein gueltiger Nutzer-Token verwendet.

Read-only-Abnahme ohne neue Consent-/Memory-Daten:

1. Web-Service `Parentpeak` -> Logs: Zeitraum **nach 22:38 MESZ** filtern.
   Auf `Prisma`, `P2022`, `P2021`, `consentVersion`, `consentRevision`,
   `does not exist`, `Unknown column`, SQLSTATE `42703` und HTTP-500-Fehler
   achten. Historische Fehler vor Migration getrennt behandeln.
   Keine Fehler ohne tatsaechliche Requests sind kein Funktionsnachweis;
   Logtexte koennen Nutzerdaten enthalten und sollen nicht ungefiltert geteilt werden.
2. Mit bereits vorhandenem gueltigem Firebase-ID-Token eines eigenen Kontos
   ausschliesslich `GET /ai/settings` ausfuehren: erwartet HTTP 200 und
   JSON mit boolean `enabled` und nullable `consentVersion`.
   Die Route verwendet `findUnique`, keine Erstellung/Upsert.
   `enabled: false` ist ohne passende Zustimmung korrekt; kein Opt-in erzwingen.
   Ohne Token HTTP 401: Auth-Gate erreicht, aber Prisma-Abfrage nicht getestet.
3. Optional `GET /ai/children`: ebenfalls DB-Read, keine Erzeugung;
   Antwort kann sensible Bestandsdaten enthalten. Nur lokal pruefen,
   nach aussen ausschliesslich HTTP-Status/Erfolg berichten.
4. Kein PUT/POST/DELETE und kein `/ai/generate`: der echte Memory-Kontext-
   Transfer und Versions-/Revision-Widerrufstest bleiben separat freizugebende
   funktionale Tests. `/health` allein prueft das Schema nicht.

**Dauerhafte Ursache noch offen:** Dashboard-Pre-Deploy zuletzt leer,
keine neue Nutzerbestaetigung zur Einrichtung. **Reihenfolge verbindlich:
erst Dokumentation sichern, dann A durch den Nutzer abnehmen; B erst nach
erfolgreicher A-Abnahme.** Der Assistent wertet nur redigierte
Nutzerrueckmeldungen aus und startet keine weiteren Live-Checks.
Anleitung fuer den spaeteren Schritt B:
Render -> Web-Service `Parentpeak` -> Settings -> Deploy ->
Pre-Deploy Command -> Edit -> `npm run migrate:deploy` -> Save.
Root Directory muss `backend` sein. Speichern als potentiell Deploy-ausloesende
Aenderung behandeln, nicht als read-only Schritt. Kein garantiertes
"Save only" fuer dieses Settingsfeld behaupten; Environment-Saveoptionen
sind ein anderer Dialog.

Vor Speichern Branch `main`, freizugebenden SHA `cfae2a2`, dessen gruene CI,
keine neueren ungeprueften main-Commits/Deployqueue und dasselbe DB-Ziel
pruefen. Danach Dashboardwert, Pre-Deploy-Log und Live-SHA kontrollieren.
Wenn ein Deploy startet, darf er keine ungeprueften neuen Migrationen mitnehmen.
Beim unveraenderten SHA und demselben DB-Ziel findet der Befehl nach unserer
erfolgreichen Migration keine ausstehenden Migrationen vor. Das gilt nicht
automatisch fuer einen spaeteren SHA oder eine andere Datenbank.
Der korrigierte Pre-Deploy-Schritt ersetzt das weiterhin fehlende
App-Migration-/Backend-Gate nicht.

Vorbereitete Datenschutz-PRs, **nicht live und nicht gemergt**:

- #157: kontobezogener Kuehlschrank-Consent mit bestaetigtem Ack,
  Service-Grenze und Google-Gemini-Texten; `analyze: SUCCESS`.
- #158: Google-Gemini-Empfaenger im Entwicklungsbericht de/en/tr/ku,
  eigene Sprach-/Fallbackregressionen; `analyze: SUCCESS`.
- #159: sichtbarer Hinweis auf ueberwiegend deutsche FAQ-Inhalte/Suchbegriffe
  und englischen Fallback fehlender UI-Texte. 15 gezielte und 9 Chrome-Tests
  bestanden; volle lokale Suite 910 bestanden / 1 Skip / nur 12 bekannte
  Events-Firebasefehler, Analyzer 11 Infos. CI separat am aktuellen PR pruefen.
- Neu verifizierter offener Entwicklungsbericht-Legacypunkt:
  `dev.ai_report_consent` ist ebenfalls global, Ack ungeprueft, keine
  dienstseitige Consent-Grenze. #158 ist nur die beauftragte Empfaenger-
  Textkorrektur, keine Behebung dieser weiteren Grenze oder Rechtsfreigabe.

## 1. Kritischer Rollout: Migration -> Backend -> App

### 1.1 Vorbedingungen und bereits aktive Automatismen

- [Migration #151](backend/prisma/migrations/20261007000000_ai_memory_consent/migration.sql)
  fuegt ausschliesslich die nullable TEXT-Spalten `consentVersion` und
  `consentRevision` zu `AiMemorySettings` hinzu. Keine Datenloeschung, keine
  automatische Zustimmung. Das [Prisma-Schema](backend/prisma/schema.prisma)
  enthaelt beide Felder.
- [Render-Blueprint](render.yaml): Service `parentpeak-backend`, `rootDir:
  backend`, `buildCommand: npm install`, `preDeployCommand: npm run
  migrate:deploy`, `startCommand: npm start`, Healthcheck `/health`,
  **`autoDeploy: true`**. Das ist der vorhandene Render-Deployweg; es gibt
  keinen separaten Render-Deploy-GitHub-Workflow in `.github/workflows`.
- [Backend-Paket](backend/package.json): `migrate:deploy` = `prisma migrate
  deploy`, `postinstall` = `prisma generate`, `start` = `node server.js`.
  Prisma liest `DATABASE_URL` aus [prisma.config.ts](backend/prisma.config.ts).
- Blueprint-Datei ist nicht gleich Dashboard-Konfiguration: laut
  [Backend-Dokumentation](backend/README.md) muss ein geaenderter
  `preDeployCommand` im Render-Dashboard per Blueprint-Sync uebernommen werden.
  Die Dashboard-Nachpruefung zeigt einen leeren Pre-Deploy-Befehl
  (Abschnitt 0.1); den Blueprint-Befehl nicht als aktive Konfiguration behandeln.
- [Pages-Workflow](.github/workflows/deploy-web-pages.yml) deployt bei jedem
  Push auf `main` **ohne Abhaengigkeit von Migration/Render oder `analyze`**.
  Die App-Reihenfolge wird also nicht automatisch erzwungen. Mobile
  Auslieferung ist separat; der aktuelle Web-Stand ist schon deployed.

**Vor weiterer Freigabe:** verantwortliche Person, freizugebenden SHA,
DB-Ziel, Backups/Restore-Verfahren und kompatiblen Backend-Rollback festhalten.
Render-Autodeploy, Branch und Pages-Auslieferung kontrollieren bzw. fuer den
koordinierten Release pausieren. Nicht behaupten, der Backend-vor-App-Gate sei
bereits eingehalten worden. Den schon publizierten Web-Stand zuerst mit dem
realen Backend abgleichen; bei unklarer Transfergrenze keine weitere
Memory-Freigabe und betroffene Nutzung betrieblich begrenzen.

### 1.2 Vorhandene Prisma-Workflows und konkrete Befehle

**Die folgenden Befehle bleiben ein Runbook, keine neue Ausfuehrungsfreigabe.**
Die Read-only-GitHub-Diagnose wurde ausgefuehrt (Abschnitt 0.1).
Die Produktionskonsolidierung erfolgte separat lokal gegen die Render-DB
(Abschnitt 0.2), nicht durch Starten des GitHub-Deployworkflows.
Von der Repo-Wurzel; `main` waehrend des Rollouts auf dem freigegebenen SHA
halten. Die Workflows haben keinen eigenen Release-SHA-Input.

1. Zielkonfiguration pruefen: GitHub-Secret `DATABASE_URL` und Render-
   `DATABASE_URL` muessen dieselbe freigegebene Produktionsdatenbank
   adressieren. Vergleich administrativ, ohne Zugangsdaten in Logs/Dokumente
   zu kopieren. Backup und moeglichen parallelen Deploy vorher klaeren.
2. Read-only Diagnose ueber [prisma-migrate-diagnose.yml](.github/workflows/prisma-migrate-diagnose.yml):

   ```bash
   gh workflow run prisma-migrate-diagnose.yml --repo arambucak/Parentpeak --ref main
   gh run list --repo arambucak/Parentpeak --workflow prisma-migrate-diagnose.yml --limit 5
   # Die passende neue Run-ID auswaehlen, SHA und Ergebnis pruefen:
   gh run view <RUN_ID> --repo arambucak/Parentpeak --json headSha,conclusion,jobs
   gh run view <RUN_ID> --repo arambucak/Parentpeak --log
   ```

   Das Script liest `_prisma_migrations`; seine einzelnen Schema-Checks
   betreffen aeltere Treasure/Event-Tabellen, **nicht** die neuen Consent-
   Spalten. Diagnose-SUCCESS allein ist kein #151-Schema-Nachweis.
3. Ausstehende committete Migrationen ueber
   [prisma-migrate-deploy.yml](.github/workflows/prisma-migrate-deploy.yml):

   ```bash
   gh workflow run prisma-migrate-deploy.yml --repo arambucak/Parentpeak --ref main -f confirm=deploy
   gh run list --repo arambucak/Parentpeak --workflow prisma-migrate-deploy.yml --limit 5
   gh run watch <RUN_ID> --repo arambucak/Parentpeak --exit-status
   gh run view <RUN_ID> --repo arambucak/Parentpeak --log
   ```

   Der Job installiert mit `npm ci`, prueft Status vorher, fuehrt `npm run
   migrate:deploy` aus und prueft Status nachher. Der Vorher-Status verwendet
   `|| true`; massgeblich sind erfolgreicher Deploy **und** Nachher-Status.
   `migrate deploy` wendet **alle** ausstehenden Migrationen an, nicht nur #151.
   Keine automatische Reparatur bei Drift, keine `db push`-/Reset-Kommandos.
4. Alternative mit administrativ gesetztem `DATABASE_URL`, vom Repo-Root:

   ```bash
   cd backend
   npm ci
   npx prisma generate
   npx prisma migrate status
   npm run migrate:deploy
   npx prisma migrate status
   ```

   Ein nichtgruener Vorher-Status kann schlicht ausstehende Migrationen
   bedeuten: Ausgabe zuerst einordnen. In der Render-Shell mit `rootDir:
   backend` zuerst Arbeitsverzeichnis pruefen; nicht blind erneut `cd backend`.
5. Nachher in einer freigegebenen DB-SQL-Konsole read-only pruefen:

   ```sql
   SELECT migration_name, finished_at, rolled_back_at
   FROM "_prisma_migrations"
   WHERE migration_name = '20261007000000_ai_memory_consent';

   SELECT column_name, data_type, is_nullable
   FROM information_schema.columns
   WHERE table_schema = 'public'
     AND table_name = 'AiMemorySettings'
     AND column_name IN ('consentVersion', 'consentRevision')
   ORDER BY column_name;
   ```

   Erwartung: erfolgreiche, nicht zurueckgerollte Migration und beide nullable
   TEXT-Spalten. Keine bestehenden Zustimmungen nachtraeglich setzen.

**Kein Routine-Rollout:** [prisma-migrate-resolve.yml](.github/workflows/prisma-migrate-resolve.yml)
markiert hartcodiert `20260830_add_treasure_items` und
`20260830_remove_event_host_fk` als applied und fuehrt danach Deploy aus.
Der Workflow ist auf einen historischen Drift zugeschnitten. Nicht fuer #151
blind mit `confirm=resolve` starten und kein "applied" ohne realen Schema-
Nachweis setzen. Auch `/admin/migrate-db` ersetzt dieses Runbook nicht.

### 1.3 Render-Backend deployen und Identitaet pruefen

Nach bestaetigter Migration im Render-Dashboard den Service
`parentpeak-backend` auf den freigegebenen Commit deployen (manueller Deploy
des freigegebenen Commits bzw. kontrollierter Autodeploy).

- [ ] Dashboard: korrekter Service/Branch und exakter SHA `cfae2a2...`
  oder ein separat freigegebener Nachfolger mit allen #151-Guards.
- [ ] Buildlog: Prisma-Clientgenerierung erfolgreich; Predeploy:
  `npm run migrate:deploy` erfolgreich; Start: `npm start`, neue Instanz live.
- [ ] Dashboard-Deploy-ID, SHA, UTC-Zeit, DB-/Migrations-Run-ID und
  Freigabeverantwortliche im Release-Protokoll hinterlegen.
- [ ] Release-App-`BACKEND_BASE_URL` zeigt wirklich auf diesen Service,
  einschliesslich etwaiger Proxy-/Custom-Domain-Zuordnung.
- [ ] Health aus der freizugebenden App-Umgebung:

  ```bash
  # Oeffentliche Basis-URL, keine Credentials; vorher korrekt setzen:
  curl --fail-with-body --max-time 30 "$BACKEND_BASE_URL/health"
  ```

  [server.js](backend/server.js) antwortet statisch mit `status: "OK"` und
  einer Meldung. **Kein SHA, keine DB-/Consent-Bestaetigung.**
  Auch ein gruener [Keep-Alive-Workflow](.github/workflows/backend-keepalive.yml)
  reicht nicht: sein Script warnt bei schlechten HTTP-Statuscodes nur und
  beendet sie nicht zwingend als Failure.
- [ ] Zusaetzlicher authentifizierter read-only Check von `GET /ai/settings`
  mit einem eigenen freigegebenen Testkonto: aktuelle API liefert
  `enabled` und `consentVersion`. Legacy-`enabled=true` ohne neue Version darf
  nicht als wirksamer Consent erscheinen. Ein HTTP-200 allein beweist das
  nicht; Dashboard-Identitaet, DB-Nachweis und Verhalten gemeinsam pruefen.
- [ ] Auf Staging zuerst: Writes ohne `memoryConsentVersion: "chat-memory-v1"`
  und Generate mit Kindprofil ohne wirksamen Consent liefern
  `403 / MEMORY_CONSENT_REQUIRED`, ohne Google-Aufruf/Memory-Write.
  Mit synthetischen Daten Opt-in, Widerruf und Widerruf waehrend eines
  Requests pruefen. Keine solchen Mutations-/KI-Smokes gegen Produktion
  ohne eigene Freigabe.

Codebeleg: [Memory-Policy](backend/ai_memory_policy.js),
[Settings-/Generate-Routen](backend/server.js),
[Policy-/Routenregressionen](backend/tests/unit/ai-memory-policy.test.js).
Die Guards pruefen Version und Revision auch vor/nach Provideraufrufen;
Tests sind kein Nachweis, dass Render diesen Code schon ausfuehrt.

### 1.4 Erst danach App-Freigabe

- Vor Freigabe auf denselben Release-SHA testen, produktive Konfiguration,
  Signierung und Buildnummer bestaetigen. [APIConfig](lib/config/api_config.dart)
  prueft HTTPS-Backend-/Privacy-/Terms-URLs und Kontaktadresse;
  [main.dart](lib/main.dart) blockiert fehlerhafte Konfiguration in
  **nativen** Release-Builds, nicht auf Web.
- Mobile Wege existieren in [Fastfile](fastlane/Fastfile):
  `fastlane ios beta` (TestFlight), `fastlane ios release` (Upload, kein
  automatisches Release/Review), `fastlane android beta` (Internal Testing),
  `fastlane android release` (**Production-Promotion**).
  Lanes, Signing-/Store-Zugang und Artefakte sind hier nicht ausgefuehrt oder
  als funktionsfaehig nachgewiesen. Die Buildbefehle der Lanes enthalten keine
  expliziten Release-`--dart-define`s; Konfiguration separat sicherstellen,
  keine Serversecrets in App-Artefakte einbauen.
- TestFlight/Play Internal auf realen Geraeten abnehmen (Abschnitt 3), dann
  manueller Store-Gate und kontrollierter Rollout mit Monitoring.
- Web-Gate wegen bereits erfolgreichem Pages-Deploy gesondert nachholen.
  Ein kuenftiger `gh workflow run deploy-web-pages.yml --repo
  arambucak/Parentpeak --ref main` ist ein echter App-Deploy und erst nach
  Backend-/QA-Freigabe vorgesehen, kein neutraler Test.

### 1.5 Rollback und Stop-Kriterien

**Stop:** unklarer DB-/Backend-SHA, Migration-/Clientfehler, Consent ohne
Version akzeptiert, fremder Kontokontext, oder keine belastbare Route zum
datenschutzkonformen Rollback. Dann App-Rollout stoppen.

1. Store-Promotion/gestaffelten Rollout anhalten; Web auf einen freigegebenen
   Stand zuruecknehmen bzw. betroffene Nutzung begrenzen. Bereits installierte
   Apps/gesendete Requests sind dadurch nicht rueckholbar.
2. Render bevorzugt auf den letzten getesteten **consent-faehigen**
   Backend-Deploy zurueckrollen; #151 ist in `d9a7627` enthalten. Ob dieser SHA
   ein betriebsfaehiger Rollback ist, muss vorab auf Staging nachgewiesen
   werden. Autodeploy gegen erneutes Ueberschreiben kontrollieren.
3. Die additiven Spalten und Originaldaten behalten. `prisma migrate deploy`
   bietet keinen Down-Rollback; kein Spalten-Drop, Reset oder automatisches
   Loeschen alter Memory-Werte als Reparatur.
4. Ein Backend **vor #151** darf nicht mit erreichbaren Memory-Transfers
   wieder freigegeben werden. Es gibt im geprueften Repo keinen globalen
   Memory-Kill-Switch. Per-Konto-`enabled=false` genuegt dafuer nicht, wenn
   alte Clients wieder aktivieren koennen. Vor einem solchen Notfallrollback
   muessen alle Memory-Writes/Aktivierungen und Generate-Transfers mit
   Kindkontext nachweislich serverseitig blockiert sein; fehlt diese
   Moeglichkeit, Service betriebsseitig ausser Betrieb nehmen statt unsicher
   weiterzubetreiben. Keine erfundene ENV-Flag als Loesung dokumentieren.
5. Nach jedem Rollback SHA, Health, DB-Stand, Gates und Kontotrennung erneut
   abnehmen. Lesen/gezieltes Loeschen eigener Altwerte soweit sicher erhalten;
   Ausschalten allein loescht vorhandene Daten bewusst nicht.

## 2. Ehrliche Restliste: vor Launch oder danach?

Dies sind **Empfehlungen fuer die Freigabe**, keine bereits getroffenen
Produktentscheidungen. Bei einer konditionalen Verschiebung muss der
Release-Verantwortliche die Bedingung und Restrisiken dokumentieren.

| Punkt | Code-/Repo-Befund | Einstufung / Abnahmekriterium |
|---|---|---|
| Rohe `hostUserId` | [Events-Screen](lib/ui/events_activities_screen.dart) setzt in `events_invitation_from` direkt `invitation.hostUserId` ein; [Modell](lib/models/event_invitation.dart) hat keinen Host-Anzeigenamen. | **Kann Post-Launch**, wenn technische IDs fuer diese Sichtbarkeit bewusst akzeptiert und als solche erklaert werden. Kein Anzeigename erfinden, keine Auth-ID aendern. Backend-/UI-Anzeigename separat planen; bei internen Identifikatoren mit unerwuenschter Offenlegung vor Launch loesen. |
| Lokale Verschluesselung | [Zentralenstore](lib/logic/family_hub_store.dart), [Finanzstore](lib/logic/family_finance_store.dart) und [Chatstore](lib/logic/chat_account_store.dart) nutzen JSON/SharedPreferences; Kontoskope sind keine Verschluesselung. [SecureStorage](lib/logic/secure_storage.dart) existiert fuer andere Verbraucher, schuetzt diese Stores aber nicht automatisch. | **Vor Launch noetig:** dokumentierte Schutzbedarfs-/Backup-/Geraetezugriffsentscheidung fuer Kind-/Gesundheits-/Finanzdaten. Zusaetzliche App-Verschluesselung **kann Post-Launch** nur bei begruendet akzeptiertem Restrisiko, passender Offenlegung und kontrolliertem Releaseumfang; bei notwendigem Schutz dieser Daten vor lokalem Zugriff ist Umsetzung vorher Pflicht. OS-Schutz nicht als App-Verschluesselung ausgeben. |
| Entwicklungsfragen | [Question-Localization](lib/l10n/development_question_localizations.dart) hat EN/TR/KU; DE kommt aus dem Original. Andere Sprachen erhalten unveraendert deutsche Domains. | Grossprojekt **kann Post-Launch** fuer weitere Sprachen, wenn Launch-Sprachen/Inhaltsumfang ehrlich begrenzt oder der DE-Fallback sichtbar erklaert sind. Kein Volluebersetzungsversprechen fuer alle 16 auswaehlbaren Sprachen. |
| FAQ: Planpraezisierung | Entgegen der pauschalen Restlistenformulierung sind die 32 [FAQ-Rohdaten](lib/data/eltern_wissen_data.dart) ueberwiegend deutsch. [Service](lib/logic/eltern_wissen_service.dart) sucht darin; [aktives Widget](lib/ui/widgets/eltern_wissen_widget.dart) ersetzt nur den einzelnen TR-Eintrag `klein_04`, nicht alle EN/TR/KU-FAQ. | **Vor Launch noetig:** den vorbereiteten Fallback-Hinweis aus #159 freigeben/ausliefern und manuell pruefen; noch nicht live. Bewusste Entscheidung fuer C: fachlich gepruefte Volluebersetzung plus lokalisierte Suche **Post-Launch**, nicht als bereits vier-sprachige FAQ bewerben. Der Auditplan bleibt unveraendert. |
| "EN-Fallback ueberall ehrlich?" | **Nein, nicht belegt und in geprueften Pfaden nicht einheitlich.** [AppStringsManager](lib/l10n/app_localizations_all.dart) und [AppLocalizations](lib/l10n/app_localizations.dart) fallen fuer fehlende UI-Keys auf EN zurueck; Entwicklungs-/FAQ-Inhalte auf DE. [Profilpicker](lib/ui/profile_safety_screen.dart) und [Familienprofilpicker](lib/ui/family_profile_screen.dart) zeigen keinen entsprechenden Vollstaendigkeits-/Fallbackhinweis. [Rechtliches](lib/ui/legal_info_screen.dart) enthaelt deutsche Festtexte. | **Vor Launch noetig:** Sprachumfang und EN-/DE-Inhaltsfallback ehrlich kommunizieren; sicherheitsrelevante Consent-/Rechtstexte muessen fuer die tatsaechlich adressierten Nutzer verstaendlich sein. Keine pauschale vier-/16-sprachige Freigabe aus Key-Tests ableiten. |
| Release-QA | CI belegt Tests, aber Apple-Jobs am Release-SHA sind uebersprungen; kein physisches Geraeteprotokoll. [Aelterer Releaseguide](docs/release/RELEASE_EXECUTION_GUIDE_v1.0.0.md) behauptet noch "NO ISSUES/READY", Stand Juli. | **Vor Launch noetig:** Abschnitt 3 mit signierten aktuellen Builds. Alte gruen markierte Dokumente sind kein aktueller Nachweis. JS-Web ist geprueft; Wasm-/TTS-Warnungen nicht als behoben ausgeben. Wasm-Auslieferung nur nach eigener Abnahme. |
| Finanzdaten/Links | [Audit-Restliste](AUDIT_PLAN.md) dokumentiert TR-"Cocuk Parasi", Wohngeld-HTTP403 und Quellenpflege. | **Vor Launch noetig:** [Quellenmatrix vom 06.10.2026](backend/README.md#familien-geld-einzelpruefung-amtlicher-leistungsdaten) konkret gegen die aktuellen Inhalte pruefen, nicht nur Disclaimer lesen. Bekannten 403 nicht ohne amtlichen Beleg durch eine erfundene URL ersetzen; unbestaetigtes TR-Programm nicht als amtlich bestaetigt vermarkten. Danach laufende Pflege. |

## 3. Manuelle QA: echte iOS- und Android-Geraete

**Alles unten ist noch abzunehmen.** Pro Plattform dokumentieren:
Release-SHA, App-Version/Buildnummer, OS/Geraetemodell, Backend-SHA/Deploy-ID,
Datum, Tester, Sprache, Ist-Ergebnis und redigierten Nachweis.
Ein reales iPad fuer Popover-Sharing ergaenzen, wenn iPad unterstuetzt wird.
Nur synthetische Kind-/Gesundheits-/Fotodaten und eigene Testkonten verwenden.
Netzwerkfehler/Write-Ack-Failures in Staging/Testkonfiguration simulieren,
nicht Produktionsspeicher manipulieren.

### 3.1 Consent-Matrix

Jeweils erste Nutzung, Ablehnung, Dialogabbruch, Zustimmung, Kaltstart und
Konto A -> Logout -> Konto B testen; DE/EN/TR/KU. Ein UI-Dialog allein beweist
keine Service-Grenze. Keine reale KI-Anfrage beim Ablehnungs-/Fehlertest.

| Flow / Beleg | Abnahme auf beiden Plattformen |
|---|---|
| Kuehlschrankfoto: [Screen](lib/ui/fridge_recipe_screen.dart), [Service](lib/logic/fridge_recipe_service.dart) | [ ] Ablehnung stoppt Fotoanalyse; Kamera-/Galerieabbruch, Neustart und Kontowechsel. **Offene Legacy-Luecke:** `fridge.ai_photo_consent` ist geraeteglobal, nicht versioniert; `setBool`-Ack wird nicht ausgewertet. Der Service prueft Konto, aber keinen Foto-Consent. Nicht als neues account-scoped Muster abnehmen (siehe Abschnitt 4). |
| Verschenkmarkt-Foto: [Consent](lib/logic/treasure_photo_consent.dart), [Analysegrenze](lib/logic/treasure_photo_analysis_service.dart) | [ ] Ohne Consent Foto behalten/manuell ausfuellen, kein KI-Transfer; Zustimmung bleibt bei A, B bestaetigt separat; Speicherfehler blockiert; Kontowechsel waehrend Byte-Lesen/KI liefert kein Ergebnis an B. Analyse ist keine Veroeffentlichung. |
| Familienrezept: [Consent](lib/logic/family_recipe_consent.dart), [Dialog](lib/ui/widgets/family_recipe_consent_dialog.dart) | [ ] Ohne Zustimmung nur lokale Inspiration; alters-/allergiebezogene Uebertragung erst nach Ack; Gerichtsuche einschliessen. Kuehlschrankrezept separat testen: dessen eigener Service darf nicht allein wegen dieses getrennten Consents als geschuetzt gelten. |
| Wegweiser: [Consent](lib/logic/benefit_guide_consent.dart), [Screen](lib/ui/benefit_guide_screen.dart) | [ ] Ablehnung laesst allgemeine Leistungen nutzbar; Konto/Gast-Zustimmungen getrennt; kein KI-Erfolg bei fehlendem Ack; Ausfallfallback sichtbar allgemein, Links/Sharing pruefen. |
| Chat: [Consent](lib/logic/chat_ai_consent.dart), [Screen](lib/ui/chat_screen.dart) | [ ] Kein Senden vor Zustimmung; sichtbarer Lade-/Speicherfehler; Verlaufbudget sechs volle Runden/12.000 Zeichen; Tipp folgt Tageslimit; Ausfallantwort als solche erkennbar. |
| Memory: [Consent](lib/logic/chat_memory_consent.dart), [Settings](lib/ui/ai_memory_settings_screen.dart) | [ ] Zusatz-Opt-in unabhaengig vom Chat; Ablehnung laesst normalen Chat zu; ohne Opt-in keine neuen Memory-Writes/Transfers. Neutrale Servernamen, lokaler Anzeigename, vollendetes Alter, Teilfehler ohne Doppelanlage; Aus/Ein invalidiert laufende Antwort; Aus schaltet Nutzung ab, explizites Loeschen ist separat. |
| Entwicklungsbericht: [Consent-Texte](lib/l10n/app_localizations_all.dart), [Feature](lib/models_and_widgets/development_schema_feature.dart) | [ ] Antworten nur nach Zustimmung; kein Klarname im Request; Ergebnis ersetzt Namen erst lokal. Auch hier Empfaengertext pruefen: derzeit generischer "KI-Dienst". |

### 3.2 Foto-, Veroeffentlichungs- und Share-Flows

- [ ] Kamera/Galerie erlaubt/verweigert, widerrufene OS-Berechtigung, leeres/
  grosses/ungueltiges Bild, Offline/Timeout, App in Hintergrund und Zurueck.
- [ ] Kuehlschrank: erkannte Zutaten kontrollierbar, manuelle Korrektur,
  Allergien/Altersgrenzen bei realen Rezeptausgaben plausibel und ohne
  erfundene Sicherheit. Der gepruefte Service rundet Alter noch und nutzt
  Default 3; diesen Legacy-Pfad separat vor Freigabe bewerten, nicht mit
  den korrigierten Chat-Altersregeln gleichsetzen.
- [ ] Verschenkmarkt: lokale Fotoentwuerfe nach Neustart vorhanden,
  Kategorie-Roundtrip, gerundeter Standort/ungefaehre Entfernung und
  Radiusgrenze konsistent; sichtbarer Hinweis vor oeffentlichem Foto-Upload.
- [ ] Upload-Teilfehler zeigt echten Zustand, keine falsche Erfolgsbestaetigung.
  Fotos bei ungewissem Veroeffentlichungscommit bewusst erhalten; nicht
  "bereinigen", wenn der Servercommit unbekannt ist.
- [ ] Anzeigenarchivierung, wiederholte Reservierung, Offline-Reservierung
  und Storno einmalig/konsistent; Legacy-Claim nur nach Eigentumsbestaetigung.
- [ ] Familienrezept-Speichern privat/Freunde/oeffentlich: Sichtbarkeit pruefen,
  Abbruch und Fehler ohne Erfolgsanzeige. [Rezept-Sharing](lib/logic/family_recipe_share_service.dart)
  ist Backend-Publishing, nicht automatisch ein OS-Share-Sheet.
- [ ] OS-Share-Buttons in [Familien-Geld](lib/ui/familien_geld_screen.dart),
  [Zentrale](lib/ui/familien_zentrale_screen.dart) und
  [Eltern-Netzwerk](lib/ui/eltern_netzwerk_screen.dart): Text/Dateien korrekt,
  Abbruch/Clipboardfehler ehrlich, iPad-Popoveranker, keine fremden Daten.
- [ ] Zusaetzliche erreichbare Exportpfade pruefen: [Finanzbudget-CSV](lib/ui/finance_budget_screen.dart)
  verwendet `Share.shareXFiles` ohne `sharePositionOrigin`; nicht aus den
  gefixten Kachelbuttons auf jeden Export schliessen. Bei iPad-Erreichbarkeit
  ist fehlerfreies Sharing ein Gate, kein bestandener Test.
- [ ] Entwicklungs-PDF teilen/oeffnen, externe amtliche Links und fehlende
  Ziel-App testen. Im Verschenkmarkt bedeutet "Jetzt teilen" Veroeffentlichen,
  kein unbelegtes OS-Sharing versprechen.

### 3.3 Benachrichtigungen / quiet_mode

Beleg: [NotificationService](lib/logic/notification_service.dart) und
[Ritual/Ruhe](lib/ui/ritual_ruhe_screen.dart).

- [ ] OS-Permission abgelehnt/erlaubt, spaeter in Settings geaendert; keine
  Crashs. Test mit signiertem iOS-Release: FCM wird in iOS-Debug uebersprungen.
- [ ] Kalender-/Ritualreminder zur realen Uhrzeit, Zeitzone/DST und nach
  Neustart pruefen; Android Exact-Alarm-/Benachrichtigungsrechte beachten.
- [ ] Ruhemodus blockiert **neue lokale Anzeigen und Planungen**. Bereits
  geplante OS-Reminder werden beim Toggle nicht gecancelt; das ist kein
  zugesagter Total-Stummschalter. Hintergrund-FCM/OS-Push separat testen,
  nicht aus dem lokalen Guard ableiten.
- [ ] FCM-Vordergrund/Hintergrund/Cold-Start-Tap: richtige Zielseite, keine
  fremden Texte nach Logout; Token-Abmeldung, Konto B und Tokenrefresh pruefen.
  Kontotrennung der Kachelstores beweist keine Push-Kontotrennung.
- [ ] Web: lokale Plugin-Anzeige/Planung ist `kIsWeb`-geschuetzt. Kein daraus
  abgeleitetes Versprechen, dass saemtliches FCM auf Web deaktiviert sei.

### 3.4 Logout, laufende Requests und Sprache

- [ ] In A Kind-Dossier/Allergien, Geldwerte, Netzwerkprofil, Treasure-
  Entwurf/Reservierung/Flags, Chat/Themen/Memory anlegen. Logout ohne Neustart,
  B anmelden: keinerlei A-Daten in Screens, Dialogen, Controllern, Bildern,
  Suchtreffern, Share-Inhalten oder Benachrichtigungen.
- [ ] Wechsel waehrend Claim, Laden, Speichern, Fotoanalyse, Upload,
  Chat-/Tipp-/Repair-/Memoryrequest: spaete Antwort wird nicht in B angezeigt
  oder gespeichert. Requests koennen bereits gesendet sein; keine
  rueckwirkende Ruecknahme versprechen.
- [ ] Zurueck zu A: bestaetigte eigene Daten erhalten; kein automatischer
  Claim unzugeordneter Legacydaten und keine Veroeffentlichung/Loeschung.
- [ ] DE -> EN -> TR -> KU mit offenen Screens/Dialogs, langen Texten,
  Sonderzeichen, grosser Schrift, Tastatur und kleiner Anzeige. Consent,
  Fehler, Fallback und Memory-Werte pruefen, nicht nur Menuekeys.
- [ ] Mindestens eine weitere auswaehlbare Sprache: fehlende UI-Keys EN,
  Entwicklungs-/FAQ-Inhalte DE nachweisen; sichtbare Erklaerung erforderlich.
  FAQ-Suche selbst ebenfalls pruefen, nicht nur uebersetzte Buttons.

## 4. Datenschutz, Recht und Store-Angaben

### 4.1 Impressum / Datenschutzerklaerung: nicht als aktuell freigeben

Geprueft wurden die Repo-Fassungen, **nicht** Live-Rechtstexte, Vertragsanlagen
oder Store-Konsolen. Die Release-URLs sind konfigurierbar; Pages kopiert
[Privacy](web/privacy/index.html) und [Terms](web/terms/index.html) ins Artefakt.
Beide stehen noch auf Juli 2026.

Konkrete Abweichungen zur aktuellen Implementierung:

- Privacy behauptet Kinderprofile ausschliesslich lokal; tatsaechlich gibt es
  serverseitige `AiChildProfile` mit optionalem Geburtstag/Geschlecht und
  bestaetigte Memory-Werte. Neue Namen sind neutral, Altoriginale bleiben.
- "Sensible Daten ... werden NICHT an KI-Dienste uebermittelt" ist zu pauschal:
  Allergien, bestaetigte Gesundheitswerte und personenbezogener Freitext
  koennen mit Zustimmung an Gemini gehen; Fotos werden nicht anonymisiert.
- Die Drittempfaenger-/Zweckliste bildet Foto-KI, Memory, Wegweiser,
  Nominatim/OSM-Karten, FCM und oeffentliche Medien nicht ausreichend ab.
  "Kein Profiling", "keine IP-Speicherung", "nicht dauerhaft gespeichert",
  konkrete Hostingregion/SCC und Loeschung binnen 30 Tagen muessen anhand
  realer Dienst-/Log-/Vertrags-/Loeschkonfiguration bestaetigt werden.
  App-Code allein beweist keine Provider-Retention oder Region.
- Verantwortlicher/Kontakt sind in Web-Texten vorhanden. Keine dedizierte
  Impressumsseite/-Verlinkung in den geprueften Web-/Legalpfaden;
  [LegalInfoScreen](lib/ui/legal_info_screen.dart) ist kein nachgewiesenes
  vollstaendiges Impressum. Zugaenglichkeit und Pflichtangaben rechtlich
  pruefen, keine pauschale Feststellung eines Rechtsverstosses.
- Privacy/Terms nennen `support@parentpeak.com`; Pages-Konfiguration faellt
  fuer Kontakt auf `parentpeakapp@gmail.com` zurueck. Tatsaechliche Release-
  Kontaktwerte/Erreichbarkeit und Anbieteridentitaet konsistent bestaetigen.
  Beta-"kostenlos/kein Abo"-Versprechen gegen den geplanten Launchumfang pruefen.

**Vor Launch:** Rechtstexte und erteilte Consent-Informationen mit dem
wirklichen Datenfluss abstimmen; besondere Gesundheits-/Kinddaten,
Rechtsgrundlagen, Aufbewahrung, Widerruf vs. Loeschung, Export/Kontoloeschung,
Auftragsverarbeitung und Drittlandtransfer fachlich pruefen und abnehmen.
Eine fehlende Einwilligung nicht durch blosses Aktualisieren der Privacy
Policy als geheilt betrachten.

#### 4.1.1 Unveroeffentlichter Textentwurf zur fachlichen/rechtlichen Pruefung

**Vom Nutzer nur zur Vorbereitung freigegeben, nicht zur Veroeffentlichung.**
Dies sind vorgeschlagene Bausteine, keine vollstaendige oder rechtlich
abgenommene Datenschutzerklaerung. `web/privacy` und Store-Konsolen wurden
nicht geaendert. Vor Verwendung muss der tatsaechliche Releaseumfang stimmen;
insbesondere #157/#158 sind noch nicht live und die Entwicklungsbericht-
Consent-Grenze ist weiterhin Legacy. Eckige Pruefmarker sind Stop-Kriterien,
kein veroeffentlichungsfertiger Text.

**Lokale Daten und optionale Backend-Speicherung**

> ParentPeak verarbeitet Familieninformationen fuer die von dir gewaehlten
> Funktionen. Bestimmte Kind-, Gesundheits- und Finanzangaben sowie lokale
> Entwuerfe werden auf deinem Geraet gespeichert. Diese lokalen Speicher
> haben derzeit keine zusaetzliche App-seitige Verschluesselung. Lokal
> gespeicherte Daten sind von Informationen zu unterscheiden, die du fuer
> Synchronisation, Veroeffentlichung oder optionale KI-Funktionen uebermittelst.
> Beim optionalen KI-Gedaechtnis werden Kindprofile und von dir bestaetigte
> Familieninformationen kontobezogen in unserem Backend gespeichert.
> Neue Memory-Kindprofile verwenden neutrale Bezeichnungen; die dazugehoerigen
> Klarname-Zuordnungen bleiben lokal. Bereits bestehende Memory-Daten werden
> durch diese Umstellung nicht automatisch geloescht oder nachtraeglich
> anonymisiert.

**Optionale KI-Verarbeitung und Empfaenger**

> Fuer optionale KI-Funktionen nutzen wir Google Gemini ueber unser Backend.
> Je nach ausgewaehlter Funktion koennen deine Nachrichten und benoetigter
> Gespraechskontext, Entwicklungsantworten, Alters-/Allergieangaben,
> Wegweiserangaben oder ausgewaehlte Fotos uebermittelt werden.
> Bestaetigte Memory-Werte koennen bei aktivem KI-Gedaechtnis den Kontext
> ergaenzen; dazu koennen Gesundheitsinformationen gehoeren.
> Automatische Datenminimierung und neutrale Kindbezeichnungen verhindern
> nicht jede personenbezogene Angabe in Freitext oder Bildern. Fotos werden
> fuer die Analyse nicht vollstaendig anonymisiert. Eine KI-Analyse ist
> keine Zustimmung zur Veroeffentlichung eines Fotos oder Beitrags.
> [PRUEFEN: separate, versionierte Einwilligungen und ihre technischen
> Grenzen fuer alle im Release aktivierten Flows; Rechtsgrundlagen,
> insbesondere fuer Gesundheits-/Kinddaten, fachlich festlegen.]

**Weitere Empfaenger und Zwecke**

> Firebase-Dienste werden fuer Anmeldung, Benachrichtigungen und auf
> unterstuetzten Release-Plattformen fuer Fehlerdiagnose verwendet.
> Dazu gehoeren Kontokennungen, Benachrichtigungstokens und technische
> Fehler-/Diagnosedaten. Render stellt das Backend bereit.
> Standortsuche und Karten koennen Anfragen an Nominatim/OpenStreetMap
> ausloesen. Fuer bewusst veroeffentlichte Community-Inhalte oder von dir
> ausgewaehlte Share-Ziele gelten gesonderte Datenfluesse.
> [ERGAENZEN: tatsaechliche Vertragspartner/Verarbeitungsrollen,
> aktivierte Zahlungs-/E-Mail-Dienste, Zwecke und Datenarten je Dienst,
> Hosting-/Transferlaender und nachgewiesene Transfergarantien.]

**Aufbewahrung, Deaktivierung und Loeschung**

> Das Deaktivieren des KI-Gedaechtnisses beendet nicht automatisch die
> Speicherung bereits bestaetigter Memory-Werte. Die Loeschung gespeicherter
> Daten ist ein eigener Vorgang. Keine Speicherung der Gespraechshistorie
> durch die App bedeutet nicht, dass Backend-Logs oder Dienstleister Daten
> niemals oder nur waehrend einer Anfrage aufbewahren.
> [ERGAENZEN: nachgewiesene Fristen fuer lokale Speicher, Memory-DB,
> Backend-/Diagnoselogs, Backups und jeden Dienstleister; konkretes
> Widerrufs-/Loesch-/Exportverfahren einschliesslich Altdaten und
> Kontoloeschung. Kein pauschales 30-Tage-Versprechen ohne Betriebsnachweis.]

Die bisherigen Abschnitte zu Verantwortlichem, Kontakt, Rechtsgrundlagen,
Betroffenenrechten, Aufsichtsbehoerde und Drittlandtransfer sind ebenfalls
fachlich abzustimmen; diese Bausteine ersetzen sie nicht.

### 4.2 Nennen die Consent-Texte Google Gemini?

Beleg: [de/en/tr/ku-Keys](lib/l10n/app_localizations_all.dart) und die in
Abschnitt 3 verlinkten aktiven Dialoge.

| Consent | Empfaenger im Text / offene Grenze |
|---|---|
| Familienrezept | Google Gemini explizit; Kindesalter, Allergien und ggf. Suchtext benannt. |
| Wegweiser | Google Gemini explizit; Freitext, Situation, Land, Alter und moegliche Websuche benannt. |
| Verschenkmarkt-Foto | Google Gemini explizit; Backendweg, nicht anonymisierte Bildinhalte und optionale Analyse benannt. |
| Chat | Google Gemini explizit; Nachricht/Verlauf, begrenzte Anonymisierung und separates Memory benannt. |
| Memory | Google Gemini explizit; accountbezogene Backendspeicherung, Gesundheitswerte, neutrale Namen, Altersminimierung, Aus vs. Loeschung und fehlende App-Verschluesselung benannt. |
| Kuehlschrank-Foto | **Live/main weiterhin nein**. #157 bereitet Google Gemini in de/en/tr/ku und die neue Konto-/Ack-/Service-Grenze vor, ist aber ungemergt. |
| Entwicklungsbericht | **Live/main weiterhin nein**. #158 bereitet Google Gemini in de/en/tr/ku vor, ist aber ungemergt. Globaler Consent-/Ack-/Service-Legacypunkt separat offen. |

Die letzten beiden sind **vor Launch zu klaeren/zu korrigieren oder die
entsprechenden KI-Flows vom Release auszunehmen**. Insbesondere ist das
globale Kuehlschrank-Opt-in kein Nachweis, dass Konto B eingewilligt hat.
Diese Befunde wurden nicht im Produktivcode behoben.

Genauer: in separaten Code-PRs vorbereitet, aber weder gemergt noch im
Produktionsrelease ausgerollt. Ein gruener PR ist keine Live-Behebung.

### 4.3 Apple App Privacy / Google Data Safety

**Nicht nachgewiesen:** aktuelle ausgefuellte/eingereichte Antworten in App
Store Connect oder Play Console. Fastlane-Metadaten/Lanes ersetzen sie nicht.
Das [iOS-Privacy-Manifest](ios/Runner/PrivacyInfo.xcprivacy) nennt Name,
E-Mail, User-ID, praezisen Standort, Fotos/Videos und sonstige Nutzerinhalte,
jeweils linked/app functionality/no tracking, sowie UserDefaults-Grund
`CA92.1`. Es ist weder ein App-Privacy-Export noch eine Data-Safety-Erklaerung;
Gesundheits-/Finanz-/Diagnosedaten sind darin nicht eigens aufgefuehrt.

Die folgende Matrix ist der **Pruefumfang**, keine fertig ausgefuellte
Storedeklaration. "Collected/shared", linked, ephemeral und Zwecke muessen
nach den jeweiligen Storedefinitionen und realen Dienstvertraegen bewertet
werden; kein pauschales "wir sammeln nichts"/"nichts wird geteilt".

Am 7. Oktober gegengepruefte offizielle Definitionen:
[Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
und [Google Play Data Safety FAQ](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en).
Apple bewertet insbesondere den Zugriff ausserhalb des Geraets ueber die
Echtzeitanfrage hinaus, auch bei Partnern. Ein lokaler Chat-RAM-Verlauf beweist
keine entsprechende Provider-Aufbewahrungsausnahme. Google bewertet alle
aktuell ausgelieferten Versionen gemeinsam; eine reine Verarbeitung im
Auftrag kann unter die Service-Provider-Ausnahme fuer "sharing" fallen,
muss aber durch die echte Dienstkonfiguration/Vertraege belegt sein.
Pseudonymisierung und freiwilliges Opt-in allein heben Deklarationspflichten
nicht auf. Keine Apple-Antworten ungeprueft in Google-Felder kopieren.

| Store-Prueffeld | Nachzuweisende Einordnung vor Einreichung |
|---|---|
| Kontakt / Kennungen | Apple Contact Info / User ID; Google Personal Info / User IDs sowie Device or Other IDs soweit SDK-/FCM-Daten betroffen sind. Kontozuordnung und Zwecke pruefen. |
| Gesundheits-/Memory-Inhalt | Apple Health und je nach Werten weitere User-Content-/Sensitive-Info-Kategorien; Google Health Info und relevante Personal-Info-/Content-Kategorien. Recipe-Allergien und Memory nicht nur als generischen Chattext abtun. |
| Chat / Fotos / Standort | Freitext-/Nachrichten- und Photo-Kategorien; Standortgenauigkeit nach jedem aktiven Flow, nicht nur Matching-Rundung, bewerten. Optionen "optional", "linked", "ephemeral" anhand realer Nutzung und Logs belegen. |
| Diagnose | Crash Data/Diagnostics bzw. App Info and Performance, plus zugehoerige Kennungen. Crashlytics ist auf Mobil-Release aktiv; Web-Ausschluss macht die globale Store-Angabe nicht entbehrlich. |
| Finanzen | Rein lokale Budgetwerte nicht als automatische Servercollection darstellen. Tatsaechliche KI-Freitext-/Zahlungs-/Exportpfade und danach passende Financial-Info-Kategorien pruefen. |

| Tatsachlich erreichbarer Datenpfad | Mit den Store-/Rechtstexten abzugleichen |
|---|---|
| Firebase Auth / Backendauth | E-Mail, Account-/User-ID und optionaler Anzeigename; Zuordnung zum Konto. |
| Gemini via Backend | Chat/Freitext, begrenzter Verlauf, Alters-/Allergiekontext fuer Rezepte, Wegweiserangaben, Foto-Bytes und bestaetigte Memory-/Gesundheitswerte nach Opt-in. Heuristische Minimierung ist keine Anonymisierung. |
| Memory-DB | Neutrale neue Kindnamen, optionales Geburtsdatum/Geschlecht, bestaetigte Werte und Consentdaten; alte Originale bleiben. Backendpersistenz ist von der Gemini-Kontextminimierung getrennt. |
| Standort / Karten | Nominatim erhaelt Suchtext oder gerundete Koordinaten; OSM-Kacheln eigene Requests. [Service](lib/logic/location_autocomplete_service.dart) und sichtbarer `location_osm_notice` belegen Drittanbieterprozess; Rundung bedeutet nicht keine Standortverarbeitung. Manifest "PreciseLocation" nicht ohne Gesamtpfadpruefung streichen. |
| Medien / Community | Treasure-/Rezept-Veroeffentlichung und ggf. oeffentliche Foto-URLs; [Rezeptservice](lib/logic/family_recipe_share_service.dart), [Backend](backend/server.js). KI-Consent ist keine Veroeffentlichungsfreigabe. |
| Push / Diagnose | FCM-Token/Backendregistrierung und Nachrichten; [ErrorReportingService](lib/logic/error_reporting_service.dart) aktiviert Crashlytics in Release (oder Debug-Opt-in), nicht auf Web. Fehler-/Stack-/Logdaten, moegliche Freitextanteile und Retention real pruefen. |
| Lokal / OS-Sharing | Kind-/Gesundheits-/Finanzwerte lokal; lokal allein nicht automatisch Servercollection. Explizite Exporte/Share-Ziele koennen Daten weitergeben. Jeden wirklich erreichbaren Flow und Backup gesondert bewerten. |
| Weitere aktivierte Dienste | Backend hat Stripe-/E-Mail-Dienstpfade. Nur falls im Release erreichbar: Empfaenger, Transaktions-/Kontaktdaten und Zwecke aufnehmen; Repo-Vorhandensein allein beweist keine produktive Aktivierung. |

- [ ] App Privacy und Data Safety fuer **den echten Releaseumfang** gemeinsam
  mit Privacy Policy/Consent aktualisieren, Verantwortliche und Datum festhalten.
- [ ] Loeschen/Export/Widerruf mit eigener Testidentitaet auf Staging abnehmen;
  serverseitige Memory-, Medien-, Account- und Pushdaten einschliessen.
- [ ] Provider-Retention, Region, AVV/SCC, Logging und Crashlytics-dSYM/
  Symbole nachweisen; keine Gesundheits-/Chatdaten in Diagnosebelegen ablegen.
- [ ] Legal-/Supportlinks im signierten Release ohne Login erreichbar und
  konsistent mit Storemetadaten; angemessene Sprache fuer Zielgruppe.

## 5. Priorisiert: Vor dem Launch zwingend

1. **P0 - Produktions-Transfergrenze:** #151-Schema-Mismatch am 7. Oktober
   22:37:53 MESZ behoben, unmittelbare DB-Verifikation gruen; Nutzer-Backup-
   Punkt 22:32. Noch offen: authentifizierte funktionale Backend-Abnahme,
   Consent-/Revision-Verhalten und Restore-Test. Pre-Deploy dauerhaft
   einrichten und App-Deploy-Gate mit Schema-/Backend-Nachweis umsetzen.
   Bereits deployten Web-Stand abgleichen; ohne Nachweis keine weitere
   Memory-/App-Freigabe. CI/Health allein genuegen nicht.
2. **P0 - Sicherer Stop/Rollback:** consent-faehigen Rollback und betriebliches
   Abschalten testen. Kein erreichbar unsicheres Vor-#151-Backend und keine
   Loeschung von Originaldaten/Consent-Spalten.
3. **P0 - Einwilligungsluecken:** Kuehlschrank-Foto-/Rezept-Legacypfad mit
   generischem Empfaenger, globaler Zustimmung, ungeprueftem Ack und fehlendem
   Service-Consent adressieren; Entwicklungsbericht-Empfaenger transparent
   benennen. #157/#158 sind vorbereitet, nicht live. Auch den inzwischen
   verifizierten globalen Entwicklungsbericht-Consent, dessen ungeprueften
   Schreib-Ack und fehlende Service-Grenze gesondert beheben; eine reine
   Empfaenger-Textkorrektur erledigt das nicht. Alternativ diese KI-Flows
   nachweislich vom Release ausschliessen.
4. **P0 - Recht/Stores:** veraltete bzw. widerspruechliche Privacy-Aussagen,
   Impressumszugang, Gesundheits-/Memory-/Foto-/OSM-/Diagnoseverarbeitung,
   Drittland-/Retention-/Loeschgrenzen und Storeangaben fachlich abstimmen.
5. **P0 - Reale Release-QA:** signierte iOS-/Android-Builds plus iPad-Sharing
   soweit unterstuetzt; Consent-Ablehnung/Acks, Fotos, Offline-/Teilfehler,
   Logout/laufende Requests und FCM-Kontotrennung abnehmen. Fehler sind Stop-
   Kriterien, kein nachtraeglicher Haken aufgrund vorhandener Unit-Tests.
6. **P1 - Verstaendlicher Launchumfang:** DE/EN/TR/KU manuell pruefen,
   tatsaechlichen FAQ-/Entwicklungs-DE- und UI-EN-Fallback offen kennzeichnen
   oder Sprach-/Inhaltsumfang begrenzen; sicherheitsrelevante Texte verstehen.
7. **P1 - Bewusste Risikoentscheidungen:** lokale sensible Daten/Backup/
   Verschluesselung bewerten, Finanzquellen aktualisieren und verbleibende
   Alters-/Share-Legacyfaelle abnehmen. `hostUserId`-/Volluebersetzungsarbeiten
   nur mit dokumentierter akzeptabler Einschraenkung nach hinten verschieben.

**Freigabeprotokoll vor Start:** finaler SHA/Artefakthash, Migration-/Render-
Deploy-ID, QA-Protokolle beider Plattformen, Recht-/Store-Abnahme,
Rollbackprobe, genehmigte Restpunkte, Verantwortliche und Rollout-/Monitoring-
Plan. Solange Pflichtnachweise fehlen, lautet der Status
**"Audit abgeschlossen, Launch noch nicht freigegeben"**.
