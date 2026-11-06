import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:parentpeak/l10n/app_localizations.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/family_finance_store.dart';
import 'package:parentpeak/logic/family_hub_store.dart';
import 'package:parentpeak/models/kind_dossier.dart';
import 'package:parentpeak/models/family_recipe.dart';
import 'package:parentpeak/services/feature_quota_service.dart';
import 'package:parentpeak/logic/chat_account_store.dart';
import 'package:parentpeak/logic/chat_ai_consent.dart';
import 'package:parentpeak/logic/chat_memory_consent.dart';
import 'package:parentpeak/logic/ai_memory_service.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/pedagogical_chat_backend.dart';
import 'package:parentpeak/ui/eltern_netzwerk_screen.dart';
import 'package:parentpeak/ui/gemeinsam_satt_screen.dart';
import 'package:parentpeak/ui/widgets/home/context_home_card.dart';
import 'package:parentpeak/ui/widgets/home/quick_actions_row.dart';
import 'package:parentpeak/ui/widgets/network/family_swipe_stack.dart';
import 'package:parentpeak/ui/calendar_screen.dart';
import 'package:parentpeak/ui/chat_screen.dart';
import 'package:parentpeak/ui/contacts_screen.dart';
import 'package:parentpeak/ui/create_event_screen.dart';
import 'package:parentpeak/ui/create_community_event_screen.dart';
import 'package:parentpeak/ui/family_recipes_screen.dart';
import 'package:parentpeak/ui/fridge_recipe_screen.dart';
import 'package:parentpeak/ui/family_profile_screen.dart';
import 'package:parentpeak/ui/privacy_settings_screen.dart';
import 'package:parentpeak/ui/legal_info_screen.dart';
import 'package:parentpeak/ui/auth/login_screen.dart';
import 'package:parentpeak/ui/meetup_screen.dart';
import 'package:parentpeak/ui/event_discover_screen.dart';
import 'package:parentpeak/ui/simple_meal_planner.dart';
import 'package:parentpeak/ui/tischmoment_screen.dart';
import 'package:parentpeak/ui/device_management_screen.dart';
import 'package:parentpeak/ui/entwicklung_impulse_screen.dart';
import 'package:parentpeak/ui/events_activities_screen.dart';
import 'package:parentpeak/ui/familien_geld_screen.dart';
import 'package:parentpeak/ui/familien_kueche_screen.dart';
import 'package:parentpeak/ui/familien_zentrale_screen.dart';
import 'package:parentpeak/ui/home_screen.dart';
import 'package:parentpeak/ui/marketplace_screen.dart';
import 'package:parentpeak/ui/ritual_ruhe_screen.dart';
import 'package:parentpeak/ui/wochenrueckblick_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quota_test_support.dart';

