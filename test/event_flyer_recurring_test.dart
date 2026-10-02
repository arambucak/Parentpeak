import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/logic/event_flyer_scanner_service.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';

class _FakeGemini extends GeminiAIService {
  _FakeGemini(this.result);

  final String result;
  String? lastPrompt;

  @override
  Future<GeminiProxyResponse> generate(
    String prompt, {
    String? systemInstruction,
    bool useGoogleSearch = false,
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
    String? appLanguage,
  }) async {
    lastPrompt = prompt;
    return GeminiProxyResponse(text: result, groundingUrls: const []);
  }
}

void main() {
  test('until date without an occurrence stays unknown with its stated time',
      () async {
    final gemini = _FakeGemini(
      '{"title":"Theater","date":null,"time":"10:00","recurringNote":null}',
    );
    final draft = await EventFlyerScannerService(gemini: gemini)
        .scanFromText('Theater Bis14.01.2027 10:00');
    expect(draft?.date, isNull);
    expect(draft?.time?.hour, 10);
    expect(draft?.recurringNote, isNull);
    expect(gemini.lastPrompt, contains('date=null bei Zeiträumen'));
    expect(
        gemini.lastPrompt, contains('Enddatum ist kein Veranstaltungstermin'));
    expect(gemini.lastPrompt, contains('nicht den nächsten Termin berechnen'));
    expect(gemini.lastPrompt, contains('Enddaten sind keine Wiederholung'));
  });

  test('image scans use the same conservative extraction rules', () async {
    final gemini = _FakeGemini('{"title":"Theater","date":null}');
    final draft = await EventFlyerScannerService(gemini: gemini)
        .scanFromImage(Uint8List.fromList([1, 2]));
    expect(draft?.date, isNull);
    expect(gemini.lastPrompt, contains('date=null bei Zeiträumen'));
  });

  test(
      'parser rejects ranges, end labels, normalized invalid days and timestamps',
      () async {
    for (final date in [
      'bis 2027-01-14',
      '2026-10-02 bis 2027-01-14',
      '2027-02-30',
      '2027-01-14T10:00:00Z'
    ]) {
      final draft = await EventFlyerScannerService(
        gemini: _FakeGemini(
            '{"title":"Theater","date":"$date","time":"10:00 bis 12:00"}'),
      ).scanFromText('Theater');
      expect(draft?.date, isNull, reason: date);
      expect(draft?.time, isNull);
    }
    final draft = await EventFlyerScannerService(
      gemini: _FakeGemini('{"date":"2027-01-14","time":"10:00"}'),
    ).scanFromText('Bestätigt am 14.01.2027 um 10:00');
    expect(draft?.date, DateTime(2027, 1, 14));
    expect(draft?.time?.hour, 10);
  });

  test('confirmation keys have static launch translations and English fallback',
      () {
    for (final key in [
      'event_scan_choose_date',
      'event_scan_date_required',
      'event_scan_time_required',
      'event_scan_datetime_required'
    ]) {
      for (final locale in ['de', 'en', 'tr', 'ku']) {
        expect(AppStringsManager.allStrings[locale]![key], isNotEmpty);
      }
      expect(AppStringsManager.getString('fr', key),
          AppStringsManager.allStrings['en']![key]);
    }
  });

  test('keeps an explicitly stated recurring offer in the editable draft',
      () async {
    final scanner = EventFlyerScannerService(
      gemini: _FakeGemini(
        '{"title":"Spielgruppe","description":"Für Familien",'
        '"recurringNote":"jeden Dienstag um 15 Uhr"}',
      ),
    );
    final draft =
        await scanner.scanFromText('Spielgruppe jeden Dienstag um 15 Uhr');
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
      expect(
          AppStringsManager.getString(locale, 'event_scan_recurring_confirm'),
          isNot('event_scan_recurring_confirm'));
    }
  });
}
