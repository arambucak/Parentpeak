# ParentPeak: Weg zum sicheren Launch

Stand: 8. Oktober 2026. Gepruefter Checkout: `/Users/aram/Parentpeak-1`,
Release-`main` und Live-Backend:
`cb1350ca68ddb904cff3f3aca0327cd966bb1ce7` (#167).
`backend/`-Tree: `626ed19ab4b09428c7fd21a75563bfa9e96ebcbd`.
#160 ist gemergt und veroeffentlicht; #156/#158 sind als ersetzt geschlossen.
Security-Code mit #167 live abgenommen. Technischer Nachlauf:
**Node 24.21.0 pinnen - PR vorbereitet, Produktionsabnahme noch offen.**
Diese Runtime-PR aendert den Backend-Tree; der neue Stand ist noch nicht live.

Das [Kachel-Audit](AUDIT_PLAN.md#gesamt-abschluss-des-kachel-audits--7-oktober-2026)
ist abgeschlossen: zehn Kacheln, 53 Fix-PRs #103-#155. **Das ist keine
Produktions-, Datenschutz- oder Rechtsfreigabe.** Dieses Dokument ist eine
belegbasierte Release-Checkliste, keine solche Freigabe.

Der Auditplan ist eine lokale, absichtlich unversionierte Uebergabe; sein Link
ist im GitHub-Checkout nicht verfuegbar. Die hier dokumentierten Release-
Nachweise und Restpunkte sind deshalb eigenstaendig aufgefuehrt.

## 0. Was belegt ist und was nicht

Statusbegriffe:

- **Belegt:** direkt am aktuellen Repo oder einem konkreten CI-Lauf geprueft.
- **Offen:** eine konkrete Luecke im geprueften Stand.
- **Nicht nachgewiesen:** externe Konfiguration, Produktionszustand oder
  manuelle QA, fuer die hier kein belastbarer Nachweis vorliegt.
- Ein leeres Kontrollkaestchen ist ein Abnahmeschritt, kein bestandener Test.

| Bereich | Verifizierter Stand |
|---|---|
| Gemergter Code / CI | `analyze: SUCCESS` fuer Release-SHA `cb1350c`: [Run 37778703512](https://github.com/arambucak/Parentpeak/actions/runs/37778703512), volle Fluttertests, 212 Backendunits, Analyzer-/Baselinepruefung. |
| Physische Apple-/Android-Abnahme | Nicht nachgewiesen. `apple-prepare`, `ios-smoke-build`, `macos-smoke-build` sind in diesem Lauf **SKIPPED**. |
| Web-Auslieferung | **Pages erfolgreich veroeffentlicht:** [Run 37778703514](https://github.com/arambucak/Parentpeak/actions/runs/37778703514) fuer `cb1350c`; beide Gates bestaetigen exakt denselben Live-Backend-SHA. Kein unabhaengiger Browser-/CDN-/Custom-Domain-Cache- oder Geraete-QA-Nachweis. |
| #151-Produktionsmigration | **Schema-Mismatch behoben:** nach ausdruecklicher Nutzerfreigabe am 7. Oktober 2026 um 22:37:53 MESZ erfolgreich gegen die Render-DB angewandt. Beide nullable TEXT-Spalten, erfolgreicher Migrationseintrag und keine ausstehenden Migrationen unmittelbar read-only bestaetigt (Abschnitt 0.2). |
| Backup vor Migration | Nutzer bestaetigt: PITR 3 Tage aktiv, vollstaendiger Render-Export `completed`, Sicherungspunkt 7. Oktober 2026, 22:32 Uhr (als MESZ gefuehrt). Kein unabhaengiger Restore-Test nachgewiesen. |
| Laufende Render-Version | Service `Parentpeak`, `cb1350c`, [Deploy dep-db3ov16q1p3s73fgnhh0](https://dashboard.render.com/web/srv-d8q0p5j6sc1c73auvfa0/deploys/dep-db3ov16q1p3s73fgnhh0), Live seit 8. Oktober 14:42:55 MESZ. Build erfolgreich, Pre-Deploy `No pending migrations to apply`, Readiness-Vertrag und Health HTTP 200. Runtime 26.11.1 bestaetigt; Rueckkehr zu exakt Node 24.21.0 LTS vorbereitet, noch nicht deployt. |
| Deploy-Gate | #163 aktiv und praktisch verifiziert: erfolgreiche genaue main-CI, versioniertes Backend-/Schemazeugnis vor Build und nochmals vor Publikation. Identischer kompletter Backend-Tree erlaubt aelteren Live-SHA; keine Health-only-Freigabe. |
| Consent-/FAQ-Fixes | #157, #161 (enthaelt #158) und #159 gemergt und erfolgreich auf Pages veroeffentlicht; Nachweise in 0.3. #158 als ersetzt geschlossen. Manuelle Geraete-/Rechtsabnahme bleibt offen. |
| Multer / OTP | #165 bringt Multer 2.4.0 mit `fieldArrayIndexLimit: 0` und Release-Nachweis live. Nutzer bestaetigte installierte Version read-only. OTP_HASH_SECRET durch Nutzer gespeichert und mit #163-Deploy wirksam; Fallback-Warnung im neuen Startlog weg. SMS-/OTP-Flow trotzdem nicht produktionsfunktional (0.4). |
| Weitere Security-Fixes / Runtime | #167 live: proxy-addr 2.0.8, fast-uri 3.1.8, fast-xml-parser 5.10.1, Nodemailer 10.0.16. Render-Shell-Audit: critical 0, high 7, moderate 13; vier Zielpakete weg. Offene engines-Range fuehrte zu Node 26 Current. Pin-Fix ist vorbereitet, **nicht als live erledigt abgehakt** (0.5). |
| Audit-Testnachweise | Lokaler Abschlussplan: 134 gezielte Tests, 29 Chrome-Tests, Web-JS-Release gruen; volle lokale Suite 902 bestanden / 1 Skip / nur 12 bekannte Events-Firebasefehler; Analyzer 11 Infos. Nicht als neu ausgefuehrte Tests dieses Dokumentationsauftrags ausgeben. |

Fuer dieses Dokument wurden Repo-Dateien, GitHub-Metadaten/Logs und das
freigegebene Render-Dashboard gelesen. Der vorhandene Read-only-Diagnoseworkflow
wurde ausgefuehrt; er liest ausschliesslich Schema-/Migrationsmetadaten.
Die urspruengliche Doku-PR #160 aenderte keinen Produktivcode; die aktuelle
Runtime-PR aendert Node-Auswahl, Lifecycle-Pruefungen und Backend-CI.
Die spaeter gesondert
freigegebene Produktionsmigration ist in Abschnitt 0.2 dokumentiert.
Die separat freigegebenen Deploys/Merges sind unten dokumentiert. Dieser
Doku-Auftrag fuehrt keinen weiteren Produktionsmerge/Deploy, keine Store-
Einreichung und keine KI-Testanfrage aus.

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

**Betriebliche Logs-Abnahme vom Nutzer akzeptiert; vertiefte funktionale QA
bleibt offen:** Schema-Nachweis ist kein erfolgreicher authentifizierter
Settings-GET oder vollstaendiger Opt-in-Test.
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

**Pre-Deploy-Einrichtung erledigt:** Nutzer bestaetigt am 7. Oktober 2026,
23:13 MESZ: Command gespeichert, Deploy auf `cfae2a2`, Log `No pending migrations`,
Status Live und `/health` HTTP 200. Spaetere freigegebene Deploys siehe 0.3.
A-Logs-Abnahme zuvor vom Nutzer akzeptiert; authentifizierter Settings-GET
bewusst auf spaetere Geraete-QA verschoben, nicht als ausgefuehrt behauptet.
Das App-/Backend-Deploy-Gate ist inzwischen mit #163 aktiv (0.3).
Pre-Deploy prueft bei jedem neuen Backenddeploy alle ausstehenden Migrationen;
spaetere Migrationen und DB-Ziele weiterhin vor Freigabe pruefen.

### 0.3 Verifizierte Releases am 8. Oktober

Alle Merges erfolgten nach einzelner ausdruecklicher Nutzerfreigabe.

| Release | Squash-SHA / Nachweis |
|---|---|
| #165: #164 Multer + #162 Readiness | `9984d2e4a05836f7f2f62a23ac1b2c4559876f62`, Merge 00:45:41 MESZ, Render Live 00:46:55. 181 Backendtests lokal; Build/Pre-Deploy/Readiness/Health abgenommen, Multer 2.4.0 vom Nutzer in Render-Shell bestaetigt. #162/#164 ersetzt. |
| #163: Pages-Gate + gespeichertes OTP-Secret | `64358dfbaf4daa3bb2dcc508f96fc4bd07fd049a`, Merge 01:14:47 MESZ, Render Live 01:16:04. [main-CI 37701141463](https://github.com/arambucak/Parentpeak/actions/runs/37701141463) und [Pages 37701141424](https://github.com/arambucak/Parentpeak/actions/runs/37701141424) SUCCESS. Gates 01:19:34 / 01:22:14, jeweils Release- und Backend-SHA identisch. |
| #157: Kuehlschrank-Consent | `b029834b400e49aabb63ca59c081755926a43df3`, Merge 11:40:40 MESZ. [main-CI 37758311867](https://github.com/arambucak/Parentpeak/actions/runs/37758311867) und [Pages 37758311914](https://github.com/arambucak/Parentpeak/actions/runs/37758311914) SUCCESS. Gates 11:45:19 / 11:47:34 akzeptieren Backend `64358df`. |
| #161: Entwicklungsbericht-Consent inklusive #158 | `2d81164d2700cc6f65692f21e8b4f0df566f0a3d`, Merge 12:20:38 MESZ. [main-CI 37762847460](https://github.com/arambucak/Parentpeak/actions/runs/37762847460) und [Pages 37762847484](https://github.com/arambucak/Parentpeak/actions/runs/37762847484) SUCCESS. Gates 12:25:38 / 12:28:01 akzeptieren Backend `64358df`. #158 danach als ersetzt geschlossen. |
| #159: ehrlicher FAQ-Sprachhinweis | `138ca5d93aafc7b099361c8b472fb7dd75cf9cc0`, Merge 12:56:50 MESZ. [main-CI 37766825467](https://github.com/arambucak/Parentpeak/actions/runs/37766825467) und [Pages 37766825449](https://github.com/arambucak/Parentpeak/actions/runs/37766825449) SUCCESS. Gates 13:01:35 / 13:04:23 akzeptieren Backend `64358df`. |
| #160: Launch-Doku inklusive #156 | `fcd94920786b43d35b3ce15b505023ebfde36618`, Merge 13:25:19 MESZ. [main-CI 37769932540](https://github.com/arambucak/Parentpeak/actions/runs/37769932540) und [Pages 37769932629](https://github.com/arambucak/Parentpeak/actions/runs/37769932629) SUCCESS. Gates 13:29:18 / 13:32:02 akzeptieren Backend `64358df`. #156 danach geschlossen. |
| #167: vier gezielte Security-Updates | `cb1350ca68ddb904cff3f3aca0327cd966bb1ce7`, Merge 14:41:38 MESZ. Render Live 14:42:55, [main-CI 37778703512](https://github.com/arambucak/Parentpeak/actions/runs/37778703512) und [Pages 37778703514](https://github.com/arambucak/Parentpeak/actions/runs/37778703514) SUCCESS. Gates 14:45:21 / 14:47:31 pruefen exakt neuen Backend-SHA. Keine Pages-Neuausloesung. |

Nach #157/#161/#159 blieb Render Live auf `64358df`, Readiness `ready`;
kein neuer Renderdeploy beobachtet. Client-Doku liegt ohne Inhaltsverlust in
[Client-Datenschutz und Sprachumfang](docs/client-privacy-and-language.md).
Dadurch bleibt der vollstaendige Backend-Tree identisch. Das Gate selbst
wurde nicht abgeschwaecht. Ein Renderdeploy ist nicht fuer die Gate-Kompatibilitaet
noetig; tatsaechliches Auto-Deploy-Verhalten haengt von Render-Filtern ab.

Das Gate wartet auf die genaue main-CI, nicht auf ein inkompatibles Backend.
Bei fehlendem Backendnachweis bleibt der bisherige Pages-Stand live; ein
kontrollierter erneuter Lauf benoetigt eigene Freigabe. In diesen Releases
waren keine erneuten Pages-Laeufe noetig. Zweite Pruefung ist keine atomare
Sperre gegen manuelle Backendrollbacks; kompatiblen Betrieb weiter sichern.

### 0.4 OTP-Konfiguration und verbleibende Telefon-Verifizierung

Nutzer hat `OTP_HASH_SECRET` sicher als Render-Environment-Variable per
Save only gespeichert (kein Deploy), anschliessend wurde es mit dem
freigegebenen #163-Deploy wirksam. Im neuen Startlog fehlt die zuvor sichtbare
Fallback-Warnung. Secret-Wert nicht gelesen, ausgegeben oder im Repo gespeichert.

[hashOtpForUser und OTP-Routen](backend/server.js) verwenden das Secret nur
fuer die separate Eltern-Matching-Telefonverifizierung, nicht fuer Firebase-
Login, E-Mail-Verifizierung oder Passwort-Reset. Der OTP-Speicher ist eine
prozesslokale Map: offene Anfragen gehen bei Neustart/Instanzwechsel verloren,
auch mit festem Secret. Es gibt keinen SMS-Provider-Versand; Produktion
liefert keinen devCode, obwohl die Anforderungsantwort channel sms meldet.
[ParentMatchingScreen](lib/ui/parent_matching_screen.dart) hat keinen gefundenen
App-Einstieg; die aktuelle Home-Kachel oeffnet ElternNetzwerkScreen.

**Kein Launch-Blocker fuer den aktuell nicht verdrahteten Flow**, nach
Nutzerentscheidung. **Vor Aktivierung zwingend:** echten SMS-Versand,
gemeinsamen kurzlebigen OTP-Speicher und ehrliche Versand-/Fehleranzeige
nachruesten und abnehmen. Ein festes Secret allein repariert den Flow nicht.

### 0.5 Technischer Nachlauf: Node-Runtime pinnen

Nach #167 bestaetigte die read-only Render-Shell Nodemailer 10.0.16,
Commit `cb1350c` und Node 26.11.1. Produktions-Audit: 20 Meldungen
(13 moderate, 7 high, 0 critical), die vier Zielpakete nicht mehr gemeldet.
Build/Pre-Deploy/Start/Readiness/Health abgenommen, Startlog ohne Fehler.
Nutzer bestaetigte vor dem Merge Render-Export completed am 8. Oktober
14:36 MESZ und PITR 3 Tage. Backup ist kein Restore-Test.

Node 26 ist am 8. Oktober Current; Node 24 ist LTS.
Die Runtime-PR bereitet [backend/.node-version](backend/.node-version)
mit **24.21.0** und engines `>=24.0.0 <25.0.0` vor.
[Runtime-Guard](backend/node_runtime.cjs) prueft exakt die tatsaechliche
Node-Version vor Build-Installation, Pre-Deploy und Start. CI liest denselben
Backend-Pin. Pin und Guard liegen im vollstaendig Gate-geprueften Backend-Tree.
Prisma 7.8.0 und Nodemailer 10.0.16 bleiben unveraendert und kompatibel.

Render-Prioritaet: NODE_VERSION > .node-version > .nvmrc > engines.
Dokumentierte RootDir-Regel: Dateien/Kommandos relativ zum Service-Root
`backend`; `.node-version` liegt dort. Read-only Dashboardpruefung am
8. Oktober: kein NODE_VERSION-Eintrag und keine verknuepfte Environmentgruppe
sichtbar. Kein Dashboardwert geaendert. Ob die Datei beim echten Build exakt
so ausgewaehlt wird, bleibt **Deploy-Abnahme**, kein vorweggenommener Nachweis.
Der Guard verhindert Erfolg auf einer abweichenden Runtime auch bei Override.

- [x] Code-Auswahl vorbereitet; exakter Pin im Backend-Tree.
- [ ] Nutzer: frisches Backup/PITR und eigener Merge-/Deployentscheid.
- [ ] Render-Buildlog und Shell: **exakt 24.21.0**, nicht 26.x oder anderer Patch.
- [ ] Neuer main-SHA Live, Pre-Deploy No pending migrations, Readiness mit
  beiden Migrationen/nullable-text, Health 200 und Startlog ohne Fehler.
- [ ] Audit weiter critical 0 und vier Fixpakete nicht gemeldet.
- [ ] main-CI und beide Pages-Gates auf kompatiblem neuen Backend erfolgreich.

Erst danach Status **Node-Pin produktiv erledigt** setzen. Weitere 24.x-
Patches bewusst per eigener PR und Tests freigeben; engines erlaubt die Linie,
aber exakter Pin und Guard verhindern automatische Patch-/Majorwechsel.
#166 bleibt eine separate offene Doku-PR: ihre angehaengten Checklisten werden
hier weder ersetzt noch geloescht. Nach diesem Runtime-Stand #166 auf main
aktualisieren und die historischen Security-Entscheidungen als solche
kennzeichnen, ohne manuelle Freigaben als bereits erteilt zu markieren.

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
  Die Erstnachpruefung zeigte einen leeren Pre-Deploy-Befehl (Abschnitt 0.1).
  Inzwischen Einrichtung und erfolgreicher Lauf vom Nutzer bestaetigt (0.2).
- [Pages-Workflow](.github/workflows/deploy-web-pages.yml) startet bei main-Push
  oder manueller Ausloesung, publiziert seit #163 aber nur nach erfolgreicher
  genauer main-CI und kompatiblem Live-Backend. [Gate](scripts/pages_release_gate.cjs)
  prueft versionierten Vertrag, erforderliche Migrationen/Spalten und exakten
  SHA oder identischen kompletten Backend-Tree vor Build und vor Publikation.
  Mobile Auslieferung und manuelle Storefreigabe bleiben separat.

**Vor weiterer Freigabe:** verantwortliche Person, freizugebenden SHA,
DB-Ziel, Backups/Restore-Verfahren und kompatiblen Backend-Rollback festhalten.
Render-Autodeploy, Branch und Pages-Auslieferung kontrollieren. Das aktive
Gate nicht umgehen; bei fehlendem Backendnachweis stoppen. Den freizugebenden
Web-Stand mit dem realen Backend abgleichen; bei unklarer Transfergrenze keine weitere
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
`Parentpeak` auf den freigegebenen Commit deployen (manueller Deploy
des freigegebenen Commits bzw. kontrollierter Autodeploy).

- [ ] Dashboard: korrekter Service/Branch und freigegebener SHA mit allen
  #151-Guards. Aktueller verifizierter Live-SHA steht in Abschnitt 0.
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
  Zusaetzlich `/release/readiness`: HTTP 200, `status: ready`, erwarteter
  Commit/Backend-Tree und Vertrag `parentpeak-memory-consent-v1` mit
  `chat-memory-v1`, beiden Migrationen und nullable-text Consent-Spalten.
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
- Aktives Web-Gate bei jedem Release beibehalten; main-CI und beide
  Backendpruefungen mit finalem Pages-Ergebnis protokollieren.
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
| FAQ: Planpraezisierung | Die 32 [FAQ-Rohdaten](lib/data/eltern_wissen_data.dart) sind ueberwiegend deutsch; [Service](lib/logic/eltern_wissen_service.dart) sucht darin. #159 liefert jetzt den sichtbaren Sprachhinweis im [aktiven Widget](lib/ui/widgets/eltern_wissen_widget.dart) live. | **Code/Pages erledigt, manuelle Sprach-QA offen.** Fachlich gepruefte Volluebersetzung und lokalisierte Suche bleiben Post-Launch; nicht als vollstaendig vier-sprachige FAQ bewerben. |
| Telefon-Verifizierung / SMS | Festes OTP-Secret wirksam; Matching-OTP trotzdem ohne SMS-Versand und gemeinsamen Speicher. Separater Screen aktuell nicht verdrahtet (0.4). | Nach Nutzerentscheidung **kein aktueller Launch-Blocker**, aber **vor jeder Aktivierung zwingend nachruesten und testen**. Nicht als funktionierende SMS-Verifizierung bewerben. |
| Weitere npm-Schwachstellen | Multer mit #165 und vier weitere Zielpakete mit #167 live behoben. Render-Shell-Audit am 8. Oktober: 20 Produktionsmeldungen (13 moderate, 7 high, 0 critical), vier Zielpakete weg. | Sechs bedingte Akzeptanzentscheidungen plus Prisma-Sammeleintrag weiterhin getrennt abnehmen; kein vollstaendig sauberer Audit. Kein npm audit fix --force oder Prisma-Downgrade. Node-LTS-Pin ist technischer Nachlauf, noch nicht live abgenommen. |
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
| Kuehlschrankfoto: [Consent](lib/logic/fridge_photo_consent.dart), [Screen](lib/ui/fridge_recipe_screen.dart), [Service](lib/logic/fridge_recipe_service.dart) | [ ] #157 live: Ablehnung stoppt KI; Kamera-/Galerieabbruch, Neustart, Legacy-Key ohne neue Freigabe, fehlender Schreib-Ack, Konto A/B und Wechsel waehrend Bildlesen/HTTP/Retry manuell abnehmen. Konto-/Gast-Key und Service-Consent vor/nach Anfrage implementiert, Geraete-QA nicht daraus ableiten. |
| Verschenkmarkt-Foto: [Consent](lib/logic/treasure_photo_consent.dart), [Analysegrenze](lib/logic/treasure_photo_analysis_service.dart) | [ ] Ohne Consent Foto behalten/manuell ausfuellen, kein KI-Transfer; Zustimmung bleibt bei A, B bestaetigt separat; Speicherfehler blockiert; Kontowechsel waehrend Byte-Lesen/KI liefert kein Ergebnis an B. Analyse ist keine Veroeffentlichung. |
| Familienrezept: [Consent](lib/logic/family_recipe_consent.dart), [Dialog](lib/ui/widgets/family_recipe_consent_dialog.dart) | [ ] Ohne Zustimmung nur lokale Inspiration; alters-/allergiebezogene Uebertragung erst nach Ack; Gerichtsuche einschliessen. Kuehlschrankrezept separat testen: dessen eigener Service darf nicht allein wegen dieses getrennten Consents als geschuetzt gelten. |
| Wegweiser: [Consent](lib/logic/benefit_guide_consent.dart), [Screen](lib/ui/benefit_guide_screen.dart) | [ ] Ablehnung laesst allgemeine Leistungen nutzbar; Konto/Gast-Zustimmungen getrennt; kein KI-Erfolg bei fehlendem Ack; Ausfallfallback sichtbar allgemein, Links/Sharing pruefen. |
| Chat: [Consent](lib/logic/chat_ai_consent.dart), [Screen](lib/ui/chat_screen.dart) | [ ] Kein Senden vor Zustimmung; sichtbarer Lade-/Speicherfehler; Verlaufbudget sechs volle Runden/12.000 Zeichen; Tipp folgt Tageslimit; Ausfallantwort als solche erkennbar. |
| Memory: [Consent](lib/logic/chat_memory_consent.dart), [Settings](lib/ui/ai_memory_settings_screen.dart) | [ ] Zusatz-Opt-in unabhaengig vom Chat; Ablehnung laesst normalen Chat zu; ohne Opt-in keine neuen Memory-Writes/Transfers. Neutrale Servernamen, lokaler Anzeigename, vollendetes Alter, Teilfehler ohne Doppelanlage; Aus/Ein invalidiert laufende Antwort; Aus schaltet Nutzung ab, explizites Loeschen ist separat. |
| Entwicklungsbericht: [Consent](lib/logic/development_report_consent.dart), [Service](lib/logic/development_report_service.dart), [aktiver Screen](lib/ui/entwicklung_impulse_screen.dart) | [ ] #161 live: Google Gemini, Konto-/Gast-Zustimmung, Ack-Fehler, Widerruf/Retry, A-B-A-Wechsel und kontobezogene Berichte/History/Scores abnehmen. Kein Klarname im Request; Name erst lokal einsetzen. Legacy-Key/Altberichte nicht automatisch autorisieren/zuordnen. |

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
Die Client-Consent-Fixes #157/#161 sind inzwischen live; dies ersetzt keine
fachliche/rechtliche Pruefung. Eckige Pruefmarker sind Stop-Kriterien,
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
| Kuehlschrank-Foto | **Live mit #157:** Google Gemini in de/en/tr/ku, Konto-/Gast-Key, bestaetigter Ack und Service-/Retry-Grenzen. Alte globale Zustimmung autorisiert keine Verarbeitung. |
| Entwicklungsbericht | **Live mit #161 inklusive #158:** Google Gemini in de/en/tr/ku, Konto-/Gast-Consent, Ack und Service-/Retry-/Ergebnisgrenzen. Globale Legacy-Zustimmung gilt nicht als neuer Consent. |

Die dokumentierten Mechanismusluecken sind implementiert und auf Pages
ausgerollt. Geraete-QA, Verstaendlichkeit und rechtliche Abnahme bleiben offen.
Client-Service-Guards sind keine unabhaengige Backend-Consent-Sperre fuer
fremde Clients; Provider-Retention und bereits abgesandte Requests bleiben
gesonderte Grenzen. Details: [Client-Dokumentation](docs/client-privacy-and-language.md).

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
   Consent-/Revision-Verhalten und Restore-Test. Pre-Deploy-Einrichtung
   und App-Deploy-Gate mit Schema-/Backend-Nachweis erledigt und live verifiziert.
   Bereits deployten Web-Stand abgleichen; ohne Nachweis keine weitere
   Memory-/App-Freigabe. CI/Health allein genuegen nicht.
2. **P0 - Sicherer Stop/Rollback:** consent-faehigen Rollback und betriebliches
   Abschalten testen. Kein erreichbar unsicheres Vor-#151-Backend und keine
   Loeschung von Originaldaten/Consent-Spalten.
3. **P0 - Einwilligungsabnahme:** #157/#161 beheben die dokumentierten
   Kuehlschrank-/Entwicklungsbericht-Mechanismusluecken und sind auf Pages live;
   #158 enthalten und ersetzt. Kein weiterer offener Codefix fuer diese
   Befunde behauptet. Reale Geraete-, Konto-/Retry-/Ack- und rechtliche
   Abnahme bleibt Pflicht; clientseitige Grenze nicht als Server-Sperre ausgeben.
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

## 6. Launch-Endspurt: priorisierte To-dos

Planungsstand: 8. Oktober 2026, nach erfolgreichem #160-Release.
App/main: `fcd94920786b43d35b3ce15b505023ebfde36618`;
Live-Backend: `64358dfbaf4daa3bb2dcc508f96fc4bd07fd049a`.
Die Live-Nachweise stammen aus der bereits abgeschlossenen Abnahme, nicht
aus neuen Produktionsrequests fuer diese Checkliste. Dieser Abschnitt
autorisiert weder Merge noch Deploy, Installation, Secret-/Renderaenderung,
Produktions-Schreibtest oder oeffentlichen Launch.

### 6.1 Stufe 1 - Launch-Blocker

Abhaken bedeutet **nachgewiesen und vom Release-Verantwortlichen freigegeben**,
nicht nur vorbereitet. Pro Entscheidung Datum, Verantwortlichen, Release-SHA
und redigierten Nachweis festhalten; keine Tokens oder echten Kinddaten ablegen.

| Gate | Genau zu pruefen | Copilot kann ohne Produktionszugriff vorbereiten | Nutzer / extern zwingend |
|---|---|---|---|
| [ ] Recht / Store | Privacy Policy, Impressum, App Privacy / Data Safety gegen 6.1.2 und Abschnitt 4 abgleichen; reale Dienste, Zwecke, Gesundheitsdaten, Fotos, Retention, Loeschung, Transfers und Sprachumfang. | Codebelege, Datenflussmatrix, Widerspruchsliste und Text-/Deklarationsvorlagen; keine Rechtsberatung oder Freigabe. | Verantwortlicher/Kontakt, reale Vertragsanbieter, Regionen, AVV/Transfergarantien und Fristen liefern; anwaltliche/fachliche Pruefung organisieren; Storeantworten selbst bestaetigen/einreichen. |
| [ ] Signierte Geraete-QA | Alle Zeilen in 6.1.3 auf iOS **und** Android; iPad wenn unterstuetzt. Fehler oder fremde Kontodaten stoppen die Freigabe. | Synthetische Szenarien, vorhandene Unit-/CI-Nachweise, Protokollvorlage und Auswertung redigierter Fehler. | Signierte Builds, reale Geraete und eigene Testkonten; Berechtigungen, OS-Sharing und Push physisch pruefen; separate Freigabe fuer schreibende Tests. |
| [ ] Security-Restrisiko-Abnahme | Alle elf Paketentscheidungen in 6.1.1 einzeln; keine Akzeptanz nur wegen niedriger Prioritaet oder DoS-Kategorie. | Retained-Audit/Lockfile-/Codebelege, Erreichbarkeitsanalyse und spaeter getrennte Fix-PRs nach Auftrag. | Empfehlungen einzeln akzeptieren oder Fix verlangen; echte Deployment-/SMTP-Konfiguration ohne Secret-Offenlegung bestaetigen. Ungeklaerter erreichbarer Pfad ist kein gruener Haken. |

#### 6.1.1 Security: abhakbare Entscheidungstabelle

Quelle ist die **vorhandene Auditaufnahme nach dem Multer-Fix**, kein frischer
npm-/Registry-Scan: 24 Produktions-Paketmeldungen, davon 1 critical, 10 high,
13 moderate. Der lokale Auditbeleg liegt ausserhalb des Repos; er hat keinen
Lockfile-Digest, daher ist seine exakte Entstehung nicht kryptografisch belegt.
Die gelockten Versionen sind in [package-lock.json](backend/package-lock.json)
pruefbar. Counts sind **npm-Paketeintraege, nicht elf unabhaengige Angriffe**:
Prisma/config rollen transitive Meldungen auf. Moderate-Meldungen sind durch
diese Tabelle weder behoben noch automatisch akzeptiert.

"Akzeptieren" ist eine **bedingte Empfehlung fuer den geprueften Releaseumfang**,
kein dauerhafter Freibrief. "Fixen" bedeutet separater Auftrag/PR mit Tests,
keine Aenderung in diesem Doku-PR. Patched-Ziele stammen aus der gespeicherten
Auditaufnahme und sind vor einem Fix erneut zu verifizieren; keine blinden
Overrides, kein `npm audit fix --force`, kein Prisma-Downgrade.
DoS ist ausdruecklich Teil der Bewertung.

| Freigabe | Paket / Audit-Severity / Lock-Version | Laufzeit, Pfad und Grenze | Klare Empfehlung / Begruendung |
|---|---|---|---|
| [ ] Entscheidung + Datum: ____ | `proxy-addr` / critical / 2.0.7; GHSA-jqcg-44mw-7w3h | Express-Laufzeitabhaengigkeit. [Backend](backend/server.js) setzt kein `trust proxy`; der betroffene IPv4-mapped-IPv6-Subnetz-Vertrauenspfad ist nicht als aktiviert belegt. `getClientIp` liest separat rohes X-Forwarded-For: nicht mit dieser Advisory verwechseln. | **Fixen empfohlen:** kompatible transitive Aufloesung auf 2.0.8+ pruefen. Kein nachgewiesener Advisory-Exploit im aktuellen Code, aber kleine Laufzeitkorrektur statt dauerhafter Critical-Ausnahme bevorzugen. Bis dahin nur explizite, begruendete Ausnahme; Header-/Rate-Limit-Vertrauensgrenze separat bewerten. |
| [ ] Entscheidung + Datum: ____ | `@fastify/busboy` / high / 3.2.0; GHSA-xjh9-v7x6-24jw, GHSA-x8mw-p69m-v3mx | Firebase Admin parst damit **ausgehende API-Multipartantworten** (`handleMultipartResponse`), nicht unseren `/uploads/image`-Ingress. Unser Upload verwendet Multer mit anderem `busboy`. | **Akzeptieren fuer diesen Umfang:** kein direkt vom Upload-Angreifer kontrollierter Parserpfad belegt; Google-Antworten sind die Grenze, nicht pauschal "Tooling". Bei fremdem Multipart-Input neu bewerten. Geplantes SDK-Update auf Aufloesung 3.2.2+ pruefen (auch moderate Meldung). |
| [ ] Entscheidung + Datum: ____ | `@grpc/grpc-js` / high / 1.14.4; GHSA-m9gg-hp2v-232j | Optionale Google-GAX/Firestore-Kette; Backend nutzt Firebase Auth/Messaging/Storage, kein eigener gRPC-Server oder Firestore-Pfad gefunden. Advisory betrifft bestimmte Server-Zertifikatskonfigurationen. | **Akzeptieren:** betroffene Serverfunktion im Release nicht belegt. Vor gRPC-/Firestore-Erweiterung neu bewerten; kompatibles SDK-Update auf 1.14.5+ einplanen. |
| [ ] Entscheidung + Datum: ____ | `@prisma/config` / high / 7.8.0 | CLI-/Pre-Deploy-Tooling; vererbte `deepmerge-ts`-Meldung, keine eigene Advisory. [Konfiguration](backend/prisma.config.ts) stammt aus Repo/Environment, nicht aus HTTP-JSON. | **Akzeptieren:** kein Angreifer-Objektgraph in diesem Toolingpfad belegt. Tooling laeuft beim Deploy, ist also nicht "nie benutzt". Zusammen mit kompatiblem Prisma-Update pflegen. |
| [ ] Entscheidung + Datum: ____ | `brace-expansion` / high / 2.1.2; vier DoS-Advisories: GHSA-mh99-v99m-4gvg, GHSA-rgw5-rvv9-x895, GHSA-qhr7-859c-m2p7, GHSA-6j4f-fj2g-mc7p | Transitive optionale `glob`-/Google-Kette; kein Backendrequest mit nutzerkontrolliertem Globmuster gefunden. | **Akzeptieren:** fehlender untrusted-Glob-Eingang ist die Begruendung, nicht DoS als Kategorie. Bei dynamischen Nutzer-Globmustern vorher fixen. |
| [ ] Entscheidung + Datum: ____ | `deepmerge-ts` / high / 7.1.5; GHSA-ggr8-5vv4-36mx | Prisma-Konfiguration/CLI; rekursiver Objektgraph kann Stack erschoepfen. Keine HTTP-Nutzdaten in dieser Config-Zusammenfuehrung belegt. | **Akzeptieren:** kontrollierte Tooling-Eingaben. Kompatibles Prisma/config-Update mit 8.0.0+ pruefen; nicht unabhaengig vom Config-API-Vertrag erzwingen. |
| [ ] Entscheidung + Datum: ____ | `fast-uri` / high / 3.1.3; sieben high-Advisories zu Host-/Authority-Verwechslung und SSRF | Prisma-CLI-/AJV-Kette; kein laufender HTTP-Pfad in diesen Parser gefunden. Mehrere URI-Sicherheitsfehler, keine sieben separaten Laufzeitwege bewiesen. | **Fixen empfohlen:** kompatible Tooling-Aufloesung auf 3.1.7+ pruefen und Prisma regressionspruefen. Aktuell kein belegter Runtime-Angriff; dennoch URI-Sicherheitskorrektur geplant statt ungepruefte Dauerakzeptanz. |
| [ ] Entscheidung + Datum: ____ | `fast-xml-parser` / high / 5.10.0; GHSA-8r6m-32jq-jx6q | Optionale Google-Storage-Kette, Entity-Expansion-DoS. Storage wird fuer Account-Medienbereinigung verwendet; genauer XML-Aufruf/Responsepfad in der lokalen optionalen Installation nicht vollstaendig belegt. | **Fixen empfohlen:** kompatibles SDK-/Parser-Update ausserhalb des betroffenen Bereichs pruefen. **Nicht** als sicher unerreichbar akzeptieren, solange der XML-Inputpfad ungeklaert ist. Alternativ expliziten Negativnachweis vor Ausnahme liefern. |
| [ ] Entscheidung + Datum: ____ | `mysql2` / high / 3.15.3; GHSA-3f6p-5ww8-9rcr | Prisma-CLI-Abhaengigkeit; Auth-Downgrade bei MySQL. [Datasource](backend/prisma/schema.prisma) und Adapter sind PostgreSQL; kein MySQL-Verbindungsweg gefunden. | **Akzeptieren:** anderes DB-Protokoll, betroffene Authentifizierung nicht genutzt. Vor MySQL-Nutzung kompatible Aufloesung 3.22.0+ pruefen. |
| [ ] Entscheidung + Datum: ____ | `nodemailer` / high / 9.0.3; GHSA-2x7j-588g-ccc2, GHSA-v53p-9fqp-m79j | Direkte Laufzeitabhaengigkeit. `sendEmail` nutzt zuerst Resend, sonst SMTP. Passwortreset nimmt Request-E-Mail an, Firebase-Linkgenerierung erfolgt vor `sendMail`; Verifizierung verwendet Token-E-Mail. Formatpruefung allein beweist keine Sicherheit des Address-Parsers. Produktions-SMTP/Resend-Konfiguration hier nicht gelesen. | **Fixen empfohlen:** bei moeglichem SMTP-Betrieb Parser-DoS nicht wegakzeptieren. Gepatchte kompatible Version ausserhalb des gespeicherten Bereichs `<=10.0.5` verifizieren, Mailflows testen. Ausnahme nur mit Nachweis, dass SMTP-Pfad deaktiviert bleibt; Firebase-Vorpruefung allein reicht nicht als Unmoeglichkeitsbeweis. |
| [ ] Entscheidung + Datum: ____ | `prisma` / high / 7.8.0 | CLI `postinstall`/`migrate:deploy`; Sammelmeldung fuer config/dev/mysql2, keine zusaetzliche eigenstaendige Advisory. Prisma Client und PostgreSQL-Runtime nicht mit dem CLI-Eintrag gleichsetzen. | **Fixen empfohlen als Toolchain-Buendel:** insbesondere `fast-uri` kompatibel aufloesen; andere oben begruendete Ausnahmen separat erfassen. Keine pauschale Major-Downgrade-Empfehlung uebernehmen. |

- [ ] Release-Verantwortlicher bestaetigt jede Zeile bzw. beauftragt getrennte
  Fixes; vorgeschlagene Fixes gelten ohne begruendete Ausnahme als offen.
- [ ] Nach spaeterem Fix erneute Auditaufnahme mit Lockfile-Hash,
  Backendtests und unveraendertem Prisma-/Readinessvertrag dokumentieren.
- [ ] Keine komplette Security-Freigabe allein aus dieser statischen Analyse
  oder dem erfolgreich behobenen Multer-DoS ableiten.

#### 6.1.2 Recht / Store: Datenfluss-Nachweis aus dem Code

Dies ist eine technische Faktenmatrix, **keine Rechtsberatung** und keine
vorab ausgefuellte Apple-/Google-Deklaration. Pfad im Code bedeutet nicht
automatisch produktive Aktivierung. SDK-Konfiguration, Regionen, Vertraege,
Retention und Storekategorien muss der Verantwortliche bestaetigen.
Heuristische Sanitization/Rundung ist keine garantierte Anonymisierung.

| Daten | Wohin / Zweck | Lokal oder externer Empfaenger; Grenze | Codebeleg |
|---|---|---|---|
| E-Mail, Login-Credentials/Providerdaten, UID, ID-Token | Anmeldung, Verifizierung, Backendauth | Firebase Auth; Token/UID auch eigenes Render-Backend. Nicht jeder Loginwert ist KI-Kontext. | [Auth](lib/logic/auth_service.dart), [API](lib/logic/backend_api_client.dart), [Backend](backend/server.js) |
| E-Mail und Reset-/Verifizierungslink | Kontozugang wiederherstellen / E-Mail bestaetigen | Backend -> Firebase Admin; Versand Resend oder SMTP/Nodemailer je Config. Telefonnummer-OTP ist hiervon getrennt. | [Mailrouten und sendEmail](backend/server.js#L11374) |
| Chatnachricht, begrenzter Verlauf, Sprache, ggf. Freitext mit sensiblen Angaben | KI-Elternberatung | App -> Render `/ai/generate` -> Google Gemini. Text-Sanitizer begrenzt Offenlegung, beweist aber keine Anonymitaet; Chat-Consent erforderlich. | [Chat](lib/ui/chat_screen.dart), [KI-Proxyclient](lib/logic/gemini_ai_service.dart), [Backend-Proxy](backend/server.js#L3030) |
| Bestaetigte Kind-/Gesundheits-/Memorywerte, Consent-Version/-Revision; optional Geburtsdatum/Geschlecht | Kontobezogenes KI-Gedaechtnis und personalisierter Kontext | Render/Prisma-DB; freigegebener minimierter Kontext an Gemini. Lokaler Anzeigename von neuem neutralem Servernamen getrennt; alte Originale bleiben. Ausschalten ist nicht Loeschen. | [Memoryclient](lib/logic/ai_memory_service.dart), [Settings](lib/ui/ai_memory_settings_screen.dart), [Schema](backend/prisma/schema.prisma), [Kontext](backend/server.js) |
| Kindesalter, Allergien, Gerichtswunsch | Kindgerechte Familienrezepte | Lokales Profil/Dossier -> Render -> Gemini nach eigenem Rezept-Consent; keine automatische Publikation. | [Rezepte](lib/logic/family_recipe_service.dart), [Consent](lib/logic/family_recipe_consent.dart) |
| Kuehlschrank-Fotobytes; bestaetigte Zutaten, Alter/Allergien fuer Rezept | Zutaten erkennen / Rezept vorschlagen | Bild base64 -> Render -> Gemini, danach Rezeptkontext; Fotoanalyse ist kein Backend-Publishing. Provider-/Log-Retention unbekannt, kein "nirgends gespeichert"-Versprechen. | [Kuehlschrankservice](lib/logic/fridge_recipe_service.dart), [KI-Transport](lib/logic/gemini_ai_service.dart) |
| Verschenkmarkt-Fotobytes | Optionale Titel-/Kategorie-/Beschreibungsvorschlaege | Render -> Gemini nach Foto-Consent; Bild nicht vor Uebertragung anonymisiert. Manuelle Eingabe bleibt moeglich. | [Fotoanalyse](lib/logic/treasure_photo_analysis_service.dart) |
| Entwicklungsantworten/Profilkontext, Alter, Scores; neutraler `[KIND]`-Platzhalter | Entwicklungsbericht erstellen | Render -> Gemini nach Bericht-Consent; Name erst lokal im Bericht eingesetzt. Bericht/History lokal konto-/gastbezogen gespeichert. | [Prompt](lib/ui/entwicklung_impulse_screen.dart#L1159), [Berichtservice](lib/logic/development_report_service.dart) |
| Wegweiser-Freitext, Situation, Land, Alter, Suchanfrage | Allgemeine/individualisierte Leistungsorientierung | Nach Consent Render -> Gemini; optional Google-Suche. Allgemeiner Fallback ist keine individuelle Fachberatung. | [Wegweiser](lib/ui/benefit_guide_screen.dart), [KI-Client](lib/logic/gemini_ai_service.dart) |
| Kind-Dossier, Allergien, Budget/Finanzwerte, lokale Entwuerfe/Consents | Lokale Appfunktionen und Kontotrennung | JSON/SharedPreferences lokal, keine zugesagte App-Verschluesselung. Auswahl fuer KI/Sharing ist gesonderter externer Pfad; OS-/Browserbackups nicht aus Repo bewiesen. | [Zentrale](lib/logic/family_hub_store.dart), [Finanzen](lib/logic/family_finance_store.dart), [Chatstore](lib/logic/chat_account_store.dart) |
| Suchtext oder gerundete GPS-/Pin-Koordinaten; Kartenkachelanfragen | Ortssuche, Karte, Discovery | Nominatim/OpenStreetMap direkt; Matchingprofil ans eigene Backend. Rundung nur nach geprueftem Pfad, keine Behauptung "kein Standorttransfer". | [Ortssuche](lib/logic/location_autocomplete_service.dart), [Event-Geocoder](lib/logic/event_geocoder.dart), [Netzwerk](lib/ui/eltern_netzwerk_screen.dart) |
| Fotos, Anzeigen-/Rezepttexte, Autorname/UID, Sichtbarkeit | Bewusste Community-Veroeffentlichung | Backend/Medien-URL und jeweilige Zielgruppe. `/uploads` wird statisch bereitgestellt: URL-Sichtbarkeit gesondert von Listen-/Rezeptsichtbarkeit pruefen. KI-Consent ist keine Publikationsfreigabe. | [Rezept-Publishing](lib/logic/family_recipe_share_service.dart), [Upload/static](backend/server.js#L11583) |
| Kalender-/Event-/Netzwerk-/Freundschaftsdaten, Kontokennungen | Synchronisierung, Einladungen, Match | Eigenes Backend je aktivem Flow, nicht pauschal lokal. Im Event-Einladungstext rohe Host-ID sichtbar. | [Kalendersync](lib/logic/calendar_backend_service.dart), [Freundschaft](lib/logic/friendship_service.dart), [Events](lib/ui/events_activities_screen.dart) |
| FCM-Token, User-ID, Benachrichtigungspayload | Pushzustellung und Zielnavigation | Backend/Firebase Messaging; lokale Reminder separat OS-lokal. Logout/Token-Abmeldung manuell nachweisen. | [Notifications](lib/logic/notification_service.dart), [Backend](backend/server.js) |
| Fehler, Stacktraces, technischer Kontext/Logtexte | Fehlerdiagnose | Firebase Crashlytics auf unterstuetzten Mobil-Releasepfaden; Web ausgeschlossen. Freitext kann sensible Anteile enthalten; Fristen nicht aus Code bewiesen. | [ErrorReporting](lib/logic/error_reporting_service.dart) |
| CSV/PDF/Text/Bilder, je ausgewaehltem Export | Nutzerinitiiertes Teilen | OS-Share-Ziel/Clipboard bzw. Ziel-App; deren Weiterverarbeitung nicht unter Appkontrolle. Kein automatischer KI-Transfer durch OS-Sharing. | [CSV](lib/ui/finance_budget_screen.dart), [PDF](lib/ui/entwicklung_impulse_screen.dart), [Zentrale](lib/ui/familien_zentrale_screen.dart) |
| Zahlungs-/Transaktions-/Kontaktdaten, falls Zahlungsflow aktiviert | Zahlungsabwicklung | Stripe-Pfad im Backend vorhanden; tatsaechliche Release-Erreichbarkeit/Config gesondert feststellen. Keine erfundene pauschale Collection-Aussage. | [Backend-Stripepfade](backend/server.js), [Dependency](pubspec.yaml) |

- [ ] Nutzer liefert reale Verarbeitungsrollen/Empfaenger, Regionen,
  Aufbewahrungs-/Backupfristen, Loesch-/Exportverfahren und aktive Dienstpfade.
- [ ] Fachliche Pruefung gleicht **jede Zeile** mit Privacy Policy,
  App Privacy und Data Safety nach deren jeweils eigenen Definitionen ab.
- [ ] Keine Aussagen "keine Daten geteilt", "voll anonym", "30 Tage" oder
  "vollstaendig uebersetzt" ohne belegten Betriebs-/Inhaltsnachweis.

#### 6.1.3 Geraete-QA: iOS und Android separat abhaken

Pro Plattform Kopf ausfuellen: App-SHA/Buildnummer ____, signierter Build ____,
OS/Modell ____, Tester/Datum ____, Backend/Testumgebung ____,
Nachweis/Abweichung ____. `[ ]` erst nach Durchfuehrung abhaken.
Eigene A/B-Testkonten, Gast und synthetische Daten verwenden.
Schreibende/Provider-Tests nur in freigegebener Testumgebung; nicht durch
diese Liste Produktionszugriff ableiten. Ablehnungstests duerfen keinen
KI-Request ausloesen; Netzwerkbelege aus Testinstrumentierung redigieren.
Abschnitt 3 bleibt der detaillierte Erwartungskatalog.

Fuer **jeden Consent**: erste Nutzung, Ablehnung, Zurueck/Abbruch, Zustimmung,
persistierter Ack, Neustart, Gast -> A -> Logout -> B -> A; DE/EN/TR/KU,
grosse Schrift und Speicher-/Netzwerkfehler. Fehlenden Ack in Testharness
simulieren, nicht produktive Preferences sabotieren. Spaete Antworten
duerfen nach Kontowechsel nicht beim neuen Konto landen.

| Szenario / bestandenes Kriterium | iOS | Android |
|---|---|---|
| Familienrezept-Consent: Ablehnung nur lokale Inspiration; Alter/Allergien/Gericht erst nach Zustimmung und Ack an KI. | [ ] | [ ] |
| Kuehlschrank-Consent: Legacy-Zustimmung gilt nicht; kein Bildtransfer bei Ablehnung/Ack-Fehler; Kamera-/Galerieabbruch ohne Request, Retry-/Kontowechselgrenzen. | [ ] | [ ] |
| Verschenkmarkt-Foto-Consent: Ablehnung erlaubt manuelle Anzeige; Bild behalten; KI-Analyse getrennt von sichtbarer Publikationsfreigabe. | [ ] | [ ] |
| Entwicklungsbericht-Consent: Empfaenger Google Gemini sichtbar; A-B-A waehrend Retry; keine fremden Berichte/History/Scores; Name lokal eingesetzt, Legacydaten nicht automatisch zugeordnet. | [ ] | [ ] |
| Wegweiser-Consent: allgemeine Leistungen bei Ablehnung; individueller Request erst nach Ack; Ausfallfallback erkennbar allgemein. | [ ] | [ ] |
| Chat-Consent: kein Senden vorher; Fehler/Tageslimit ehrlich; Gast/A/B-Zustimmungen getrennt; spaete Antwort nicht an B. | [ ] | [ ] |
| Memory-Zusatz-Consent: unabhaengig vom Chat; Aus/Ein invalidiert laufende Nutzung; Ausschalten vs. explizites Loeschen klar; kein neuer Transfer ohne gueltige Zustimmung. | [ ] | [ ] |
| Standortverarbeitungsinfo und Profil-Claim: Nominatim/OSM-Hinweis sichtbar; GPS/Pin/Manuelle Suche, Ablehnung von OS-Standortrecht; lokaler Legacyentwurf nur nach ausdruecklicher Kontozuordnung, nicht automatisch aktiv/veroeffentlicht. | [ ] | [ ] |
| Kamera/Galerie: erlaubt, verweigert, nachtraeglich widerrufen; leeres/ungueltiges/grosses Bild, Hintergrund/Neustart, Offline/Timeout; kein falscher Upload-/KI-Erfolg. | [ ] | [ ] |
| Kuehlschrankausgabe: erkannte Zutaten korrigierbar, Allergien plausibel; vorhandene Altersrundung/Default 3 separat fachlich bewerten. | [ ] | [ ] |
| Treasure/Rezepte: Entwurf nach Neustart, gerundeter Ort, Sichtbarkeit privat/Freunde/oeffentlich, Reservierung/Storno/Teilfehler ohne Doppelaktion; oeffentliche Foto-URL-Grenze bewusst pruefen. | [ ] | [ ] |
| Logout ohne Neustart: A-Dossier/Allergien/Geld/Profil/Entwurf/Chat/Memory angelegt; B sieht nichts davon in Screens, Suche, Bildern, Controllern, Share oder Push; zurueck A eigene Daten erhalten. | [ ] | [ ] |
| Logout waehrend Laden/Speichern/Claim/Upload/KI: keine spaeten Ergebnisse oder Writes im B-Scope; bereits gesendete Requests nicht als rueckwirkend geloescht darstellen. | [ ] | [ ] |
| DE -> EN -> TR -> KU: offene Dialoge, Fehler, Consent, FAQ-Suche, lange Texte, Tastatur und 200/300-Prozent-Schrift; weiterer Sprachpicker mit tatsaechlichem EN-/DE-Fallback, keine Volluebersetzungsbehauptung. | [ ] | [ ] |
| Sharing: Geld/Zentrale/Netzwerk, Budget-CSV, Entwicklungs-PDF; Ziel-App fehlt, Abbruch, Clipboardfehler, keine A-Daten bei B; iPad-Popover inkl. CSV gesondert pruefen. | [ ] | [ ] |
| Push/Reminder: Permission, Vorder-/Hintergrund/Cold-Start, Zielnavigation, Tokenrefresh/Logout; Uhrzeit/Zeitzone/DST; Ruhemodus nicht als Cancel aller bereits geplanten Reminder darstellen. | [ ] | [ ] |
| Recht-/Support-/amtliche Links ohne Login; TR-Leistungsangaben und Wohngeld-Link verifiziert; Deaktivierung/Loesch-/Exportweg mit Testidentitaet nachvollziehbar. | [ ] | [ ] |

- [ ] iPad-Sharing-Abnahme falls unterstuetzt; keine Freigabe aus iPhone
  ableiten (CSV-Popover ist noch kein bestandener Nachweis).
- [ ] Abweichungen mit redigiertem Nachweis klassifizieren; Blocker beheben
  und betroffene Szenarien erneut ausfuehren, nicht als Restrisiko verstecken.

### 6.2 Stufe 2 - Bewusste Restrisiken dokumentieren und entscheiden

Diese Stufe darf parallel vorbereitet werden, ersetzt aber keine Stufe-1-
Abnahme. Nutzer dokumentiert akzeptierten Umfang, Begruendung, Termin und
Verantwortlichen. Copilot kann Vorlagen/Codebelege liefern, nicht das reale
Betriebsrisiko stellvertretend akzeptieren.

| Entscheidung | Grenze / konkrete Freigabe |
|---|---|
| [ ] SMS / OTP | Flow bleibt nicht verdrahtet und nicht als produktionsfunktional beworben. Festes Secret ist aktiv, SMS-Versand/geteilter Speicher fehlen. Vor Aktivierung eigener Fix + Abnahme zwingend. |
| [ ] Lokale Verschluesselung | Schutzbedarf fuer Kind-/Gesundheits-/Finanzdaten und OS-/Browserbackups bewerten. App-Verschluesselung nur bei begruendet akzeptierter Grenze verschieben; Kontoskope nicht als Verschluesselung bezeichnen. |
| [ ] `hostUserId` | Sichtbare technische Kennung ausdruecklich akzeptieren oder vor Launch ersetzen lassen; keine erfundenen Hostnamen. |
| [ ] Volluebersetzung | Ehrlichen Launch-Sprachumfang/Fallback festlegen. Volluebersetzung darf spaeter kommen, unverstaendlicher Consent/Rechtstext fuer die adressierte Zielgruppe nicht. |
| [ ] Restore-Probe / Rollback | Backup/PITR ist **kein** Restore-Nachweis. Testplan, isoliertes Ziel, Wiederherstellungs-/Consent-Pruefung und kompatibler Rollback vorbereiten. Abschnitt 5 stuft die sichere Probe weiterhin als Pflicht vor Launch ein; Aufnahme hier bedeutet **keine automatische Verschiebung**. Verschiebung waere eine gesonderte ausdrueckliche Aenderung der Freigabekriterien. |

### 6.3 Stufe 3 - Nach Launch, separat priorisieren

| Backlog | Grenze / naechster Auftrag |
|---|---|
| [ ] Dependency-PRs | #35-#39 und #93 einzeln auf aktuelles main, API-/Native-Kompatibilitaet und volle CI pruefen. #33/#34 sind bereits geschlossen; Pages-Upgrades in #163, Gate nicht durch alte Workflows ueberschreiben. Sicherheitsfixes aus Stufe 1 sind **nicht** durch diesen Backlog auf nach Launch verschoben. |
| [ ] Alt-Features | #22 Nutzersync, #27 Startup-Fast-Path, #28 private Gruppen/unbegrenzte Einladungen separat fachlich entscheiden; #28 hatte zuletzt fehlgeschlagenes analyze. Kein pauschales Mergepaket. |
| [ ] Vertiefte Memory-Staging-Abnahme | Zusaetzliche Belastungs-/Langzeit-/Randfallmatrix, Provider-Ausfaelle, konkurrierende Revisionen und wiederholte Kontowechsel mit synthetischen Daten auf Staging erweitern. **Pflichtbasis vor Launch bleibt:** authentifizierte Settings-Abnahme, gueltiger Consent/Revision, Widerruf/Transfergrenze und sichere Betriebs-/Rollbacknachweise aus Abschnitt 5. Ist diese Basis unbewiesen, Memory nicht als launchfreigegeben behandeln; vor Verschiebung eigenen Scope-/Deaktivierungsentscheid verlangen. |

**Reihenfolge:** Stufe 1 belegen und Entscheidungen aus Stufe 2 abschliessen;
danach finales Freigabeprotokoll aus Abschnitt 5. Erst mit ausdruecklicher
Launchfreigabe veroeffentlichen/Stores freigeben; Stufe 3 separat bearbeiten.
