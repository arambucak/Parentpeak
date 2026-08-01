import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:parentpeak/config/api_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundles dotenv as an asset for runtime loading', () async {
    final dotenvContents = await rootBundle.loadString('.env');

    expect(dotenvContents, contains('GEMINI_API_KEY='));
    expect(dotenvContents, contains('GEMINI_MODEL_NAME='));
  });

  test('loads Gemini config from the bundled dotenv file', () async {
    await dotenv.load(fileName: '.env', isOptional: true);

    final apiKey = APIConfig.getGeminiApiKey();
    final modelName = APIConfig.getGeminiModelName();

    expect(apiKey, isNotNull);
    expect(apiKey, isNotEmpty);
    expect(modelName, isNotEmpty);
  });
}
