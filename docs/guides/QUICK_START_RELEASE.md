# Quick Start: Release Parentpeak v1.0.0

**5-Minute Overview for Release Team**

---

## 🎯 You Are Here

✅ Code is production-ready  
✅ Tests all pass (38/38)  
✅ Error monitoring configured  
✅ Documentation complete  

**Next:** Execute the release workflow

---

## 📋 The 3-Step Release Process

### Step 1: Validate (5 minutes)

```bash
cd /path/to/Parentpeak
./scripts/validate_release.sh
```

**Expected Output:**
```
🎉 All checks passed! App is ready for release.
```

**If it fails:** Stop and fix issues. Re-run until all pass.

---

### Step 2: Build & Test (20 minutes)

```bash
# Build releases
flutter build apk --release
flutter build ios --release

# Run smoke test (manual)
# See: docs/TESTFLIGHT_SMOKE_TEST.md
```

**Expected Outcome:**
- ✅ Android APK built (build/app/outputs/flutter-apk/app-release.apk)
- ✅ iOS IPA built (build/ios/ipa/Parentpeak.ipa)
- ✅ Smoke test passes (all 8 steps)

---

### Step 3: Deploy (30 minutes)

**iOS:**
```bash
# Upload to TestFlight
open https://appstoreconnect.apple.com
# (Use Xcode or Transporter to upload the IPA)
```

**Android:**
```bash
# Upload to Google Play Console
open https://play.google.com/console
# (Upload the AAB file)
```

**Expected Outcome:**
- ✅ TestFlight shows new build in 5-15 minutes
- ✅ Google Play shows new release pending review

---

## 📚 Key Documents

| Document | Purpose | When to Read |
|----------|---------|--------------|
| [RELEASE_NOTES_v1.0.0.md](RELEASE_NOTES_v1.0.0.md) | What's new in this release | Before deployment |
| [PRODUCTION_READINESS_REPORT.md](PRODUCTION_READINESS_REPORT.md) | Go/no-go decision | Before starting |
| [docs/TESTFLIGHT_SMOKE_TEST.md](docs/TESTFLIGHT_SMOKE_TEST.md) | How to validate on device | During Step 2 |
| [docs/CRASHLYTICS_RELEASE_CHECKLIST.md](docs/CRASHLYTICS_RELEASE_CHECKLIST.md) | Deployment details | During Step 3 |
| [docs/DEPLOYMENT_AUTOMATION_GUIDE.md](docs/DEPLOYMENT_AUTOMATION_GUIDE.md) | Full automation reference | For troubleshooting |

---

## ⚡ Common Commands

```bash
# Run all validation checks
./scripts/validate_release.sh

# Build Android
flutter build apk --release

# Build iOS
flutter build ios --release

# Check code quality
flutter analyze

# Run tests
flutter test

# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --release
```

---

## 🚨 If Something Goes Wrong

### Error: Tests fail

```bash
flutter test --verbose
# Fix the failing test, then re-run
```

### Error: Code quality issues

```bash
flutter analyze
# Review and fix the issues
```

### Error: Build fails

```bash
flutter clean
flutter pub get
flutter build apk --release --verbose
# Check the verbose output for the specific error
```

### Error: Firebase dSYM upload fails

See [docs/DEPLOYMENT_AUTOMATION_GUIDE.md](docs/DEPLOYMENT_AUTOMATION_GUIDE.md) section "Debugging Failed Automation → Crashlytics dSYM Upload Fails"

---

## ✅ Sign-Off Checklist

Before you mark this release as done:

- [ ] `./scripts/validate_release.sh` passes
- [ ] Build artifacts created (APK + IPA)
- [ ] Smoke test steps 1-8 all pass
- [ ] Crashlytics dashboard shows test error within 10 min
- [ ] TestFlight build deployed to testers
- [ ] Android build ready for Play Console
- [ ] No unexpected crash spikes in first 2 hours
- [ ] All team members notified of release

---

## 📞 Support

**Questions about release process?**
- See [docs/DEPLOYMENT_AUTOMATION_GUIDE.md](docs/DEPLOYMENT_AUTOMATION_GUIDE.md)

**Questions about code quality?**
- See [PRODUCTION_READINESS_REPORT.md](PRODUCTION_READINESS_REPORT.md)

**Questions about testing?**
- See [docs/TESTFLIGHT_SMOKE_TEST.md](docs/TESTFLIGHT_SMOKE_TEST.md)

---

## 🚀 You Got This!

The app is production-ready. Follow the 3 steps and you're done.

Good luck! 🎉
