import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';

class _RecordingApiClient extends BackendApiClient {
  _RecordingApiClient() : super(baseUrl: 'https://example.invalid');

  String? path;
  Map<String, dynamic>? body;

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    this.path = path;
    this.body = body;
    return {
      'text': 'Sichere Antwort',
      'groundingUrls': ['https://example.com/source'],
    };
  }
}

void main() {
  test('sends AI requests through the backend without an API key', () async {
    final client = _RecordingApiClient();
    final service = GeminiAIService(
      modelName: 'gemini-3.5-flash',
      apiClient: client,
    );

    final response = await service.generate(
      'Familienevent suchen',
      useGoogleSearch: true,
    );

    expect(client.path, '/ai/generate');
    expect(client.body?['model'], 'gemini-3.5-flash');
    expect(client.body?['useGoogleSearch'], isTrue);
    expect(client.body?.containsKey('apiKey'), isFalse);
    expect(response.text, 'Sichere Antwort');
    expect(response.groundingUrls, ['https://example.com/source']);
  });
}