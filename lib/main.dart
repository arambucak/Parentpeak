import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/logic/revocation_service_impl.dart';
import 'package:parentpeak/logic/secure_storage.dart';
import 'package:parentpeak/logic/background_sync_manager.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/notification_service.dart';
import 'package:parentpeak/logic/error_reporting_service.dart';
import 'package:parentpeak/models/trusted_device.dart';
import 'package:parentpeak/ui/home_screen.dart';
import 'package:parentpeak/ui/profile_safety_screen.dart';
import 'package:parentpeak/ui/treasure_handover_screen.dart';
import 'package:parentpeak/ui/treasure_upload_screen.dart';
import 'package:parentpeak/ui/finance_budget_screen.dart';
import 'package:parentpeak/ui/kettenbrecher_dashboard.dart';
import 'package:parentpeak/ui/auth/login_screen.dart';
import 'package:parentpeak/ui/auth/paywall_screen.dart';
import 'package:parentpeak/ui/onboarding/onboarding_screen.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/config/feature_flags.dart';
import 'package:parentpeak/logic/entitlement_service.dart';
import 'package:parentpeak/logic/theme_service.dart';
import 'package:parentpeak/logic/language_service.dart';
import 'package:parentpeak/widgets/language_aware_widget.dart';
import 'package:parentpeak/l10n/app_localizations.dart';
import 'package:parentpeak/widgets/language_provider.dart';

// Global service instances
final themeService = ThemeService();
final languageService = LanguageService();
// Global key for DemoApp state access
final GlobalKey<DemoAppState> demoAppKey = GlobalKey<DemoAppState>();

// Development shortcut: skips auth gate and opens the app shell directly.
const bool _debugBypassAuthGate =
    bool.fromEnvironment('PP_DEBUG_SKIP_LOGIN', defaultValue: false);
const String _debugStartTab =
    String.fromEnvironment('PP_DEBUG_START_TAB', defaultValue: 'home');

void _reportAppError(String context, Object error, StackTrace stackTrace) {
  debugPrint('AppError[$context]: $error');
  debugPrint(stackTrace.toString());
  unawaited(
    ErrorReportingService.instance.recordError(
      error,
      stackTrace,
      context: context,
      fatal: true,
    ),
  );
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      unawaited(
        ErrorReportingService.instance.recordFlutterError(
          details,
          context: 'FlutterError.onError',
          fatal: true,
        ),
      );
      _reportAppError(
        'FlutterError.onError',
        details.exception,
        details.stack ?? StackTrace.current,
      );
    };
    PlatformDispatcher.instance.onError =
        (Object error, StackTrace stackTrace) {
      _reportAppError('PlatformDispatcher.onError', error, stackTrace);
      return true;
    };

    await _startApp();
  }, (Object error, StackTrace stackTrace) {
    _reportAppError('runZonedGuarded', error, stackTrace);
  });
}

