# Post-Launch 7-Day Monitoring Plan

## Ziel

In den ersten 7 Tagen nach Release Stabilitaet sichern, frueh lernen und schnell nachsteuern.

## Kernmetriken

| Bereich | Metrik | Ziel | Warnschwelle | Kritisch |
|---|---|---|---|---|
| Stabilitaet | Crash-Free Sessions | >= 99.5% | < 99.3% | < 99.0% |
| Backend | API 5xx Rate (Kernendpunkte) | < 0.5% | >= 1.0% | >= 2.0% |
| Payments | Payment Success Rate | >= 95% | < 93% | < 90% |
| Activation | First Core Action in <60s | >= 70% | < 60% | < 50% |
| Retention | D1 Retention | >= 35% | < 30% | < 25% |
| Support | Erstantwortzeit | < 12h | > 18h | > 24h |

## Tagesrhythmus (Tag 1-7)

1. 09:00: Metrics Snapshot und Alert Review.
2. 10:00: Top 3 Probleme priorisieren (Severity + Nutzerimpact).
3. 13:00: Statusupdate mit ETA fuer offene Punkte.
4. 17:00: EOD Review mit Entscheidungen fuer den naechsten Tag.

## Day-by-Day Fokus

| Tag | Fokus | Konkrete Aktion |
|---|---|---|
| Tag 1 | Stabilitaet + Payments | Crash/API/Payment eng monitoren, Rollout nur bei gruenem Status erweitern |
| Tag 2 | Onboarding | Abbruchstellen analysieren, 1-2 schnelle UX-Fixes priorisieren |
| Tag 3 | Support Learnings | Top Support-Fragen in Produkttexte und FAQ rueckfuehren |
| Tag 4 | Performance | p95 Ladezeiten und Startzeit optimieren |
| Tag 5 | Vertrauen | Datenschutz-/Sicherheitsfeedback auswerten und klare Hinweise verbessern |
| Tag 6 | Retention | Push/Reminder-Tonality und Timing nachjustieren |
| Tag 7 | Wochenreview | KPI-Review, Hotfix-Liste, Plan fuer Woche 2 freigeben |

## Eskalationsmatrix

| Severity | Beispiel | Reaktion |
|---|---|---|
| Sev-1 | App unbenutzbar, kritische Payment-Fehler, Sicherheitsvorfall | Sofortiger Rollout-Stop + Incident-Modus |
| Sev-2 | Hohe Fehlerrate in Kernflow, deutlicher KPI-Einbruch | Hotfix innerhalb 24h |
| Sev-3 | UX-Probleme ohne Systemrisiko | In naechsten Patch aufnehmen |

## KI-Kostenschutz nach Launch neu bewerten

Nach dem Store-Launch (Google Play / App Store) mit echten Nutzungszahlen die
KI-Limits anhand realer Daten pruefen und nachjustieren. Alle Werte sind ueber
Render-Environment-Variablen aenderbar — ohne Code-Aenderung oder Deploy-Risiko.

Aktive Schutzebenen (Stand Okt 2026):

| Schutz | Env-Variable | Default | Bedeutung |
|---|---|---|---|
| KI nur fuer eingeloggte Nutzer | `FIREBASE_REQUIRE_AUTH` | `1` | kein anonymer KI-Zugriff |
| Pro-Konto-Limit (KI) | `AI_RATE_LIMIT_MAX` / `AI_RATE_LIMIT_WINDOW_MS` | 30 / 15 Min | bremst ein einzelnes Konto |
| Globales Tagesbudget (KI) | `AI_DAILY_BUDGET_MAX` | 2000/Tag | harte Gesamt-Kostenobergrenze (0 = aus) |
| Schreib-Rate-Limit | `WRITE_RATE_LIMIT_MAX` / `_WINDOW_MS` | 120 / 15 Min pro IP | allgemeiner Spam-Schutz |

Nach Launch beobachten und entscheiden:
- Erreichen echte Nutzer regelmaessig das Pro-Konto-Limit (30/15 Min)? Falls ja
  und legitim → `AI_RATE_LIMIT_MAX` moderat erhoehen.
- Naehert sich das taegliche KI-Volumen dem `AI_DAILY_BUDGET_MAX`? Budget an die
  tatsaechlichen Gemini-Kosten/Reichweite anpassen (hoch bei Wachstum, runter zum
  Deckeln). Warn-Log `AI daily budget reached` im Backend beobachten.
- Haeufen sich `429`/`503` auf `/ai/generate` fuer legitime Nutzer? → Limits zu
  streng, nachjustieren.

Optionaler Ausbau (nur bei Bedarf, noch nicht umgesetzt):
- Proaktiver Alarm bei ~80 % des Tagesbudgets (statt nur zu blocken), damit man
  vor dem Hard-Cap reagieren kann.
- Gemini-Kosten-/Volumen-Dashboard fuer Trendsicht.

## Daily Report Template

- Datum:
- Rollout-Stufe:
- Crash-Free:
- API 5xx:
- Payment Success:
- D1/Activation Snapshot:
- Top 3 Probleme:
- Heute gefixte Punkte:
- Risiken fuer morgen:
- Entscheidung (weiter ausrollen / halten / stoppen):
