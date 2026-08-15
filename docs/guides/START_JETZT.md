# 🚀 START JETZT – Schritt-für-Schritt

**Dein Team kann SOFORT anfangen. Hier sind die exakten Befehle.**

---

## 🎯 Minute 1: Überblick bekommen

**Alle im Team:**
```bash
# 1. Öffne diesen Link
open https://github.com/fatihbucak56-beep/Parentpeak/blob/main/QUICK_START_RELEASE.md

# Oder von der Kommandozeile:
cat QUICK_START_RELEASE.md
```

**Lese:** Die 3-Step Workflow (2 Minuten)

---

## ✅ Minute 5–10: Validierung durchführen

**Release Lead:**
```bash
# 1. Gehe ins Projekt-Verzeichnis
cd /Users/aram/Documents/GitHub/Parentpeak

# 2. Starten Validierungs-Skript
./scripts/validate_release.sh
```

**Erwartet Output:**
```
=== Release Validation Summary ===
Results:
  ✅ Passed: 35
  ⚠️  Warnings: 0
  ❌ Failed: 0

🎉 All checks passed! App is ready for release.
```

**Wenn rot/Fehler?** → Stopp. Message hier posten, ich fix es. Dann erneut laufen.

**Wenn grün?** → Weiter zu Schritt 3

---

## 🏗️ Minute 15–35: Builds erzeugen

**Release Lead (oder Build Engineer):**

```bash
# Sauberer Start
flutter clean
flutter pub get

# Android Release bauen (~2 Min)
flutter build apk --release

# iOS Release bauen (~3 Min)
flutter build ios --release
```

**Nach erfolgreich:**

```bash
# Verifiziere Android-Build
ls -lh build/app/outputs/flutter-apk/app-release.apk

# Verifiziere iOS-Build
ls -lh build/ios/ipa/Parentpeak.ipa
```

**Erwartet:**
```
-rw-r--r--  1 aram  staff  98.7M Jun 24 14:23 app-release.apk
-rw-r--r--  1 aram  staff   70.0M Jun 24 14:25 Parentpeak.ipa
```

**✅ Wenn beide Dateien existieren:** Schritt 4

---

## 🧪 Minute 40–60: Smoke Test durchführen

**QA Lead:**

```bash
# Öffne die Smoke-Test-Anleitung
open docs/TESTFLIGHT_SMOKE_TEST.md

# Oder im Terminal:
cat docs/TESTFLIGHT_SMOKE_TEST.md
```

**Schritt 1–8 durchführen** (ca. 15–20 Min):
1. ✅ TestFlight-Build auf Device installieren
2. ✅ Network-Verbindung prüfen
3. ✅ Network-Error triggen (WiFi aus)
4. ✅ Crashlytics-Dashboard öffnen
5. ✅ Error muss dort in 10 Min sichtbar sein
6. ✅ Stack-Trace muss lesbar sein (nicht Hex)
7. ✅ Critical User Flows testen (Auth, Events, Create, Paywall)
8. ✅ Finale Verifizierung

**Nach all 8 Steps grün:**

```bash
# Sign-off Checklist ausfüllen (in TESTFLIGHT_SMOKE_TEST.md)
# Alle Checkboxen müssen ✅ sein
```

---

## 🚢 Minute 70–100: Deploy

### 🍎 iOS zu TestFlight

```bash
# Option A: Via Xcode UI (easiest)
open ios/Runner.xcworkspace

# In Xcode:
# 1. Product → Archive (warte ~2 Min)
# 2. Distribute App → TestFlight → Upload
# 3. Folge Dialog (Select Signing Team, etc.)

# Option B: Via Transporter CLI
open -a Transporter
# Drag & drop: build/ios/ipa/Parentpeak.ipa
```

**Nach Upload:** 5–15 Min warten → TestFlight zeigt neue Build

```bash
# Verifiziere Upload
open https://appstoreconnect.apple.com
# Gehe zu TestFlight → Builds
# Neue Build sollte sichtbar sein
```

---

### 🤖 Android zu Google Play Console

