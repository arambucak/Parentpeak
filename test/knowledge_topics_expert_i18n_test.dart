import 'package:flutter_test/flutter_test.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/data/expert_recommendations.dart';

/// Sichert ab, dass die Wissen-Themenkarten und die Expert-Library-UI für
/// FR/ES/IT/AR übersetzt sind und nicht auf EN/DE zurückfallen.
void main() {
  String s(String lang, String key) =>
      AppStringsManager.getString(lang, key);

  // Themenkarten-Labels/-Hints + Expert-Library-UI, mit EN- und DE-Fallbacktext.
  const samples = <String, (String en, String de)>{
    'knowledge_topic_anger_label': ('Anger & defiance', 'Wut & Trotz'),
    'knowledge_topic_sleep_label': ('Sleep', 'Schlafen'),
    'knowledge_topic_boundaries_label': ('Boundaries', 'Grenzen'),
    'knowledge_topic_eating_label': ('Eating', 'Essen'),
    'knowledge_topic_siblings_label': ('Siblings', 'Geschwister'),
    'knowledge_topic_media_label': ('Screens', 'Medien'),
    'knowledge_topic_anger_hint': ('Tantrums, hitting', 'Wutanfälle, Hauen'),
    'expert_library_title': ('Expert Library', 'Eltern-Bibliothek'),
    'expert_library_subtitle': (
      'Podcasts, videos & books that really help.',
      'Podcasts, Videos & Bücher die wirklich helfen.'
    ),
    'expert_library_filter_all': ('All', 'Alle'),
    'expert_library_empty': (
      'No recommendations for this category yet.',
      'Noch keine Empfehlungen für diese Kategorie.'
    ),
    'expert_action_listen': ('Listen', 'Anhören'),
    'expert_action_watch': ('Watch', 'Ansehen'),
    'expert_action_more_info': ('More info', 'Mehr erfahren'),
    'expert_action_read': ('Read', 'Lesen'),
  };

  group('Wissen-Themenkarten & Expert-Library-Lokalisierung', () {
    for (final lang in ['fr', 'es', 'it', 'ar']) {
      test('$lang: UI-Keys weder englisch noch deutsch, nicht roh', () {
        samples.forEach((key, fb) {
          final value = s(lang, key);
          expect(value, isNotEmpty, reason: '$lang/$key leer');
          expect(value, isNot(key), reason: '$lang/$key liefert den Rohschlüssel');
          expect(value, isNot(fb.$1), reason: '$lang/$key noch englisch: $value');
          expect(value, isNot(fb.$2), reason: '$lang/$key noch deutsch: $value');
        });
      });

      test('$lang: Expert-Kategorie-Labels übersetzt', () {
        for (final cat in ExpertCategory.values) {
          final label = ExpertRecommendations.categoryLabel(cat, lang);
          final en = ExpertRecommendations.categoryLabel(cat, 'en');
          final de = ExpertRecommendations.categoryLabel(cat, 'de');
          expect(label, isNotEmpty, reason: '$lang/$cat leer');
          expect(label, isNot(en), reason: '$lang/$cat noch englisch: $label');
          expect(label, isNot(de), reason: '$lang/$cat noch deutsch: $label');
        }
      });
    }

    test('unbekannte Expert-Kategorie-Sprache fällt auf EN zurück', () {
      final xx = ExpertRecommendations.categoryLabel(
        ExpertCategory.schlafen,
        'xx',
      );
      final en = ExpertRecommendations.categoryLabel(
        ExpertCategory.schlafen,
        'en',
      );
      expect(xx, en);
    });
  });
}
