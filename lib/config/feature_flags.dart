import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Launch-Phase für gestaffeltes Feature-Rollout.
///
/// Phase 1 (Launch): Features die ohne Community funktionieren
/// Phase 2 (ab ~500 User): Community-Features
/// Phase 3 (ab ~2000 User): Marktplatz-Features
enum LaunchPhase {
  phase1, // Impulse, KI-Chat, Kalender, Organisation
  phase2, // + Eltern Match, Events
  phase3, // + Verschenkmarkt, GemeinsamSatt, Finanzen
}

/// Repräsentiert den Zustand eines Features im System.
enum FeatureState {
  /// Feature ist aktiv und vollständig nutzbar.
  enabled,

  /// Feature ist sichtbar aber gesperrt ("Coming Soon").
  comingSoon,

  /// Feature ist komplett ausgeblendet.
  hidden,
}

/// Freemium-Tier — bestimmt welche Features kostenlos vs. Premium sind.
enum SubscriptionTier {
  free,
  premium,
}

/// Einzelnes Feature mit Metadaten für Gating und Launch-Steuerung.
class FeatureDefinition {
  final String id;
  final String label;
  final LaunchPhase phase;
  final bool availableInFreeTier;
  final String? freeTierLimit; // z.B. "1x pro Tag" für KI-Chat

  const FeatureDefinition({
    required this.id,
    required this.label,
    required this.phase,
    this.availableInFreeTier = false,
    this.freeTierLimit,
  });
}

/// Zentraler Feature-Flag-Service.
///
/// Steuert:
/// - Welche Features in der aktuellen Launch-Phase sichtbar sind
/// - Ob ein Feature "Coming Soon" oder aktiv ist
/// - Freemium-Gating (Free vs. Premium)
/// - Tap-Tracking auf gesperrte Features (für Priorisierung)
///
/// Aktuell: SharedPreferences-basiert mit compile-time Phase.
/// Später: Firebase Remote Config als Drop-in-Replacement.
class FeatureFlagService extends ChangeNotifier {
  FeatureFlagService._();
  static final FeatureFlagService instance = FeatureFlagService._();

  // ─── Aktuelle Launch-Phase ─────────────────────────────────────────────────
  // Wird in Release über Remote Config steuerbar. Für jetzt compile-time.
  static const LaunchPhase _defaultPhase = LaunchPhase.phase1;
  LaunchPhase _currentPhase = _defaultPhase;
  LaunchPhase get currentPhase => _currentPhase;

  // ─── Feature-Registry ──────────────────────────────────────────────────────

  static const List<FeatureDefinition> allFeatures = [
    // Phase 1 — Solo-nutzbar, kein Netzwerkeffekt nötig
    FeatureDefinition(
      id: 'impulse_entwicklung',
      label: 'Impulse & Entwicklung',
      phase: LaunchPhase.phase1,
      availableInFreeTier: true,
      freeTierLimit: 'Basis-Impulse, Details nur Premium',
    ),
    FeatureDefinition(
      id: 'ki_elternberatung',
      label: 'KI Elternberatung',
      phase: LaunchPhase.phase1,
      availableInFreeTier: true,
      freeTierLimit: '3 Nachrichten pro Tag',
    ),
    FeatureDefinition(
      id: 'kalender',
      label: 'Kalender',
      phase: LaunchPhase.phase1,
      availableInFreeTier: true,
    ),
    FeatureDefinition(
      id: 'organisation',
      label: 'Organisation',
      phase: LaunchPhase.phase1,
      availableInFreeTier: true,
    ),
    FeatureDefinition(
      id: 'eltern_match',
      label: 'Eltern-Netzwerk',
      phase: LaunchPhase.phase1,
      availableInFreeTier: true,
    ),

    // Phase 2 — Community-Features, brauchen kritische Masse
    FeatureDefinition(
      id: 'events_aktivitaeten',
      label: 'Events & Aktivitäten',
      phase: LaunchPhase.phase1,
      availableInFreeTier: true,
    ),

    // Phase 3 — Marktplatz, braucht Angebot UND Nachfrage
    FeatureDefinition(
      id: 'verschenkmarkt',
      label: 'Verschenkmarkt',
      phase: LaunchPhase.phase3,
      availableInFreeTier: false,
    ),
    FeatureDefinition(
      id: 'gemeinsam_satt',
      label: 'GemeinsamSatt',
      phase: LaunchPhase.phase3,
      availableInFreeTier: false,
    ),
    FeatureDefinition(
      id: 'finanzen_budget',
      label: 'Finanzen & Budget',
      phase: LaunchPhase.phase3,
      availableInFreeTier: false,
    ),
  ];

