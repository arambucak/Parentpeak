import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:parentpeak/firebase_options.dart';

class ErrorReportingService {
  ErrorReportingService._();

  static final ErrorReportingService instance = ErrorReportingService._();

  static const bool _enableCrashlyticsInDebug =
      bool.fromEnvironment('PP_ENABLE_CRASHLYTICS_DEBUG', defaultValue: false);

  bool _initialized = false;
  bool _crashlyticsReady = false;

  bool get isCrashlyticsReady => _crashlyticsReady;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb) {
      debugPrint('ErrorReportingService: Crashlytics is not supported on web.');
      return;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      debugPrint(
          'ErrorReportingService: Crashlytics is disabled on macOS debug builds.');
      return;
    }

    if (kIsWeb) {
      debugPrint('ErrorReportingService: Crashlytics is not supported on web.');
      return;
    }

    try {
      await _initializeFirebaseIfNeeded();
    } catch (e, st) {
      debugPrint(
          'ErrorReportingService.initialize(): Firebase init failed: $e');
      debugPrint(st.toString());
      return;
    }

    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
          kReleaseMode || _enableCrashlyticsInDebug);
      await FirebaseCrashlytics.instance
          .setCustomKey('build_mode', kReleaseMode ? 'release' : 'debug');
      _crashlyticsReady = true;
    } catch (e, st) {
      debugPrint(
          'ErrorReportingService.initialize(): Crashlytics unavailable: $e');
      debugPrint(st.toString());
      _crashlyticsReady = false;
    }
  }

  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    required String context,
    bool fatal = false,
  }) async {
    if (!_crashlyticsReady) return;

    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: context,
        fatal: fatal,
      );
    } catch (e) {
      debugPrint('ErrorReportingService.recordError(): failed: $e');
    }
  }

  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    required String context,
    bool fatal = false,
  }) async {
    if (!_crashlyticsReady) return;

    try {
      if (fatal) {
        await FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      } else {
        await FirebaseCrashlytics.instance.recordFlutterError(details);
      }
      await FirebaseCrashlytics.instance.log('FlutterError context: $context');
    } catch (e) {
      debugPrint('ErrorReportingService.recordFlutterError(): failed: $e');
    }
  }

  Future<void> _initializeFirebaseIfNeeded() async {
    if (Firebase.apps.isNotEmpty) return;

    FirebaseOptions? options;
    try {
      options = DefaultFirebaseOptions.currentPlatform;
    } catch (_) {
      options = null;
    }

    if (options != null) {
      await Firebase.initializeApp(options: options);
      return;
    }

    await Firebase.initializeApp();
  }
}
