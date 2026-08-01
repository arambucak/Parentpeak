# Release Preparation Checklist v1.0.0

## 📋 Release Information
- **App Name**: Parentpeak
- **Target Version**: 1.0.0 (Initial Public Release)
- **Build Number**: Auto-increment via script
- **Release Platform**: TestFlight → App Store (iOS), Google Play (Android)
- **Release Timeline**: Immediate after validation

---

## ✅ Pre-Release Checklist

### 1. Version & Build Configuration
- [ ] Update `pubspec.yaml` version to `1.0.0+1`
- [ ] Verify `CFBundleVersion` in `ios/Runner/Info.plist` = `1`
- [ ] Verify `CFBundleShortVersionString` in `ios/Runner/Info.plist` = `1.0.0`
- [ ] Verify Android versionCode in `android/app/build.gradle.kts` = `1`
- [ ] Verify Android versionName in `android/app/build.gradle.kts` = `1.0.0`
- [ ] Update `RELEASE_NOTES_v1.0.0.md` with final changes
- [ ] Verify build number auto-increment strategy

### 2. Code Quality Assurance
- [ ] Run `flutter analyze` - NO ISSUES
- [ ] Run full test suite: `flutter test`
- [ ] Verify all overflow fixes in place (responsive breakpoints <360px)
- [ ] Verify all entrance animations working smoothly (no jank)
- [ ] Check console logs for any warnings/errors in release build
- [ ] Test on iOS simulator (small screen test)
- [ ] Test on Android emulator (small screen test)
- [ ] Test on physical device if available

### 3. iOS Release Build
- [ ] Clean build: `flutter clean && flutter pub get`
- [ ] Build for iOS: `flutter build ios --release`
- [ ] Verify build artifact location: `build/ios/iphoneos/Runner.app`
- [ ] Archive with Xcode:
  ```bash
  cd ios
  xcodebuild -workspace Runner.xcworkspace -scheme Runner \
    -configuration Release -archivePath ../build/ios/Parentpeak.xcarchive \
    archive
  ```
- [ ] Export IPA: Use Xcode or Transporter
- [ ] Verify IPA size (~50-100MB expected)
- [ ] Test on TestFlight beta before App Store submission

### 4. Android Release Build
- [ ] Verify `android/key.properties` contains signing credentials
- [ ] Build AAB for Play Store: `flutter build appbundle --release`
- [ ] Verify AAB artifact: `build/app/outputs/bundle/release/app-release.aab`
- [ ] Optional: Build APK for direct testing: `flutter build apk --release`

### 5. Store Metadata & Assets

#### iOS App Store Connect
- [ ] **App Description** (4000 chars max):
  ```
  Parentpeak – Dein digitales Netzwerk für nachhaltige Elternschaft
  
  Eine Plattform, die Eltern verbindet, unterstützt und gemeinsam stark macht:
  - Eltern-Matching: Finde andere Familien mit ähnlichen Werten
  - Gemeinsam Satt: Teile Essensvorräte und nachhaltiges Kochen
  - Wöchentliche Impulse: Erhalte Evidence-Based Entwicklungstipps
  - Treasure Handover: Nachhaltiger Gegenstände-Tausch
  - Familie & Freunde: Verwalte dein Netzwerk einfach
  ```
- [ ] **Subtitle** (30 chars): "Eltern-Netzwerk für Nachhaltigkeit"
- [ ] **Promotional Text** (170 chars): "Verbinde dich mit anderen Eltern, teile Ressourcen und wachse gemeinsam"
- [ ] **Keywords** (100 chars): "Parenting, Community, Sharing, Nachhaltigkeit, Familie"
- [ ] **Support URL**: App support/contact page
- [ ] **Privacy Policy URL**: Valid privacy policy
- [ ] **Screenshots** (iPhone 6.7" + 5.5"):
  1. Parent Matching screen
  2. Gemeinsam Satt (Meal Sharing)
  3. Family Circle
  4. Weekly Impulses
  5. Treasure Handover (Marketplace)
- [ ] **App Preview Video**: Optional promotional video (15-30s)
- [ ] **Category**: Lifestyle / Parenting
- [ ] **Content Rating**: Complete questionnaire
- [ ] **Age Rating**: 4+

#### Google Play Console
- [ ] Similar metadata as iOS
- [ ] **Short Description**: 80 chars
- [ ] **Full Description**: 4000 chars
- [ ] **Screenshots**: Android phone + tablet versions
- [ ] **Feature Graphic**: 1024x500px
- [ ] **Icon**: 512x512px
- [ ] **Category**: Lifestyle / Parenting

### 6. Permissions & Privacy

