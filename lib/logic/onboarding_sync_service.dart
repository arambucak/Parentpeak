import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/profile_account_store.dart';

/// Syncs only the existing minimal account setup, never the local child list.
class OnboardingSyncService {
  OnboardingSyncService({BackendApiClient? api, ProfileAccountStore? store})
      : _api = api ?? BackendServiceFactory.createApiClient(),
        _store = store ?? ProfileAccountStore.instance;

  static final instance = OnboardingSyncService();
  final BackendApiClient? _api;
  final ProfileAccountStore _store;

  String _owner(ProfileAccountTicket ticket) {
    _store.require(ticket);
    final uid = _store.userId;
    if (uid == null || uid.isEmpty) throw StateError('Sign in to sync onboarding');
    return uid;
  }

  BackendApiClient get _client =>
      _api ?? (throw StateError('Onboarding backend is not configured'));

  Future<void> pushCompleted(ProfileAccountTicket ticket) async {
    final uid = _owner(ticket);
    final data = await _store.read(ticket);
    _store.require(ticket);
    if (data[ProfileAccountStore.completedKey] != true) {
      throw StateError('Local onboarding has not completed');
    }
    final result = await _client.withRequestGuard(() => _store.require(ticket))
        .postJsonAny('/api/onboarding', {
      'userId': uid,
      'completed': true,
      'familyName': data[ProfileAccountStore.familyNameKey] ?? '',
      'parentRole': data[ProfileAccountStore.roleKey] ?? '',
      'priorities': data[ProfileAccountStore.prioritiesKey] ?? <String>[],
    });
    _store.require(ticket);
    if (result is! Map || result['ok'] != true) {
      throw StateError('Onboarding sync was not acknowledged');
    }
  }

  Future<bool> pullCompleted(ProfileAccountTicket ticket) async {
    final uid = _owner(ticket);
    final data = await _client.withRequestGuard(() => _store.require(ticket))
        .getJson('/api/onboarding/${Uri.encodeComponent(uid)}');
    _store.require(ticket);
    if (data is! Map<String, dynamic> || data['completed'] is! bool) {
      throw const FormatException('Invalid onboarding response');
    }
    if (data['completed'] != true) return false;
    final values = <String, dynamic>{ProfileAccountStore.completedKey: true};
    for (final entry in {
      'familyName': ProfileAccountStore.familyNameKey,
      'parentRole': ProfileAccountStore.roleKey,
    }.entries) {
      final value = data[entry.key];
      if (value is! String) throw const FormatException('Invalid onboarding text');
      if (value.trim().isNotEmpty) values[entry.value] = value.trim();
    }
    final priorities = data['priorities'];
    if (priorities is! List || priorities.any((v) => v is! String)) {
      throw const FormatException('Invalid onboarding priorities');
    }
    if (priorities.isNotEmpty) values[ProfileAccountStore.prioritiesKey] = priorities;
    await _store.write(ticket, values);
    return true;
  }
}
