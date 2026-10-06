import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/config/benefit_application_de.dart';
import 'package:parentpeak/config/country_finance_data.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/finance_content.dart';
import 'package:parentpeak/l10n/finance_content_keys.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/benefit_guide_agent.dart';
import 'package:parentpeak/logic/benefit_guide_consent.dart';
import 'package:parentpeak/logic/finance_link_policy.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all curated application and non-DE content is covered in four languages',
    () {
      final sources = <String>{};
      for (final application in BenefitApplicationDE.allBenefits) {
        sources.addAll([
          application.benefitName,
          application.responsibleAuthority,
          application.processingTime,
          if (application.renewalNote != null) application.renewalNote!,
          if (application.proTip != null) application.proTip!,
          if (application.aiTemplatePrompt != null)
            application.aiTemplatePrompt!,
          for (final doc in application.documents) ...[
            doc.name,
            if (doc.whereToGet != null) doc.whereToGet!,
          ],
          for (final step in application.steps) ...[
            step.title,
            step.description,
          ],
        ]);
      }
      for (final country in CountryFinanceData.availableCountries.where(
        (c) => c.code != 'de',
      )) {
        sources.addAll([
          for (final benefit in country.benefits) ...[
            benefit.name,
            benefit.description,
            if (benefit.amount != null) benefit.amount!,
            if (benefit.eligibility != null) benefit.eligibility!,
          ],
          for (final milestone in country.milestones)
            if (milestone.note != null) milestone.note!,
        ]);
      }
      for (final source in sources) {
        final key = financeContentKeys[source];
        expect(key, isNotNull, reason: 'Unlocalized curated source: $source');
        for (final language in ['de', 'en', 'tr', 'ku']) {
          final value = AppStringsManager.getString(language, key!);
          expect(value, isNot(key), reason: '$language/$key');
          expect(value.trim(), isNotEmpty);
        }
      }
      expect(
        financeContent('Canta, kirtasiye, forma', 'en'),
        'Bag, stationery, uniform',
      );
      expect(
        financeContent('Canta, kirtasiye, forma', 'de'),
        'Schultasche, Schreibwaren, Uniform',
      );
      expect(
        financeContent('Weekly payment for each child.', 'de'),
        'Wöchentliche Zahlung für jedes Kind.',
      );
      expect(
        financeContent('Uniform, bag, shoes, stationery', 'tr'),
        'Üniforma, çanta, ayakkabı, kırtasiye',
      );
      expect(
        financeContent('Canta, kirtasiye, forma', 'fr'),
        financeContent('Canta, kirtasiye, forma', 'en'),
      );
    },
  );

  test(
    'localization preserves application URLs, order, optionals and numbers',
    () {
      for (final application in BenefitApplicationDE.allBenefits) {
        for (final language in ['de', 'en', 'tr', 'ku']) {
          final translated = localizedFinanceApplication(application, language);
          if (language == 'de') {
            expect(translated.processingTime, application.processingTime);
            expect(
              translated.steps.map((s) => s.description),
              application.steps.map((s) => s.description),
            );
            expect(
              translated.documents.map((d) => d.name),
              application.documents.map((d) => d.name),
            );
          }
          expect(translated.benefitId, application.benefitId);
          expect(
            translated.onlineApplicationUrl,
            application.onlineApplicationUrl,
          );
          expect(translated.documents.length, application.documents.length);
          for (var i = 0; i < application.documents.length; i++) {
            expect(
              translated.documents[i].isOptional,
              application.documents[i].isOptional,
            );
            expect(
              translated.documents[i].whereToGet == null,
              application.documents[i].whereToGet == null,
            );
          }
          expect(
            translated.steps.map((s) => s.url),
            application.steps.map((s) => s.url),
          );
          expect(
            translated.steps.map((s) => s.stepNumber),
            application.steps.map((s) => s.stepNumber),
          );
          final numbers = RegExp(r'\d+');
          expect(
            numbers
                .allMatches(translated.processingTime)
                .map((m) => m.group(0)),
            numbers
                .allMatches(application.processingTime)
                .map((m) => m.group(0)),
          );
        }
      }
    },
  );

  test(
    'finance URLs require HTTPS without credentials or nonstandard ports',
    () {
      for (final invalid in [
        'javascript:alert(1)',
        'http://www.gov.uk/',
        '//www.gov.uk/',
        'https://www.gov.uk@evil.invalid/',
        'https://www.gov.uk:444/',
      ]) {
        expect(FinanceLinkPolicy.isHttps(invalid), isFalse, reason: invalid);
      }
      final official = CountryFinanceData.uk.benefits.first.url!;
      expect(
        FinanceLinkPolicy.isCurated(official, CountryFinanceData.uk),
        isTrue,
      );
      for (final invalid in [
        '$official?redirect=https://evil.invalid',
        'https://www.gov.uk.evil.invalid/child-benefit/what-youll-get',
        'https://evil.invalid/?next=$official',
      ]) {
        expect(
          FinanceLinkPolicy.isCurated(invalid, CountryFinanceData.uk),
          isFalse,
        );
      }
    },
  );

  late BenefitGuideConsent consent;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    consent = BenefitGuideConsent(scopeProvider: () => 'guest');
  });

  GeminiAIService ai(
    Map<String, dynamic> response, {
    void Function(Map<String, dynamic>)? capture,
  }) => GeminiAIService(
    apiClient: BackendApiClient(
      baseUrl: 'https://example.invalid',
      authToken: 'audit-token',
      httpClient: MockClient((request) async {
        capture?.call(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(jsonEncode(response), 200);
      }),
    ),
  );

  for (final entry in {
    'de': 'German',
    'en': 'English',
    'tr': 'Turkish',
    'ku': 'Kurmanji Kurdish',
  }.entries) {
    test(
      'guide uses ${entry.key} and a localized marked fallback for invalid JSON',
      () async {
        await consent.grant('guest');
        Map<String, dynamic>? body;
        final result =
            await BenefitGuideAgent(
              consent: consent,
              aiService: ai({
                'text': 'invalid JSON',
              }, capture: (value) => body = value),
            ).guide(
              country: CountryFinanceData.austria,
              situation: 'Example',
              expectedScope: 'guest',
              languageCode: entry.key,
            );
        expect(body!['language'], entry.key);
        expect(
          body!['systemInstruction'],
          contains('Respond in ${entry.value}'),
        );
        expect(body!['systemInstruction'], contains('Return only valid JSON'));
        expect(body!['prompt'], isNot(contains('Antworte auf Deutsch')));
        expect(result.isFallback, isTrue);
        expect(
          result.matched.length,
          CountryFinanceData.austria.benefits.length,
        );
        expect(
          result.nextSteps.first,
          AppStringsManager.getString(entry.key, 'benefit_fallback_check'),
        );
        expect(
          result.matched.first.name,
          financeContent('Familienbeihilfe', entry.key),
        );
      },
    );
  }

  test(
    'known IDs use curated names/URLs; unknown and cross-country IDs are discarded',
    () async {
      await consent.grant('guest');
      final official = CountryFinanceData.germany.benefits.first.url!;
      final result =
          await BenefitGuideAgent(
            consent: consent,
            aiService: ai({
              'text':
                  '```json\n${jsonEncode({
                    'matched': [
                      {'benefitId': 'kindergeld', 'name': '', 'url': 'https://evil.invalid'},
                      {'benefitId': 'unknown', 'name': 'Invented benefit', 'url': official},
                      {'benefitId': 'child_benefit', 'name': 'Wrong country', 'url': 'https://www.gov.uk/'},
                    ],
                  })}\n```',
              'groundingUrls': [
                official,
                official,
                '$official?redirect=evil',
                'https://evil.invalid',
              ],
            }),
          ).guide(
            country: CountryFinanceData.germany,
            situation: 'Example',
            expectedScope: 'guest',
            languageCode: 'en',
          );
      expect(result.isFallback, isFalse);
      expect(result.matched, hasLength(1));
      expect(result.matched.single.name, 'Child Benefit');
      expect(result.matched.single.url, official);
      expect(result.sources, [official]);
    },
  );

  test(
    'a known benefit without a curated URL never inherits an AI URL',
    () async {
      await consent.grant('guest');
      final result =
          await BenefitGuideAgent(
            consent: consent,
            aiService: ai({
              'text': jsonEncode({
                'matched': [
                  {
                    'benefitId': 'cocuk_parasi',
                    'name': 'Cocuk Parasi',
                    'url': 'https://evil.invalid',
                  },
                ],
              }),
            }),
          ).guide(
            country: CountryFinanceData.turkey,
            situation: 'Example',
            expectedScope: 'guest',
            languageCode: 'en',
          );
      expect(result.isFallback, isFalse);
      expect(result.matched.single.benefitId, 'cocuk_parasi');
      expect(result.matched.single.url, isEmpty);
    },
  );

  test(
    'an unusable unknown-only answer returns general country guidance',
    () async {
      await consent.grant('guest');
      final result =
          await BenefitGuideAgent(
            consent: consent,
            aiService: ai({
              'text': jsonEncode({
                'matched': [
                  {
                    'benefitId': 'unknown',
                    'name': 'Invented',
                    'url': 'https://evil.invalid',
                  },
                ],
              }),
            }),
          ).guide(
            country: CountryFinanceData.uk,
            situation: 'Example',
            expectedScope: 'guest',
            languageCode: 'en',
          );
      expect(result.isFallback, isTrue);
      expect(
        result.matched.map((b) => b.benefitId),
        CountryFinanceData.uk.benefits.map((b) => b.id),
      );
    },
  );
}
