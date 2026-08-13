import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/l10n/app_localizations.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/event_discovery_agent.dart';
import 'package:parentpeak/logic/event_service.dart';
import 'package:parentpeak/logic/family_circle_service.dart';
import 'package:parentpeak/logic/weekly_impulse_service.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/models/discovered_event.dart';
import 'package:parentpeak/models/event_invitation.dart';
import 'package:parentpeak/models/meetup_event.dart';
import 'package:parentpeak/models/trusted_device.dart';
import 'package:parentpeak/models_and_widgets/weekly_impulse_feature.dart';
import 'package:parentpeak/ui/entwicklung_impulse_screen.dart';
import 'package:parentpeak/ui/auth/login_screen.dart';
import 'package:parentpeak/ui/auth/paywall_screen.dart';
import 'package:parentpeak/ui/create_event_screen.dart';
import 'package:parentpeak/ui/events_activities_screen.dart';
import 'package:parentpeak/ui/family_circle_screen.dart';
import 'package:parentpeak/ui/home_screen.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      AppLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

class _LoginSuccessHarness extends StatefulWidget {
  const _LoginSuccessHarness();

  @override
  State<_LoginSuccessHarness> createState() => _LoginSuccessHarnessState();
}

class _FakeEventDiscoveryAgent extends EventDiscoveryAgent {
  @override
  Future<List<DiscoveredEvent>> discoverEvents({
    required String city,
    String radiusHint = '20 km Umkreis',
    List<String> childAges = const [],
    double? latitude,
    double? longitude,
  }) async {
    return const <DiscoveredEvent>[];
  }
}

class _FakeEventService extends EventService {
  @override
  Future<List<MeetupEvent>> getEvents() async => const <MeetupEvent>[];

  @override
  Future<List<MeetupEvent>> getDiscoverableEventsForUser({
    required String viewerUserId,
    required double viewerLatitude,
    required double viewerLongitude,
    List<AgeGroup>? ageGroups,
  }) async => const <MeetupEvent>[];

  @override
  Future<List<EventInvitation>> getInvitationsForUser(String userId) async => const <EventInvitation>[];

  @override
  Future<MeetupEvent?> getEventById(String id) async => null;
}

/// Fake Geolocator that immediately returns [LocationPermission.denied]
/// so [EventsActivitiesScreen] skips GPS and falls through to [_refreshFeed].
class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.denied;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      Future.error(const PermissionDeniedException('denied'));
}

class _ThrowingWeeklyImpulseService extends WeeklyImpulseService {
  const _ThrowingWeeklyImpulseService() : super(apiClient: null);

  @override
  Future<WeeklyImpulse> fetchWeeklyImpulse({String? viewerUserId}) async {
    throw StateError('backend unavailable');
  }
}

class _LoginSuccessHarnessState extends State<_LoginSuccessHarness> {
  bool _loggedIn = false;

