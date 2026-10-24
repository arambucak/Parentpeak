import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/config/feature_flags.dart';

enum EntitlementState { loading, verified, unavailable }

enum EntitlementAccess { none, trial, active, grace, expired, revoked }

class EntitlementSnapshot {
  const EntitlementSnapshot({
    required this.state,
    this.tier,
    this.access = EntitlementAccess.none,
    this.validFrom,
    this.validUntil,
    this.verifiedAt,
    this.adsEligibleByEntitlement = false,
  });

  const EntitlementSnapshot.loading() : this(state: EntitlementState.loading);

  const EntitlementSnapshot.unavailable()
      : this(state: EntitlementState.unavailable);

  final EntitlementState state;
  final SubscriptionTier? tier;
  final EntitlementAccess access;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final DateTime? verifiedAt;
  final bool adsEligibleByEntitlement;

  bool get isPremium =>
      state == EntitlementState.verified && tier == SubscriptionTier.premium;

  bool get isFree =>
      state == EntitlementState.verified && tier == SubscriptionTier.free;

  bool get adsEligible =>
      state == EntitlementState.verified &&
      tier == SubscriptionTier.free &&
      adsEligibleByEntitlement;

  factory EntitlementSnapshot.fromJson(Map<String, dynamic> json) {
    final tier = switch (json['tier']) {
      'free' => SubscriptionTier.free,
      'premium' => SubscriptionTier.premium,
      _ => null,
    };
    final access = switch (json['access']) {
      'trial' => EntitlementAccess.trial,
      'active' => EntitlementAccess.active,
      'grace' => EntitlementAccess.grace,
      'expired' => EntitlementAccess.expired,
      'revoked' => EntitlementAccess.revoked,
      'none' => EntitlementAccess.none,
      _ => null,
    };
    final validFrom = _parseDate(json['validFrom']);
    final validUntil = _parseDate(json['validUntil']);
    final verifiedAt = _parseDate(json['verifiedAt']);
    final now = DateTime.now().toUtc();
    final activeAccess = access == EntitlementAccess.trial ||
        access == EntitlementAccess.active ||
        access == EntitlementAccess.grace;

    if (json['state'] != 'verified' ||
        tier == null ||
        access == null ||
        json['adsEligibleByEntitlement'] is! bool) {
      throw const FormatException('Invalid entitlement snapshot');
    }
    if (tier == SubscriptionTier.premium &&
        (!activeAccess ||
            validFrom == null ||
            validUntil == null ||
            verifiedAt == null ||
            validFrom.isAfter(now) ||
            !validUntil.isAfter(now))) {
      throw const FormatException('Invalid premium validity period');
    }

    return EntitlementSnapshot(
      state: EntitlementState.verified,
      tier: tier,
      access: access,
      validFrom: validFrom,
      validUntil: validUntil,
      verifiedAt: verifiedAt,
      adsEligibleByEntitlement: json['adsEligibleByEntitlement'] as bool,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException('Invalid entitlement date');
    }
    return DateTime.tryParse(value)?.toUtc() ??
        (throw const FormatException('Invalid entitlement date'));
  }
}

/// Central server-backed entitlement facade and local usage-limit manager.
class EntitlementService extends ChangeNotifier {
  EntitlementService._();
  static final EntitlementService instance = EntitlementService._();

  // ─── Konfiguration ─────────────────────────────────────────────────────────

  /// Tägliches Limit für KI-Chat im Free-Tier.
  static const int freeTierDailyChatLimit = 3;

  /// Tägliches Limit für detaillierte Impulse-Inhalte im Free-Tier.
  static const int freeTierDailyImpulseDetailLimit = 1;

  // ─── State ─────────────────────────────────────────────────────────────────

  @visibleForTesting
  static BackendApiClient? Function() apiClientFactory =
      BackendServiceFactory.createVerifiedApiClient;

  EntitlementSnapshot _snapshot = const EntitlementSnapshot.loading();
  EntitlementSnapshot get snapshot => _snapshot;
  EntitlementState get state => _snapshot.state;
  SubscriptionTier? get currentTier =>
      _snapshot.state == EntitlementState.verified ? _snapshot.tier : null;
  bool get isPremium => _snapshot.isPremium;
  bool get isFree => _snapshot.isFree;
  bool get adsEligibleByEntitlement => _snapshot.adsEligible;

