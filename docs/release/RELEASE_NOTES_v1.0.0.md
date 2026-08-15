# Release Notes – Parentpeak v1.0.0

**Release Date:** June 24, 2026  
**Version:** 1.0.0  
**Status:** Production Release

---

## What's New

### 🔍 Error Monitoring & Crash Reporting

**Firebase Crashlytics Integration**
- Centralized error reporting for all uncaught exceptions
- Global error hooks capture Flutter, platform, and zone-level errors
- Release-only reporting (debug/test builds log locally to prevent noise)
- Automatic stack trace symbolication for iOS (with dSYM upload)
- Real-time crash dashboard for monitoring app health

**Silent Error Elimination**
- Systematically replaced empty catch blocks with explicit logging
- Core services now report all caught errors with context
- Better visibility into error patterns for debugging and feature improvement

### 🧪 Comprehensive Test Coverage

**Extended Widget Test Suite**
- 38 total tests (up from 30)
- Coverage of all critical user flows:
  - Authentication (login, registration, trial logic)
  - Home/Profile tab navigation
  - Event discovery and creation
  - Premium paywall and activation
  - Full app-flow scenario (start → login → home → events → create)
- 100% pass rate; zero flaky tests

### 🔐 Hardened Release Path

**Authentication Hardening**
- Local auth fallback disabled in release builds
- Firebase-first authentication enforced in production
- Test/debug paths remain flexible for development
- Session seeding available for deterministic testing

---

## Security Improvements

- ✅ Error reporting disabled in debug builds (prevents accidental cloud logging)
- ✅ Sensitive errors logged locally only in debug mode
- ✅ All error data properly sanitized before cloud transmission
- ✅ No PII or credentials in error reports

---

## Documentation

New deployment and validation guides added:

- **[PRODUCTION_READINESS_REPORT.md](PRODUCTION_READINESS_REPORT.md)** – Full quality gates and go/no-go decision
- **[docs/CRASHLYTICS_RELEASE_CHECKLIST.md](docs/CRASHLYTICS_RELEASE_CHECKLIST.md)** – Step-by-step deployment workflow
- **[docs/TESTFLIGHT_SMOKE_TEST.md](docs/TESTFLIGHT_SMOKE_TEST.md)** – QA validation procedures with sign-off checklist
- **[docs/GITHUB_ISSUES_TEMPLATES.md](docs/GITHUB_ISSUES_TEMPLATES.md)** – Tracked work items for future sprints (SPM plugin upgrades)

---

## Known Issues & Workarounds

### Plugin Deprecation Warnings (Non-Blocking)

**Swift Package Manager Support**
- `printing`, `flutter_tts`, and `mobile_scanner` plugins show SPM warnings
- **Status:** Warning only; apps build and run successfully
- **Action:** Planned for future upgrade sprint (see GitHub issues in [docs/GITHUB_ISSUES_TEMPLATES.md](docs/GITHUB_ISSUES_TEMPLATES.md))
- **Timeline:** Must upgrade before next major Flutter version

**Kotlin Gradle Plugin (KGP) Adoption**
- Some plugins apply KGP directly (flutter_tts, mobile_scanner, share_plus, stripe_android)
- **Status:** Warning only; future deprecation notice
- **Action:** Track plugin releases for KGP-compatible versions

---

## Files Changed in This Release

### New Files
- `lib/logic/error_reporting_service.dart` – Centralized error reporting
- `docs/CRASHLYTICS_RELEASE_CHECKLIST.md` – Deployment checklist
- `docs/TESTFLIGHT_SMOKE_TEST.md` – QA validation guide
- `docs/GITHUB_ISSUES_TEMPLATES.md` – Tracked work items

### Modified Files
- `lib/main.dart` – Global error hooks for crash monitoring
- `pubspec.yaml` – Added firebase_crashlytics dependency
- `test/widget_test.dart` – Extended test suite with async cleanup
- `README.md` – Added Crashlytics section

---

## Performance

### Build Times
- Android Release APK: ~90 seconds
- Flutter Analyze: 4.1 seconds
- Full Test Suite: 2 minutes

### App Size
- Android APK (release): 98.7 MB (with tree-shaken assets)
- iOS IPA (estimated): ~70 MB

---

## Quality Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Tests Passing | 38/38 (100%) | ✅ PASS |
| Code Quality Issues | 0 | ✅ PASS |
| Crashlytics Integration | Configured | ✅ PASS |
| Error Monitoring | Comprehensive | ✅ PASS |
| Auth Release Path | Hardened | ✅ PASS |

---

## Breaking Changes

None. This is a production-ready release with backward-compatible changes.

---

## Migration Guide

No migration required for users or developers. All changes are additive (error monitoring) or internal (test improvements).

---

## Deprecations

No deprecations in this release. However, see "Known Issues & Workarounds" for plugin deprecation warnings (non-breaking).

---

## Testing Notes

### Pre-Release Validation

All critical paths tested and validated:

```bash
# Automated validation
flutter analyze    # ✅ 0 issues
flutter test      # ✅ 38/38 passing

# Manual smoke test (on TestFlight/internal build)
# - See docs/TESTFLIGHT_SMOKE_TEST.md for full procedure
```

### Post-Release Monitoring

- Monitor Crashlytics dashboard for crash spikes in first 24 hours
- Check for error patterns that require immediate hotfixes
- Verify stack traces are properly symbolicated (iOS dSYM upload working)

---

## Next Steps

### For QA Team
1. Execute [docs/TESTFLIGHT_SMOKE_TEST.md](docs/TESTFLIGHT_SMOKE_TEST.md) on TestFlight build
2. Verify Crashlytics dashboard receives test errors within 10 minutes
3. Sign off on release checklist

### For Release Team
1. Build iOS IPA: `flutter build ios --release`
2. Upload to App Store Connect / Google Play Console
3. Follow [docs/CRASHLYTICS_RELEASE_CHECKLIST.md](docs/CRASHLYTICS_RELEASE_CHECKLIST.md) deployment procedure
4. Monitor first 24 hours of production for errors/crashes

### For Future Sprints
- Upgrade SPM plugins (3 issues filed in [docs/GITHUB_ISSUES_TEMPLATES.md](docs/GITHUB_ISSUES_TEMPLATES.md))
- Expand test coverage for family/payment detail flows
- Evaluate advanced crash analytics (Sentry, DataDog)

---

## Contributors

- Engineering Team: Release-readiness hardening, test coverage expansion, error monitoring integration
- QA Team: Validation and smoke testing (pending)

---

## Support

For issues or questions:
- See [PRODUCTION_READINESS_REPORT.md](PRODUCTION_READINESS_REPORT.md) for go/no-go decision
- See [docs/CRASHLYTICS_RELEASE_CHECKLIST.md](docs/CRASHLYTICS_RELEASE_CHECKLIST.md) for deployment help
- See [docs/TESTFLIGHT_SMOKE_TEST.md](docs/TESTFLIGHT_SMOKE_TEST.md) for validation help

---

## Version History

- **v1.0.0** (2026-06-24) – Initial production release with Crashlytics integration and comprehensive test coverage

---

**Ready for production deployment.** ✅
