import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/l10n/app_localizations.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/friend_chat_service.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/ui/group_chat_screen.dart';
import 'package:parentpeak/ui/match_conversation_screen.dart';
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

  FriendChatService service(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final client = MockClient(handler);
    addTearDown(client.close);
    return FriendChatService(
      accountStore: store,
      apiClient: BackendApiClient(
        baseUrl: 'https://backend.example',
        authTokenProvider: () async => 'firebase-a',
        requireAuthToken: true,
        httpClient: client,
      ),
    );
  }

  Widget screen(bool group, FriendChatService chat) => group
      ? GroupChatScreen(
          roomId: 'group_g',
          groupName: 'Group',
          chatService: chat,
          accountStore: store,
        )
      : MatchConversationScreen(
          profileId: 'a__b',
          profileName: 'B',
          isFriendChat: true,
          chatService: chat,
          accountStore: store,
        );

  Future<void> open(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
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

  String text(String key) =>
      AppStringsManager.getString(languageService.currentLanguage, key);

  for (final group in [false, true]) {
    for (final status in [403, 503]) {
      testWidgets(
        '${group ? 'group' : 'direct'} read $status stays visibly failed',
        (tester) async {
          final chat = service((request) async {
            if (request.url.path.endsWith('/members')) {
              return http.Response('{"members":[]}', 200);
            }
            return http.Response('{"code":"not_participant"}', status);
          });
          await open(tester, screen(group, chat));
          expect(
            find.text(
              text(
                status == 403
                    ? 'chat_access_unavailable'
                    : 'friend_chat_request_failed',
              ),
            ),
            findsWidgets,
          );
          if (status == 403) expect(find.byType(TextField), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }

    testWidgets(
      '${group ? 'group' : 'direct'} clears account data and stops polling',
      (tester) async {
        var requests = 0;
        final chat = service((request) async {
          requests++;
          return http.Response(
            jsonEncode(
              request.url.path.endsWith('/members')
                  ? {'members': []}
                  : {
                      'messages': [
                        {
                          'id': 'm',
                          'content': 'Private A',
                          'authorUserId': 'b',
                          'authorName': 'B',
                        },
                      ],
                    },
            ),
            200,
          );
        });
        await open(tester, screen(group, chat));
        expect(find.text('Private A'), findsOneWidget);
        uid = 'c';
        store.synchronize();
        await tester.pumpAndSettle();
        expect(find.text('Private A'), findsNothing);
        expect(find.byType(TextField), findsNothing);
        final before = requests;
        await tester.pump(const Duration(seconds: 15));
        expect(requests, before);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('unfriend send preserves archive and disables new messages', (
    tester,
  ) async {
    final chat = service(
      (request) async => request.method == 'POST'
          ? http.Response('{"code":"not_friends"}', 403)
          : http.Response(
              '{"messages":[{"id":"m","content":"Archive","authorUserId":"b"}]}',
              200,
            ),
    );
    await open(tester, screen(false, chat));
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(find.text('Archive'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('late group member response cannot repaint after read denial', (
    tester,
  ) async {
    final members = Completer<http.Response>();
    final chat = service(
      (request) async => request.url.path.endsWith('/members')
          ? await members.future
          : http.Response('{"code":"not_member"}', 403),
    );
    await open(tester, screen(true, chat));
    members.complete(
      http.Response(
        '{"members":[{"userId":"a","displayName":"Private member"}]}',
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Private member'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('late direct poll cannot repaint after forbidden send', (
    tester,
  ) async {
    var reads = 0;
    final lateRead = Completer<http.Response>();
    final chat = service((request) async {
      if (request.method == 'POST') {
        return http.Response('{"code":"blocked"}', 403);
      }
      if (++reads == 1) {
        return http.Response('{"messages":[{"content":"Old archive"}]}', 200);
      }
      return await lateRead.future;
    });
    await open(tester, screen(false, chat));
    await tester.pump(const Duration(seconds: 5));
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    lateRead.complete(
      http.Response('{"messages":[{"content":"Late private data"}]}', 200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Old archive'), findsNothing);
    expect(find.text('Late private data'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
