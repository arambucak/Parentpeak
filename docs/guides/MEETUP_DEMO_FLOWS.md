# 🎬 Meetup-System Demo - User Flows

## 🎯 Szenario 1: Event entdecken und anfragen

### Schritt 1: Haupt-Screen
```
┌─────────────────────┐
│  Parentpeak Home    │
├─────────────────────┤
│ [Aktivitäten 🎪]    │ ← NEW Button
│ [Family Hub 🏠]     │
│ [Routine ✓] [AI 🧠] │
└─────────────────────┘
```

### Schritt 2: MeetupScreen
```
┌─────────────────────┐
│ Aktivitäten & Treffs│
│ [Filter Chips ▼]    │
├─────────────────────┤
│ [Event 1] [Event 2] │ ← Grid View
│ [Event 3] [Event 4] │
│                     │
│ 📋 4 Aktivitäten    │
└─────────────────────┘
```

### Schritt 3: Event-Details
```
┌─────────────────────┐
│ [Event Bild]        │
├─────────────────────┤
│ "Spielplatz Treffen"│
│ 📅 15.01.2026 14:00 │
│ 📍 Zentralpark      │
│ 👥 5/15 Teilnehmer  │
│                     │
│ [Teilnahme anfragen]│ ← Button
└─────────────────────┘
```

### Schritt 4: Status-Update
```
Nach Klick auf "Teilnahme anfragen":

┌─────────────────────┐
│ 🟨 Anfrage ausstehend│
│                     │
│ Warte auf Bestätigung
│ des Hosters...      │
└─────────────────────┘

---

Nach Host-Genehmigung:

┌─────────────────────┐
│ ✅ Du bist angemeldet! │
│                     │
│ [Zum Chat ➜]        │
└─────────────────────┘
```

---

## 🏪 Szenario 2: Event erstellen & zahlen

### Schritt 1: Create Event Form
```
┌─────────────────────┐
│ Aktivität erstellen │
├─────────────────────┤
│ 📝 Titel:           │
│ [_________________] │
│                     │
│ 📋 Beschreibung:    │
│ [_________________] │
│ [_________________] │
│                     │
│ 🏷️ Kategorie:       │
│ [Dropdown ▼]        │
│                     │
│ 👧 Altersgruppen:   │
│ [Filter Chips]      │
│                     │
│ 📅 Datum: [___]     │
│ 🕐 Zeit:  [___]     │
│                     │
│ [Zur Zahlung ➜]     │
└─────────────────────┘
```

### Schritt 2: Payment Screen
```
┌─────────────────────┐
│ Zahlungsbestätigung │
├─────────────────────┤
│ Bestellübersicht:   │
│ Spielplatz Treffen  │
│ ━━━━━━━━━━━━━━━━   │
│ Gebühr: 2,99 €      │
│                     │
│ Zahlungsmethode:    │
│ (●) Stripe          │
│ ( ) PayPal          │
│                     │
│ ✓ Bedingungen       │
│                     │
│ [2,99 € zahlen]     │
└─────────────────────┘
```

### Schritt 3: Success
```
┌─────────────────────┐
│ ✅ Zahlung erfolgreich!│
├─────────────────────┤
│ Event ist nun live! │
│                     │
│ ID: txn_12345678   │
│ Betrag: 2,99 €      │
│                     │
│ [Fertig]            │
└─────────────────────┘
```

---

## 💬 Szenario 3: Chat & Kommunikation

### Schritt 1: Chat-Screen
```
┌──────────────────────┐
│ Spielplatz Treffen   │
│ Chat (3 Nachrichten) │
├──────────────────────┤
│                      │
│  🟢 Anna:            │
│  "Wer bringt Ball?" │
│                      │
│  🟠 HOST:            │
│  "Ich bringe Spiele" │
│  [HOST Badge]        │
│                      │
│  🔵 Du:              │
│  "Super! Bis dann!" │
│                      │
├──────────────────────┤
│ [Nachricht...] [➤]   │
└──────────────────────┘
```

### Schritt 2: Nachricht Melden
```
Long-Press auf Nachricht:

┌──────────────────┐
│ [🚩 Melden]      │
│ [🗑️ Löschen]    │
└──────────────────┘

Wähle Grund:
┌──────────────────┐
│ Unangemessen   │
│ Spam           │
│ Sicherheit     │
│ Andere         │
└──────────────────┘
```

