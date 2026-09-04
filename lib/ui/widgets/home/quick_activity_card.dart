import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Was machen wir heute?" — Spielerischer Aktivitäts-Generator.
///
/// Zeigt eine kreative, altersgerechte Aktivität als ansprechende Karte.
/// Features: Kategorien-Filter, Materialien-Liste, Favoriten, Shuffle-Animation.
class QuickActivityCard extends StatefulWidget {
  const QuickActivityCard({super.key});

  @override
  State<QuickActivityCard> createState() => _QuickActivityCardState();
}

class _QuickActivityCardState extends State<QuickActivityCard>
    with SingleTickerProviderStateMixin {
  _ActivityItem? _current;
  int _currentIndex = 0;
  String _selectedCategory = 'alle';
  bool _isFavorite = false;
  bool _showDetails = false;
  String _parentRole = 'kleinkind';

  late final AnimationController _cardController;
  late final Animation<double> _cardAnimation;

  static const List<_Category> _categories = [
    _Category('alle', 'Alle', '\u{1F3B2}'),
    _Category('kreativ', 'Kreativ', '\u{1F3A8}'),
    _Category('bewegung', 'Bewegung', '\u{1F3C3}'),
    _Category('draussen', 'Draußen', '\u{1F333}'),
    _Category('lernen', 'Lernen', '\u{1F4A1}'),
    _Category('zusammen', 'Zusammen', '\u{1F46A}'),
  ];

  @override
  void initState() {
    super.initState();
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _cardAnimation = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutBack,
    );
    _cardController.value = 1.0;
    _loadActivity();
  }

  @override
  void dispose() {
    _cardController.dispose();
    super.dispose();
  }

  Future<void> _loadActivity() async {
    final prefs = await SharedPreferences.getInstance();
    _parentRole = prefs.getString('onboarding.parent_role') ?? 'kleinkind';
    final activities = _filteredActivities();
    if (activities.isEmpty) return;
    final dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    _currentIndex = dayOfYear % activities.length;
    await _applyActivity(activities[_currentIndex]);
  }

  List<_ActivityItem> _filteredActivities() {
    final all = _activitiesForRole(_parentRole);
    if (_selectedCategory == 'alle') return all;
    return all.where((a) => a.category == _selectedCategory).toList();
  }

  Future<void> _applyActivity(_ActivityItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final favKey = 'activity.fav.${item.id}';
    final isFav = prefs.getBool(favKey) ?? false;
    if (mounted) {
      setState(() {
        _current = item;
        _isFavorite = isFav;
        _showDetails = false;
      });
    }
  }

  void _shuffle() {
    HapticFeedback.lightImpact();
    final activities = _filteredActivities();
    if (activities.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % activities.length;
    _cardController.forward(from: 0);
    _applyActivity(activities[_currentIndex]);
  }

  void _selectCategory(String category) {
    HapticFeedback.selectionClick();
    setState(() => _selectedCategory = category);
    final activities = _filteredActivities();
    if (activities.isEmpty) {
      setState(() => _current = null);
      return;
    }
    _currentIndex = 0;
    _cardController.forward(from: 0);
    _applyActivity(activities[0]);
  }

  Future<void> _toggleFavorite() async {
    if (_current == null) return;
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    final favKey = 'activity.fav.${_current!.id}';
    final newState = !_isFavorite;
    await prefs.setBool(favKey, newState);
    if (mounted) setState(() => _isFavorite = newState);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8B5CF6).withValues(alpha: 0.06),
            const Color(0xFFA78BFA).withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text('\u{2728}', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('quick_activity_title'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      context.tr('quick_activity_idea'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _shuffle,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      size: 20, color: Color(0xFF7C3AED)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Kategorie-Filter als kompakte Icon-Reihe
          Row(
            children: _categories.map((cat) {
              final isActive = _selectedCategory == cat.id;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _selectCategory(cat.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isActive
                          ? Border.all(
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.4))
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cat.emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 3),
                        Text(
                          cat.label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive
                                ? const Color(0xFF7C3AED)
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          // Aktivitäts-Karte
          if (_current != null) _buildActivityContent(theme),
          if (_current == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Keine Aktivitäten in dieser Kategorie',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityContent(ThemeData theme) {
    final item = _current!;

    return ScaleTransition(
      scale: _cardAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titel-Zeile mit Badges
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _toggleFavorite,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _isFavorite
                          ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 16,
                      color: _isFavorite
                          ? const Color(0xFFEF4444)
                          : theme.colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Beschreibung
            Text(
              item.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            // Meta-Badges (Dauer, Ort, Alter)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildBadge(
                  theme,
                  icon: Icons.timer_outlined,
                  text: item.duration,
                  color: const Color(0xFF6366F1),
                ),
                _buildBadge(
                  theme,
                  icon: item.isIndoor ? Icons.home_rounded : Icons.park_rounded,
                  text: item.isIndoor ? 'Drinnen' : 'Draußen',
                  color: item.isIndoor
                      ? const Color(0xFFD97706)
                      : const Color(0xFF059669),
                ),
                if (item.materials.isNotEmpty)
                  _buildBadge(
                    theme,
                    icon: Icons.inventory_2_outlined,
                    text:
                        '${item.materials.length} Material${item.materials.length > 1 ? 'ien' : ''}',
                    color: const Color(0xFF8B5CF6),
                  ),
              ],
            ),
            // Materialien (aufklappbar)
            if (item.materials.isNotEmpty) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => setState(() => _showDetails = !_showDetails),
                child: Row(
                  children: [
                    Text(
                      'Was ihr braucht',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showDetails
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: const Color(0xFF7C3AED),
                    ),
                  ],
                ),
              ),
              if (_showDetails) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: item.materials.map((m) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        m,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(ThemeData theme,
      {required IconData icon, required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Aktivitäten-Datenbank ──────────────────────────────────────────────────

  List<_ActivityItem> _activitiesForRole(String role) {
    switch (role) {
      case 'neugeboren':
        return const [
          _ActivityItem(
              id: 'nb1',
              title: 'Sinnesgarten auf dem Boden',
              description:
                  'Lege verschiedene Materialien auf eine Decke (Alufolie, Stoff, Fell, Papier) und lass dein Baby fühlen und greifen.',
              duration: '10 Min',
              isIndoor: true,
              category: 'kreativ',
              materials: ['Decke', 'Verschiedene Stoffe', 'Alufolie']),
          _ActivityItem(
              id: 'nb2',
              title: 'Seifenblasen-Zauber',
              description:
                  'Puste sanft Seifenblasen und lass dein Baby mit den Augen folgen. Trainiert die Augenmuskeln spielerisch.',
              duration: '5 Min',
              isIndoor: true,
              category: 'zusammen',
              materials: ['Seifenblasen']),
          _ActivityItem(
              id: 'nb3',
              title: 'Naturspaziergang mit Erzählung',
              description:
                  'Geh raus und beschreibe alles laut: Farben, Geräusche, Gerüche. Dein Baby speichert jedes Wort.',
              duration: '20 Min',
              isIndoor: false,
              category: 'draussen',
              materials: []),
          _ActivityItem(
              id: 'nb4',
              title: 'Kontrast-Karten basteln',
              description:
                  'Male schwarze Formen auf weißes Papier (Kreise, Streifen). Babys lieben hohe Kontraste.',
              duration: '15 Min',
              isIndoor: true,
              category: 'kreativ',
              materials: ['Weißes Papier', 'Schwarzer Stift']),
          _ActivityItem(
              id: 'nb5',
              title: 'Baby-Massage mit Öl',
              description:
                  'Sanfte Streichbewegungen an Armen und Beinen. Fördert Bindung und Körperwahrnehmung.',
              duration: '10 Min',
              isIndoor: true,
              category: 'zusammen',
              materials: ['Babyöl', 'Warme Unterlage']),
        ];
      case 'kleinkind':
        return const [
          _ActivityItem(
              id: 'kk1',
              title: 'Höhle der Abenteuer',
              description:
                  'Baut zusammen eine Höhle aus Decken, Kissen und Stühlen. Taschenlampe rein — fertig ist das Abenteuer.',
              duration: '20 Min',
              isIndoor: true,
              category: 'kreativ',
              materials: ['Decken', 'Kissen', 'Stühle', 'Taschenlampe']),
          _ActivityItem(
              id: 'kk2',
              title: 'Regenbogen-Knete selbst machen',
              description:
                  'Mehl + Salz + Wasser + Öl + Lebensmittelfarbe. Kneten, formen, staunen.',
              duration: '20 Min',
              isIndoor: true,
              category: 'kreativ',
              materials: ['Mehl', 'Salz', 'Wasser', 'Öl', 'Lebensmittelfarbe']),
          _ActivityItem(
              id: 'kk3',
              title: 'Pfützen-Olympiade',
              description:
                  'Gummistiefel an und raus! Wer spritzt am höchsten? Wer findet die größte Pfütze?',
              duration: '20 Min',
              isIndoor: false,
              category: 'bewegung',
              materials: ['Gummistiefel', 'Regenkleidung']),
          _ActivityItem(
              id: 'kk4',
              title: 'Schatzsuche mit Karte',
              description:
                  'Male eine simple Karte, verstecke einen "Schatz" (Gummibärchen) und lass dein Kind suchen.',
              duration: '25 Min',
              isIndoor: false,
              category: 'draussen',
              materials: ['Papier', 'Stifte', 'Kleiner Schatz']),
          _ActivityItem(
              id: 'kk5',
              title: 'Kissen-Parcours',
              description:
                  'Baue einen Hindernisparcours quer durchs Wohnzimmer. Drüber klettern, unten durch, balancieren.',
              duration: '15 Min',
              isIndoor: true,
              category: 'bewegung',
              materials: ['Kissen', 'Decken', 'Stühle']),
          _ActivityItem(
              id: 'kk6',
              title: 'Farbsortier-Spiel',
              description:
                  'Sammle bunte Gegenstände und lass dein Kind nach Farben sortieren. Lernen ohne es zu merken.',
              duration: '10 Min',
              isIndoor: true,
              category: 'lernen',
              materials: ['Bunte Alltagsgegenstände', 'Schüsseln']),
          _ActivityItem(
              id: 'kk7',
              title: 'Familien-Konzert',
              description:
                  'Töpfe als Trommeln, Löffel als Sticks, Reis in Dosen als Rasseln. Macht gemeinsam Musik!',
              duration: '15 Min',
              isIndoor: true,
              category: 'zusammen',
              materials: ['Töpfe', 'Löffel', 'Dosen mit Reis']),
          _ActivityItem(
              id: 'kk8',
              title: 'Blätter-Kunst im Park',
              description:
                  'Sammelt verschiedene Blätter und klebt zu Hause ein Bild daraus. Tiere, Gesichter oder Muster.',
              duration: '30 Min',
              isIndoor: false,
              category: 'kreativ',
              materials: ['Kleber', 'Papier']),
          _ActivityItem(
              id: 'kk9',
              title: 'Tier-Yoga',
              description:
                  'Macht zusammen Yoga-Posen als Tiere: Schlange, Katze, Baum, Frosch. Kinder lieben die Geräusche dazu.',
              duration: '10 Min',
              isIndoor: true,
              category: 'bewegung',
              materials: []),
          _ActivityItem(
              id: 'kk10',
              title: 'Eiskünstler',
              description:
                  'Füllt Wasser mit Farbe in Eiswürfelformen, friert es ein und malt damit draußen auf Papier.',
              duration: '15 Min',
              isIndoor: false,
              category: 'kreativ',
              materials: ['Eiswürfelform', 'Lebensmittelfarbe', 'Papier']),
        ];
      case 'schulkind':
        return const [
          _ActivityItem(
              id: 'sk1',
              title: 'Papierflugzeug-Contest',
              description:
                  'Baut verschiedene Modelle und testet: Welches fliegt am weitesten? Am längsten? Am verrücktesten?',
              duration: '25 Min',
              isIndoor: true,
              category: 'kreativ',
              materials: ['Papier (verschiedene Größen)']),
          _ActivityItem(
              id: 'sk2',
              title: 'Familien-Kochduell',
              description:
                  'Jeder bekommt 3 Zutaten und muss daraus etwas Leckeres zaubern. Jury bewertet!',
              duration: '40 Min',
              isIndoor: true,
              category: 'zusammen',
              materials: ['Verschiedene Lebensmittel']),
          _ActivityItem(
              id: 'sk3',
              title: 'Foto-Safari',
              description:
                  '10 Aufgaben: Fotografiere etwas Rotes, etwas Winziges, etwas das dich glücklich macht...',
              duration: '30 Min',
              isIndoor: false,
              category: 'draussen',
              materials: ['Handy/Kamera']),
          _ActivityItem(
              id: 'sk4',
              title: 'Vulkan-Experiment',
              description:
                  'Backpulver + Essig + Spüli + Lebensmittelfarbe = Mini-Vulkanausbruch! Wissenschaft zum Anfassen.',
              duration: '15 Min',
              isIndoor: true,
              category: 'lernen',
              materials: [
                'Backpulver',
                'Essig',
                'Spüli',
                'Lebensmittelfarbe',
                'Glas'
              ]),
          _ActivityItem(
              id: 'sk5',
              title: 'Geocaching-Abenteuer',
              description:
                  'Ladet eine Geocaching-App und sucht versteckte Schätze in eurer Umgebung. Digitale Schnitzeljagd!',
              duration: '45 Min',
              isIndoor: false,
              category: 'draussen',
              materials: ['Handy mit Geocaching-App']),
          _ActivityItem(
              id: 'sk6',
              title: 'Comic-Werkstatt',
              description:
                  'Erfindet gemeinsam einen Superhelden und zeichnet ein kurzes Comic-Heft (4-6 Seiten reichen).',
              duration: '30 Min',
              isIndoor: true,
              category: 'kreativ',
              materials: ['Papier', 'Stifte', 'Buntstifte']),
          _ActivityItem(
              id: 'sk7',
              title: 'Familien-Quiz',
              description:
                  'Jeder schreibt 5 Fragen auf. Themen: Tiere, Weltraum, Familie, Länder. Wer gewinnt?',
              duration: '20 Min',
              isIndoor: true,
              category: 'lernen',
              materials: ['Zettel', 'Stifte']),
          _ActivityItem(
              id: 'sk8',
              title: 'Murmelbahn aus Kartons',
              description:
                  'Sammelt Kartons, Klorollen und Klebeband. Baut die längste Murmelbahn der Welt!',
              duration: '35 Min',
              isIndoor: true,
              category: 'kreativ',
              materials: ['Kartons', 'Klorollen', 'Klebeband', 'Murmel']),
        ];
      case 'teenager':
        return const [
          _ActivityItem(
              id: 'tn1',
              title: 'Länder-Kochen',
              description:
                  'Euer Teenager wählt ein Land, ihr kocht zusammen ein typisches Gericht. Spotify-Playlist aus dem Land dazu!',
              duration: '50 Min',
              isIndoor: true,
              category: 'zusammen',
              materials: ['Rezept-Zutaten', 'Musik']),
          _ActivityItem(
              id: 'tn2',
              title: 'Workout-Challenge',
              description:
                  'Sucht euch ein YouTube-Workout und macht es zusammen. Wer gibt zuerst auf?',
              duration: '20 Min',
              isIndoor: true,
              category: 'bewegung',
              materials: ['Matte', 'Handy/TV']),
          _ActivityItem(
              id: 'tn3',
              title: 'Nacht-Spaziergang',
              description:
                  'Geht abends mit Taschenlampe raus. Redet über alles außer Schule. Sterne zählen optional.',
              duration: '30 Min',
              isIndoor: false,
              category: 'draussen',
              materials: ['Taschenlampe']),
          _ActivityItem(
              id: 'tn4',
              title: 'Zimmer-Umstyling',
              description:
                  'Hilf deinem Teenager das Zimmer umzugestalten. Möbel rücken, Deko ändern, Lichterkette aufhängen.',
              duration: '60 Min',
              isIndoor: true,
              category: 'kreativ',
              materials: ['Evtl. neue Deko']),
          _ActivityItem(
              id: 'tn5',
              title: 'Doku + Diskussion',
              description:
                  'Schaut zusammen eine spannende Doku (Natur, Technologie, Geschichte) und diskutiert danach.',
              duration: '50 Min',
              isIndoor: true,
              category: 'lernen',
              materials: ['Streaming-Zugang']),
          _ActivityItem(
              id: 'tn6',
              title: 'Gaming-Nachmittag',
              description:
                  'Lass dir von deinem Teenager ein Spiel zeigen und spiel mit. Ohne zu urteilen. Einfach mitmachen.',
              duration: '30 Min',
              isIndoor: true,
              category: 'zusammen',
              materials: ['Konsole/PC']),
        ];
      default:
        return const [
          _ActivityItem(
              id: 'def1',
              title: 'Gemeinsam Neues wagen',
              description:
                  'Probiert heute etwas, das ihr noch nie gemacht habt. Klein oder groß — Hauptsache neu.',
              duration: '20 Min',
              isIndoor: true,
              category: 'zusammen',
              materials: []),
          _ActivityItem(
              id: 'def2',
              title: 'Ziellos spazieren',
              description:
                  'An jeder Kreuzung entscheidet das Kind: links oder rechts? Schaut was ihr entdeckt.',
              duration: '25 Min',
              isIndoor: false,
              category: 'draussen',
              materials: []),
        ];
    }
  }
}

// ─── Daten-Modelle ────────────────────────────────────────────────────────────

class _Category {
  final String id;
  final String label;
  final String emoji;
  const _Category(this.id, this.label, this.emoji);
}

class _ActivityItem {
  final String id;
  final String title;
  final String description;
  final String duration;
  final bool isIndoor;
  final String category;
  final List<String> materials;

  const _ActivityItem({
    required this.id,
    required this.title,
    required this.description,
    required this.duration,
    required this.isIndoor,
    required this.category,
    required this.materials,
  });
}
