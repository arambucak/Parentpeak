import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/notification_account_binding.dart';

typedef NotificationTapHandler = void Function(Map<String, dynamic> data);

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static void _logIgnoredError(String context, Object error) {
    debugPrint('$context: $error');
  }

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _fcmListenersRegistered = false;
  NotificationTapHandler? _onNotificationTap;
  int _sessionGeneration = 0;
  String? _sessionOwner;
  BackendApiClient? _sessionApiClient;
  late final _binding = NotificationAccountBinding(
    currentUserId: () => Firebase.apps.isEmpty
        ? null : FirebaseAuth.instance.currentUser?.uid,
    getToken: () async => kIsWeb ? null : FirebaseMessaging.instance.getToken(),
    deleteToken: () async {
      if (!kIsWeb && Firebase.apps.isNotEmpty) {
        await FirebaseMessaging.instance.deleteToken();
      }
    },
    cancelReminders: () async {
      if (!kIsWeb && _initialized) await _plugin.cancelAll();
    },
  );

  bool get _isRunningOnIOSSimulator {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;
    return false; // Cannot detect simulator on web-safe code
  }

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Berlin'));

    if (kDebugMode && defaultTargetPlatform == TargetPlatform.iOS) {
      _initialized = true;
      return;
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosInit = DarwinInitializationSettings(
      requestAlertPermission: !_isRunningOnIOSSimulator,
      requestBadgePermission: !_isRunningOnIOSSimulator,
      requestSoundPermission: !_isRunningOnIOSSimulator,
    );
    final settings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      macOS: iosInit,
    );
    await _plugin.initialize(settings: settings);

    if (_isRunningOnIOSSimulator) {
      _initialized = true;
      return;
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      'parentpeak_events',
      'Terminerinnerungen',
      description: 'Erinnerungen für Familienkalender',
      importance: Importance.high,
    ));

    _initialized = true;
  }

  /// Wire up FCM: request permission, get token, register with backend,
  /// and handle foreground messages as local notifications.
  Future<void> initFcm({
    BackendApiClient? apiClient,
    String? userId,
    NotificationTapHandler? onNotificationTap,
  }) async {
    _onNotificationTap = onNotificationTap ?? _onNotificationTap;
    if (kIsWeb || apiClient == null || userId == null ||
        Firebase.apps.isEmpty ||
        FirebaseAuth.instance.currentUser?.uid != userId) {
      return;
    }
    _sessionApiClient = apiClient;
    if (_sessionOwner != userId) {
      _sessionOwner = userId;
      _sessionGeneration++;
    }
    final generation = _sessionGeneration;
    void requireSession() {
      if (_sessionOwner != userId || _sessionGeneration != generation ||
          FirebaseAuth.instance.currentUser?.uid != userId) {
        throw const NotificationAccountChanged();
      }
    }
    if (kDebugMode && !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return; // Skip on iOS Simulator in debug
    }

    if (!kIsWeb && _isRunningOnIOSSimulator) {
      return;
    }

    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      requireSession();
      final idToken = await FirebaseAuth.instance.currentUser!.getIdToken();
      requireSession();
      if (idToken == null || idToken.isEmpty) {
        throw StateError('A Firebase token is required for notification binding');
      }
      // Retain the originating credential for deregistration after a UID switch,
      // never resolve a new account's credential for an old account's DELETE.
      final ownerClient = BackendApiClient(
        baseUrl: apiClient.baseUrl,
        authToken: idToken,
      );
      await _binding.bind(userId, ownerClient);
      requireSession();

      if (!_fcmListenersRegistered) {
        _fcmListenersRegistered = true;
        // Re-register whenever the token is refreshed.
        messaging.onTokenRefresh.listen((newToken) async {
          try {
            await _refreshAccountToken(newToken);
          } catch (e) {
            _logIgnoredError('Notification token refresh failed', e);
          }
        });

        // Show foreground FCM messages as local notifications.
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (!_binding.acceptsMessage(message.data['accountUserId'] as String?)) return;
          final notification = message.notification;
          if (notification != null) {
            showLocalNotification(
              title: notification.title ?? 'Parentpeak',
              body: notification.body ?? '',
            );
          }
        });
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          if (!_binding.acceptsMessage(message.data['accountUserId'] as String?)) return;
          _onNotificationTap?.call(message.data);
        });
      }
      final initialMessage = await messaging.getInitialMessage();
      requireSession();
      if (initialMessage != null &&
          _binding.acceptsMessage(initialMessage.data['accountUserId'] as String?)) {
        _onNotificationTap?.call(initialMessage.data);
      }
    }
  }

  /// Unregister the currently active FCM token on backend (e.g. on logout).
  Future<void> unregisterFcmToken({
    required BackendApiClient apiClient,
    required String userId,
  }) async {
    await endAccountSession();
  }

  Future<void> endAccountSession() async {
    _sessionOwner = null;
    _sessionApiClient = null;
    _sessionGeneration++;
    await _binding.endSession();
  }

  Future<void> _refreshAccountToken(String token) async {
    final owner = _sessionOwner;
    final api = _sessionApiClient;
    final generation = _sessionGeneration;
    final user = FirebaseAuth.instance.currentUser;
    if (owner == null || api == null || user?.uid != owner) return;
    final idToken = await user!.getIdToken();
    if (_sessionGeneration != generation ||
        FirebaseAuth.instance.currentUser?.uid != owner) {
      throw const NotificationAccountChanged();
    }
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Missing Firebase credential for token refresh');
    }
    await _binding.refresh(token, client: BackendApiClient(
      baseUrl: api.baseUrl,
      authToken: idToken,
    ));
  }

  /// Display an immediate local notification (no scheduling).
  Future<void> showLocalNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    final generation = _sessionGeneration;
    final prefs = await SharedPreferences.getInstance();
    if (generation != _sessionGeneration) return;
    if (prefs.getBool('ritual_ruhe.quiet_mode') == true) return;
    const androidDetails = AndroidNotificationDetails(
      'parentpeak_events',
      'Terminerinnerungen',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch % 2147483647,
      title: title,
      body: body,
      notificationDetails:
          const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
    if (generation != _sessionGeneration) await _plugin.cancelAll();
  }

  Future<void> scheduleReminder(
      DateTime when, String title, String body) async {
    if (kIsWeb) return;
    final generation = _sessionGeneration;
    final prefs = await SharedPreferences.getInstance();
    if (generation != _sessionGeneration) return;
    if (prefs.getBool('ritual_ruhe.quiet_mode') == true) return;
    final now = DateTime.now();
    if (when.isBefore(now)) return; // keine Vergangenheit planen
    final tzWhen = tz.TZDateTime.from(when, tz.local);
    final id = when.millisecondsSinceEpoch % 2147483647;

    const androidDetails = AndroidNotificationDetails(
      'parentpeak_events',
      'Terminerinnerungen',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzWhen,
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    if (generation != _sessionGeneration) await _plugin.cancelAll();
  }

  Future<void> scheduleEventReminder({
    required String eventId,
    required DateTime when,
    required String title,
    required String body,
    required String reminderKey,
  }) async {
    if (kIsWeb) return;
    final generation = _sessionGeneration;
    final prefs = await SharedPreferences.getInstance();
    if (generation != _sessionGeneration) return;
    if (prefs.getBool('ritual_ruhe.quiet_mode') == true) return;
    final now = DateTime.now();
    if (when.isBefore(now)) return;

    final id = _stableNotificationId(
        '$eventId|$reminderKey|${when.toIso8601String()}');
    final tzWhen = tz.TZDateTime.from(when, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'parentpeak_events',
      'Terminerinnerungen',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzWhen,
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    if (generation != _sessionGeneration) await _plugin.cancelAll();
  }

  Future<void> scheduleStandardCalendarReminders({
    required String eventId,
    required DateTime eventStart,
    required String title,
    required String body,
  }) async {
    final generation = _sessionGeneration;
    final entries = <({String key, DateTime when})>[
      (key: 'week_before', when: eventStart.subtract(const Duration(days: 7))),
      (key: 'day_before', when: eventStart.subtract(const Duration(days: 1))),
      (key: 'event_day', when: eventStart),
    ];

    for (final entry in entries) {
      if (generation != _sessionGeneration) return;
      await scheduleEventReminder(
        eventId: eventId,
        when: entry.when,
        title: title,
        body: body,
        reminderKey: entry.key,
      );
    }
  }

  int _stableNotificationId(String seed) {
    var hash = 0;
    for (var i = 0; i < seed.length; i++) {
      hash = (hash * 31 + seed.codeUnitAt(i)) & 0x7fffffff;
    }
    if (hash == 0) {
      return 1;
    }
    return hash;
  }
}