  bool _initialized = false;
  int _refreshGeneration = 0;

  // ─── Initialisierung ───────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    await refreshEntitlements();
  }

  /// Loads only the authenticated backend snapshot; failures stay unavailable.
  Future<void> refreshEntitlements() async {
    final generation = ++_refreshGeneration;
    _snapshot = const EntitlementSnapshot.loading();
    notifyListeners();

    try {
      final apiClient = apiClientFactory();
      if (apiClient == null) {
        throw StateError('Authenticated entitlement API is unavailable');
      }
      final payload = await apiClient.getJson(
        '${APIConfig.getBackendEntitlementsPath()}/me',
      );
      if (generation != _refreshGeneration) return;
      if (payload is! Map<String, dynamic> ||
          payload['item'] is! Map<String, dynamic>) {
        throw const FormatException('Invalid entitlement response');
      }
      _snapshot = EntitlementSnapshot.fromJson(
        Map<String, dynamic>.from(payload['item'] as Map),
      );
      _initialized = true;
      notifyListeners();
    } catch (error) {
      if (generation != _refreshGeneration) return;
      _snapshot = const EntitlementSnapshot.unavailable();
      _initialized = true;
      debugPrint('EntitlementService.refreshEntitlements(): $error');
      notifyListeners();
    }
  }

  void resetForLogout() {
    _refreshGeneration++;
    _snapshot = const EntitlementSnapshot.unavailable();
    _initialized = false;
    notifyListeners();
  }

  // ─── Berechtigungsprüfungen ────────────────────────────────────────────────

  /// Prüft ob der User ein bestimmtes Feature nutzen darf.
  ///
  /// Gibt ein [EntitlementResult] zurück mit Status und Grund.
  Future<EntitlementResult> checkAccess(String featureId) async {
    final featureFlags = FeatureFlagService.instance;

    // Feature muss überhaupt aktiviert sein
    if (!featureFlags.isEnabled(featureId)) {
      if (featureFlags.isComingSoon(featureId)) {
        return EntitlementResult.comingSoon(featureId);
      }
      return EntitlementResult.unavailable(featureId);
    }

    if (state != EntitlementState.verified) {
      return EntitlementResult.unavailable(featureId);
    }

    // Premium User haben überall Zugang
    if (isPremium) {
      return EntitlementResult.granted(featureId);
    }

    // Free-Tier: Prüfe ob das Feature überhaupt free verfügbar ist
    if (!featureFlags.isAvailableInFreeTier(featureId)) {
      return EntitlementResult.premiumRequired(
        featureId,
        reason: _getPremiumUpgradeReason(featureId),
      );
    }

    // Free-Tier: Prüfe Usage-Limits
    return await _checkUsageLimit(featureId);
  }

  /// Schnelle synchrone Prüfung ob ein Feature grundsätzlich zugänglich ist.
  /// Für UI-Rendering (zeige Lock-Icon oder nicht).
  bool canAccessSync(String featureId) {
    final featureFlags = FeatureFlagService.instance;

    if (!featureFlags.isEnabled(featureId)) return false;
    if (state != EntitlementState.verified) return false;
    if (isPremium) return true;
    return featureFlags.isAvailableInFreeTier(featureId);
  }

  // ─── Usage-Tracking ────────────────────────────────────────────────────────

  /// Zeichnet eine Nutzung auf (z.B. eine KI-Chat-Nachricht).
  Future<void> recordUsage(String featureId) async {
    if (isPremium) return; // Premium trackt nicht

    final prefs = await SharedPreferences.getInstance();
    final key = _dailyUsageKey(featureId);
    final current = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, current + 1);
    notifyListeners();
  }

  /// Gibt die verbleibende Nutzung für heute zurück.
  /// Null = unbegrenzt (Premium oder kein Limit definiert).
  Future<int?> getRemainingUsage(String featureId) async {
    if (isPremium) return null;

    final limit = _getDailyLimit(featureId);
    if (limit == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final key = _dailyUsageKey(featureId);
    final used = prefs.getInt(key) ?? 0;
    final remaining = limit - used;
    return remaining < 0 ? 0 : remaining;
  }

  /// Gibt die heutige Nutzung zurück.
  Future<int> getTodayUsage(String featureId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _dailyUsageKey(featureId);
    return prefs.getInt(key) ?? 0;
  }

  // ─── Private Helpers ───────────────────────────────────────────────────────

  int? _getDailyLimit(String featureId) {
    switch (featureId) {
      case 'ki_elternberatung':
        return freeTierDailyChatLimit;
      case 'impulse_entwicklung':
        return freeTierDailyImpulseDetailLimit;
      default:
        return null;
    }
  }

  Future<EntitlementResult> _checkUsageLimit(String featureId) async {
    final limit = _getDailyLimit(featureId);
    if (limit == null) {
      return EntitlementResult.granted(featureId);
    }

    final prefs = await SharedPreferences.getInstance();
    final key = _dailyUsageKey(featureId);
    final used = prefs.getInt(key) ?? 0;

    if (used >= limit) {
      return EntitlementResult.limitReached(
        featureId,
        dailyLimit: limit,
        used: used,
      );
    }

    return EntitlementResult.granted(
      featureId,
      remainingToday: limit - used,
    );
  }

  String _dailyUsageKey(String featureId) {
    final now = DateTime.now();
    final day =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return 'entitlement.usage.$featureId.$day';
  }

  String _getPremiumUpgradeReason(String featureId) {
    switch (featureId) {
      case 'eltern_match':
        return 'Finde gleichgesinnte Eltern in deiner Nähe';
      case 'events_aktivitaeten':
        return 'Entdecke und erstelle Events für Familien';
      case 'verschenkmarkt':
        return 'Verschenke und finde Kindersachen in deiner Nähe';
      case 'gemeinsam_satt':
        return 'Teile Mahlzeiten und spare mit anderen Familien';
      case 'finanzen_budget':
        return 'Behalte Familienausgaben im Blick und spare smarter';
      default:
        return 'Schalte alle Funktionen frei mit Premium';
    }
  }
}

