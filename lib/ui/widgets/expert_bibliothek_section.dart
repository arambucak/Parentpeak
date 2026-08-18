import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:parentpeak/data/expert_recommendations.dart';
import 'package:parentpeak/main.dart';

/// Eltern-Bibliothek — kuratierte Experten-Empfehlungen.
///
/// Zeigt Empfehlungen nach Kategorie gefiltert, in der Sprache des Nutzers.
/// Jede Karte hat: Typ-Icon, Titel, Experte, empathischer Satz, Button.
class ExpertBibliothekSection extends StatefulWidget {
  const ExpertBibliothekSection({super.key});

  @override
  State<ExpertBibliothekSection> createState() =>
      _ExpertBibliothekSectionState();
}

class _ExpertBibliothekSectionState extends State<ExpertBibliothekSection> {
  ExpertCategory? _selectedCategory;

  String get _lang {
    final l = languageService.currentLanguage;
    if (l == 'de' || l == 'en' || l == 'tr' || l == 'ku') return l;
    return 'en'; // Fallback
  }

  List<ExpertRecommendation> get _filteredItems {
    if (_selectedCategory == null) {
      return ExpertRecommendations.getByLanguage(_lang);
    }
    return ExpertRecommendations.getByCategory(_lang, _selectedCategory!);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _filteredItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        const SizedBox(height: 28),
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                  child: Text('📚', style: TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _lang == 'en'
                        ? 'Expert Library'
                        : _lang == 'tr'
                            ? 'Uzman Kütüphanesi'
                            : _lang == 'ku'
                                ? 'Pirtûkxaneya Pisporan'
                                : 'Eltern-Bibliothek',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    _lang == 'en'
                        ? 'Podcasts, videos & books that really help.'
                        : _lang == 'tr'
                            ? 'Gerçekten yardımcı olan podcast, video ve kitaplar.'
                            : _lang == 'ku'
                                ? 'Podcast, vîdyo û pirtûkên ku bi rastî dibin alîkar.'
                                : 'Podcasts, Videos & Bücher die wirklich helfen.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Category chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _categoryChip(theme, null, _lang == 'en' ? 'All' : 'Alle'),
              ...ExpertCategory.values.map((cat) => _categoryChip(
                    theme,
                    cat,
                    '${ExpertRecommendations.categoryEmoji(cat)} ${ExpertRecommendations.categoryLabel(cat, _lang)}',
                  )),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Recommendations
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                _lang == 'en'
                    ? 'No recommendations for this category yet.'
                    : 'Noch keine Empfehlungen für diese Kategorie.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
          )
        else
          ...items.map((item) => _recommendationCard(theme, item)),
      ],
    );
  }

  Widget _categoryChip(ThemeData theme, ExpertCategory? cat, String label) {
    final selected = _selectedCategory == cat;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedCategory = cat);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF8B5CF6)
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? const Color(0xFF8B5CF6)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _recommendationCard(ThemeData theme, ExpertRecommendation item) {
    final typeColor = switch (item.type) {
      ExpertContentType.podcast => const Color(0xFF16A34A),
      ExpertContentType.youtube => const Color(0xFFDC2626),
      ExpertContentType.book => const Color(0xFFF59E0B),
      ExpertContentType.article => const Color(0xFF2563EB),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type badge + expert name
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ExpertRecommendations.typeLabel(item.type),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: typeColor,
                  ),
                ),
              ),
              const Spacer(),
              if (item.duration != null)
                Text(
                  item.duration!,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            item.title,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            item.expertName,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF8B5CF6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),

          // Why it helps (empathic text)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              item.whyItHelps,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.5,
                color: const Color(0xFF4C1D95),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Action button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openUrl(item.url),
              icon: Icon(
                item.type == ExpertContentType.podcast
                    ? Icons.headphones_rounded
                    : item.type == ExpertContentType.youtube
                        ? Icons.play_circle_rounded
                        : item.type == ExpertContentType.book
                            ? Icons.menu_book_rounded
                            : Icons.open_in_new_rounded,
                size: 16,
              ),
              label: Text(
                item.type == ExpertContentType.podcast
                    ? (_lang == 'en' ? 'Listen' : 'Anhören')
                    : item.type == ExpertContentType.youtube
                        ? (_lang == 'en' ? 'Watch' : 'Ansehen')
                        : item.type == ExpertContentType.book
                            ? (_lang == 'en' ? 'More info' : 'Mehr erfahren')
                            : (_lang == 'en' ? 'Read' : 'Lesen'),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: typeColor,
                side: BorderSide(color: typeColor.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
