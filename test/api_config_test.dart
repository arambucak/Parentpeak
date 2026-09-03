import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:parentpeak/config/api_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundles a placeholder env template (no real secrets)', () async {
    final envContents = await rootBundle.loadString('assets/env.template');

    // The template must expose the expected keys...
    expect(envContents, contains('GEMINI_MODEL_NAME='));
    expect(envContents, contains('BACKEND_API_TOKEN='));

    // ...but must NOT contain any real secret values.
    expect(envContents.contains('pp_live_'), isFalse,
        reason: 'Real backend token must never be bundled.');
    expect(RegExp(r'AIza[A-Za-z0-9_-]{20,}').hasMatch(envContents), isFalse,
        reason: 'Real API keys must never be bundled.');
  });

  test('loads model config from the bundled placeholder template', () async {
    await dotenv.load(fileName: 'assets/env.template', isOptional: true);

    // Model name has a safe default in the template.
    final modelName = APIConfig.getGeminiModelName();
    expect(modelName, isNotEmpty);
  });

  test('release build configuration does not embed backend admin token', () {
    final releaseSources = [
      File('.github/workflows/deploy-web-pages.yml').readAsStringSync(),
      File('RELEASE.md').readAsStringSync(),
    ];

    for (final source in releaseSources) {
      expect(source, isNot(contains('--dart-define=BACKEND_API_TOKEN')));
      expect(source, isNot(contains('--dart-define=GEMINI_API_KEY')));
    }
  });

  test('web release receives admin UIDs from the GitHub variable', () {
    final workflow =
        File('.github/workflows/deploy-web-pages.yml').readAsStringSync();

    expect(workflow, contains('ADMIN_USER_IDS: \${{ vars.ADMIN_USER_IDS }}'));
    expect(workflow, isNot(contains('secrets.ADMIN_USER_IDS')));
    expect('ADMIN_USER_IDS:'.allMatches(workflow), hasLength(1));
    expect('--dart-define=ADMIN_USER_IDS='.allMatches(workflow), hasLength(1));
  });
}
