import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/config/benefit_application_de.dart';
import 'package:parentpeak/config/country_finance_data.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/benefit_guide_agent.dart';
import 'package:parentpeak/logic/benefit_guide_consent.dart';
import 'package:parentpeak/logic/childcare_tax_estimate.dart';
import 'package:parentpeak/logic/family_finance_store.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('childcare illustration applies 80 percent and the per-child cap', () {
    expect(ChildcareTaxEstimate.deductible(0), 0);
    expect(ChildcareTaxEstimate.deductible(1000), 800);
    expect(ChildcareTaxEstimate.deductible(3600), 2880);
    expect(ChildcareTaxEstimate.deductible(6000), 4800);
    expect(ChildcareTaxEstimate.deductible(12000), 4800);
    expect(ChildcareTaxEstimate.source,
        'https://www.gesetze-im-internet.de/estg/__10.html');
  });

  test('childcare illustration rejects invalid annual values', () {
    for (final value in [-1.0, double.nan, double.infinity, -double.infinity]) {
      expect(() => ChildcareTaxEstimate.deductible(value),
          throwsFormatException);
    }
  });

  test('valid annualized monthly input does not exceed the deduction cap', () {
    expect(ChildcareTaxEstimate.deductible(9007199254740991.0 * 12), 4800);
  });

  test('individually verified amounts, conditions and sources stay explicit', () {
    const amounts = {
      'de/kindergeld': ['259'],
      'de/kinderzuschlag': ['297', 'Monat'],
      'de/but': ['195'],
      'de/elterngeld': ['Basis:', '300', '1.800', 'Plus:', '150', '900'],
      'de/unterhaltsvorschuss': ['227', '299', '394', '12–17'],
      'de/pflegegeld': ['347', '599', '800', '990', '2 / 3 / 4 / 5'],
      'at/familienbeihilfe': ['138,40', '148', '171,80', '200,40', '0 / 3 / 10 / 19'],
      'at/kinderabsetzbetrag': ['70,90'],
      'at/kinderbetreuungsgeld': ['17,65', '41,14', '80%', '80,12', '/Tag'],
      'ch/kinderzulage': ['mindestens 215'],
      'ch/ausbildungszulage': ['mindestens 268'],
      'tr/dogum_yardimi': ['einmalig 5.000', '1.500', '5.000', '/Monat'],
      'gb/child_benefit': ['27.05', '17.90', '/week'],
      'gb/universal_credit': ['303.94', '47.94', '6 April 2017'],
      'gb/tax_free_childcare': ['500/3 months', '2,000/year', '1,000/3 months', '4,000/year'],
    };
    final benefits = {
      for (final country in CountryFinanceData.availableCountries)
        for (final benefit in country.benefits)
          '${country.code}/${benefit.id}': benefit,
    };
    for (final entry in amounts.entries) {
      final benefit = benefits[entry.key];
      expect(benefit, isNotNull, reason: entry.key);
      for (final fragment in entry.value) {
        expect(benefit!.amount, contains(fragment), reason: entry.key);
      }
      expect(benefit!.url, startsWith('https://'), reason: entry.key);
    }
    expect(benefits['de/pflegegeld']!.url,
        'https://www.gesetze-im-internet.de/sgb_11/__37.html');
    expect(benefits['de/pflegegeld']!.eligibility, contains('sichergestellt'));
    expect(benefits['de/unterhaltsvorschuss']!.eligibility, contains('zusätzliche'));
    expect(benefits['ch/ausbildungszulage']!.description, contains('15'));
    expect(benefits['tr/dogum_yardimi']!.description, contains('01.01.2025'));
    expect(benefits['tr/dogum_yardimi']!.description, contains('60. Monat'));
    expect(benefits['tr/sed']!.url,
        'https://www.aile.gov.tr/sss/cocuk-hizmetleri-genel-mudurlugu/sed-hizmeti/');
    // The unresolved programme stays unchanged, as explicitly agreed.
    expect(benefits['tr/cocuk_parasi']!.description,
        'Monatliches Kindergeld für Familien.');
    expect(benefits['tr/cocuk_parasi']!.amount, 'einkommensabhängig');
    expect(benefits['tr/cocuk_parasi']!.url, isNull);
    expect(BenefitApplicationDE.pflegegeld.processingTime, contains('25 Arbeitstage'));
    expect(BenefitApplicationDE.pflegegeld.steps.last.description, contains('ein Monat'));
    expect(BenefitApplicationDE.pflegegeld.steps.last.description, contains('drei Monate'));
  });

  test('all four main languages carry corrected facts and no blanket date seal', () {
    for (final language in ['de', 'en', 'tr', 'ku']) {
      String text(String key) => AppStringsManager.getString(language, key);
      expect(text('finance_saving_tip_de'), matches(RegExp(r'4[.,]800')));
      expect(text('finance_tax_deductible_share'), contains('80'));
      expect(text('finance_benefit_de_kinderzuschlag'), contains('297'));
      for (final amount in ['227', '299', '394']) {
        expect(text('finance_benefit_de_unterhaltsvorschuss'), contains(amount));
      }
      for (final amount in ['347', '599', '800', '990']) {
        expect(text('finance_benefit_de_pflegegeld'), contains(amount));
      }
      expect(text('finance_amounts_disclaimer'), isNot(contains('2026')));
      for (final key in [
        'finance_tax_example_limits',
        'finance_orientation_only',
        'finance_save_orientation',
      ]) {
        expect(text(key), isNot(key), reason: '$language/$key');
      }
      expect(text('finance_tax_example_limits'), contains('30'));
      expect(text('finance_tax_example_limits'), contains('14'));
    }
  });

  test('real guide request uses corrected facts without a truth guarantee', () async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.logout();
    final scope = FamilyFinanceStore.instance.scope;
    await BenefitGuideConsent.instance.grant(scope);
    String? prompt;
    final agent = BenefitGuideAgent(
      aiService: GeminiAIService(
        apiClient: BackendApiClient(
          baseUrl: 'https://example.invalid',
          authToken: 'audit-token',
          httpClient: MockClient((request) async {
            prompt = (jsonDecode(request.body) as Map<String, dynamic>)['prompt']
                as String;
            return http.Response(jsonEncode({
              'text': jsonEncode({'checklist': ['Official source check']}),
            }), 200);
          }),
        ),
      ),
    );
    await agent.guide(
      country: CountryFinanceData.germany,
      situation: 'Example family',
      expectedScope: scope,
    );
    expect(prompt, contains('nur teilweise amtlich verifiziert'));
    expect(prompt, contains('keine vollständigen Anspruchsregeln'));
    expect(prompt, isNot(contains('WAHRHEIT')));
    expect(prompt, contains('297'));
    expect(prompt, contains('347 / 599 / 800 / 990'));
    expect(prompt, contains('__37.html'));
  });
}
