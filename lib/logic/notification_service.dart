import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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
  bool _handledLocalLaunch = false;
  NotificationTapHandler? _onNotificationTap;
  int _sessionGeneration = 0;
  String? _sessionOwner;
  BackendApiClient? _sessionApiClient;
  late final _binding = NotificationAccountBinding(
    currentUserId: () =>
        Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser?.uid,
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
    // Echte Gerätezeitzone verwenden, damit Erinnerungen weltweit zur
    // richtigen lokalen Uhrzeit feuern (vorher hart Europe/Berlin → für
    // Eltern in AT/CH/TR/GB verschoben). Berlin bleibt sicherer Fallback.
    var timeZoneName = 'Europe/Berlin';
    try {
      final deviceTz = await FlutterTimezone.getLocalTimezone();
      if (deviceTz.trim().isNotEmpty) timeZoneName = deviceTz.trim();
    } catch (error) {
      _logIgnoredError('NotificationService: Gerätezeitzone unlesbar', error);
    }
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (error) {
      _logIgnoredError(
          'NotificationService: Zeitzone "$timeZoneName" unbekannt', error);
      tz.setLocalLocation(tz.getLocation('Europe/Berlin'));
    }

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
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        _handleLocalNotificationPayload(response.payload);
      },
    );

    if (_isRunningOnIOSSimulator) {
      _initialized = true;
      return;
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    // Android 13+: Laufzeit-Erlaubnis für Benachrichtigungen. Ohne sie wird
    // nichts angezeigt, egal wie gut geplant.
    await android?.requestNotificationsPermission();
    // Android 12+: Erlaubnis für exakte Alarme, damit Erinnerungen pünktlich
    // feuern. Verweigert der Nutzer, fällt zonedSchedule auf inexakt zurück
    // (siehe _resolveAndroidScheduleMode) — die App funktioniert weiter.
    try {
      await android?.requestExactAlarmsPermission();
    } catch (error) {
      _logIgnoredError('NotificationService: Exact-Alarm-Permission', error);
    }
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      'parentpeak_events',
      'Terminerinnerungen',
      description: 'Erinnerungen für Familienkalender',
      importance: Importance.high,
    ));

    _initialized = true;
  }

  /// Wählt den Android-Alarmmodus: exakt, wenn erlaubt; sonst inexakt (statt
  /// stiller Fehlschlag). So überlebt die Erinnerung auch ohne Exact-Alarm-
  /// Erlaubnis, nur ggf. etwas ungenauer.
  Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final canExact = await android?.canScheduleExactNotifications();
      return canExact == false
          ? AndroidScheduleMode.inexactAllowWhileIdle
          : AndroidScheduleMode.exactAllowWhileIdle;
    } catch (error) {
      _logIgnoredError('NotificationService: Exact-Alarm-Check', error);
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  /// Wire up FCM: request permission, get token, register with backend,
  /// and handle foreground messages as local notifications.
  Future<void> initFcm({
    BackendApiClient? apiClient,
    String? userId,
    NotificationTapHandler? onNotificationTap,
  }) async {
    _onNotificationTap = onNotificationTap ?? _onNotificationTap;
    if (kIsWeb ||
        apiClient == null ||
        userId == null ||
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
      if (_sessionOwner != userId ||
          _sessionGeneration != generation ||
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
        throw StateError(
            'A Firebase token is required for notification binding');
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
          if (!_binding
              .acceptsMessage(message.data['accountUserId'] as String?)) {
            return;
          }
          final notification = message.notification;
          if (notification != null) {
            showLocalNotification(
              title: notification.title ?? 'Parentpeak',
              body: notification.body ?? '',
              data: message.data,
            );
          }
        });
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          if (!_binding
              .acceptsMessage(message.data['accountUserId'] as String?)) {
            return;
          }
          _onNotificationTap?.call(message.data);
        });
      }
      final initialMessage = await messaging.getInitialMessage();
      requireSession();
      if (initialMessage != null &&
          _binding.acceptsMessage(
              initialMessage.data['accountUserId'] as String?)) {
        _onNotificationTap?.call(initialMessage.data);
      }
      if (!_handledLocalLaunch) {
        _handledLocalLaunch = true;
        final localLaunch = await _plugin.getNotificationAppLaunchDetails();
        requireSession();
        if (localLaunch?.didNotificationLaunchApp == true) {
          _handleLocalNotificationPayload(
              localLaunch?.notificationResponse?.payload);
        }
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
    await _binding.refresh(token,
        client: BackendApiClient(
          baseUrl: api.baseUrl,
          authToken: idToken,
        ));
  }

  /// Display an immediate local notification (no scheduling).
  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (kIsWeb) return;
    final generation = _sessionGeneration;
    final prefs = await SharedPreferences.getInstance();
    if (generation != _sessionGeneration) return;
    if (prefs.getBool('ritual_ruhe.quiet_mode') == true &&
        data?['type'] != 'moderation_report') {
      return;
    }
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
      payload: data == null ? null : jsonEncode(data),
    );
    if (generation != _sessionGeneration) await _plugin.cancelAll();
  }

  void _handleLocalNotificationPayload(String? payload) {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload);
      if (data is! Map<String, dynamic> || data['accountUserId'] is! String) {
        debugPrint('Notification payload missing account owner');
        return;
      }
      if (_binding.acceptsMessage(data['accountUserId'] as String)) {
        _onNotificationTap?.call(data);
      }
    } on FormatException catch (error) {
      _logIgnoredError('Notification payload invalid', error);
    }
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
    final scheduleMode = await _resolveAndroidScheduleMode();
    if (generation != _sessionGeneration) return;

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
      androidScheduleMode: scheduleMode,
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
    final scheduleMode = await _resolveAndroidScheduleMode();
    if (generation != _sessionGeneration) return;

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
      androidScheduleMode: scheduleMode,
    );
    if (generation != _sessionGeneration) await _plugin.cancelAll();
  }

  /// Reine, testbare Berechnung der "Smart"-Erinnerungszeitpunkte:
  /// 1 Woche vorher, 1 Tag vorher und zum Termin. Nur Zeitpunkte in der
  /// Zukunft (relativ zu [now]) werden zurückgegeben — vergangene (z. B. die
  /// "1 Woche vorher"-Erinnerung bei einem kurzfristig angelegten Termin)
  /// fallen bewusst weg.
  static List<({String key, DateTime when})> smartReminderTimes(
    DateTime eventStart, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final candidates = <({String key, DateTime when})>[
      (key: 'week_before', when: eventStart.subtract(const Duration(days: 7))),
      (key: 'day_before', when: eventStart.subtract(const Duration(days: 1))),
      (key: 'event_day', when: eventStart),
    ];
    return [
      for (final c in candidates)
        if (c.when.isAfter(reference)) c,
    ];
  }

  Future<void> scheduleStandardCalendarReminders({
    required String eventId,
    required DateTime eventStart,
    required String title,
    required String body,
  }) async {
    final generation = _sessionGeneration;
    final entries = smartReminderTimes(eventStart);

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