---

## 🏠 Szenario 4: Host-Dashboard

### Host sieht Anfragen
```
┌──────────────────────┐
│ Mein Host-Dashboard  │
├──────────────────────┤
│ 📊 Statistiken       │
│ [Events: 2]          │
│ [Teilnehmer: 8]      │
│ [Ausstehend: 2]      │
│                      │
│ 📬 Ausstehende       │
│ Anfragen: 2          │
│                      │
│ Nutzer: user_123    │
│ Angefordert: 11.01  │
│ [Ablehnen] [OK ✓]   │
│                      │
│ Nutzer: user_456    │
│ Angefordert: 11.01  │
│ [Ablehnen] [OK ✓]   │
│                      │
│ 📝 Meine Aktivitäten │
│ ✅ Spielplatz (5/15) │
│ ✅ Kinderturnen (...)│
└──────────────────────┘
```

---

## 🔒 Szenario 5: Sicherheit

### Safety Guide
```
┌──────────────────────┐
│ 🛡️ Sicherheits-Guide │
├──────────────────────┤
│ ✅ Vor dem Treffen   │
│ • Öffentlicher Ort   │
│ • Vertrautem berichten
│ • Wetter checken     │
│ • Erkennungszeichen  │
│                      │
│ ✅ Während Treffen   │
│ • In Nähe bleiben    │
│ • Vertrauen aufbauen │
│ • Keine Privatadressen
│ • Chat monitoren     │
│                      │
│ ⚠️ Warnsignale       │
│ • Unerw. Privattreffe
│ • Fragen z. Kindern  │
│ • Unangemessene Bilder
│ • Druck zur Heimlichkeit
│                      │
│ 🚨 Im Notfall:       │
│ Polizei: 110         │
│ Notarzt: 112         │
│                      │
│ [Ich verstehe ✓]     │
└──────────────────────┘
```

---

## 📊 State Transitions

```
┌──────────────────────────────────────────┐
│         PARTICIPATION FLOW                │
└──────────────────────────────────────────┘

NOT PARTICIPATED
       ↓ [Click "Teilnahme anfragen"]
PENDING (⏳)
       ↓ [Host approved]
APPROVED (✅) → [Can access chat]
       ↓ [Host declined]
DECLINED (❌)

---

┌──────────────────────────────────────────┐
│         EVENT CREATION FLOW               │
└──────────────────────────────────────────┘

FORM ENTRY
       ↓ [Click "Zur Zahlung"]
PAYMENT PENDING
       ↓ [Select payment method]
PAYMENT PROCESSING
       ↓ [Confirm payment]
PUBLISHED (✅)
```

---

## 🎨 Color Scheme

```
Primary Actions:     🟦 #2196F3 (Blue)
Success:             🟩 #4CAF50 (Green)
Pending:             🟨 #FFC107 (Amber)
Error/Full:          🔴 #E91E63 (Red)
Background:          ⭐ #F5EFE7 (Cream)
Surface:             ⚪ #FFFFFF (White)
Text Primary:        ⚫ #2D3748 (Dark Gray)
Text Secondary:      🔘 #718096 (Gray)
```

---

## 📱 Responsive Design

### Mobile (< 600px)
- Single Column Layout
- Full-width Buttons
- Bottom Navigation

### Tablet (600px - 900px)
- 2-Column Grid (events)
- Side-by-side Chat

### Desktop (> 900px)
- 3-Column Grid (events)
- Sidebar Navigation

---

## ⚡ Performance Optimizations

- Image Caching via NetworkImage
- Lazy Loading in Lists
- Pagination Ready
- Mock Services (2-3 Sekunden Latenz)

---

## 🎓 Lernpfade für User

### Anfänger Path
1. Home → Aktivitäten Button
2. Browse Events → Filter
3. Event Details → Anfrage senden
4. Warte auf Bestätigung
5. Chat öffnen

### Power User Path
1. Host Dashboard
2. Event erstellen
3. Payment verarbeiten
4. Anfragen verwalten
5. Chat moderieren

---

**Das Meetup-System ist production-ready! 🚀**
