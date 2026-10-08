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
    SharedPreferences.setMockInitialValues({
      'profile.children': ['Private legacy|4'],
      ProfileAccountStore.storageKey: jsonEncode({
        'version': 1, 'legacyOwners': {},
        'accounts': {store.scope: {
          'owner': store.scope,
          'data': {'profile.children': ['Own|3']},
        }},
      }),
    });
    await mount(tester); await tester.pumpAndSettle();
    await tester.tap(find.text(text('profile_claim_confirm')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(text('profile_claim_confirm')).last);
    await tester.pumpAndSettle();
    expect(find.text(text('profile_account_failed')), findsOneWidget);
    expect((await store.read(store.ticket))['profile.children'], ['Own|3']);
  });
}
