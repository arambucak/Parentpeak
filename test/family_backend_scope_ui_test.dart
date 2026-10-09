import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/l10n/app_localizations.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
import 'package:parentpeak/logic/shopping_backend_service.dart';
import 'package:parentpeak/logic/todo_backend_service.dart';
import 'package:parentpeak/ui/shopping_screen.dart';
import 'package:parentpeak/ui/todo_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late String? uid;
  late ProfileAccountStore store;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    uid = 'a';
    store = ProfileAccountStore(userIdProvider: () => uid);
  });
  tearDown(() => store.dispose());
  Widget screen(
    bool shopping,
    Future<http.Response> Function(http.Request) handler,
  ) {
    final client = MockClient(handler);
    addTearDown(client.close);
    final api = BackendApiClient(
      baseUrl: 'https://backend.example',
      authTokenProvider: () async => 'firebase-$uid',
      requireAuthToken: true,
      httpClient: client,
    );
    return shopping
        ? ShoppingScreen(
            accountStore: store,
            shoppingService: ShoppingBackendService(
              apiClient: api,
              accountStore: store,
            ),
          )
        : TodoScreen(
            accountStore: store,
            todoService: TodoBackendService(
              apiClient: api,
              accountStore: store,
            ),
          );
  }

  Future<void> open(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLanguages.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          AppLanguages.materialLocalizationsDelegate,
          AppLanguages.widgetsLocalizationsDelegate,
          AppLanguages.cupertinoLocalizationsDelegate,
        ],
        home: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  http.Response items(String value) => http.Response(
    jsonEncode({
      'items': [
        {
          'id': value,
          'title': value,
          'name': value,
          'completed': false,
          'checked': false,
        },
      ],
    }),
    200,
  );

  for (final shopping in [false, true]) {
    final name = shopping ? 'shopping' : 'todo';
    for (final status in [401, 403, 503]) {
      testWidgets('$name $status is visible without backend config gate', (
        tester,
      ) async {
        await open(
          tester,
          screen(
            shopping,
            (_) async => http.Response('{"error":"Denied"}', status),
          ),
        );
        expect(find.textContaining('$status'), findsWidgets);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
    testWidgets('$name switches accounts and discards delayed old list', (
      tester,
    ) async {
      var first = true;
      final oldResponse = Completer<http.Response>();
      await open(
        tester,
        screen(shopping, (request) async {
          if (first) {
            first = false;
            return items('Private A');
          }
          if (request.headers['Authorization'] == 'Bearer firebase-a') {
            return await oldResponse.future;
          }
          return items('Private B');
        }),
      );
      expect(find.text('Private A'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pump();
      uid = 'b';
      store.synchronize();
      await tester.pumpAndSettle();
      expect(find.text('Private A'), findsNothing);
      expect(find.text('Private B'), findsOneWidget);
      oldResponse.complete(items('Late A'));
      await tester.pumpAndSettle();
      expect(find.text('Late A'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets(
      '$name discards failed optimistic toggle after account switch',
      (tester) async {
        final oldMutation = Completer<http.Response>();
        await open(
          tester,
          screen(shopping, (request) async {
            if (request.method == 'PUT') return await oldMutation.future;
            return items(uid == 'a' ? 'Private A' : 'Private B');
          }),
        );
        await tester.tap(find.byType(Checkbox).first);
        await tester.pump();
        uid = 'b';
        store.synchronize();
        await tester.pumpAndSettle();
        oldMutation.complete(http.Response('{"error":"Denied"}', 403));
        await tester.pumpAndSettle();
        expect(find.text('Private A'), findsNothing);
        expect(find.text('Private B'), findsOneWidget);
        expect(
          tester.widget<Checkbox>(find.byType(Checkbox).first).value,
          isFalse,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets('$name discards old failed delete rollback after account switch', (tester) async {
      final oldMutation = Completer<http.Response>();
      await open(tester, screen(shopping, (request) async {
        if (request.method == 'DELETE') return await oldMutation.future;
        return items(uid == 'a' ? 'Private A' : 'Private B');
      }));
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pump();
      uid = 'b';
      store.synchronize();
      await tester.pumpAndSettle();
      oldMutation.complete(http.Response('{"error":"Denied"}', 503));
      await tester.pumpAndSettle();
      expect(find.text('Private A'), findsNothing);
      expect(find.text('Private B'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('$name logout clears rows and pending draft immediately', (
      tester,
    ) async {
      await open(tester, screen(shopping, (_) async => items('Private A')));
      await tester.enterText(find.byType(TextField), 'Private draft');
      uid = null;
      store.synchronize();
      await tester.pumpAndSettle();
      expect(find.text('Private A'), findsNothing);
      expect(find.text('Private draft'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('shopping undo cannot restore deleted A item into B', (tester) async {
    await open(tester, screen(true, (request) async {
      if (request.method == 'DELETE') return http.Response('', 204);
      return items(uid == 'a' ? 'Private A' : 'Private B');
    }));
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    final undo = tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed;
    uid = 'b';
    store.synchronize();
    await tester.pumpAndSettle();
    undo();
    await tester.pump();
    expect(find.text('Private A'), findsNothing);
    expect(find.text('Private B'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
