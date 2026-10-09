import 'backend_api_client.dart';
import 'profile_account_store.dart';

class FamilyBackendScope {
  FamilyBackendScope({ProfileAccountStore? accountStore})
      : accountStore = accountStore ?? ProfileAccountStore.instance;

  final ProfileAccountStore accountStore;

  BackendApiClient requireClient(
    BackendApiClient? client,
    ProfileAccountTicket? expected,
  ) {
    final ticket = expected ?? accountStore.ticket;
    accountStore.require(ticket);
    if (accountStore.userId == null || accountStore.userId!.isEmpty) {
      throw StateError('Firebase session required for family sync.');
    }
    if (client == null) throw StateError('Family backend is not configured.');
    return client.withRequestGuard(() => accountStore.require(ticket));
  }
}
