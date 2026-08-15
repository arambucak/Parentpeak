# 🔴 LIVE MODE: Action Plan für Dich

## TL;DR - Das Wichtigste in 3 Schritten

### Schritt 1: Live Webhook Secret von Stripe holen (5 min)
```
https://dashboard.stripe.com/live/workbench/webhooks
├─ Klick: "Ziel hinzufügen"
├─ URL: https://parentpeak.onrender.com/payments/stripe/webhook
├─ Events: Alle relevanten auswählen
└─ → Kopiere das Secret (whsec_...)
```

### Schritt 2: Secret in Render eintragen (2 min)
```
https://dashboard.render.com/web/srv-d8q0p5j6sc1c73auvfa0/env
├─ Finde: STRIPE_WEBHOOK_SECRET
├─ Wert ersetzen mit dem Secret von Schritt 1
└─ → Save (Auto-Deploy startet)
```

### Schritt 3: Validierung (1 min)
```bash
curl -X POST https://parentpeak.onrender.com/payments/stripe/webhook \
  -H 'Content-Type: application/json' -d '{}'
# → Sollte zurückgeben: 400 mit "Ungueltige Stripe-Signatur"
# Das ist OK! Wir haben keine gültige Signatur gesendet.
```

---

## 📋 Detaillierte Schritte

### 1️⃣ Stripe Live Webhook erstellen

**Browser:** https://dashboard.stripe.com/live/workbench/webhooks

**Was zu tun ist:**
1. Wende Dich an den "Ziel hinzufügen" Button
2. Gib ein: `https://parentpeak.onrender.com/payments/stripe/webhook`
3. Wähle Events (empfohlen):
   - ✅ `payment_intent.succeeded`
   - ✅ `payment_intent.payment_failed`
   - ✅ `charge.refunded`
4. Klick "Endpoint erstellen"
5. **Wichtig:** Kopiere den Webhook Secret (sieht so aus: `whsec_12345...`)

### 2️⃣ Render aktualisieren

**Browser:** https://dashboard.render.com/web/srv-d8q0p5j6sc1c73auvfa0/env

**Was zu tun ist:**
1. Finde die Umgebungsvariable `STRIPE_WEBHOOK_SECRET`
2. Ersetze den Wert:
   - **ALT:** das bisherige Test-Secret (Wert absichtlich entfernt)
   - **NEU:** `whsec_...` (Dein Live Secret von Schritt 1)
3. Klick **Save**
4. Warte 30 Sekunden auf Auto-Deployment

### 3️⃣ Live Webhook testen

**Terminal:**
```bash
# Einfacher Test - sollte 400 zurückgeben
curl -sS -w "\nStatus: %{http_code}\n" \
  -X POST https://parentpeak.onrender.com/payments/stripe/webhook \
  -H 'Content-Type: application/json' \
  -d '{}'

# Erwartet: 400 Fehler = RICHTIG ✅
# Grund: Wir senden keine gültige Stripe-Signatur
```

---

## ✅ Erfolgs-Checkliste

Nach allen 3 Schritten sollte Dein System:

- [ ] Stripe Live Webhook erstellt haben
- [ ] Live Secret in Render aktualisiert haben
- [ ] Auto-Deployment abgeschlossen haben (grüner Status in Render)
- [ ] 400-Fehler auf ungültige Requests zurückgeben
- [ ] Gültige Live Webhooks von Stripe akzeptieren

---

## 🔍 Wie man es überprüft

### Stripe Dashboard Check
1. Gehe zu: https://dashboard.stripe.com/acct_1Tjhoi0tdYAsNwR0/live/workbench/webhooks
2. Klick auf Dein Endpoint
3. Tab "Recent deliveries" (Letzte Zustellungen)
4. Solltest Du Einträge sehen, wenn Webhooks ankommen

### Render Log Check
1. Gehe zu: https://dashboard.render.com/web/srv-d8q0p5j6sc1c73auvfa0
2. Tab "Logs"
3. Suche nach "webhook" oder "stripe"
4. Sollte keine Signatur-Fehler zeigen

### Live Test (Optional)
1. Erstelle eine Test-Zahlung in Stripe Live
2. Stripe sendet Webhook automatisch
3. Check Render Logs ob Event angekommen ist

---

## ⚠️ Häufige Fehler & Lösungen

### Fehler: "Ungueltige Stripe-Signatur"
**Problem:** Secret in Render passt nicht zu Stripe Secret
**Lösung:** 
- Kopier das Secret nochmal exakt von Stripe
- Achte auf kein copy-paste Fehler
- Keine Leerzeichen vor/nach dem Secret

### Fehler: Endpoint antwortet gar nicht (Timeout)
**Problem:** Render Service läuft nicht
**Lösung:**
- Check Render Dashboard Status
- Klick "Manual Deploy" wenn nötig
- Warte auf "Live" Status

### Fehler: Webhook kommt nie an
**Problem:** Stripe kennt Dein Secret nicht
**Lösung:**
- Verify URL exakt: `https://parentpeak.onrender.com/payments/stripe/webhook`
- Verifiziere Endpoint ist im Live-Modus (nicht Sandbox!)

---

## 🎯 Was passiert danach

Sobald alles konfiguriert ist:

1. **Stripe sendet Live-Payments** → Endpoint erhält Webhook
2. **Backend verarbeitet Event** → Signatur wird validiert
3. **System antwortet mit 202** → Stripe weiß: Webhook war erfolgreich
4. **Payment wird registriert** → Deine App kennt den Status

---

## 📞 Wenn etwas schiefgeht

1. **Terminal öffnen:**
   ```bash
   cd /Users/aram/Documents/GitHub/Parentpeak
   bash scripts/release_smoke_suite.sh
   ```
   Alle Tests sollten grün sein ✅

2. **Log anschauen:**
   ```bash
   # Render Logs
   https://dashboard.render.com/web/srv-d8q0p5j6sc1c73auvfa0/logs
   
   # Stripe Webhook Logs
   https://dashboard.stripe.com/acct_1Tjhoi0tdYAsNwR0/live/workbench/webhooks
   ```

3. **Zurück zu Test-Modus** (wenn nötig):
   ```bash
   # In Render: STRIPE_WEBHOOK_SECRET auf das rotierte Test-Secret setzen.
   ```

---

## 🎉 Fertig!

Das ist alles, was Du brauchst. Backend-Code ändert sich nicht - nur die Umgebungsvariable!

**Aktuelle Status:**
- ✅ Test-Mode: Läuft perfekt
- ⏳ Live-Mode: Wartet auf Dich
- 📝 Dokumentation: Bereit zum Nachschlagen

Wenn Du Fragen hast, schau in `/docs/STRIPE_LIVE_WEBHOOK_SETUP.md` - dort sind alle Details!

**Punkt:** Die Umgebungsvariable ist das Einzige was zwischen Test und Live unterscheidet. Alles andere funktioniert gleich!
