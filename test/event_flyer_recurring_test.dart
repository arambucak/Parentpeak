import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/event_flyer_scanner_service.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';

class _FakeGemini extends GeminiAIService {
  _FakeGemini(this.result);

  final String result;

  @override
  Future<GeminiProxyResponse> generate(
    String prompt, {
    String? systemInstruction,
    bool useGoogleSearch = false,
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
    String? appLanguage,
  }) async => GeminiProxyResponse(text: result, groundingUrls: const []);
}

void main() {
  test('keeps an explicitly stated recurring offer in the editable draft', () async {
    final scanner = EventFlyerScannerService(
      gemini: _FakeGemini(
        '{"title":"Spielgruppe","description":"Für Familien",'
        '"recurringNote":"jeden Dienstag um 15 Uhr"}',
      ),
    );
    final draft = await scanner.scanFromText('Spielgruppe jeden Dienstag um 15 Uhr');
    expect(draft?.recurringNote, 'jeden Dienstag um 15 Uhr');
  });

  test('does not label a one-off event as recurring', () async {
    final scanner = EventFlyerScannerService(
      gemini: _FakeGemini('{"title":"Fest","recurringNote":null}'),
    );
    final draft = await scanner.scanFromText('Fest am 3. Oktober');
    expect(draft?.recurringNote, isNull);
  });

  test('recurrence confirmation is translated in target languages', () {
    for (final locale in ['de', 'en', 'tr', 'ku']) {
      expect(AppStringsManager.getString(locale, 'event_scan_recurring_confirm'),
          isNot('event_scan_recurring_confirm'));
    }
  });
}