Future<void> _startApp() async {
  final startupInviteInput = _extractStartupInviteInput();
  await APIConfig.ensureRuntimeEnvLoaded();
  final hasDotEnv = await _loadOptionalDotEnv();
  await APIConfig.ensureRuntimeEnvLoaded();
  debugPrint('Gemini runtime model: ${APIConfig.getGeminiModelName()}');
  debugPrint('Gemini API configured: ${APIConfig.isGeminiApiKeyConfigured()}');

  final missingSecrets = APIConfig.getMissingRequiredSecrets();
  final releaseConfigIssues = APIConfig.getReleaseConfigIssues();
  const isBlockingReleaseConfig = kReleaseMode && !kIsWeb;

  if (isBlockingReleaseConfig && missingSecrets.isNotEmpty) {
    throw StateError(
        'Fehlende Pflicht-Secrets für Release: ${missingSecrets.join(', ')}');
  }
  if (isBlockingReleaseConfig && releaseConfigIssues.isNotEmpty) {
    throw StateError(
        'Unsichere Release-Konfiguration: ${releaseConfigIssues.join('; ')}');
  }
  if (kReleaseMode && kIsWeb && missingSecrets.isNotEmpty) {
    debugPrint(
      'Web Release Hinweis: Secrets fehlen (${missingSecrets.join(', ')}). Features werden ggf. deaktiviert.',
    );
  }
  if (kReleaseMode && kIsWeb && releaseConfigIssues.isNotEmpty) {
    debugPrint(
      'Web Release Hinweis: ${releaseConfigIssues.join('; ')}. App startet im degradieren Modus.',
    );
  }
  if (!kReleaseMode && hasDotEnv && missingSecrets.isNotEmpty) {
    debugPrint(
        'Konfigurationshinweis: Fehlende Secrets (${missingSecrets.join(', ')}).');
  }
  if (!kReleaseMode && hasDotEnv && releaseConfigIssues.isNotEmpty) {
    debugPrint('Konfigurationshinweis: ${releaseConfigIssues.join('; ')}');
  }

  await ErrorReportingService.instance.initialize();

  await BackgroundSyncManager.initialize();
  if (!kIsWeb) {
    await NotificationService.instance.initialize();
  }
  await AuthService.instance.initialize();
  await FeatureFlagService.instance.initialize();
  await EntitlementService.instance.initialize();

  // Stripe publishable key (from .env or compile-time dart-define).
  final stripeKey = APIConfig.getStripePublishableKey()?.trim();
  final stripeSupported = APIConfig.isStripePaymentSheetSupportedPlatform();
  if (!kIsWeb &&
      stripeSupported &&
      APIConfig.isStripePublishableKeyConfigured()) {
    try {
      Stripe.publishableKey = stripeKey!;
      await Stripe.instance.applySettings();
    } catch (e) {
      debugPrint('Warnung: Stripe konnte nicht initialisiert werden: $e');
    }
  }

  // Wire FCM push notifications for the already-authenticated user.
  final currentUser = AuthService.instance.currentUser;
  if (currentUser != null && !kIsWeb) {
    final apiClient = BackendServiceFactory.createApiClient();
    unawaited(
      NotificationService.instance.initFcm(
        apiClient: apiClient,
        userId: currentUser.uid,
      ),
    );
  }

  runApp(DemoApp(
    key: demoAppKey,
    startupInviteInput: startupInviteInput,
  ));
}

Future<bool> _loadOptionalDotEnv() async {
  // Web deployments (e.g. GitHub Pages) do not ship a root .env asset.
  if (kIsWeb) {
    debugPrint('dotenv: skipped on web');
    return false;
  }

  try {
    await dotenv.load(fileName: '.env', isOptional: true);
    final hasGemini = (dotenv.env['GEMINI_API_KEY'] ?? '').trim().isNotEmpty;
    final hasAny = dotenv.env.isNotEmpty;
    debugPrint(
      'dotenv: loaded=$hasAny, geminiKeyPresent=$hasGemini, keyCount=${dotenv.env.length}',
    );
    return hasAny;
  } catch (e) {
    debugPrint('Warnung: .env konnte nicht geladen werden: $e');
    return false;
  }
}

String? _extractStartupInviteInput() {
  // Support app-start deep links via route name (mobile) and base URI (web/desktop).
  final candidates = <String>[
    WidgetsBinding.instance.platformDispatcher.defaultRouteName,
    Uri.base.toString(),
  ];

  for (final candidate in candidates) {
    final parsed = _extractInviteInputFromString(candidate);
    if (parsed != null) return parsed;
  }

  return null;
}

String? _extractInviteInputFromString(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final input = raw.trim();

  final uri = Uri.tryParse(input);
  if (uri != null) {
    final code = uri.queryParameters['code']?.trim();
    if (code != null && code.isNotEmpty) {
      return code;
    }
  }

  final codeMatch = RegExp(r'(PP-[A-Za-z0-9]+)').firstMatch(input);
  if (codeMatch != null) {
    return codeMatch.group(1)?.toUpperCase();
  }

  return null;
}

class DemoApp extends StatefulWidget {
  final String? startupInviteInput;

  const DemoApp({super.key, this.startupInviteInput});

