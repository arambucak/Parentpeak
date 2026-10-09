import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
import 'package:parentpeak/logic/profile_data_export_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ProfileDataExportService', () {
    late String? userId;
    late ProfileAccountStore accounts;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      userId = 'export-user';
      accounts = ProfileAccountStore(userIdProvider: () => userId);
    });

    tearDown(() => accounts.dispose());

    test(
      'exports only the current owner and excludes legacy preferences',
      () async {
        final scope = accounts.scope;
        const otherScope = 'account.other-user';
        const profileKey = ProfileAccountStore.storageKey;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          profileKey,
          jsonEncode({
            'version': 1,
            'accounts': {
              scope: {
                'owner': scope,
                'data': {ProfileAccountStore.familyNameKey: 'Own family'},
              },
              otherScope: {
                'owner': otherScope,
                'data': {ProfileAccountStore.familyNameKey: 'Foreign family'},
              },
            },
            'legacyOwners': {'children': otherScope},
          }),
        );
        await prefs.setString(
          'chat.accounts.v1',
          jsonEncode({
            'accounts': {
              scope: {
                'owner': scope,
                'topics': {'own-topic': 2},
              },
              otherScope: {
                'owner': otherScope,
                'topics': {'foreign-topic': 8},
              },
            },
            'legacyOwner': null,
          }),
        );
        for (final key in [
          'familyhub.accounts.v1',
          'famgeld.accounts.v1',
          'treasure.accounts.v1',
        ]) {
          await prefs.setString(
            key,
            jsonEncode({
              'accounts': {
                scope: {
                  'owner': scope,
                  'data': {'value': 'own-$key'},
                },
                otherScope: {
                  'owner': otherScope,
                  'data': {'value': 'foreign-$key'},
                },
              },
              'legacyOwner': otherScope,
            }),
          );
        }
        await prefs.setString(
          'spielfreunde.profile.$scope',
          jsonEncode({
            'ownerUserId': userId,
            'profile': {'displayName': 'Own profile'},
          }),
        );
        await prefs.setBool('chat.memory_consent.v1.$scope', true);
        await prefs.setBool('chat.memory_consent.v1.$otherScope', false);
        await prefs.setBool('chat.memory_consent.v1', true);
        await prefs.setString('unrelated.global.setting', 'not exportable');
        await prefs.setString('auth.id_token', 'not exportable');
        await prefs.setString('profile.children', 'unassigned child data');
        await prefs.setString(
          'spielfreunde.profile',
          'unassigned matching data',
        );

        final exported = await ProfileDataExportService(
          accounts: accounts,
        ).collectLocalData(accounts.ticket);
        final encoded = jsonEncode(exported);

        expect(exported['owner'], scope);
        expect(
          exported['accountData']['profile'][ProfileAccountStore.familyNameKey],
          'Own family',
        );
        expect(exported['accountData']['chat.accounts.v1']['own-topic'], 2);
        for (final key in [
          'familyhub.accounts.v1',
          'famgeld.accounts.v1',
          'treasure.accounts.v1',
        ]) {
          expect(exported['accountData'][key]['value'], 'own-$key');
        }
        expect(
          exported['accountData']['parentMatchingProfile']['displayName'],
          'Own profile',
        );
        expect(
          exported['accountPreferences']['chat.memory_consent.v1.$scope'],
          isTrue,
        );
        expect(encoded, isNot(contains('Foreign family')));
        expect(encoded, isNot(contains('foreign-topic')));
        expect(encoded, isNot(contains('foreign-familyhub.accounts.v1')));
        expect(encoded, isNot(contains('unassigned child data')));
        expect(encoded, isNot(contains('unassigned matching data')));
        expect(encoded, isNot(contains('unrelated.global.setting')));
        expect(encoded, isNot(contains('not exportable')));
        expect(encoded, isNot(contains('legacyOwners')));
        expect(encoded, isNot(contains(otherScope)));
        expect(encoded, isNot(contains('chat.memory_consent.v1"')));
      },
    );

    test('rejects export when the account changes during collection', () async {
      final ticket = accounts.ticket;
      final prefs = await SharedPreferences.getInstance();
      final service = ProfileDataExportService(
        accounts: accounts,
        preferences: () async {
          userId = 'different-user';
          return prefs;
        },
      );

      await expectLater(
        service.collectLocalData(ticket),
        throwsA(isA<ProfileAccountChanged>()),
      );
    });
  });
}
