import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/chat_ai_consent.dart';
import 'package:parentpeak/logic/chat_context_policy.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/logic/pedagogical_chat_backend.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Map<String, String>> round(String text) => [
  {'role': 'user', 'content': text},
  {'role': 'assistant', 'content': 'Answer $text'},
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'at most six complete rounds, no orphan assistant, original unchanged',
    () {
      final history = [
        {'role': 'assistant', 'content': 'Orphan'},
        for (var i = 0; i < 8; i++) ...round('Round $i'),
      ];
      final copy = jsonEncode(history);
      final result = ChatContextPolicy.limitHistory(history);
      expect(result.length, 12);
      expect(result.first['content'], 'Round 2');
      expect(result.last['content'], 'Answer Round 7');
      expect(jsonEncode(history), copy);
    },
  );

  test(
    'exact 12000 character boundary includes entire round, one more excludes it',
    () {
      for (final size in [11999, 12000, 12001]) {
        final result = ChatContextPolicy.limitHistory([
          {'role': 'user', 'content': 'u'},
          {'role': 'assistant', 'content': 'a' * (size - 1)},
        ]);
        expect(result.length, size <= 12000 ? 2 : 0);
      }
    },
  );

  test(
    'never clips messages or skips an oversized recent round to send stale context',
    () {
      final result = ChatContextPolicy.limitHistory([
        ...round('Old context'),
        {'role': 'user', 'content': 'q' * 12001},
      ]);
      expect(result, isEmpty);
      final bounded = ChatContextPolicy.limitHistory([
        ...round('old' * 3900),
        ...round('new'),
      ]);
      expect(bounded, round('new'));
    },
  );

  test(
    'completed age respects birthday, no cap, no default or future date',
    () {
      ChildEntry child(DateTime birth) =>
          ChildEntry(name: 'Private', birthDate: birth);
      expect(ChatContextPolicy.completedAge(null), isNull);
      expect(
        ChatContextPolicy.completedAge(
          child(DateTime(2023, 10, 8)),
          now: DateTime(2026, 10, 7),
        ),
        2,
      );
      expect(
        ChatContextPolicy.completedAge(
          child(DateTime(2023, 10, 8)),
          now: DateTime(2026, 10, 8),
        ),
        3,
      );
      expect(
        ChatContextPolicy.completedAge(
          child(DateTime(2026, 10, 8)),
          now: DateTime(2026, 10, 7),
        ),
        isNull,
      );
      expect(
        ChatContextPolicy.completedAge(
          child(DateTime(2008, 10, 8)),
          now: DateTime(2026, 10, 8),
        ),
        18,
      );
      expect(
        ChatContextPolicy.completedAge(
          child(DateTime(2026, 10, 8)),
          now: DateTime(2026, 10, 8),
        ),
        0,
      );
    },
  );

  test(
    'tip prompt is localized and unknown age is explicit, no clear name or DOB',
    () {
      for (final language in ['de', 'en', 'tr', 'ku']) {
        final unknown = ChatContextPolicy.tipPrompt('MY_TIP', language, null);
        final known = ChatContextPolicy.tipPrompt('MY_TIP', language, 2);
        expect(unknown, contains('MY_TIP'));
        expect(known, contains('2'));
        expect(unknown, isNot(contains('null')));
        expect(unknown, isNot(contains('3')));
        expect(unknown, isNot(contains('{ageContext}')));
        if (language != 'de') expect(unknown, isNot(contains('Die Eltern')));
      }
    },
  );

  test(
    'actual HTTP uses recent context only, question once, known names remain neutral across boundary',
    () async {
      SharedPreferences.setMockInitialValues({});
      final consent = ChatAiConsent(scopeProvider: () => 'account.history');
      await consent.grant(consent.scope);
      final requests = <Map<String, dynamic>>[];
      final backend = PedagogicalChatBackend(
        consent: consent,
        geminiService: GeminiAIService(
          apiClient: BackendApiClient(
            baseUrl: 'https://example.invalid',
            httpClient: MockClient((request) async {
              requests.add(jsonDecode(request.body) as Map<String, dynamic>);
              return http.Response(
                jsonEncode({
                  'text':
                      'Das klingt gerade herausfordernd. Du könntest beim Einschlafen abends eine ruhige Wahl anbieten und daneben präsent bleiben. Was passiert bei euch direkt vor dieser Situation?',
                }),
                200,
              );
            }),
          ),
        ),
      );
      const question = 'Wie begleiten wir das Einschlafen abends?';
      await backend
          .streamReply(
            history: [
              ...round('mein sohn Max ist 3 Jahre alt OLD_CONTEXT'),
              ...round('OLD_CONTEXT_2'),
              for (var i = 0; i < 6; i++)
                ...round('Max fragt zu NEW_CONTEXT_$i'),
              {'role': 'user', 'content': question},
            ],
            userMessage: question,
          )
          .toList();
      expect(requests, isNotEmpty);
      final prompt = requests.first['prompt'] as String;
      expect(prompt, isNot(contains('OLD_CONTEXT')));
      expect(RegExp(r'\bMax\b').hasMatch(prompt), isFalse);
      expect(prompt, contains('[KINDNAME]'));
      expect(prompt, contains('NEW_CONTEXT_0'));
      expect(prompt.split(question).length - 1, 1);
    },
  );
}