const _recipe = FamilyRecipe(
  id: 'audit-recipe',
  title: 'Un délicieux repas de famille avec beaucoup de légumes',
  description: 'Un repas à préparer et à savourer ensemble en famille.',
  prepMinutes: 30,
  costPerPortion: 2,
  minChildAge: 1,
  ingredients: ['Gemüse', 'Kartoffeln'],
  steps: ['Gemeinsam vorbereiten und kochen.'],
  season: 'alle',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    for (final language in ['tr', 'fr', 'ar']) {
      await initializeDateFormatting(language);
    }
  });
  final screens = <String, Widget Function()>{
    'home': () => const HomeScreen(),
    'chat': () => const ChatScreen(),
    'calendar': () => const CalendarScreen(),
    'events': () => const EventsActivitiesScreen(),
    'kitchen': () => const FamilienKuecheScreen(),
    'family-hub': () => const FamilienZentraleScreen(),
    'finance': () => const FamilienGeldScreen(),
    'marketplace': () => const MarketplaceScreen(),
    'rituals': () => const RitualRuheScreen(),
    'rituals-with-child': () => const RitualRuheScreen(),
    'weekly-review': () => const WochenrueckblickScreen(),
    'development': () => const EntwicklungImpulseScreen(),
    'community': () => const ElternNetzwerkScreen(),
    'contacts': () => const ContactsScreen(),
    'create-event': () => const CreateEventScreen(),
    'create-community-event': () => const CreateCommunityEventScreen(),
    'family-recipes': () => const FamilyRecipesScreen(),
    'fridge-recipes': () => const FridgeRecipeScreen(),
    'family-profile': () => FamilyProfileScreen(
          devices: const [],
          onRevoke: (id, name) async => true,
        ),
    'privacy': () => PrivacySettingsScreen(
          isPrivacyModeEnabled: true,
          onPrivacyModeChanged: (_) async {},
        ),
    'legal': () => const LegalInfoScreen(),
    'login': () => const LoginScreen(),
    'meetup': () => const MeetupScreen(),
    'event-discover': () => const EventDiscoverScreen(),
    'simple-meal-planner': () => const SimpleMealPlanner(),
    'table-moment': () => const TischmomentScreen(),
    'devices': () => DeviceManagementScreen(
          devices: const [],
          onRevoke: (id, name) async => true,
        ),
    'shared-meals': () => const GemeinsamSattScreen(),
    'quick-actions': () => Scaffold(
          body: QuickActionsRow(
            onChat: () {},
            onCalendar: () {},
            onEvents: () {},
            onImpulse: () {},
            onNetzwerk: () {},
            calendarBadge: 123,
          ),
        ),
    for (final hour in [8, 14, 19, 2])
      'context-card-$hour': () => Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ContextHomeCard(
                now: () => DateTime(2026, 4, 15, hour),
                onOpenWeeklyReview: () {},
              ),
            ),
          ),
    'community-card': () => Scaffold(
          body: Builder(builder: (context) {
            final language = Localizations.localeOf(context).languageCode;
            String tr(String key) => AppStringsManager.getString(language, key);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: FamilySwipeStack(
                cards: [
                  FamilySwipeCardData(
                    id: 'family',
                    name: 'Famille avec un nom de famille vraiment long',
                    city: 'Saint-Martin-de-Belleville et les environs',
                    bio: tr('what_today_together'),
                    tags: [
                      tr('family_hub_tab_children'),
                      tr('home_quick_calendar')
                    ],
                    reasons: [tr('what_today_together')],
                  ),
                ],
                likeLabel: tr('network_like_action'),
                passLabel: tr('network_pass_action'),
                onLike: (_) {},
                onPass: (_) {},
              ),
            );
          }),
        ),
  };
  for (final screen in screens.entries) {
    for (final language in ['tr', 'fr', 'ar']) {
      for (final size in [const Size(360, 640), const Size(390, 844)]) {
        for (final scale in [1.3, 1.5]) {
          testWidgets('${screen.key} $language ${size.width} scale $scale',
              (tester) async {
            final errors = <FlutterErrorDetails>[];
            final previousOnError = FlutterError.onError;
            FlutterError.onError = (details) {
              errors.add(details);
              previousOnError?.call(details);
            };
            addTearDown(() => FlutterError.onError = previousOnError);
            SharedPreferences.setMockInitialValues({
              'user.displayName': 'Un prénom et un nom de famille très longs',
              FamilyFinanceStore.storageKey: jsonEncode({
                'accounts': {
                  'guest': {
                    'owner': 'guest',
                    'data': {FamilyFinanceStore.countryKey: 'de'},
                  },
                },
              }),
              if (['family-hub', 'rituals-with-child'].contains(screen.key))
                FamilyHubStore.storageKey: jsonEncode({
                  'accounts': {
                    'guest': {
                      'owner': 'guest',
                      'data': {
                        FamilyHubStore.dossierKey: [
                          KindDossier(
                            childName:
                                'Alexandra mit einem langen Familiennamen',
                            birthDate: DateTime(2020, 3, 18),
                          ).toJson(),
                        ],
                      },
                    },
                  },
                }),
              'familyküche.saved': jsonEncode([_recipe.toJson()]),
            });
            disableQuotasForTest();
            if (screen.key == 'kitchen') {
              FeatureQuotaService.apiClientFactory = () => BackendApiClient(
                    baseUrl: 'https://quota.example.test',
                    httpClient: MockClient((request) async {
                      final body = switch (request.url.path) {
                        '/usage/me' => {
                            'enabled': true,
                            'tier': 'free',
                            'serverTime': '2026-04-15T12:00:00Z',
                            'items': {
                              'recipes': {'remaining': 1},
                            },
                          },
                        '/usage/recipes/today' => {'item': _recipe.toJson()},
                        _ => throw StateError('Unexpected quota request'),
                      };
                      return http.Response(jsonEncode(body), 200);
                    }),
                  );
            }
            await tester.runAsync(() => languageService.setLanguage(language));
            Widget child = screen.value();
            if (screen.key == 'chat') {
              final store = ChatAccountStore(userIdProvider: () => 'overflow');
              addTearDown(store.dispose);
              final consent = ChatAiConsent(scopeProvider: () => store.scope);
              await tester.runAsync(() => consent.grant(store.scope));
              child = ChatScreen(
                accountStore: store,
                chatBackend: PedagogicalChatBackend(
                    accountStore: store, consent: consent),
                memoryService: AiMemoryService(
                  accountStore: store,
                  consent: ChatMemoryConsent(scopeProvider: () => store.scope),
                  apiClient: BackendApiClient(
                    baseUrl: 'https://example.invalid',
                    httpClient: MockClient(
                        (_) async => http.Response('{"enabled":false}', 200)),
                  ),
                ),
              );
            }
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(MaterialApp(
              locale: Locale(language),
              supportedLocales: AppLanguages.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                AppLanguages.materialLocalizationsDelegate,
                AppLanguages.widgetsLocalizationsDelegate,
                AppLanguages.cupertinoLocalizationsDelegate,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                ),
                child: child!,
              ),
              home: child,
            ));
            await tester.pump();
            await tester.pump(const Duration(seconds: 1));
            if (screen.key == 'kitchen') {
              expect(find.byType(AlertDialog), findsOneWidget);
              await tester.tap(find
                  .descendant(
                    of: find.byType(AlertDialog),
                    matching: find.byType(TextButton),
                  )
                  .first);
              await tester.pumpAndSettle();
              expect(find.text(_recipe.title), findsOneWidget);
            }
            if (screen.key == 'rituals-with-child') {
              await tester.tap(find.byIcon(Icons.nightlight_round).first);
              await tester.pumpAndSettle();
            }
            expect(
                Directionality.of(tester.element(find.byType(Scaffold).first)),
                language == 'ar' ? TextDirection.rtl : TextDirection.ltr);
            expect(tester.takeException(), isNull,
                reason: errors.map((error) => error.toString()).join('\n'));
            Future<void> checkScrolling() async {
              for (final state in tester
                  .stateList<ScrollableState>(find.byType(Scrollable))
                  .toList()) {
                if (!state.mounted ||
                    axisDirectionToAxis(state.axisDirection) != Axis.vertical) {
                  continue;
                }
                final position = state.position;
                if (!position.hasContentDimensions ||
                    !position.maxScrollExtent.isFinite) {
                  continue;
                }
                for (final fraction in [0.5, 1.0]) {
                  position.jumpTo(position.maxScrollExtent * fraction);
                  await tester.pump();
                  expect(tester.takeException(), isNull,
                      reason: 'Scroll $fraction: ${errors.join('\n')}');
                }
              }
            }

            void checkTabLabels() {
              for (final element in find
                  .descendant(
                      of: find.byType(TabBar), matching: find.byType(RichText))
                  .evaluate()) {
                final paragraph = element.renderObject! as RenderParagraph;
                expect(paragraph.didExceedMaxLines, isFalse,
                    reason: 'Clipped tab: ${paragraph.text.toPlainText()}');
              }
            }

            checkTabLabels();
            await checkScrolling();
            String tr(String key) => AppStringsManager.getString(language, key);
            if (screen.key == 'home') {
              final all = find.text('${tr('all')} \u{2192}');
              await tester.ensureVisible(all);
              await tester.tap(all);
              await tester.pumpAndSettle();
              expect(find.byType(DraggableScrollableSheet), findsOneWidget);
              await checkScrolling();
              expect(tester.takeException(), isNull, reason: errors.join('\n'));
              Navigator.of(
                      tester.element(find.byType(DraggableScrollableSheet)))
                  .pop();
              await tester.pumpAndSettle();
            }
            if (screen.key == 'context-card-19') {
              final mood = find.text(tr('home_mood_great'));
              await tester.ensureVisible(mood);
              await tester.tap(mood);
              await tester.pump();
              expect(
                  find.text(tr('home_best_moment_question')), findsOneWidget);
              final skip = find.text(tr('skip_mood'));
              await tester.ensureVisible(skip);
              await tester.tap(skip);
              await tester.pump();
              expect(find.text(tr('view_your_week')), findsOneWidget);
              expect(tester.takeException(), isNull, reason: errors.join('\n'));
            }
            if (screen.key == 'kitchen') {
              await tester.tap(find.byIcon(Icons.bookmark_rounded).first);
              await tester.pumpAndSettle();
              expect(find.byType(DraggableScrollableSheet), findsOneWidget);
              await checkScrolling();
              expect(tester.takeException(), isNull, reason: errors.join('\n'));
              Navigator.of(
                      tester.element(find.byType(DraggableScrollableSheet)))
                  .pop();
              await tester.pumpAndSettle();
            }
            if (screen.key == 'calendar' ||
                screen.key == 'rituals-with-child') {
              final button = screen.key == 'calendar'
                  ? find.byIcon(Icons.add_rounded).last
                  : find.byIcon(Icons.edit_rounded);
              if (screen.key == 'rituals-with-child') {
                final scrollable = find.byType(Scrollable).first;
                tester.state<ScrollableState>(scrollable).position.jumpTo(0);
                await tester.pump();
                await tester.tap(find.byIcon(Icons.wb_sunny_rounded).first);
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull,
                    reason: errors.join('\n'));
                await tester.scrollUntilVisible(button, 150,
                    scrollable: scrollable);
              }
              await tester.ensureVisible(button);
              await tester.pumpAndSettle();
              expect(button.hitTestable(), findsOneWidget);
              await tester.tap(button);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: errors.join('\n'));
              await checkScrolling();
              tester.view.viewInsets = const FakeViewPadding(bottom: 260);
              addTearDown(tester.view.resetViewInsets);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull,
                  reason: 'Keyboard: ${errors.join('\n')}');
              await checkScrolling();
              Navigator.of(tester.element(find.byType(TextField).first)).pop();
              tester.view.resetViewInsets();
              await tester.pumpAndSettle();
            }
            for (final tabBar
                in tester.widgetList<TabBar>(find.byType(TabBar))) {
              final controller = tabBar.controller;
              if (controller == null) continue;
              for (var index = 1; index < controller.length; index++) {
                controller.animateTo(index);
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 500));
                expect(tester.takeException(), isNull,
                    reason: 'Tab $index: ${errors.join('\n')}');
                await checkScrolling();
              }
            }

            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          },
              variant: TargetPlatformVariant({
                size.width == 360 ? TargetPlatform.android : TargetPlatform.iOS,
              }));
        }
      }
    }
  }
}
