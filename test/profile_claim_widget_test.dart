import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
import 'package:parentpeak/ui/widgets/profile_legacy_claim.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String? uid;
  late ProfileAccountStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'profile.children': ['Private legacy|4']});
    await languageService.setLanguage('en');
    uid = 'a';
    store = ProfileAccountStore(userIdProvider: () => uid);
  });
  tearDown(() => store.dispose());

  Future<void> mount(WidgetTester tester) => tester.pumpWidget(MaterialApp(
    home: Scaffold(body: ProfileLegacyClaim(
        domain: ProfileLegacyDomain.children, store: store)),
  ));
  String text(String key) => AppStringsManager.getString('en', key);

  testWidgets('legacy stays hidden until explicit local claim; cancel preserves it', (tester) async {
    await mount(tester); await tester.pumpAndSettle();
    expect(find.textContaining('Private legacy'), findsNothing);
    await tester.tap(find.text(text('profile_claim_confirm')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await store.read(store.ticket), isEmpty);
    await tester.tap(find.text(text('profile_claim_confirm')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(text('profile_claim_confirm')).last);
    await tester.pumpAndSettle();
    expect((await store.read(store.ticket))['profile.children'], ['Private legacy|4']);
    expect(find.text(text('profile_legacy_children')), findsNothing);
  });

  testWidgets('confirmation opened for A never adopts for B or new A session', (tester) async {
    await mount(tester); await tester.pumpAndSettle();
    await tester.tap(find.text(text('profile_claim_confirm')));
    await tester.pump(const Duration(milliseconds: 300));
    uid = null; store.synchronize();
    uid = 'a'; store.synchronize();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(text('profile_claim_confirm')).last);
    await tester.pumpAndSettle();
    expect(await store.read(store.ticket), isEmpty);
    expect(await store.hasLegacy(store.ticket, ProfileLegacyDomain.children), true);
  });

  testWidgets('conflicting account data displays failure without overwrite', (tester) async {
    await mount(tester); await tester.pumpAndSettle();
    // A conflicting value appears after the availability check.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ProfileAccountStore.storageKey, jsonEncode({
      'version': 1, 'legacyOwners': {},
      'accounts': {store.scope: {
        'owner': store.scope,
        'data': {'profile.children': ['Own|3']},
      }},
    }));
    await tester.tap(find.text(text('profile_claim_confirm')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(text('profile_claim_confirm')).last);
    await tester.pumpAndSettle();
    expect(find.text(text('profile_account_failed')), findsOneWidget);
    expect((await store.read(store.ticket))['profile.children'], ['Own|3']);
  });

  testWidgets('new user with only default/empty local fields sees no legacy sections',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'profile.children': <String>[],
      'onboarding.family_name': '',
      'onboarding.completed': false,
      'holiday.country': 'DE', 'holiday.region': 'NRW',
      'location.city': ' ', 'location.method': 'manual',
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
      for (final domain in ProfileLegacyDomain.values)
        ProfileLegacyClaim(domain: domain, store: store),
    ]))));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);
    expect(find.text(text('profile_claim_confirm')), findsNothing);
  });

  testWidgets('real setup and event search location display the corresponding claims',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding.family_name': 'Our family',
      'events.saved_city': 'Berlin',
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
      ProfileLegacyClaim(domain: ProfileLegacyDomain.onboarding, store: store),
      ProfileLegacyClaim(domain: ProfileLegacyDomain.location, store: store),
    ]))));
    await tester.pumpAndSettle();
    expect(find.text(text('profile_legacy_onboarding')), findsOneWidget);
    expect(find.text(text('profile_legacy_location')), findsOneWidget);
  });
}
