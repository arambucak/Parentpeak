# Weekly Impulse Community Runbook

## Ziel

Dieses Runbook beschreibt den Betriebsablauf fuer den Wochenimpuls-Communitybereich mit:

- Community-Posts
- Likes und Kommentaren
- Moderationsmeldungen
- globalem Ausblenden/Wiederfreigeben
- Fachverifizierung fuer paedagogische Stimmen

## Erforderliche Backend-Umgebungsvariablen

```bash
REQUIRE_AUTH_FOR_WRITES=1
INTERNAL_MODERATOR_EMAILS=lead@parentpeak.de,ops@parentpeak.de
INTERNAL_MODERATOR_DOMAINS=parentpeak.de,parentpeak.com
```

Hinweise:

- `INTERNAL_MODERATOR_EMAILS` ist fuer einzelne bekannte Reviewer gedacht.
- `INTERNAL_MODERATOR_DOMAINS` erlaubt interne Moderation fuer komplette Firmen-/Team-Domains.
- Firebase Admin muss wie fuer die anderen authentifizierten Routen konfiguriert sein.
- Alle Community-Schreibaktionen und privaten Verifizierungs-/Moderationsabfragen
  verlangen einen gueltigen Firebase-ID-Token, unabhaengig von globalen Auth-Flags.
  Ein statischer `BACKEND_API_TOKEN` ersetzt keine Nutzeridentitaet.
- Review-Rechte stammen ausschliesslich aus der bestaetigten Token-E-Mail
  (`email_verified=true`) und der bestehenden E-Mail-/Domain-Allowlist.
  `moderatorEmail`/`reviewerEmail` in Body oder Query vergeben keine Rechte.
- Nutzer-ID und Fachstimmen-Status stammen aus dem Token-Konto. Eigene
  Verifizierungsanfragen benoetigen eine bestaetigte E-Mail; fremde Statusabfragen
  oder geliehene Fachstimmen-Badges ueber Body-/Query-Identitaeten sind nicht erlaubt.
- Review-/Moderationsentscheidungen protokollieren die bestaetigte Token-E-Mail
  statt eines frei gesetzten Moderatornamens.

## Relevante Endpunkte

### Community lesen und schreiben

- `GET /api/weekly-impulse`
- `POST /api/weekly-impulse/community/posts`
- `POST /api/weekly-impulse/community/posts/:postId/like`
- `POST /api/weekly-impulse/community/posts/:postId/comments`
- `POST /api/weekly-impulse/community/posts/:postId/report`

### Moderation

- `GET /api/weekly-impulse/community/reports`
- `POST /api/weekly-impulse/community/reports/:reportId/resolve`
- `POST /api/weekly-impulse/community/posts/:postId/moderation-visibility`

### Fachverifizierung

- `GET /api/weekly-impulse/community/verification-status`
- `POST /api/weekly-impulse/community/verification-requests`
- `GET /api/weekly-impulse/community/verification-requests`
- `POST /api/weekly-impulse/community/verification-requests/:requestId/approve`

## Erwartetes Verhalten

### Normaler Nutzer

- darf Community-Beitraege lesen, posten, liken, kommentieren und melden
- darf keine Moderationslisten laden
- darf keine Moderationsentscheidungen treffen
- darf keine Verifizierungsanfragen anderer pruefen oder freigeben

### Interner Moderator

- darf Moderationsreports laden
- darf Reports als bearbeitet markieren
- darf Beitraege global ausblenden oder wieder freigeben
- darf offene Fachverifizierungsanfragen sehen und freigeben

## Go-Live Checkliste

1. Backend mit Firebase Admin und den passenden Moderator-Allowlisten deployen.
2. Mit internem Account pruefen, dass das Admin-/Moderationspanel in der App funktioniert.
3. Mit normalem Account pruefen, dass Moderations-Review-Endpunkte serverseitig `403` liefern.
4. Test-Community-Post erstellen.
5. Test-Report auf den Post absetzen.
6. Mit internem Account den Post im Moderationspanel laden.
7. Testweise global ausblenden und wieder freigeben.
8. Testweise eine Fachverifizierungsanfrage stellen.
9. Mit internem Account die Anfrage freigeben.
10. Danach einen neuen Paedagogik-Post erstellen und pruefen, dass das Verifizierungs-Badge automatisch gesetzt wird.

## Empfohlene Smoke-Tests

### Voller Community-Smoke als Script

Nur gegen ein isoliertes Test-Backend ausfuehren: Der Ablauf legt Daten an und
gibt ein Testkonto als Fachstimme frei. Zwei getrennte Firebase-Testkonten mit
bestaetigter E-Mail verwenden: ein normales Konto und einen internen Moderator.
Frische ID-Token sicher als Umgebungsvariablen bereitstellen, nicht committen
oder in Logs ausgeben. Das normale Testkonto darf noch keine offene Anfrage haben.

```bash
BACKEND_BASE_URL=https://YOUR_BACKEND \
FIREBASE_ID_TOKEN="$TEST_USER_ID_TOKEN" \
INTERNAL_REVIEWER_ID_TOKEN="$TEST_MODERATOR_ID_TOKEN" \
bash scripts/weekly_impulse_community_smoke_test.sh
```

Optional im bestehenden Sammel-Smoke:

```bash
BACKEND_BASE_URL=https://YOUR_BACKEND \
RUN_BACKEND_SECURITY_SMOKE=1 \
RUN_STRIPE_WEBHOOK_SMOKE=0 \
RUN_WEEKLY_IMPULSE_COMMUNITY_SMOKE=1 \
FIREBASE_ID_TOKEN="$TEST_USER_ID_TOKEN" \
INTERNAL_REVIEWER_ID_TOKEN="$TEST_MODERATOR_ID_TOKEN" \
bash scripts/release_smoke_suite.sh
```

### Moderationszugriff intern

Erwartung: `200`

```bash
curl -i "https://YOUR_BACKEND/api/weekly-impulse/community/reports?impulseId=imp_years_3_gfk_w1&includeResolved=1" \
  -H "Authorization: Bearer $TEST_MODERATOR_ID_TOKEN"
```

### Moderationszugriff extern blockiert

Erwartung: `403`

```bash
curl -i "https://YOUR_BACKEND/api/weekly-impulse/community/reports?impulseId=imp_years_3_gfk_w1&includeResolved=1&moderatorEmail=lead@parentpeak.de" \
  -H "Authorization: Bearer $TEST_USER_ID_TOKEN"
```

Ohne Token oder mit einem ungueltigen Token wird `401` erwartet, auch wenn die
Query eine interne E-Mail enthaelt. Eine nicht bestaetigte interne Token-E-Mail
liefert ebenfalls keinen Moderationszugriff (`403`).

### Fachanfrage intern freigeben

Erwartung: `200`

```bash
curl -i -X POST "https://YOUR_BACKEND/api/weekly-impulse/community/verification-requests/REQUEST_ID/approve" \
  -H "Authorization: Bearer $TEST_MODERATOR_ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "reviewNote": "Ausbildung geprueft.",
    "verificationLabel": "Verifizierte Fachstimme"
  }'
```

## Produkt-Hinweis

Die Backend-Autorisierung gilt unabhaengig von UI-Sichtbarkeit oder mitgeschickten
Profilangaben. Die tatsaechliche Erreichbarkeit der Moderationsoberflaechen bleibt
Teil der manuellen QA; reine Service-/Routentests ersetzen diesen Nachweis nicht.