  static void setThemeMode(ThemeMode mode) {
    debugPrint('📱 DemoApp.setThemeMode() called with mode=$mode');
    final state = demoAppKey.currentState;
    if (state == null) {
      debugPrint('❌ ERROR: DemoApp state not found via GlobalKey!');
      return;
    }
    state._setThemeMode(mode);
    debugPrint('   setState() called, rebuilding with themeMode=$mode');
  }

  @override
  State<DemoApp> createState() => DemoAppState();
}

class DemoAppState extends State<DemoApp> with WidgetsBindingObserver {
  late ThemeMode _currentThemeMode;

  @override
  void initState() {
    super.initState();
    themeService.addListener(_onThemeChanged);
    languageService.addListener(_onLanguageChanged);
    // Reset to light mode first, then initialize from preferences
    _currentThemeMode = ThemeMode.light;
    debugPrint('✅ App starting with Light Mode');
    // Initialize theme from SharedPreferences
    themeService.initialize().then((_) {
      if (mounted) {
        setState(() {
          _currentThemeMode =
              themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light;
          debugPrint(
              '✅ Theme initialized: isDarkMode=${themeService.isDarkMode}, _currentThemeMode=$_currentThemeMode');
        });
      }
    });
  }

  @override
  void dispose() {
    themeService.removeListener(_onThemeChanged);
    languageService.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      debugPrint('🔄 _onThemeChanged() called');
      debugPrint('   isDarkMode=${themeService.isDarkMode}');
      debugPrint('   OLD _currentThemeMode=$_currentThemeMode');
      setState(() {
        _currentThemeMode =
            themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light;
        debugPrint('   NEW _currentThemeMode=$_currentThemeMode');
      });
    }
  }

  void _onLanguageChanged() {
    if (mounted) {
      debugPrint(
          '🔄 _onLanguageChanged() called: currentLanguage=${languageService.currentLanguage}');
      setState(() {
        // Erzwinge einen Rebuild wenn die Sprache wechselt
      });
    }
  }

  void _setThemeMode(ThemeMode mode) {
    if (!mounted) return;
    setState(() {
      _currentThemeMode = mode;
      debugPrint('   Set _currentThemeMode=$mode inside setState()');
    });
  }

  @override
  Widget build(BuildContext context) {
    final backendBaseUrl = APIConfig.getBackendBaseUrl() ?? '';
    const storage = FlutterSecureStorageAdapter();
    final service =
        RevocationServiceImpl(baseUrl: backendBaseUrl, secureStorage: storage);

    return MaterialApp(
      title: 'Parentpeak',
      theme: themeService.getLightTheme(),
      darkTheme: themeService.getDarkTheme(),
      themeMode: _currentThemeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: LanguageProviderWrapper(
        child: AuthGate(
          devices: const [],
          startupInviteInput: widget.startupInviteInput,
          onRevoke: (uuid, name) async {
            try {
              return await service.revokeDevice(uuid, 'Revoke');
            } catch (e) {
              return false;
            }
          },
        ),
      ),
    );
  }
}

class ParentpeakAppShell extends StatefulWidget {
  final List<TrustedDevice> devices;
  final Future<bool> Function(String deviceUuid, String deviceName) onRevoke;
  final String? startupInviteInput;

  const ParentpeakAppShell(
      {super.key,
      required this.devices,
      required this.onRevoke,
      this.startupInviteInput});

  @override
  State<ParentpeakAppShell> createState() => _ParentpeakAppShellState();
}

class _ParentpeakAppShellState extends State<ParentpeakAppShell> {
  int _index = _debugStartTab == 'family' ? 1 : 0;