  // ─── Remote Overrides (simuliert Remote Config) ────────────────────────────
  final Map<String, FeatureState> _remoteOverrides = {};

  // ─── Initialisierung ───────────────────────────────────────────────────────

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Lade gespeicherte Phase (kann durch Remote Config überschrieben werden)
    final prefs = await SharedPreferences.getInstance();
    final savedPhase = prefs.getString('ff.current_phase');
    if (savedPhase != null) {
      _currentPhase = LaunchPhase.values.firstWhere(
        (p) => p.name == savedPhase,
        orElse: () => _defaultPhase,
      );
    }

    // Lade Remote Overrides
    final overrideKeys =
        prefs.getStringList('ff.remote_override_keys') ?? <String>[];
    for (final key in overrideKeys) {
      final stateStr = prefs.getString('ff.remote_override.$key');
      if (stateStr != null) {
        final state = FeatureState.values.firstWhere(
          (s) => s.name == stateStr,
          orElse: () => FeatureState.comingSoon,
        );
        _remoteOverrides[key] = state;
      }
    }

    _initialized = true;
    notifyListeners();
  }

  // ─── Feature-State Abfragen ────────────────────────────────────────────────

  /// Gibt den aktuellen Zustand eines Features zurück.
  FeatureState getFeatureState(String featureId) {
    // Remote Override hat höchste Priorität
    if (_remoteOverrides.containsKey(featureId)) {
      return _remoteOverrides[featureId]!;
    }

    // Feature in Registry suchen
    final definition = allFeatures.firstWhere(
      (f) => f.id == featureId,
      orElse: () => const FeatureDefinition(
        id: '_unknown',
        label: 'Unknown',
        phase: LaunchPhase.phase3,
      ),
    );

    // Phasenbasierte Logik
    if (definition.phase.index <= _currentPhase.index) {
      return FeatureState.enabled;
    }

    // Features der nächsten Phase → "Coming Soon"
    if (definition.phase.index == _currentPhase.index + 1) {
      return FeatureState.comingSoon;
    }

    // Features 2+ Phasen entfernt → versteckt
    return FeatureState.hidden;
  }

  /// Prüft ob ein Feature vollständig nutzbar ist.
  bool isEnabled(String featureId) {
    return getFeatureState(featureId) == FeatureState.enabled;
  }

  /// Prüft ob ein Feature als "Coming Soon" angezeigt werden soll.
  bool isComingSoon(String featureId) {
    return getFeatureState(featureId) == FeatureState.comingSoon;
  }

  /// Prüft ob ein Feature komplett versteckt sein soll.
  bool isHidden(String featureId) {
    return getFeatureState(featureId) == FeatureState.hidden;
  }

  /// Prüft ob ein Feature im Free-Tier verfügbar ist.
  bool isAvailableInFreeTier(String featureId) {
    final definition = allFeatures.firstWhere(
      (f) => f.id == featureId,
      orElse: () => const FeatureDefinition(
        id: '_unknown',
        label: 'Unknown',
        phase: LaunchPhase.phase3,
      ),
    );
    return definition.availableInFreeTier;
  }

  /// Gibt das Free-Tier Limit für ein Feature zurück (null = unbegrenzt).
  String? getFreeTierLimit(String featureId) {
    final definition = allFeatures.firstWhere(
      (f) => f.id == featureId,
      orElse: () => const FeatureDefinition(
        id: '_unknown',
        label: 'Unknown',
        phase: LaunchPhase.phase3,
      ),
    );
    return definition.freeTierLimit;
  }

  /// Gibt die Feature-Definition zurück.
  FeatureDefinition? getDefinition(String featureId) {
    try {
      return allFeatures.firstWhere((f) => f.id == featureId);
    } catch (_) {
      return null;
    }
  }

  // ─── Phase-Steuerung ───────────────────────────────────────────────────────

  /// Setzt die aktuelle Launch-Phase (z.B. durch Remote Config Update).
  Future<void> setPhase(LaunchPhase phase) async {
    if (_currentPhase == phase) return;
    _currentPhase = phase;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ff.current_phase', phase.name);
    notifyListeners();
  }

  /// Setzt einen Remote Override für ein einzelnes Feature.
  Future<void> setRemoteOverride(String featureId, FeatureState state) async {
    _remoteOverrides[featureId] = state;

    final prefs = await SharedPreferences.getInstance();
    final keys = _remoteOverrides.keys.toList();
    await prefs.setStringList('ff.remote_override_keys', keys);
    await prefs.setString('ff.remote_override.$featureId', state.name);
    notifyListeners();
  }

  /// Entfernt einen Remote Override.
  Future<void> clearRemoteOverride(String featureId) async {
    _remoteOverrides.remove(featureId);

    final prefs = await SharedPreferences.getInstance();
    final keys = _remoteOverrides.keys.toList();
    await prefs.setStringList('ff.remote_override_keys', keys);
    await prefs.remove('ff.remote_override.$featureId');
    notifyListeners();
  }

  // ─── Tap-Tracking für gesperrte Features ───────────────────────────────────

  /// Zeichnet einen Tap auf ein gesperrtes Feature auf.
  /// Damit weißt du welche "Coming Soon" Features am meisten gewünscht werden.
  Future<void> recordLockedFeatureTap(String featureId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'ff.locked_taps.$featureId';
    final current = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, current + 1);

    // Auch tageweise tracken
    final now = DateTime.now();
    final dayKey =
        'ff.locked_taps_daily.$featureId.${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final dailyCurrent = prefs.getInt(dayKey) ?? 0;
    await prefs.setInt(dayKey, dailyCurrent + 1);
  }

  /// Gibt die Gesamtzahl der Taps auf ein gesperrtes Feature zurück.
  Future<int> getLockedFeatureTapCount(String featureId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('ff.locked_taps.$featureId') ?? 0;
  }

  /// Gibt eine sortierte Liste aller "Coming Soon" Features nach Beliebtheit zurück.
  Future<List<MapEntry<String, int>>> getMostWantedFeatures() async {
    final prefs = await SharedPreferences.getInstance();
    final results = <MapEntry<String, int>>[];

    for (final feature in allFeatures) {
      if (!isEnabled(feature.id)) {
        final count = prefs.getInt('ff.locked_taps.${feature.id}') ?? 0;
        if (count > 0) {
          results.add(MapEntry(feature.id, count));
        }
      }
    }

    results.sort((a, b) => b.value.compareTo(a.value));
    return results;
  }

  // ─── Legacy-Kompatibilität ─────────────────────────────────────────────────

  /// Family Circle bleibt deaktiviert bis der volle Flow fertig ist.
  static const bool enableFamilyCircle = false;
}

/// Legacy-Klasse für Abwärtskompatibilität.
/// Neue Features sollten [FeatureFlagService] direkt nutzen.
class FeatureFlags {
  const FeatureFlags._();

  static const bool enableFamilyCircle = FeatureFlagService.enableFamilyCircle;
}