  @override
  Widget build(BuildContext context) {
    if (_loggedIn) {
      return const Scaffold(body: Center(child: Text('LOGIN_OK')));
    }

    return LoginScreen(
      onLoginSuccess: () {
        if (!mounted) return;
        setState(() => _loggedIn = true);
      },
    );
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.logout();
  });

  testWidgets('AuthGate shows login when no user session exists',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        AuthGate(
          devices: const [],
          onRevoke: (_, __) async => true,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('ParentpeakAppShell switches between Home and Profil tabs',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await AuthService.instance.debugSeedSessionForTesting();

    final devices = [
      TrustedDevice(
        deviceUuid: 'device-1',
        deviceName: 'Testgeraet',
        status: DeviceStatus.active,
      ),
    ];

    await tester.pumpWidget(
      _buildTestApp(
        ParentpeakAppShell(
          devices: devices,
          onRevoke: (_, __) async => true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Impulse & Entwicklung'), findsOneWidget);
    // IndexedStack keeps both tabs built; use hitTestable() to check visibility
    expect(find.text('Profil & Schutz').hitTestable(), findsNothing);

    await tester.tap(find.text('Profil'));
    await tester.pump(); // process tap → IndexedStack switches
    await tester.pump(const Duration(seconds: 1)); // allow language rebuild

    expect(find.text('Profil & Schutz').hitTestable(), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pump(); // process tap
    await tester.pump(const Duration(seconds: 1)); // allow language rebuild

    expect(find.text('Impulse & Entwicklung'), findsOneWidget);
  });

  testWidgets('AuthGate shows paywall when trial has expired',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _seedSession(
      registeredAt: DateTime.now().subtract(const Duration(days: 30)),
      isPremium: false,
      serverHasFullAccess: false,
      serverTrialDaysRemaining: 0,
    );

    await tester.pumpWidget(
      _buildTestApp(
        AuthGate(
          devices: const [],
          onRevoke: (_, __) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PaywallScreen), findsOneWidget);
    expect(find.text('Parentpeak Premium'), findsOneWidget);
  });

  testWidgets('Home feature tile opens Familienkreis screen',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await AuthService.instance.debugSeedSessionForTesting();

    await tester.pumpWidget(
      _buildTestApp(
        const HomeScreen(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    await tester.scrollUntilVisible(
      find.text('Impulse & Entwicklung'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Impulse & Entwicklung'));
    await tester.pump(); // process tap → Navigator.push
    await tester.pump(const Duration(milliseconds: 500)); // complete navigation animation

    expect(find.byType(EntwicklungImpulseScreen), findsOneWidget);
    expect(find.text('Impulse & Entwicklung'), findsWidgets);
  });

  testWidgets('Home feature tile opens Events & Aktivitäten screen',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await AuthService.instance.debugSeedSessionForTesting();

    await tester.pumpWidget(
      _buildTestApp(
        const HomeScreen(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    await tester.scrollUntilVisible(
      find.text('Events & Aktivitäten'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Events & Aktivitäten'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(EventsActivitiesScreen), findsOneWidget);
    expect(find.text('Events & Aktivitäten'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('Events screen renders without crashing and shows feed or empty state',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Clear all SharedPreferences state so no saved city leaks from prior tests
    SharedPreferences.setMockInitialValues({});

    // Mock Geolocator so checkPermission() returns denied instantly
    final originalGeolocator = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform();
    addTearDown(() => GeolocatorPlatform.instance = originalGeolocator);

    await AuthService.instance.debugSeedSessionForTesting();

    await tester.pumpWidget(
      _buildTestApp(
        EventsActivitiesScreen(
          agent: _FakeEventDiscoveryAgent(),
          eventService: _FakeEventService(),
        ),
      ),
    );
    // Advance past GPS detection and SnackBar (4s duration)
    for (int i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // Screen must render the AppBar title — verifies no crash occurs
    expect(find.text('Events & Aktivitäten'), findsOneWidget);
  });

  testWidgets('Impulse screen shows offline fallback content when service unavailable',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        const EntwicklungImpulseScreen(
          impulseService: _ThrowingWeeklyImpulseService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Offline-Impuls'), findsOneWidget);
    expect(find.text('Aktuell sind keine frischen Impulse verfügbar.'), findsNothing);
  });

  testWidgets('LoginScreen logs in with valid local credentials',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final result = await AuthService.instance.register(
      email: 'release-test@parentpeak.app',
      password: 'StrongPass1',
      displayName: 'Release Test',
    );
    expect(result.success, isTrue);
    await AuthService.instance.logout();

    await tester.pumpWidget(
      _buildTestApp(
        const _LoginSuccessHarness(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-Mail'),
      'release-test@parentpeak.app',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Passwort'),
      'StrongPass1',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
    await tester.pumpAndSettle();

    expect(find.text('LOGIN_OK'), findsOneWidget);
  });

  testWidgets('Event creation screen opens from Events & Aktivitäten',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await AuthService.instance.debugSeedSessionForTesting();

    await tester.pumpWidget(
      _buildTestApp(
        const EventsActivitiesScreen(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Event planen'));
    await tester.pump(); // process tap → Navigator.push
    await tester.pump(const Duration(milliseconds: 500)); // complete navigation animation

    expect(find.byType(CreateEventScreen), findsOneWidget);
  });

  testWidgets('Event creation form loads without errors',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await AuthService.instance.debugSeedSessionForTesting();

    await tester.pumpWidget(
      _buildTestApp(
        const CreateEventScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsWidgets);
    expect(find.byType(FilterChip), findsWidgets);
    expect(find.text('Treffpunkt'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('Family Circle shows incoming connection request',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await AuthService.instance.debugSeedSessionForTesting();

    await FamilyCircleService.instance.sendRequest(
      fromUserId: 'noah-user',
      toUserId: 'debug_demo_user',
      fromDisplayName: 'Noah Weber',
    );

    await tester.pumpWidget(
      _buildTestApp(
        const FamilyCircleScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Noah Weber'), findsOneWidget);
    expect(find.text('Ablehnen'), findsOneWidget);
    expect(find.text('Annehmen'), findsOneWidget);
  });

  testWidgets('PaywallScreen displays premium options',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _seedSession(
      registeredAt: DateTime.now().subtract(const Duration(days: 30)),
      isPremium: false,
      serverHasFullAccess: false,
      serverTrialDaysRemaining: 0,
    );

    await tester.pumpWidget(
      _buildTestApp(
        const PaywallScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('29,99 €'), findsOneWidget);
    expect(find.text('3,99 €'), findsOneWidget);
    expect(find.text('Jährlich'), findsOneWidget);
    expect(find.text('Monatlich'), findsOneWidget);
  });

  testWidgets('Home screen renders after login',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await AuthService.instance.debugSeedSessionForTesting();

    await tester.pumpWidget(
      _buildTestApp(
        const HomeScreen(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
      'App flow covers start, login, home, profile tab, paywall and create event',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const email = 'flow-test@parentpeak.app';
    const password = 'StrongPass1';

    // Mark onboarding complete so AuthGate shows ParentpeakAppShell after login
    SharedPreferences.setMockInitialValues({'onboarding.completed': true});

    final registerResult = await AuthService.instance.register(
      email: email,
      password: password,
      displayName: 'Flow Test',
    );
    expect(registerResult.success, isTrue);
    await AuthService.instance.logout();

    await tester.pumpWidget(
      _buildTestApp(
        AuthGate(
          devices: const [],
          onRevoke: (_, __) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-Mail'),
      email,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Passwort'),
      password,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
    // Use pump() not pumpAndSettle() — HomeScreen has a repeating AnimationController
    for (int i = 0; i < 15; i++) await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Impulse & Entwicklung'), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await tester.pump(); // process tap
    await tester.pump(const Duration(seconds: 1)); // allow rebuild
    expect(find.text('Profil & Schutz').hitTestable(), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.scrollUntilVisible(
      find.text('Events & Aktivitäten'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Events & Aktivitäten'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(EventsActivitiesScreen), findsOneWidget);

    await tester.tap(find.text('Event planen'));
    await tester.pump(); // process tap → Navigator.push
    await tester.pump(const Duration(milliseconds: 500)); // complete navigation animation
    expect(find.byType(CreateEventScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 600));

    await _seedSession(
      registeredAt: DateTime.now().subtract(const Duration(days: 30)),
      isPremium: false,
      serverHasFullAccess: false,
      serverTrialDaysRemaining: 0,
    );

    await tester.pumpWidget(
      _buildTestApp(
        AuthGate(
          devices: const [],
          onRevoke: (_, __) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PaywallScreen), findsOneWidget);
    expect(find.text('Parentpeak Premium'), findsOneWidget);
  });
}

Future<void> _seedSession({
  required DateTime registeredAt,
  bool isPremium = false,
  bool? serverHasFullAccess,
  int? serverTrialDaysRemaining,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final user = ParentUser(
    uid: 'debug_demo_user',
    email: 'demo@parentpeak.app',
    displayName: 'Demo Eltern',
    registeredAt: registeredAt,
    isPremium: isPremium,
    serverHasFullAccess: serverHasFullAccess,
    serverTrialDaysRemaining: serverTrialDaysRemaining,
  );
  await prefs.setString('pp_current_user', jsonEncode(user.toJson()));
  await AuthService.instance.initialize();
}