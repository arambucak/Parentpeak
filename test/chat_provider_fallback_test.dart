import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/account_ai_consent.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/chat_ai_consent.dart';
import 'package:parentpeak/logic/chat_provider_exception.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/logic/pedagogical_chat_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _question = 'Wie begleiten wir das Einschlafen abends?';
const _answer =
    'Das klingt gerade herausfordernd. Du könntest beim Einschlafen abends eine ruhige Wahl anbieten und daneben präsent bleiben. Die Seiten 401, 403 und 429 zeigen Beispiele. Was passiert bei euch direkt vor dieser Situation?';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ChatAiConsent consent;
  late GeminiAIService service;
  late PedagogicalChatBackend backend;
  late List<Map<String, dynamic>> requests;
  late Future<http.Response> Function(http.Request) respond;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    consent = ChatAiConsent(scopeProvider: () => 'account.provider');
    await consent.grant(consent.scope);
    requests = [];
    respond = (_) async => http.Response(jsonEncode({'text': _answer}), 200);
    service = GeminiAIService(
      apiClient: BackendApiClient(
        baseUrl: 'https://example.invalid',
        httpClient: MockClient((request) {
          requests.add(jsonDecode(request.body) as Map<String, dynamic>);
          return respond(request);
        }),
      ),
    );
    backend = PedagogicalChatBackend(consent: consent, geminiService: service);
  });

  Future<String> reply({String language = 'de'}) async =>
      (await backend
              .streamReply(
                history: const [],
                userMessage: _question,
                languageCode: language,
              )
              .toList())
          .join();

  test('normal reply with 401/403/429 is not an HTTP error', () async {
    expect(await reply(), _answer);
    expect(requests, hasLength(1));
  });

  for (final status in [401, 403, 429, 502]) {
    test(
      'HTTP $status gives typed provider failure and never sends raw server text to user',
      () async {
        respond = (_) async => http.Response(
          '{"error":"Private user echo SECRET_NAME 401"}',
          status,
        );
        await expectLater(
          service.chatWithHistory([
            {'role': 'user', 'content': _question},
          ]),
          throwsA(isA<ChatProviderException>()),
        );
        requests.clear();
        for (final language in ['de', 'en', 'tr', 'ku']) {
          final result = await reply(language: language);
          expect(
            result,
            startsWith(
              AppStringsManager.getString(
                language,
                'chat_provider_unavailable',
              ),
            ),
          );
          expect(result, isNot(contains('SECRET_NAME')));
          expect(result, isNot(contains('Debug:')));
          expect(requests.last['language'], language);
        }
        expect(requests, hasLength(4));
      },
    );
  }

  test(
    'empty, non-string and malformed responses fail visibly, not success-shaped',
    () async {
      for (final body in [
        '{"text":""}',
        '{"text":42}',
        '{"text":{"name":"SECRET_NAME"}}',
        'not-json',
      ]) {
        respond = (_) async => http.Response(body, 200);
        final result = await reply(language: 'en');
        expect(result, contains('No valid personal reply'));
        expect(result, isNot(contains('SECRET_NAME')));
      }
    },
  );

  test('network and timeout give localized safe fallback', () async {
    for (final error in [
      http.ClientException('PRIVATE_NETWORK_DATA'),
      TimeoutException('PRIVATE_TIMEOUT_DATA'),
    ]) {
      respond = (_) async => throw error;
      final result = await reply(language: 'tr');
      expect(
        result,
        contains(AppStringsManager.getString('tr', 'chat_provider_network')),
      );
      expect(result, isNot(contains('PRIVATE')));
    }
  });

  test(
    'failed quality retry reports unavailable, never pretends prior fragment is personal success',
    () async {
      respond = (_) async => requests.length == 1
          ? http.Response('{"text":"Short fragment."}', 200)
          : http.Response('{"error":"PRIVATE_RETRY"}', 502);
      final result = await reply(language: 'en');
      expect(requests, hasLength(2));
      expect(result, contains('No valid personal reply'));
      expect(result, isNot(contains('Short fragment')));
    },
  );

  test(
    'revoked consent on failed HTTP still propagates privacy boundary instead of fallback',
    () async {
      respond = (_) async {
        await (await SharedPreferences.getInstance()).remove(
          'chat.ai_consent.v1.${consent.scope}',
        );
        return http.Response('{"error":"Failed"}', 502);
      };
      await expectLater(
        reply(),
        throwsA(isA<AccountAiConsentRequiredException>()),
      );
      expect(requests, hasLength(1));
    },
  );
}
