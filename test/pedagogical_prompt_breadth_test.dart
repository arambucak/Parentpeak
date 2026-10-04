import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/logic/pedagogical_chat_backend.dart';

/// Zeichnet den an /ai/generate gesendeten Prompt auf, damit wir prüfen können,
/// WELCHE pädagogischen Impulse der Coaching-Prompt situativ mitgibt.
class _RecordingApiClient extends BackendApiClient {
  _RecordingApiClient() : super(baseUrl: 'https://example.invalid');

  final List<String> prompts = [];

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) async {
    prompts.add(body['prompt']?.toString() ?? '');
    // Eine kurze, GfK-konforme, markdownfreie Antwort, die keinen Quality-Retry
    // auslöst (Empathie-Signal + eine Frage + überschaubare Länge).
    return {
      'text': 'Das klingt gerade herausfordernd und das kann es sein, '
          'dass dein Kind Nähe sucht. Du könntest ihm heute eine ruhige Wahl '
          'anbieten und daneben präsent bleiben. '
          'Was passiert bei euch direkt vor dieser Situation?',
      'groundingUrls': <String>[],
    };
  }
}

Future<String> _run(PedagogicalChatBackend backend, String message) async {
  final chunks = await backend
      .streamReply(history: const [], userMessage: message).toList();
  return chunks.join();
}

void main() {
  late _RecordingApiClient client;
  late PedagogicalChatBackend backend;

  setUp(() {
    client = _RecordingApiClient();
    backend = PedagogicalChatBackend(
      geminiService: GeminiAIService(
        modelName: 'gemini-3.5-flash',
        apiClient: client,
      ),
    );
  });

  String firstPrompt() => client.prompts.first.toLowerCase();

  group('Coaching-Prompt — pädagogische Breite', () {
    test('Selbstständigkeits-Thema bringt Montessori/Situationsansatz ein',
        () async {
      await _run(backend,
          'Mein Kind soll sich morgens selbststaendig anziehen, aber ich mache es immer.');
      expect(firstPrompt(), contains('montessori'));
      expect(firstPrompt(), contains('situationsansatz'));
    });

    test('Spiel-/Kreativ-Thema bringt Fröbel/Reggio/Freinet ein', () async {
      await _run(backend,
          'Meinem Kind ist oft langweilig, es will nur spielen und basteln.');
      final p = firstPrompt();
      expect(p, contains('froebel'));
      expect(p, contains('reggio'));
      expect(p, contains('freinet'));
    });

    test('Geschwisterkonflikt bringt Juul (vollwertige Menschen) ein',
        () async {
      await _run(backend,
          'Meine Kinder streiten staendig und hauen sich, Geschwisterkonflikt pur.');
      expect(firstPrompt(), contains('juul'));
    });

    test('Kern bleibt Hüther/GfK (kein Zurückdrehen des Fundaments)', () async {
      await _run(backend, 'Mein Kind hat staendig Wutanfälle und schreit.');
      final p = firstPrompt();
      expect(p, contains('hüther'));
      expect(p, contains('gfk'));
    });

    test('Allgemeine Frage bietet die Linsen-Auswahl als Option an', () async {
      await _run(backend, 'Wie kann ich meinem Kind mehr Sicherheit geben?');
      final p = firstPrompt();
      // Optionaler Impuls-Abschnitt ist vorhanden und nennt die Vielfalt.
      expect(p, contains('optional'));
      expect(p, contains('montessori'));
    });
  });
}
