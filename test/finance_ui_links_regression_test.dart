import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parentpeak/config/benefit_application_de.dart';
import 'package:parentpeak/config/country_finance_data.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/finance_content.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/benefit_guide_agent.dart';
import 'package:parentpeak/logic/benefit_guide_consent.dart';
import 'package:parentpeak/logic/family_finance_store.dart';
import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/ui/antragshelfer_screen.dart';
import 'package:parentpeak/ui/benefit_guide_screen.dart';
import 'package:parentpeak/ui/familien_geld_screen.dart';
import 'package:parentpeak/ui/widgets/finance_link_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('four-language guide, application, links and iPad sharing flows', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() => AuthService.instance.logout());
    final store = FamilyFinanceStore.instance;
    await BenefitGuideConsent.instance.grant(store.scope);
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const urlChannel = MethodChannel('plugins.flutter.io/url_launcher');
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    var throwLink = false;
    var throwShare = false;
    var throwCopy = false;
    Completer<bool>? pendingLink;
    Map<String, dynamic>? shared;
    final openedUrls = <String>[];
    messenger.setMockMethodCallHandler(urlChannel, (call) async {
      if (call.method == 'launch') {
        openedUrls.add((call.arguments as Map)['url'] as String);
        if (throwLink) throw PlatformException(code: 'launch-failed');
        if (pendingLink != null) return pendingLink.future;
        return false;
      }
      return true;
    });
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      if (call.method == 'share') {
        shared = Map<String, dynamic>.from(call.arguments as Map);
        if (throwShare) throw PlatformException(code: 'share-failed');
        return 'dev.fluttercommunity.plus/share/unavailable';
      }
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData' && throwCopy) {
        throw PlatformException(code: 'copy-failed');
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(urlChannel, null);
      messenger.setMockMethodCallHandler(shareChannel, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    Future<void> settle() async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
    }

    Future<void> open(Widget screen, String language) async {
      await tester.pumpWidget(MaterialApp(
        key: UniqueKey(), locale: Locale(language),
        supportedLocales: const [Locale('de'), Locale('en'), Locale('tr'), Locale('ku')],
        localizationsDelegates: const [
          AppLanguages.materialLocalizationsDelegate,
          AppLanguages.widgetsLocalizationsDelegate,
          AppLanguages.cupertinoLocalizationsDelegate,
        ],
        home: screen,
      ));
      await settle();
    }

    String tr(String language, String key) => AppStringsManager.getString(language, key);
    Map<String, dynamic>? requestBody;
    GeminiAIService ai(String text) => GeminiAIService(
      apiClient: BackendApiClient(
        baseUrl: 'https://example.invalid', authToken: 'audit-token',
        httpClient: MockClient((request) async {
          requestBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'text': text}), 200);
        }),
      ),
    );

    const documentNames = {
      'de': 'Geburtsurkunde des Kindes', 'en': 'Child’s birth certificate',
      'tr': 'Çocuğun doğum belgesi', 'ku': 'Belgeya zayîna zarokî',
    };
    for (final language in documentNames.keys) {
      await open(BenefitGuideScreen(
        country: CountryFinanceData.austria,
        agent: BenefitGuideAgent(aiService: ai('invalid JSON')),
      ), language);
      expect(find.text(tr(language, 'benefit_chip_single')), findsOneWidget);
      await tester.tap(find.text(tr(language, 'benefit_chip_single')));
      await tester.ensureVisible(find.text(tr(language, 'benefit_ask_action')));
      await tester.tap(find.text(tr(language, 'benefit_ask_action')));
      await settle();
      expect(requestBody!['language'], language);
      expect(requestBody!['prompt'], contains(tr(language, 'benefit_chip_single')));
      expect(requestBody!['prompt'], contains('Alleinerziehend: ja'));
      expect(find.text(tr(language, 'benefit_fallback_notice')), findsOneWidget);
      expect(find.text(tr(language, 'benefit_fallback_check')), findsOneWidget);
      expect(find.text('Prüfe die verlinkten offiziellen Stellen für die Details.'),
          language == 'de' ? findsOneWidget : findsNothing);
      final link = find.text(tr(language, 'benefit_check_link')).first;
      await tester.ensureVisible(link);
      await tester.tap(link);
      await settle();
      expect(find.text(tr(language, 'finance_link_open_failed')), findsOneWidget);
      for (final detector in tester.widgetList<GestureDetector>(find.byType(GestureDetector))) {
        if (detector.onTap != null) expect(detector.behavior, HitTestBehavior.opaque);
      }

      await open(AntragshelferScreen(
        benefit: BenefitApplicationDE.kindergeld, aiService: ai('Example template'),
      ), language);
      expect(find.text(documentNames[language]!), findsOneWidget);
      expect(find.text(tr(language, 'antrag_documents_tab')), findsOneWidget);
      expect(find.text(tr(language, 'antrag_content_limits')), findsOneWidget);
      final checkbox = find.byType(CheckboxListTile).first;
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await settle();
      expect(tester.widget<CheckboxListTile>(checkbox).value, isTrue);
      await tester.tap(checkbox);
      await settle();
      expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
      await tester.tap(find.text(tr(language, 'antrag_guide_tab')));
      await settle();
      final applicationLink = find.text(tr(language, 'antrag_open_link')).first;
      await tester.ensureVisible(applicationLink);
      throwLink = true;
      await tester.tap(applicationLink);
      await settle();
      throwLink = false;
      expect(find.text(tr(language, 'finance_link_open_failed')), findsOneWidget);
      await tester.tap(find.text(tr(language, 'antrag_ai_tab')));
      await settle();
      await tester.tap(find.byType(FilledButton).first);
      await settle();
      expect(requestBody!['language'], language);
      expect(requestBody!['systemInstruction'], contains('Write the template in'));
      expect(find.text('Example template'), findsOneWidget);
      expect(find.text(tr(language, 'antrag_ai_disclaimer')), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await settle();
      await tester.tap(find.byIcon(Icons.copy_rounded));
      await settle();
      expect(find.text(tr(language, 'antrag_copied')), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await settle();
      throwCopy = true;
      await tester.tap(find.byIcon(Icons.copy_rounded));
      await settle();
      throwCopy = false;
      expect(find.text(tr(language, 'antrag_copy_failed')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => store.write({
        FamilyFinanceStore.countryKey: 'tr',
        FamilyFinanceStore.amountsKey: {'kita': 0.0},
      }, expectedScope: store.scope));
      await open(FamilienGeldScreen(store: store), language);
      await tester.tap(find.text(tr(language, 'finance_tab_benefits')));
      await settle();
      expect(find.text(financeContent('Monatliches Kindergeld für Familien.', language)), findsOneWidget);
      await tester.tap(find.text(tr(language, 'finance_tab_milestones')));
      await settle();
      expect(find.text(financeContent('Canta, kirtasiye, forma', language)), findsOneWidget);
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => store.write({
      FamilyFinanceStore.countryKey: 'at',
      FamilyFinanceStore.amountsKey: {'kita': 10.0},
    }, expectedScope: store.scope));
    await open(FamilienGeldScreen(store: store), 'en');
    final buttonRect = tester.getRect(find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Share overview',
    ));
    await tester.tap(find.byTooltip('Share overview'));
    await settle();
    expect(shared!['text'], contains('Family Allowance (Familienbeihilfe)'));
    expect(shared!['text'], contains('70.90'));
    expect(shared!['originX'], buttonRect.left);
    expect(shared!['originY'], buttonRect.top);
    expect(shared!['originWidth'], buttonRect.width);
    expect(shared!['originHeight'], buttonRect.height);
    throwShare = true;
    await tester.tap(find.byTooltip('Share overview'));
    await settle();
    expect(find.text('Could not share the overview. Please try again.'), findsOneWidget);

    await open(Scaffold(body: Builder(builder: (context) => TextButton(
      onPressed: () => openFinanceLink(context, 'javascript:alert(1)'),
      child: const Text('Invalid link'),
    ))), 'en');
    final count = openedUrls.length;
    await tester.tap(find.text('Invalid link'));
    await settle();
    expect(openedUrls.length, count);
    expect(find.text(tr('en', 'finance_link_open_failed')), findsOneWidget);
    pendingLink = Completer<bool>();
    await open(Scaffold(body: Builder(builder: (context) => TextButton(
      onPressed: () => openFinanceLink(context, 'https://www.gov.uk/tax-free-childcare'),
      child: const Text('Delayed link'),
    ))), 'en');
    await tester.tap(find.text('Delayed link'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pendingLink.complete(false);
    await settle();
    expect(tester.takeException(), isNull);
  });
}
