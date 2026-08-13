import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:trusted_circle_demo/config/api_config.dart';
import 'package:trusted_circle_demo/logic/gemini_ai_service.dart';

Future<void> main(List<String> args) async {
  await dotenv.load(fileName: '.env');

  final prompt = args.isNotEmpty
      ? args.join(' ')
      : 'Mein 4-jaehriger rastet jeden Morgen aus, wenn wir zur Kita müssen. Ich werde laut und fuehle mich danach schlecht. Was kann ich heute konkret anders machen?';

  final modelName = APIConfig.getGeminiModelName();
  final apiKey = APIConfig.getGeminiApiKey();

  if (apiKey == null || apiKey.isEmpty) {
    print('FEHLER: Kein GEMINI_API_KEY gefunden.');
    return;
  }

  final service = GeminiAIService(apiKey: apiKey, modelName: modelName);
  final buffer = StringBuffer();

  await for (final chunk in service.chatWithStreaming(prompt)) {
    buffer.write(chunk);
  }

  print('--- MODEL ---');
  print(modelName);
  print('--- PROMPT ---');
  print(prompt);
  print('--- RESPONSE ---');
  print(buffer.toString().trim());
}