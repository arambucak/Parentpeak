import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/family_hub_store.dart';
import 'package:parentpeak/models/shopping_item.dart';
import 'package:parentpeak/ui/familien_zentrale_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('copy preserves completion date unless explicitly cleared', () {
    final completed = ShoppingItem.fromInput('Milk').copyWith(
      isDone: true,
      doneAt: DateTime(2025, 4, 3),
    );
    expect(completed.copyWith().doneAt, completed.doneAt);
    final reopened = completed.copyWith(isDone: false, clearDoneAt: true);
    expect(reopened.doneAt, isNull);
    expect(reopened.id, completed.id);
    expect(reopened.createdAt, completed.createdAt);
  });

  test('reopening clears completion date on disk and completing sets a new date',
      () async {
    final store = FamilyHubStore(userIdProvider: () => 'owner');
    final service = ShoppingListService(store: store);
    final original = ShoppingItem.fromInput('Milk');
    final oldDate = DateTime.now().subtract(const Duration(days: 6));
    await store.write({
      FamilyHubStore.doneKey: [
        original.copyWith(isDone: true, doneAt: oldDate).toJson(),
      ],
    }, expectedScope: store.scope);
    await service.load();
    await service.toggleDone(original.id);
    await service.load();
    expect(service.activeItems.single.doneAt, isNull);
    expect(service.activeItems.single.isDone, isFalse);
    await service.toggleDone(original.id);
    await service.load();
    expect(service.doneItems.single.doneAt, isNot(oldDate));
    expect(service.doneItems.single.doneAt, isNotNull);
  });

  test('seven-day cleanup does not delete old but reopened active items',
      () async {
    final store = FamilyHubStore(userIdProvider: () => 'owner');
    final service = ShoppingListService(store: store);
    final old = DateTime.now().subtract(const Duration(days: 8));
    await store.write({
      FamilyHubStore.activeKey: [
        ShoppingItem(id: 'active', name: 'Milk', createdAt: old).toJson(),
      ],
      FamilyHubStore.doneKey: [
        ShoppingItem(id: 'done', name: 'Bread', createdAt: old,
            isDone: true, doneAt: old).toJson(),
      ],
    }, expectedScope: store.scope);
    await service.load();
    await service.addItem(ShoppingItem.fromInput('Rice'));
    await service.load();
    expect(service.activeItems.map((item) => item.id), contains('active'));
    expect(service.doneItems, isEmpty);
  });

  testWidgets('shopping actions, iPad share anchor and late completion are safe',
      (tester) async {
    final milk = ShoppingItem.fromInput('2x Milk');
    SharedPreferences.setMockInitialValues({
      FamilyHubStore.storageKey: jsonEncode({
        'accounts': {
          'guest': {
            'owner': 'guest',
            'data': {
              FamilyHubStore.activeKey: [milk.toJson()],
            },
          },
        },
      }),
    });
    final calls = <MethodCall>[];
    var failShare = false;
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (failShare) throw PlatformException(code: 'share_unavailable');
      return 'test-share';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(const MaterialApp(home: FamilienZentraleScreen()));
    await tester.pumpAndSettle();
    final share = find.byIcon(Icons.ios_share_rounded);
    final anchor = tester.getRect(share);
    await tester.tap(share);
    await tester.pumpAndSettle();
    expect(calls.single.method, 'share');
    final args = Map<String, dynamic>.from(calls.single.arguments as Map);
    final origin = Rect.fromLTWH(
      args['originX'] as double,
      args['originY'] as double,
      args['originWidth'] as double,
      args['originHeight'] as double,
    );
    expect(origin.width, greaterThan(0));
    expect(origin.height, greaterThan(0));
    expect(origin.contains(anchor.center), isTrue);
    expect(origin.width, lessThan(100), reason: 'Button anchor, not full screen');
    expect(args['text'], contains('Milk (2x)'));
    failShare = true;
    await tester.tap(share);
    await tester.pumpAndSettle();
    expect(find.text('Sharing failed'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '3x Rice');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.runAsync(() async { await Future<void>.delayed(Duration.zero); });
    await tester.pumpAndSettle();
    final service = ShoppingListService.instance;
    expect(service.activeItems.map((item) => item.name), contains('Rice'));
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, isEmpty);
    final milkTile = find.widgetWithText(ListTile, '${milk.emoji} ${milk.name}');
    await tester.tap(milkTile);
    await tester.pumpAndSettle();
    await tester.runAsync(() async { await Future<void>.delayed(Duration.zero); });
    await tester.pumpAndSettle();
    expect(service.doneItems.single.doneAt, isNotNull);
    await tester.tap(milkTile);
    await tester.pumpAndSettle();
    await tester.runAsync(() async { await Future<void>.delayed(Duration.zero); });
    await tester.pumpAndSettle();
    expect(service.activeItems.first.doneAt, isNull);

    await tester.tap(milkTile);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async { await Future<void>.delayed(Duration.zero); });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
