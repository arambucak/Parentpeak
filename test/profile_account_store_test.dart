import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String? uid;
  late ProfileAccountStore store;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    uid = 'a';
    store = ProfileAccountStore(userIdProvider: () => uid);
  });
  tearDown(() => store.dispose());
  void switchTo(String? owner) {
    uid = owner;
    store.synchronize();
  }

  test('isolates children, setup, region, tile order and location for A/B/guest', () async {
    final a = store.ticket;
    final values = {
      ProfileAccountStore.childrenKey: ['A child|4'],
      ProfileAccountStore.completedKey: true,
      ProfileAccountStore.rolesKey: ['baby', 'school'],
      ProfileAccountStore.agesKey: ['baby'],
      ProfileAccountStore.countryKey: 'TR',
      ProfileAccountStore.regionKey: 'TR',
      ProfileAccountStore.tileOrderKey: ['calendar'],
      ProfileAccountStore.latitudeKey: 40.0,
      ProfileAccountStore.longitudeKey: 30.0,
      ProfileAccountStore.cityKey: 'A city',
    };
    await store.write(a, values);
    for (final next in ['b', null]) {
      switchTo(next);
      expect(await store.read(store.ticket), isEmpty);
      await expectLater(store.read(a), throwsA(isA<ProfileAccountChanged>()));
    }
    switchTo('a');
    expect(await store.read(store.ticket), values);
    final restarted = ProfileAccountStore(userIdProvider: () => uid);
    expect(await restarted.read(restarted.ticket), values);
    restarted.dispose();
  });

  test('no automatic legacy read; decline and claim are local and exclusive', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(ProfileAccountStore.childrenKey, ['Old child|5']);
    expect(await store.read(store.ticket), isEmpty);
    expect(await store.hasLegacy(store.ticket, ProfileLegacyDomain.children), true);
    await store.claim(store.ticket, ProfileLegacyDomain.children,
        confirmOwnership: () async => false);
    expect(await store.read(store.ticket), isEmpty);
    await store.claim(store.ticket, ProfileLegacyDomain.children,
        confirmOwnership: () async => true);
    expect((await store.read(store.ticket))[ProfileAccountStore.childrenKey], ['Old child|5']);
    expect(prefs.getStringList(ProfileAccountStore.childrenKey), ['Old child|5']);
    switchTo('b');
    expect(await store.hasLegacy(store.ticket, ProfileLegacyDomain.children), false);
    await expectLater(store.claim(store.ticket, ProfileLegacyDomain.children,
        confirmOwnership: () async => true), throwsStateError);
    expect(await store.read(store.ticket), isEmpty);
  });

  test('onboarding and location claims are separate; preserves unused keys', () async {
    SharedPreferences.setMockInitialValues({
      ProfileAccountStore.completedKey: true,
      ProfileAccountStore.rolesKey: ['baby', 'school'],
      ProfileAccountStore.agesKey: ['baby'],
      ProfileAccountStore.latitudeKey: 50.0,
      ProfileAccountStore.longitudeKey: 10.0,
    });
    await store.claim(store.ticket, ProfileLegacyDomain.onboarding,
        confirmOwnership: () async => true);
    final setup = await store.read(store.ticket);
    expect(setup[ProfileAccountStore.rolesKey], ['baby', 'school']);
    expect(setup[ProfileAccountStore.agesKey], ['baby']);
    expect(setup.containsKey(ProfileAccountStore.latitudeKey), false);
    expect(await store.hasLegacy(store.ticket, ProfileLegacyDomain.location), true);
  });

  test('claim refuses existing account data rather than overwrite or merge', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(ProfileAccountStore.childrenKey, ['Legacy|4']);
    await store.write(store.ticket, {ProfileAccountStore.childrenKey: ['Own|5']});
    await expectLater(store.claim(store.ticket, ProfileLegacyDomain.children,
        confirmOwnership: () async => true), throwsStateError);
    expect((await store.read(store.ticket))[ProfileAccountStore.childrenKey], ['Own|5']);
    expect(await store.hasLegacy(store.ticket, ProfileLegacyDomain.children), true);
  });

  test('parallel claims cannot both commit; owner marker is in the same write', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(ProfileAccountStore.childrenKey, ['Legacy|4']);
    final gate = Completer<bool>();
    final ticket = store.ticket;
    final first = store.claim(ticket, ProfileLegacyDomain.children,
        confirmOwnership: () => gate.future);
    await store.claim(ticket, ProfileLegacyDomain.children,
        confirmOwnership: () async => true);
    gate.complete(true);
    await expectLater(first, throwsStateError);
    final root = jsonDecode(prefs.getString(ProfileAccountStore.storageKey)!);
    expect(root['legacyOwners']['children'], ticket.scope);
    expect(root['accounts'][ticket.scope]['owner'], ticket.scope);
  });

  test('pending confirmation and old tickets rejected even after A logout A', () async {
    final gate = Completer<bool>();
    final old = store.ticket;
    final claim = store.claim(old, ProfileLegacyDomain.children,
        confirmOwnership: () => gate.future);
    switchTo(null);
    switchTo('a');
    gate.complete(true);
    await expectLater(claim, throwsA(isA<ProfileAccountChanged>()));
    await expectLater(store.write(old, {ProfileAccountStore.completedKey: true}),
        throwsA(isA<ProfileAccountChanged>()));
  });

  for (final throws in [false, true]) {
    test('failed persistence ($throws) leaves legacy unassigned and data unchanged', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(ProfileAccountStore.childrenKey, ['Legacy|4']);
      final failing = ProfileAccountStore(userIdProvider: () => uid,
          persist: (key, value) async {
            if (throws) throw StateError('disk unavailable');
            return false;
          });
      await expectLater(failing.claim(failing.ticket, ProfileLegacyDomain.children,
          confirmOwnership: () async => true), throwsStateError);
      expect(await failing.read(failing.ticket), isEmpty);
      expect(await failing.hasLegacy(failing.ticket, ProfileLegacyDomain.children), true);
      failing.dispose();
    });
  }

  test('mismatched owner, corrupt root and invalid fields fail explicitly', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ProfileAccountStore.storageKey, jsonEncode({
      'version': 1, 'legacyOwners': {},
      'accounts': {store.scope: {'owner': 'other', 'data': {}}},
    }));
    await expectLater(store.read(store.ticket), throwsFormatException);
    await prefs.setString(ProfileAccountStore.storageKey, '{broken');
    await expectLater(store.read(store.ticket), throwsFormatException);
    expect(() => store.write(store.ticket, {ProfileAccountStore.latitudeKey: 1000}),
        throwsFormatException);
  });

  test('account switch during acknowledged write never commits into the new owner', () async {
    final started = Completer<void>();
    final saved = Completer<bool>();
    store.dispose();
    store = ProfileAccountStore(userIdProvider: () => uid,
      persist: (key, value) async {
        started.complete();
        await saved.future;
        return (await SharedPreferences.getInstance()).setString(key, value);
      });
    final result = store.write(store.ticket, {
      ProfileAccountStore.childrenKey: ['A only|4'],
    });
    final checked = expectLater(result, throwsA(isA<ProfileAccountChanged>()));
    await started.future;
    switchTo('b');
    saved.complete(true);
    await checked;
    expect(await store.read(store.ticket), isEmpty);
    switchTo('a');
    expect((await store.read(store.ticket))[ProfileAccountStore.childrenKey],
        ['A only|4']);
  });
}
