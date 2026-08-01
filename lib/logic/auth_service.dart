/// AuthService – lokale Implementierung, Firebase-ready.
///
/// Architektur:
///   - Alle Methoden sind async und geben typisierte Results zurück.
///   - Passwörter werden NIEMALS im Klartext gespeichert (SHA-256 + Salt).
///   - Firebase Auth kann 1:1 als Drop-in eingesetzt werden (gleiche API).
///   - Trial-Logik: 14 Tage ab Registrierung, dann Paywall.
///
/// Sicherheit:
///   - Passwort-Hashing: SHA-256 mit zufälligem Salt (hex)
///   - Sessions über SharedPreferences (für Prod: flutter_secure_storage)
///   - Input-Sanitierung vor jeder Datenbankoperation

import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/logic/notification_service.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';

// ─── Result-Typen ────────────────────────────────────────────────────────────

enum AuthErrorCode {
  emailAlreadyInUse,
  invalidEmail,
  weakPassword,
  userNotFound,
  wrongPassword,
  tooManyRequests,
  networkError,
  unknown,
}

class AuthResult {
  final bool success;
  final AuthErrorCode? errorCode;
  final String? errorMessage;
  final ParentUser? user;

  const AuthResult._({
    required this.success,
    this.errorCode,
    this.errorMessage,
    this.user,
  });

  factory AuthResult.ok(ParentUser user) =>
      AuthResult._(success: true, user: user);

  factory AuthResult.fail(AuthErrorCode code, String message) =>
      AuthResult._(success: false, errorCode: code, errorMessage: message);
}

// ─── User-Model ──────────────────────────────────────────────────────────────

class ParentUser {
  final String uid;
  final String email;
  final String displayName;
  final DateTime registeredAt;
  final bool isPremium;
  final bool? serverHasFullAccess;
  final int? serverTrialDaysRemaining;

  const ParentUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.registeredAt,
    required this.isPremium,
    this.serverHasFullAccess,
    this.serverTrialDaysRemaining,
  });

  bool get isTrialActive {
    final trialEnd = registeredAt.add(const Duration(days: 14));
    return DateTime.now().isBefore(trialEnd);
  }

  int get trialDaysRemaining {
    if (serverTrialDaysRemaining != null) {
      return serverTrialDaysRemaining! < 0 ? 0 : serverTrialDaysRemaining!;
    }
    final trialEnd = registeredAt.add(const Duration(days: 14));
    final diff = trialEnd.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  bool get hasFullAccess {
    if (isPremium) return true;
    if (serverHasFullAccess != null) return serverHasFullAccess!;
    return isTrialActive;
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'registeredAt': registeredAt.toIso8601String(),
        'isPremium': isPremium,
        'serverHasFullAccess': serverHasFullAccess,
        'serverTrialDaysRemaining': serverTrialDaysRemaining,
      };

  factory ParentUser.fromJson(Map<String, dynamic> j) => ParentUser(
        uid: j['uid'] as String,
        email: j['email'] as String,
        displayName: j['displayName'] as String,
        registeredAt: DateTime.parse(j['registeredAt'] as String),
        isPremium: j['isPremium'] as bool,
        serverHasFullAccess: j['serverHasFullAccess'] as bool?,
        serverTrialDaysRemaining: j['serverTrialDaysRemaining'] as int?,
      );
}

// ─── AuthService ─────────────────────────────────────────────────────────────

class AuthService {
  static const _kUserKey = 'pp_current_user';
  static const _kUserProfilePrefix = 'pp_user_profile_';
  static const _kLocalEmailIndexPrefix = 'pp_local_email_uid_';
  static const _kLocalAuthRecordPrefix = 'pp_local_auth_record_';

  ParentUser? _currentUser;
  ParentUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  bool _firebaseReady = false;
  FirebaseAuth? _firebaseAuth;
  final BackendApiClient? _apiClient = BackendServiceFactory.createApiClient();

  static BackendApiClient? Function() backendApiClientFactory =
      BackendServiceFactory.createApiClient;

  static bool disableFirebaseInitForTesting = false;

  static Future<void> Function({
    required BackendApiClient apiClient,
    required String userId,
  }) fcmUnregisterHandler = _defaultFcmUnregisterHandler;

  // Singleton
  static final AuthService instance = AuthService._();
  AuthService._();

