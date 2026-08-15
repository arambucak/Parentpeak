# 🧪 Meetup-System - Quick Test Guide

## 🚀 So testest du das System

### 1️⃣ **App starten**
```bash
cd c:\Users\Admin\Documents\GitHub\Parentpeak
flutter run -d RFCY30GWBEB
```
(Dauert beim ersten Mal ~2-3 Minuten)

---

## 📱 Test-Flows

### **Flow 1: Event entdecken**
1. Starte die App
2. Auf HomeScreen → **"Aktivitäten & Treffs" Button** klicken (neuer blauer Button oben)
3. Du siehst die **MeetupScreen** mit 2 Test-Events
4. Oben sind Filter-Chips (Altersgruppen)
5. Rechts oben: Icon zum Umschalten **Grid ↔ List View**

### **Flow 2: Event-Details ansehen**
1. Klick auf eines der Events (Grid oder List)
2. Du siehst:
   - 🖼️ Event-Bild
   - 📝 Titel & Beschreibung
   - 📅 Datum/Uhrzeit
   - 📍 Ort
   - 👥 Teilnehmerzahl
   - 🏷️ Altersgruppen

### **Flow 3: Teilnahme anfragen**
1. Im EventDetailScreen → **"Teilnahme anfragen" Button** klicken
2. Status ändert sich zu: **⏳ "Anfrage ausstehend"**
3. (Im echten System würde der Host bestätigen)

### **Flow 4: Chat öffnen**
1. (Nur wenn bereits als "bestätigt" markiert)
2. Button **"Zum Chat"** klicken
3. Du siehst: **MeetupChatScreen**
   - Nachrichtenhistorie (leer beim ersten Mal)
   - Input-Feld zum Schreiben
   - Long-press auf Nachricht → Melden/Löschen

### **Flow 5: Event erstellen**
1. Auf MeetupScreen → **FAB (+ Button) oben rechts** klicken
2. **CreateEventScreen** öffnet sich
3. Fülle Formular aus:
   - Titel: z.B. "Mein Parkplatz-Treffen"
   - Beschreibung
   - Kategorie wählen
   - Altersgruppen Chips wählen
   - Datum & Zeit
   - Treffpunkt
   - Max Teilnehmer
4. **"Zur Zahlung" Button** klicken

### **Flow 6: Zahlung**
1. **PaymentScreen** öffnet sich
2. Wähle Zahlungsmethode: **Stripe oder PayPal**
3. Hake **"Bedingungen"** ab
4. **"2,99 € zahlen" Button** klicken
5. Erfolgsmeldung erscheint ✅

### **Flow 7: Host-Dashboard**
1. (Hier musst du manuell navigieren)
2. Stelle eine gueltige Host-ID sicher: `host_test_001` oder eine reale Host-ID aus deiner Umgebung
3. Dashboard zeigt:
   - 📊 Statistiken
   - 📬 Ausstehende Anfragen
   - 📝 Deine Events

### **Flow 8: Sicherheits-Guide**
1. (Manuell navigieren zu SafetyGuideScreen)
2. Zeigt Tipps für sichere Treffen
3. Notfall-Hotlines

---

## ✅ Test-Checkliste

- [ ] HomeScreen hat neuen "Aktivitäten & Treffs" Button
- [ ] MeetupScreen zeigt 2 Test-Events
- [ ] Filter nach Altersgruppen funktioniert
- [ ] Grid/List Toggle funktioniert
- [ ] Event-Details anzeigen funktioniert
- [ ] "Teilnahme anfragen" Button funktioniert
- [ ] Status ändert sich zu "Ausstehend"
- [ ] Chat-Button funktioniert
- [ ] CreateEventScreen öffnet sich
- [ ] Formular lässt sich ausfüllen
- [ ] PaymentScreen öffnet sich
- [ ] Zahlungsmethoden-Auswahl funktioniert
- [ ] Success-Dialog erscheint

---

## 🐛 Falls etwas nicht funktioniert

### **Problem: Button "Aktivitäten & Treffs" nicht sichtbar**
→ Überprüfe HomeScreen imports:
```dart
import 'package:your_package/ui/meetup_screen.dart';
```

### **Problem: MeetupScreen zeigt keine Events**
→ Überprüfe EventService Mock-Daten:
```dart
lib/logic/event_service.dart - Zeile ~20
```

### **Problem: Fehler beim Kompilieren**
```bash
flutter clean
flutter pub get
flutter run
```

### **Problem: App startet nicht**
→ Android-Device verbinden & verifizieren:
```bash
flutter devices
```

---

## 💡 Test-Accounts

| Role | ID | Bemerkung |
|------|-----|-----------|
| User | `user_test_001` | Regular User |
| Host | `host_test_001` | Host/Admin |

---

## 📸 Screenshots zu nehmen

Wichtige Screens zum Screenshotten:
1. ✅ HomeScreen mit neuem Button
2. ✅ MeetupScreen Grid View
3. ✅ MeetupScreen List View
4. ✅ Event-Details
5. ✅ Chat
6. ✅ Create Event Form
7. ✅ Payment Screen
8. ✅ Success Dialog

---

## 🎯 Nächste Schritte nach Tests

1. Firebase integrieren (für echte Events)
2. Stripe/PayPal echte Integration
3. Push Notifications
4. User Authentifizierung
5. Analytics

---

**Viel Spaß beim Testen! 🎉**
