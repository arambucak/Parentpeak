import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/chat_account_store.dart';
import 'package:parentpeak/logic/chat_ai_consent.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/logic/pedagogical_chat_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<List<Map<String, dynamic>>> send(
    String introduced,
    String followUp, {
    bool retry = false,
    String? assistantHistory,
  }) async {
    final store = ChatAccountStore(userIdProvider: () => 'privacy');
    final consent = ChatAiConsent(scopeProvider: () => store.scope);
    await consent.grant(store.scope);
    final requests = <Map<String, dynamic>>[];
    final backend = PedagogicalChatBackend(
      accountStore: store,
      consent: consent,
      geminiService: GeminiAIService(
        apiClient: BackendApiClient(
          baseUrl: 'https://example.invalid',
          httpClient: MockClient((request) async {
            requests.add(
              Map<String, dynamic>.from(jsonDecode(request.body) as Map),
            );
            return http.Response(
              jsonEncode({
                'text': retry && requests.length == 1
                    ? 'Try a quiet routine.'
                    : 'Das klingt gerade herausfordernd. Du könntest beim Einschlafen abends '
                          'eine ruhige Wahl anbieten und daneben präsent bleiben. '
                          'Was passiert bei euch direkt vor dieser Situation?',
              }),
              200,
            );
          }),
        ),
      ),
    );
    try {
      await backend
          .streamReply(
            history: [
              {'role': 'user', 'content': introduced},
              {
                'role': 'assistant',
                'content': assistantHistory ?? 'We can support a calm routine.',
              },
              {'role': 'user', 'content': followUp},
            ],
            userMessage: followUp,
          )
          .toList();
      return requests;
    } finally {
      store.dispose();
    }
  }

  test(
    'German lowercase relation cannot reintroduce Max as bare history anchor',
    () async {
      final requests = await send(
        'mein sohn Max ist 3 Jahre alt und braucht beim Einschlafen Begleitung.',
        'Wie begleiten wir das Einschlafen abends?',
      );

      expect(requests, isNotEmpty);
      for (final body in requests) {
        expect(RegExp(r'\bMax\b').hasMatch(jsonEncode(body)), isFalse);
        expect(body['prompt'], contains('[KINDNAME]'));
        expect(body['prompt'], contains('3 jahre'));
      }
    },
  );

  test(
    'English introduced child name and later bare references stay private',
    () async {
      final requests = await send(
        'My daughter Ada has eczema. She is 3 years old.',
        'Ada needs support at bedtime. How can we help?',
      );
      expect(requests, isNotEmpty);
      for (final body in requests) {
        expect(jsonEncode(body), isNot(contains('Ada')));
        expect(body['prompt'], contains('[KINDNAME]'));
        expect(body['prompt'], contains('eczema'));
        expect(body['prompt'], contains('3 years old'));
      }
    },
  );

  test('recognized names and assistant history stay private in repair requests', () async {
    for (final input in <String, String>{
      'Mein Kind Élodie hat abends Probleme beim Einschlafen.': 'Élodie',
      'My daughter Ada needs bedtime support.': 'Ada',
      'Kızım İpek uyumuyor.': 'İpek',
      'Zarokê min Aram şevê naxewê.': 'Aram',
    }.entries) {
      final requests = await send(input.key, 'Wie begleiten wir das Einschlafen abends?',
        retry: true, assistantHistory: '${input.value} might need support.');
      expect(requests.length, greaterThan(1));
      for (final body in requests) {
        expect(jsonEncode(body), isNot(contains(input.value)));
        expect(body['prompt'], contains('[KINDNAME]'));
      }
    }
  });

  test('first current message introduces name without requiring saved history', () async {
    final requests = await send('', 'My daughter Ada needs support at bedtime.');
    expect(requests, isNotEmpty);
    expect(requests.every((body) => !jsonEncode(body).contains('Ada')), isTrue);
  });
}