  @override
  void initState() {
    super.initState();
    languageService.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    languageService.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) {
      debugPrint(
          '🌍 Sprache geändert in ParentpeakAppShell - erzwinge Rebuild aller Screens');
      setState(() {
        // Erzwinge einen Rebuild aller Tabs
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final tabs = <Widget>[
      LanguageAwareWidget(
        key: ValueKey('home-${languageService.currentLanguage}'),
        child: HomeScreen(initialInviteInput: widget.startupInviteInput),
      ),
      LanguageAwareWidget(
          key: ValueKey('family-${languageService.currentLanguage}'),
          child: ProfileSafetyScreen(
            devices: widget.devices,
            onRevoke: widget.onRevoke,
            onBack: () => setState(() => _index = 0),
          )),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: theme.colorScheme.primaryContainer,
          labelTextStyle: WidgetStateProperty.all(
            theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (index) => setState(() => _index = index),
          height: 76,
          backgroundColor: theme.colorScheme.surface,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.nest_cam_wired_stand_outlined),
              selectedIcon: Icon(Icons.nest_cam_wired_stand_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── AuthGate ─────────────────────────────────────────────────────────────────
// Entscheidet beim App-Start: Login, Paywall oder Haupt-App

class AuthGate extends StatefulWidget {
  final List<TrustedDevice> devices;
  final Future<bool> Function(String, String) onRevoke;
  final String? startupInviteInput;

  const AuthGate({
    super.key,
    required this.devices,
    required this.onRevoke,
    this.startupInviteInput,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isRefreshingEntitlements = false;
  bool? _onboardingCompleted;

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_refresh);
    _syncEntitlements();
    _checkOnboarding();
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _checkOnboarding() async {
    final completed = await OnboardingScreen.isCompleted();
    if (mounted) {
      setState(() => _onboardingCompleted = completed);
    }
  }

  Future<void> _syncEntitlements() async {
    if (_isRefreshingEntitlements) return;
    _isRefreshingEntitlements = true;
    try {
      await AuthService.instance.refreshEntitlements();
    } finally {
      _isRefreshingEntitlements = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  bool get _allowWebQueryBypass {
    if (!kIsWeb || kReleaseMode) return false;
    final value = Uri.base.queryParameters['pp_debug_skip_login']?.trim();
    return value == '1' || value?.toLowerCase() == 'true';
  }

  String? get _debugScreen {
    if (!_allowWebQueryBypass) return null;
    final value =
        Uri.base.queryParameters['pp_debug_screen']?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
    _syncEntitlements();
  }

  @override
  Widget build(BuildContext context) {
    if ((_debugBypassAuthGate || _allowWebQueryBypass) && kDebugMode) {
      final debugScreen = _debugScreen;
      if (debugScreen != null) {
        switch (debugScreen) {
          case 'treasure_handover':
            return const TreasureHandoverScreen();
          case 'treasure_upload':
            return const TreasureUploadScreen();
          case 'finance':
            return const FinanceBudgetScreen();
          case 'kettenbrecher':
            return const KettenbrecherDashboard();
          case 'home':
            break;
          default:
            break;
        }
      }

      // Auch im Debug-Modus Onboarding zeigen wenn noch nicht abgeschlossen
      if (_onboardingCompleted == false) {
        return OnboardingScreen(
          onComplete: () {
            setState(() => _onboardingCompleted = true);
          },
        );
      }

      return ParentpeakAppShell(
        devices: widget.devices,
        onRevoke: widget.onRevoke,
        startupInviteInput: widget.startupInviteInput,
      );
    }

    final user = AuthService.instance.currentUser;

    // Nicht eingeloggt → Login
    if (user == null) {
      return LoginScreen(
        onLoginSuccess: _refresh,
      );
    }

    // Trial abgelaufen & kein Premium → Paywall
    if (!user.hasFullAccess) {
      return PaywallScreen(
        onSubscribed: () {
          _refresh();
        },
      );
    }

    // Onboarding noch nicht abgeschlossen → Onboarding zeigen
    if (_onboardingCompleted == false) {
      return OnboardingScreen(
        onComplete: () {
          setState(() => _onboardingCompleted = true);
        },
      );
    }

    // Eingeloggt & Zugang vorhanden → Haupt-App
    return ParentpeakAppShell(
      devices: widget.devices,
      onRevoke: widget.onRevoke,
      startupInviteInput: widget.startupInviteInput,
    );
  }
}