  static void _logIgnoredError(String context, Object error) {
    debugPrint('$context: $error');
  }

  static Future<void> _defaultFcmUnregisterHandler({
    required BackendApiClient apiClient,
    required String userId,
  }) {
    return NotificationService.instance.unregisterFcmToken(
      apiClient: apiClient,
      userId: userId,
    );
  }

  // ── Initialisierung ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    await _tryInitFirebase();

    if (_firebaseReady) {
      final firebaseUser = _firebaseAuth?.currentUser;
      if (firebaseUser != null) {
        _currentUser = await _readOrCreateFirebaseUser(firebaseUser);
        await refreshEntitlements();
      }
      return;
    }

    if (kReleaseMode) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kUserKey);
      _currentUser = null;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUserKey);
    if (raw == null || raw.isEmpty) {
      _currentUser = null;
      return;
    }

    try {
      _currentUser = ParentUser.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      _logIgnoredError('AuthService.initialize(): local session unreadable', e);
      await prefs.remove(_kUserKey);
      _currentUser = null;
    }
  }

  // ── Registrierung ──────────────────────────────────────────────────────────

  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _ensureFirebaseInitChecked();

    if (_firebaseReady) {
      final emailError = _validateEmail(email);
      if (emailError != null) return emailError;

      final passError = _validatePassword(password);
      if (passError != null) return passError;

      final cleanName = displayName.trim();
      if (cleanName.isEmpty) {
        return AuthResult.fail(
            AuthErrorCode.unknown, 'Bitte gib deinen Namen ein.');
      }

      try {
        final auth = _firebaseAuth;
        if (auth == null) {
          if (!kReleaseMode) {
            debugPrint(
              'AuthService.register(): Firebase auth instance missing, using local fallback in debug.',
            );
            return _registerLocal(
              email: email,
              password: password,
              displayName: displayName,
            );
          }
          return AuthResult.fail(
            AuthErrorCode.unknown,
            'Firebase ist nicht verfügbar. Bitte später erneut versuchen.',
          );
        }

        final credential = await auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );

        await credential.user?.updateDisplayName(cleanName);
        final user = await _readOrCreateFirebaseUser(
          credential.user!,
          preferredDisplayName: cleanName,
          forceNewRegisteredAt: true,
        );
        _currentUser = user;
        await refreshEntitlements();
        return AuthResult.ok(user);
      } on FirebaseAuthException catch (e) {
        debugPrint(
          'AuthService.register(): Firebase signup failed. code=${e.code}',
        );
        if (_canUseLocalAuthFallbackForFirebase(e)) {
          debugPrint(
            'AuthService.register(): recoverable Firebase error on debug build, using local fallback. code=${e.code}',
          );
          return _registerLocal(
            email: email,
            password: password,
            displayName: displayName,
          );
        }
        final mapped = _mapFirebaseError(e);
        return mapped;
      } catch (e) {
        _logIgnoredError(
          'AuthService.register(): Firebase signup failed',
          e,
        );
        if (!kReleaseMode) {
          debugPrint(
            'AuthService.register(): unknown Firebase error on debug build, using local fallback.',
          );
          return _registerLocal(
            email: email,
            password: password,
            displayName: displayName,
          );
        }
        return AuthResult.fail(
          AuthErrorCode.unknown,
          'Registrierung ist fehlgeschlagen. Bitte versuche es erneut.',
        );
      }
    }

    if (kReleaseMode) {
      return AuthResult.fail(
        AuthErrorCode.networkError,
        'Login/Registrierung ist derzeit nicht verfuegbar. Bitte spaeter erneut versuchen.',
      );
    }

    return _registerLocal(
      email: email,
      password: password,
      displayName: displayName,
    );
  }

  // ── Login ──────────────────────────────────────────────────────────────────

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    await _ensureFirebaseInitChecked();

    if (_firebaseReady) {
      final emailError = _validateEmail(email);
      if (emailError != null) return emailError;

      if (password.isEmpty) {
        return AuthResult.fail(
            AuthErrorCode.wrongPassword, 'Bitte gib dein Passwort ein.');
      }

      try {
        final auth = _firebaseAuth;
        if (auth == null) {
          if (!kReleaseMode) {
            debugPrint(
              'AuthService.login(): Firebase auth instance missing, using local fallback in debug.',
            );
            return _loginLocal(email: email, password: password);
          }
          return AuthResult.fail(
            AuthErrorCode.unknown,
            'Firebase ist nicht verfügbar. Bitte später erneut versuchen.',
          );
        }

        final credential = await auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );

        final firebaseUser = credential.user;
        if (firebaseUser == null) {
          return AuthResult.fail(
            AuthErrorCode.unknown,
            'Login ist fehlgeschlagen. Bitte versuche es erneut.',
          );
        }

        final user = await _readOrCreateFirebaseUser(firebaseUser);
        _currentUser = user;
        await refreshEntitlements();
        _triggerFcmInit(user.uid);
        return AuthResult.ok(user);
      } on FirebaseAuthException catch (e) {
        debugPrint(
          'AuthService.login(): Firebase login failed. code=${e.code}',
        );
        if (_canUseLocalAuthFallbackForFirebase(e)) {
          debugPrint(
            'AuthService.login(): recoverable Firebase error on debug build, using local fallback. code=${e.code}',
          );
          return _loginLocal(email: email, password: password);
        }
        final mapped = _mapFirebaseError(e);
        return mapped;
      } catch (e) {
        _logIgnoredError(
          'AuthService.login(): Firebase login failed',
          e,
        );
        if (!kReleaseMode) {
          debugPrint(
            'AuthService.login(): unknown Firebase error on debug build, using local fallback.',
          );
          return _loginLocal(email: email, password: password);
        }
        return AuthResult.fail(
          AuthErrorCode.unknown,
          'Login ist fehlgeschlagen. Bitte versuche es erneut.',
        );
      }
    }

    if (kReleaseMode) {
      return AuthResult.fail(
        AuthErrorCode.networkError,
        'Login/Registrierung ist derzeit nicht verfuegbar. Bitte spaeter erneut versuchen.',
      );
    }

    return _loginLocal(email: email, password: password);
  }

  Future<AuthResult> _registerLocal({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final emailError = _validateEmail(email);
    if (emailError != null) return emailError;

    final passError = _validatePassword(password);
    if (passError != null) return passError;

    final cleanName = displayName.trim();
    if (cleanName.isEmpty) {
      return AuthResult.fail(
          AuthErrorCode.unknown, 'Bitte gib deinen Namen ein.');
    }

    final prefs = await SharedPreferences.getInstance();
    final normalizedEmail = _normalizeEmail(email);
    final existingUid = prefs.getString(_localEmailIndexKey(normalizedEmail));
    if (existingUid != null && existingUid.isNotEmpty) {
      return AuthResult.fail(
        AuthErrorCode.emailAlreadyInUse,
        'Diese E-Mail-Adresse ist bereits registriert.',
      );
    }

    final uid = 'local_${DateTime.now().microsecondsSinceEpoch}';
    final salt = _generateSalt();
    final user = ParentUser(
      uid: uid,
      email: normalizedEmail,
      displayName: cleanName,
      registeredAt: DateTime.now(),
      isPremium: false,
    );

    await _persistFirebaseProfile(prefs, user);
    await prefs.setString(_localEmailIndexKey(normalizedEmail), uid);
    await prefs.setString(
      _localAuthRecordKey(uid),
      jsonEncode({
        'salt': salt,
        'hash': _hashPassword(password: password, salt: salt),
      }),
    );
    await _persistSession(prefs, user);
    _currentUser = user;
    return AuthResult.ok(user);
  }

  Future<AuthResult> _loginLocal({
    required String email,
    required String password,
  }) async {

    final emailError = _validateEmail(email);
    if (emailError != null) return emailError;
    if (password.isEmpty) {
      return AuthResult.fail(
          AuthErrorCode.wrongPassword, 'Bitte gib dein Passwort ein.');
    }

    final prefs = await SharedPreferences.getInstance();
    final normalizedEmail = _normalizeEmail(email);
    final uid = prefs.getString(_localEmailIndexKey(normalizedEmail));
    if (uid == null || uid.isEmpty) {
      return AuthResult.fail(
        AuthErrorCode.userNotFound,
        'Kein Konto mit dieser E-Mail-Adresse gefunden.',
      );
    }

    final authRaw = prefs.getString(_localAuthRecordKey(uid));
    if (authRaw == null || authRaw.isEmpty) {
      return AuthResult.fail(
        AuthErrorCode.wrongPassword,
        'E-Mail oder Passwort ist nicht korrekt.',
      );
    }

    try {
      final authMap = jsonDecode(authRaw) as Map<String, dynamic>;
      final salt = (authMap['salt'] ?? '').toString();
      final hash = (authMap['hash'] ?? '').toString();
      if (!_verifyPassword(password: password, salt: salt, expectedHash: hash)) {
        return AuthResult.fail(
          AuthErrorCode.wrongPassword,
          'E-Mail oder Passwort ist nicht korrekt.',
        );
      }

      final profileRaw = prefs.getString('$_kUserProfilePrefix$uid');
      if (profileRaw == null || profileRaw.isEmpty) {
        return AuthResult.fail(
          AuthErrorCode.userNotFound,
          'Kein Konto mit dieser E-Mail-Adresse gefunden.',
        );
      }

      final user = ParentUser.fromJson(
        jsonDecode(profileRaw) as Map<String, dynamic>,
      );
      _currentUser = user;
      await _persistSession(prefs, user);
      _triggerFcmInit(user.uid);
      return AuthResult.ok(user);
    } catch (e) {
      _logIgnoredError('AuthService.login(): local profile/auth unreadable', e);
      return AuthResult.fail(
        AuthErrorCode.unknown,
        'Login ist fehlgeschlagen. Bitte versuche es erneut.',
      );
    }
  }

  bool _canUseLocalAuthFallbackForFirebase(FirebaseAuthException e) {
    if (kReleaseMode) {
      return false;
    }

    const recoverableCodes = {
      'internal-error',
      'network-request-failed',
      'unknown',
      'app-not-authorized',
      'operation-not-allowed',
      'invalid-api-key',
    };
    final normalizedCode = e.code.trim().toLowerCase().replaceAll('_', '-');
    return recoverableCodes.contains(normalizedCode);
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  void _triggerFcmInit(String userId) {
    Future.microtask(() async {
      try {
        final apiClient = backendApiClientFactory();
        await NotificationService.instance.initFcm(
          apiClient: apiClient,
          userId: userId,
        );
      } catch (e) {
        _logIgnoredError('AuthService._triggerFcmInit(): FCM init skipped', e);
      }
    });
  }
  Future<void> logout() async {
    final currentUserId = _currentUser?.uid;
    if (currentUserId != null) {
      try {
        final apiClient = backendApiClientFactory();
        if (apiClient != null) {
          await fcmUnregisterHandler(
            apiClient: apiClient,
            userId: currentUserId,
          );
        }
      } catch (e) {
        _logIgnoredError('AuthService.logout(): FCM unregister skipped', e);
        // Logout should not fail if token unregister fails.
      }
    }

    if (_firebaseReady) {
      final auth = _firebaseAuth;
      if (auth != null) {
        await auth.signOut();
      }
      _currentUser = null;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserKey);
    _currentUser = null;
  }

  @visibleForTesting
  Future<void> debugSeedSessionForTesting() async {
    if (kReleaseMode) {
      return;
    }

    final seededUser = ParentUser(
      uid: 'debug_demo_user',
      email: 'demo@parentpeak.app',
      displayName: 'Demo Eltern',
      registeredAt: DateTime.now().subtract(const Duration(days: 1)),
      isPremium: false,
      serverHasFullAccess: true,
      serverTrialDaysRemaining: 13,
    );

    final prefs = await SharedPreferences.getInstance();
    await _persistSession(prefs, seededUser);
    _currentUser = seededUser;
  }

  // ── Abo aktivieren (Stub für In-App Purchase) ──────────────────────────────

  Future<bool> activatePremium() async {
    final currentUser = _currentUser;
    if (currentUser == null) return false;

    var backendVerified = false;

    if (_apiClient != null) {
      try {
        final payload = await _apiClient!.postJsonAny(
          '${APIConfig.getBackendEntitlementsPath()}/${currentUser.uid}${APIConfig.getBackendEntitlementsActivatePremiumSuffix()}',
          {
            'registeredAt': currentUser.registeredAt.toIso8601String(),
            'schemaVersion': APIConfig.getBackendApiVersion(),
          },
        );

        final raw = payload is Map<String, dynamic>
            ? (payload['item'] is Map<String, dynamic>
                ? Map<String, dynamic>.from(payload['item'] as Map)
                : payload)
            : <String, dynamic>{};

        final status = (raw['status'] ?? '').toString().toLowerCase();
        backendVerified =
            raw['isPremium'] == true || raw['activated'] == true || status == 'active';
      } catch (e) {
        debugPrint('AuthService.activatePremium(): backend sync failed: $e');
        if (kReleaseMode) {
          return false;
        }
      }
    }

    // In release, never unlock premium locally without explicit backend verification.
    if (kReleaseMode && !backendVerified) {
      debugPrint(
        'AuthService.activatePremium(): blocked in release because backend verification is missing.',
      );
      return false;
    }

    final user = ParentUser(
      uid: currentUser.uid,
      email: currentUser.email,
      displayName: currentUser.displayName,
      registeredAt: currentUser.registeredAt,
      isPremium: true,
      serverHasFullAccess: backendVerified ? true : currentUser.serverHasFullAccess,
      serverTrialDaysRemaining: currentUser.serverTrialDaysRemaining,
    );
    final prefs = await SharedPreferences.getInstance();
    if (_firebaseReady) {
      await _persistFirebaseProfile(prefs, user);
    } else {
      await _persistSession(prefs, user);
    }
    _currentUser = user;
    await refreshEntitlements();
    return true;
  }

  Future<void> refreshEntitlements() async {
    final current = _currentUser;
    if (current == null || _apiClient == null) {
      return;
    }

    try {
      final payload = await _apiClient!.getJson(
        '${APIConfig.getBackendEntitlementsPath()}/${current.uid}/status?registeredAt=${Uri.encodeQueryComponent(current.registeredAt.toIso8601String())}&isPremium=${current.isPremium}',
      );

      final raw = payload is Map<String, dynamic>
          ? (payload['item'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(payload['item'] as Map)
              : payload)
          : <String, dynamic>{};

      if (raw.isEmpty) return;

      final serverPremium = raw['isPremium'] == true;
      final serverHasFullAccess = raw['hasFullAccess'] == true;
      final serverTrialDaysRemaining = raw['trialDaysRemaining'] is num
          ? (raw['trialDaysRemaining'] as num).toInt()
          : null;

      final updated = ParentUser(
        uid: current.uid,
        email: current.email,
        displayName: current.displayName,
        registeredAt: current.registeredAt,
        isPremium: current.isPremium || serverPremium,
        serverHasFullAccess: serverHasFullAccess,
        serverTrialDaysRemaining: serverTrialDaysRemaining,
      );

      final prefs = await SharedPreferences.getInstance();
      if (_firebaseReady) {
        await _persistFirebaseProfile(prefs, updated);
      } else {
        await _persistSession(prefs, updated);
      }
      _currentUser = updated;
    } catch (e) {
      debugPrint('AuthService.refreshEntitlements(): failed: $e');
    }
  }

  // ── Hilfsmethoden ──────────────────────────────────────────────────────────

  Future<void> _tryInitFirebase() async {
    if (kDebugMode && disableFirebaseInitForTesting) {
      _firebaseReady = false;
      _firebaseAuth = null;
      return;
    }

    if (!kIsWeb && Platform.isMacOS) {
      _firebaseReady = false;
      _firebaseAuth = null;
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _firebaseAuth = FirebaseAuth.instance;
      _firebaseReady = true;
    } catch (e) {
      _logIgnoredError('AuthService._tryInitFirebase(): Firebase unavailable', e);
      _firebaseReady = false;
      _firebaseAuth = null;
    }
  }

  Future<void> _ensureFirebaseInitChecked() async {
    if (_firebaseReady) return;
    await _tryInitFirebase();
  }

  Future<ParentUser> _readOrCreateFirebaseUser(
    User firebaseUser, {
    String? preferredDisplayName,
    bool forceNewRegisteredAt = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final profileKey = '$_kUserProfilePrefix${firebaseUser.uid}';

    if (!forceNewRegisteredAt) {
      final storedRaw = prefs.getString(profileKey);
      if (storedRaw != null && storedRaw.isNotEmpty) {
        try {
          final stored = ParentUser.fromJson(
              jsonDecode(storedRaw) as Map<String, dynamic>);
          final updated = ParentUser(
            uid: firebaseUser.uid,
            email: firebaseUser.email?.toLowerCase().trim() ?? stored.email,
            displayName: preferredDisplayName ??
                firebaseUser.displayName ??
                stored.displayName,
            registeredAt: stored.registeredAt,
            isPremium: stored.isPremium,
          );
          await _persistFirebaseProfile(prefs, updated);
          return updated;
        } catch (e) {
          _logIgnoredError(
            'AuthService._readOrCreateFirebaseUser(): stored profile unreadable',
            e,
          );
          // Wenn das Profil unlesbar ist, wird unten neu erstellt.
        }
      }
    }

    final fresh = ParentUser(
      uid: firebaseUser.uid,
      email: (firebaseUser.email ?? '').toLowerCase().trim(),
      displayName: preferredDisplayName ??
          firebaseUser.displayName ??
          (firebaseUser.email?.split('@').first ?? 'Elternkonto'),
      registeredAt: DateTime.now(),
      isPremium: false,
    );
    await _persistFirebaseProfile(prefs, fresh);
    return fresh;
  }

  Future<void> _persistFirebaseProfile(
      SharedPreferences prefs, ParentUser user) async {
    final profileKey = '$_kUserProfilePrefix${user.uid}';
    await prefs.setString(profileKey, jsonEncode(user.toJson()));
  }

  AuthResult _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return AuthResult.fail(
          AuthErrorCode.emailAlreadyInUse,
          'Diese E-Mail-Adresse ist bereits registriert.',
        );
      case 'invalid-email':
        return AuthResult.fail(
          AuthErrorCode.invalidEmail,
          'Bitte gib eine gültige E-Mail-Adresse ein.',
        );
      case 'weak-password':
        return AuthResult.fail(
          AuthErrorCode.weakPassword,
          'Das Passwort ist zu schwach.',
        );
      case 'user-not-found':
        return AuthResult.fail(
          AuthErrorCode.userNotFound,
          'Kein Konto mit dieser E-Mail-Adresse gefunden.',
        );
      case 'wrong-password':
      case 'invalid-credential':
        return AuthResult.fail(
          AuthErrorCode.wrongPassword,
          'E-Mail oder Passwort ist nicht korrekt.',
        );
      case 'too-many-requests':
        return AuthResult.fail(
          AuthErrorCode.tooManyRequests,
          'Zu viele Versuche. Bitte später erneut versuchen.',
        );
      case 'network-request-failed':
        return AuthResult.fail(
          AuthErrorCode.networkError,
          'Netzwerkfehler. Bitte Internetverbindung prüfen.',
        );
      default:
        return AuthResult.fail(
          AuthErrorCode.unknown,
          'Authentifizierung fehlgeschlagen. Bitte erneut versuchen.',
        );
    }
  }

  Future<void> _persistSession(SharedPreferences prefs, ParentUser user) async {
    await prefs.setString(_kUserKey, jsonEncode(user.toJson()));
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  String _localEmailIndexKey(String normalizedEmail) =>
      '$_kLocalEmailIndexPrefix$normalizedEmail';

  String _localAuthRecordKey(String uid) => '$_kLocalAuthRecordPrefix$uid';

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _hashPassword({required String password, required String salt}) {
    return sha256.convert(utf8.encode('$salt::$password')).toString();
  }

  bool _verifyPassword({
    required String password,
    required String salt,
    required String expectedHash,
  }) {
    if (salt.isEmpty || expectedHash.isEmpty) return false;
    return _hashPassword(password: password, salt: salt) == expectedHash;
  }

  AuthResult? _validateEmail(String email) {
    final clean = email.trim();
    if (clean.isEmpty) {
      return AuthResult.fail(
          AuthErrorCode.invalidEmail, 'Bitte gib deine E-Mail-Adresse ein.');
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(clean)) {
      return AuthResult.fail(
          AuthErrorCode.invalidEmail, 'Bitte gib eine gültige E-Mail-Adresse ein.');
    }
    return null;
  }

  AuthResult? _validatePassword(String password) {
    if (password.length < 8) {
      return AuthResult.fail(
        AuthErrorCode.weakPassword,
        'Das Passwort muss mindestens 8 Zeichen lang sein.',
      );
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return AuthResult.fail(
        AuthErrorCode.weakPassword,
        'Das Passwort muss mindestens einen Großbuchstaben enthalten.',
      );
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return AuthResult.fail(
        AuthErrorCode.weakPassword,
        'Das Passwort muss mindestens eine Zahl enthalten.',
      );
    }
    return null;
  }

}