// ─── Ergebnis-Typ ──────────────────────────────────────────────────────────────

enum EntitlementStatus {
  /// Zugang gewährt.
  granted,

  /// Feature noch nicht verfügbar ("Coming Soon").
  comingSoon,

  /// Feature komplett nicht verfügbar (hidden).
  unavailable,

  /// Nur für Premium-User zugänglich.
  premiumRequired,

  /// Tägliches Limit erreicht.
  limitReached,
}

class EntitlementResult {
  final String featureId;
  final EntitlementStatus status;
  final String? reason;
  final int? dailyLimit;
  final int? used;
  final int? remainingToday;

  const EntitlementResult._({
    required this.featureId,
    required this.status,
    this.reason,
    this.dailyLimit,
    this.used,
    this.remainingToday,
  });

  factory EntitlementResult.granted(String featureId, {int? remainingToday}) {
    return EntitlementResult._(
      featureId: featureId,
      status: EntitlementStatus.granted,
      remainingToday: remainingToday,
    );
  }

  factory EntitlementResult.comingSoon(String featureId) {
    return EntitlementResult._(
      featureId: featureId,
      status: EntitlementStatus.comingSoon,
      reason: 'Dieses Feature kommt bald!',
    );
  }

  factory EntitlementResult.unavailable(String featureId) {
    return EntitlementResult._(
      featureId: featureId,
      status: EntitlementStatus.unavailable,
    );
  }

  factory EntitlementResult.premiumRequired(
    String featureId, {
    String? reason,
  }) {
    return EntitlementResult._(
      featureId: featureId,
      status: EntitlementStatus.premiumRequired,
      reason: reason,
    );
  }

  factory EntitlementResult.limitReached(
    String featureId, {
    required int dailyLimit,
    required int used,
  }) {
    return EntitlementResult._(
      featureId: featureId,
      status: EntitlementStatus.limitReached,
      dailyLimit: dailyLimit,
      used: used,
      reason:
          'Du hast dein tägliches Limit erreicht ($used/$dailyLimit). Upgrade auf Premium für unbegrenzten Zugang.',
    );
  }

  bool get isGranted => status == EntitlementStatus.granted;
  bool get isBlocked => status != EntitlementStatus.granted;
}
