import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:parentpeak/config/monetization_config.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/entitlement_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AdsConsentState { loading, verified, unavailable }

enum AdsConsentDecision { unknown, denied, granted }

class AdsConsentSnapshot {
  const AdsConsentSnapshot({
    required this.state,
    this.decision = AdsConsentDecision.unknown,
    this.version,
    this.revision,
  });

  final AdsConsentState state;
  final AdsConsentDecision decision;
  final String? version;
  final String? revision;

  bool get isGranted =>
      state == AdsConsentState.verified &&
      decision == AdsConsentDecision.granted &&
      version == AdsConsentService.version &&
      revision != null;

  factory AdsConsentSnapshot.fromResponse(dynamic response) {
    if (response is! Map<String, dynamic> ||
        response['item'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid consent response');
    }
    final item = response['item'] as Map<String, dynamic>;
    final decision = switch (item['decision']) {
      'unknown' => AdsConsentDecision.unknown,
      'denied' => AdsConsentDecision.denied,
      'granted' => AdsConsentDecision.granted,
      _ => null,
    };
    final revision = item['consentRevision'];
    if (decision == null ||
        item['consentVersion'] is! String ||
        revision is! String ||
        !RegExp(r'^[a-f0-9-]{36}$').hasMatch(revision)) {
      throw const FormatException('Invalid consent metadata');
    }
    return AdsConsentSnapshot(
      state: AdsConsentState.verified,
      decision: item['consentVersion'] == AdsConsentService.version
          ? decision
          : AdsConsentDecision.unknown,
      version: item['consentVersion'] as String,
      revision: revision,
    );
  }
}

/// Eligibility only, not an ad request. Future callers must refresh both
/// account snapshots immediately before processing and recheck after awaits.
bool allowsSponsorProcessing({
  required EntitlementSnapshot entitlement,
  required AdsConsentSnapshot consent,
  required bool isPublicEventDiscovery,
}) =>
    MonetizationConfig.shouldShowAds &&
    entitlement.isFree &&
    entitlement.adsEligible &&
    consent.isGranted &&
    isPublicEventDiscovery;

class AdsConsentService extends ChangeNotifier {
  AdsConsentService({
    required String? Function() ownerProvider,
    required BackendApiClient? Function() apiClientFactory,
    Listenable? accountChanges,
  })  : _ownerProvider = ownerProvider,
        _apiClientFactory = apiClientFactory,
        _accountChanges = accountChanges {
    _accountChanges?.addListener(_accountChanged);
  }

  static const version = 'ads.consent.v1';
  static const path = '/ads/consent/me';
  static final instance = AdsConsentService(
    ownerProvider: _verifiedOwner,
    apiClientFactory: BackendServiceFactory.createVerifiedApiClient,
    accountChanges: AuthService.instance,
  );

  static String? _verifiedOwner() {
    final owner = AuthService.instance.currentUser?.uid;
    if (owner == null ||
        Firebase.apps.isEmpty ||
        FirebaseAuth.instance.currentUser?.uid != owner) {
      return null;
    }
    return owner;
  }

  final String? Function() _ownerProvider;
  final BackendApiClient? Function() _apiClientFactory;
  final Listenable? _accountChanges;
  AdsConsentSnapshot _snapshot =
      const AdsConsentSnapshot(state: AdsConsentState.loading);
  String? _owner;
  int _generation = 0;
  int _accountGeneration = 0;
  Future<void> _writes = Future<void>.value();
  bool _disposed = false;
  final Set<String> _pendingDenials = {};

  int get accountGeneration => _accountGeneration;

  AdsConsentSnapshot get snapshot => _owner == _ownerProvider()
      ? _snapshot
      : const AdsConsentSnapshot(state: AdsConsentState.unavailable);

  String _pendingKey(String owner) =>
      '$version.pending_denial.account.${Uri.encodeComponent(owner)}';

  void _accountChanged() {
    _accountGeneration++;
    _generation++;
    _owner = null;
    _snapshot = const AdsConsentSnapshot(state: AdsConsentState.unavailable);
    notifyListeners();
  }

  Future<void> _serialize(Future<void> Function() work) {
    final result = _writes.then((_) => work());
    _writes = result.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return result;
  }

  void _guard(String owner, int generation) {
    if (_disposed ||
        owner.isEmpty ||
        _ownerProvider() != owner ||
        generation != _generation) {
      throw StateError('Consent account or revision changed');
    }
  }

  Future<void> refresh() => _update();

  /// Negative choices block synchronously, before any persistence/network await.
  Future<void> decide(AdsConsentDecision decision) {
    if (decision == AdsConsentDecision.unknown) {
      throw ArgumentError.value(decision, 'decision');
    }
    return _update(decision: decision);
  }

  Future<void> _update({AdsConsentDecision? decision}) {
    final owner = _ownerProvider();
    final previous = snapshot;
    if (owner != null && decision == AdsConsentDecision.denied) {
      _pendingDenials.add(owner);
    }
    final generation = ++_generation;
    _owner = owner;
    _snapshot = const AdsConsentSnapshot(state: AdsConsentState.loading);
    notifyListeners();
    return _serialize(() async {
      try {
        if (owner == null ||
            owner.trim().isEmpty ||
            owner != owner.trim() ||
            owner == 'guest') {
          throw StateError('Verified account required');
        }
        final prefs = await SharedPreferences.getInstance();
        final pendingKey = _pendingKey(owner);
        if (_pendingDenials.contains(owner)) {
          if (!await prefs.setBool(pendingKey, true)) {
            throw StateError('Could not persist pending withdrawal');
          }
        }
        _guard(owner, generation);
        final api = _apiClientFactory()?.withRequestGuard(
          () => _guard(owner, generation),
        );
        if (api == null) throw StateError('Consent API unavailable');
        final pendingDenial = prefs.getBool(pendingKey) == true;
        if (pendingDenial && decision == AdsConsentDecision.granted) {
          throw StateError('Sync pending withdrawal before granting consent');
        }
        var current = decision == AdsConsentDecision.granted
            ? previous
            : AdsConsentSnapshot.fromResponse(await api.getJson(path));
        _guard(owner, generation);
        final choice =
            decision ?? (pendingDenial ? AdsConsentDecision.denied : null);
        if (choice != null) {
          if (current.revision == null) {
            throw StateError('Reload consent before deciding');
          }
          current = AdsConsentSnapshot.fromResponse(await api.putJson(path, {
            'decision': choice.name,
            'consentVersion': version,
            'consentRevision': current.revision,
          }));
          _guard(owner, generation);
          if (current.version != version || current.decision != choice) {
            throw StateError('Consent decision was not confirmed');
          }
          if (pendingDenial && !await prefs.remove(pendingKey)) {
            throw StateError('Could not clear pending withdrawal');
          }
          if (choice == AdsConsentDecision.denied) {
            _pendingDenials.remove(owner);
          }
          _guard(owner, generation);
        }
        _snapshot = current;
        notifyListeners();
      } catch (error) {
        if (!_disposed && generation == _generation) {
          _snapshot =
              const AdsConsentSnapshot(state: AdsConsentState.unavailable);
          debugPrint('AdsConsentService: ${error.runtimeType}');
          notifyListeners();
        }
        rethrow;
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _accountChanges?.removeListener(_accountChanged);
    super.dispose();
  }
}