```bash
# Öffne Google Play Console
open https://play.google.com/console

# Dort:
# 1. Wähle App "Parentpeak"
# 2. Klick "Release" (linkes Menu)
# 3. Klick "Create new release"
# 4. Wähle "Internal testing" (first time)
# 5. Upload: build/app/outputs/bundle/release/app-release.aab
#    (ODER: build/app/outputs/flutter-apk/app-release.apk)
# 6. Add Release Notes (copy aus RELEASE_NOTES_v1.0.0.md)
# 7. Review und "Publish"
```

---

## 📊 Minute 100+: Monitor erste 2 Stunden

**DevOps/Monitoring Lead:**

```bash
# Crashlytics Dashboard öffnen
open https://console.firebase.google.com/project/parentpeak/crashlytics

# Prüfe:
# ✅ Keine neuen Crash-Spikes
# ✅ Stack Traces sind lesbar
# ✅ Error count bleibt stabil
```

**Wenn alles grün:**
```bash
# Finales Sign-Off
echo "Release v1.0.0 successfully deployed! 🎉"
```

---

## 🎯 Was machen die verschiedenen Rollen?

| Role | Minute | Task |
|------|--------|------|
| **Release Lead** | 5–10 | `./scripts/validate_release.sh` |
| **Build Eng** | 15–35 | `flutter build apk/ios --release` |
| **QA Lead** | 40–60 | Smoke test (8 steps) |
| **Release Eng** | 70–100 | Upload zu TestFlight/Play Store |
| **DevOps** | 100+ | Monitor Crashlytics |

---

## 🔴 Wenn etwas schiefgeht

### ❌ Validierungs-Skript schlägt fehl

```bash
# Re-run mit verbose output
./scripts/validate_release.sh 2>&1 | tee validation.log

# Poste den Output, ich fix es
```

### ❌ Build schlägt fehl

```bash
# Clean + Rebuild
flutter clean
rm -rf build/
flutter pub get
flutter build apk --release --verbose 2>&1 | tee build.log

# Poste letzten 50 Zeilen von build.log
```

### ❌ Crashlytics-Error erscheint nicht

```bash
# Prüfe Network auf Test-Device
# Prüfe Firebase Project ID stimmt
# Warte volle 15 Min (nicht nur 10)
# Dann erneut checken

# Falls immer noch nicht:
# Siehe: docs/TESTFLIGHT_SMOKE_TEST.md → Troubleshooting
```

### ❌ TestFlight-Upload schlägt fehl

```bash
# Prüfe Apple ID hat Developer Role
# Prüfe Code Signing ist korrekt in Xcode:
open ios/Runner.xcworkspace
# Xcode → Runner → Signing & Capabilities → Verifiziere Team

# Falls immer noch fail:
# Siehe: docs/DEPLOYMENT_AUTOMATION_GUIDE.md → Debugging
```

---

## ✅ End-To-End Checkliste

Kopiere das in dein Ticket/Task-Manager:

```
Release v1.0.0 – Deployment Checklist

□ Minute 1–10: Überblick + Validierung
  □ Team liest QUICK_START_RELEASE.md
  □ ./scripts/validate_release.sh ✅ PASS

□ Minute 15–35: Builds
  □ flutter build apk --release ✅ Success
  □ flutter build ios --release ✅ Success

□ Minute 40–60: QA Smoke Test
  □ Alle 8 Schritte durchgeführt
  □ Sign-off Checklist complete
  □ No show-stoppers found

□ Minute 70–100: Deploy
  □ iOS → TestFlight uploaded
  □ Android → Google Play Console ready
  □ Release notes synced
  □ Team notified

□ Minute 100+: Monitor
  □ Crashlytics dashboard stable (2h)
  □ No unexpected crash spikes
  □ Alerts configured

RESULT: ✅ v1.0.0 LIVE
```

---

## 📞 Fragen? Kommandos nicht klar?

**Am Anfang jeder Stunde:**

Poste hier:
1. Was du gerade machen willst
2. Welcher Schritt das ist
3. Die Fehlermeldung (wenn es eine gibt)

→ Ich helfe sofort

---

## 🚀 Los geht's!

**RIGHT NOW:**

```bash
cd /Users/aram/Documents/GitHub/Parentpeak
./scripts/validate_release.sh
```

**Nach 2 Min wirst du wissen ob alles grün ist.** 

Dann einfach den nächsten Step folgen.

**Es ist alles vorbereitet. Ihr schafft das!** ✅