#### iOS
- [ ] **Privacy Manifest** (`ios/Runner/PrivacyInfo.xcprivacy`):
  - [ ] Declare all third-party SDKs (Firebase, Stripe, etc.)
  - [ ] Justify data collection usage
  - [ ] Include required reason codes (Apple privacy requirements)

#### Android
- [ ] **AndroidManifest.xml** permissions review:
  - [ ] INTERNET ✓
  - [ ] CAMERA (if image picker enabled) ✓
  - [ ] LOCATION (if map features enabled) ✓
  - [ ] STORAGE ✓
- [ ] **Privacy Policy** linked in metadata

### 7. Security & Compliance
- [ ] Firebase API keys properly scoped (no overpermissioned keys)
- [ ] All secrets removed from code (use .env or Secrets Manager)
- [ ] GDPR compliance verified
- [ ] User data handling documented
- [ ] No hard-coded credentials in binary

### 8. TestFlight Beta Testing
- [ ] Upload build to TestFlight
- [ ] Configure beta testers (minimum 5-10 users recommended)
- [ ] Run smoke tests:
  - [ ] App launches without crashes
  - [ ] User can sign up / log in
  - [ ] Core features (matching, sharing, impulses) work
  - [ ] No overflow issues on small screens
  - [ ] Animations play smoothly
  - [ ] Performance acceptable (<3s for key screens)
- [ ] Collect beta feedback for 48-72 hours
- [ ] Fix critical bugs if any

### 9. App Store Submission (iOS)
- [ ] Complete all metadata (see §5)
- [ ] Build passed TestFlight validation
- [ ] Submit for App Store Review
- [ ] App Review typically takes 24-48 hours
- [ ] Monitor for rejection emails
- [ ] Be prepared for metadata/policy questions

### 10. Google Play Submission (Android)
- [ ] Complete all metadata (see §5)
- [ ] AAB artifact ready
- [ ] Submit to Play Store (may require phone verification)
- [ ] Play Store review typically takes 24 hours
- [ ] Monitor Play Console for approval/rejection

### 11. Post-Release Monitoring
- [ ] Monitor crash reports (Firebase Crashlytics)
- [ ] Monitor performance metrics
- [ ] Respond to user reviews & feedback
- [ ] Be ready with patch releases if critical bugs found

---

## 🔧 Build Command Reference

```bash
# Clean slate
flutter clean && flutter pub get

# Analyze
bash scripts/flutter_repo.sh analyze

# iOS Release
flutter build ios --release
# Or with verbose:
flutter build ios --release -v

# Android Release
flutter build appbundle --release
# Or APK:
flutter build apk --release

# Version bump helper (manual)
# Edit pubspec.yaml: version: X.Y.Z+N
# iOS: Edit CFBundleVersion and CFBundleShortVersionString in Info.plist
# Android: Edit versionCode and versionName in build.gradle.kts

# Archive for TestFlight (Xcode)
cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner \
  -configuration Release -archivePath build/Parentpeak.xcarchive archive
```

---

## 📱 Screen Compatibility Verification

### Small Screen Test (< 360px width)
- [ ] iPhone SE (375px) - Main test device
- [ ] Small Android phone simulator
- [ ] Verify no text overflow in:
  - [ ] Parent Matching screen (AppBar title, stat pills, buttons)
  - [ ] Family Circle (member cards)
  - [ ] Marketplace (product cards)
  - [ ] Weekly Planner (meal plan items)

### Performance Benchmarks
- [ ] App startup time: < 2.5 seconds (cold)
- [ ] Screen transitions: Smooth 60fps
- [ ] List scroll performance: 60fps on main feed
- [ ] Animation frame rate: Consistent (entrance animations shouldn't jank)

---

## 📝 Release Announcement
- [ ] Prepare release notes for:
  - [ ] GitHub releases
  - [ ] Product website
  - [ ] Social media (Twitter, LinkedIn, etc.)
- [ ] Coordinate launch timing (optimal release window)
- [ ] Prepare press/community outreach if applicable

---

## 🚀 Go/No-Go Decision Criteria

**GO if:**
- ✅ All analyzer checks pass
- ✅ TestFlight beta passed without critical crashes
- ✅ All small-screen tests pass (< 360px)
- ✅ Performance benchmarks met
- ✅ All metadata complete and accurate

**NO-GO if:**
- ❌ Crashes on startup or in core flows
- ❌ Significant visual overflow on small screens
- ❌ Animations cause jank (dropped frames)
- ❌ Privacy/security concerns unresolved
- ❌ Metadata incomplete or misleading

---

**Last Updated**: 2026-07-19
**Release Manager**: [Your Name]
**Status**: Ready for Execution
