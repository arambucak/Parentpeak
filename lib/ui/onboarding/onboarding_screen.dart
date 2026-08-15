import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/ui/onboarding/onboarding_pages.dart';

/// Onboarding-Ergebnis das nach Abschluss zurückgegeben wird.
class OnboardingResult {
  final String parentRole; // 'neugeboren', 'kleinkind', 'schulkind', 'teenager'
  final List<String> priorities; // z.B. ['tipps', 'organisation', 'community']
  final List<String> suggestedTileOrder;

  const OnboardingResult({
    required this.parentRole,
    required this.priorities,
    required this.suggestedTileOrder,
  });
}

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  /// Prüft ob Onboarding bereits abgeschlossen wurde.
  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding.completed') ?? false;
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  static const String _completedKey = 'onboarding.completed';
  static const String _roleKey = 'onboarding.parent_role';
  static const String _prioritiesKey = 'onboarding.priorities';

  final PageController _pageController = PageController();
  int _currentPage = 0;
  String? _selectedRole;
  final Set<String> _selectedRoles = {};
  final Set<String> _selectedPriorities = {};
  final List<String> _selectedChildAges = [];
  String _selectedCountry = 'DE';
  String _selectedRegion = 'NRW';
  final TextEditingController _familyNameController = TextEditingController();

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _familyNameController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (page < 0 || page > 5) return;
    HapticFeedback.lightImpact();
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _nextPage() {
    if (_currentPage < 5) {
      _goToPage(_currentPage + 1);
    }
  }

  bool get _canProceed {
    switch (_currentPage) {
      case 0:
        return true; // Welcome page, immer weiter
      case 1:
        return _familyNameController.text.trim().isNotEmpty;
      case 2:
        return true; // Phasen optional — auch ohne Auswahl weiter
      case 3:
        return _selectedRegion.isNotEmpty;
      case 4:
        return _selectedPriorities.isNotEmpty;
      case 5:
        return true; // Summary page
      default:
        return false;
    }
  }

  Future<void> _completeOnboarding() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);

    // Save family name
    final familyName = _familyNameController.text.trim();
    if (familyName.isNotEmpty) {
      await prefs.setString('onboarding.family_name', familyName);
    }

    if (_selectedRoles.isNotEmpty) {
      await prefs.setString(_roleKey, _selectedRoles.first);
      await prefs.setStringList(
          'onboarding.parent_roles', _selectedRoles.toList());
    }
    await prefs.setStringList(
      _prioritiesKey,
      _selectedPriorities.toList(),
    );

    // Save child ages
    await prefs.setStringList('onboarding.child_ages', _selectedChildAges);

    // Save country & region → auto-configures Kalender holidays
    await prefs.setString('holiday.country', _selectedCountry);
    await prefs.setString('holiday.region', _selectedRegion);

    // Speichere die personalisierte Kachel-Reihenfolge
    final tileOrder = _buildTileOrder();
    await prefs.setStringList('home.tile_order.v1', tileOrder);

    widget.onComplete();
  }

  List<String> _buildTileOrder() {
    final order = <String>[];

    // Basierend auf Prioritäten die wichtigsten Features nach oben
    if (_selectedPriorities.contains('tipps')) {
      order.add('Impulse & Entwicklung');
      order.add('KI Elternberatung');
    }
    if (_selectedPriorities.contains('organisation')) {
      order.add('Kalender');
      order.add('Organisation');
    }
    if (_selectedPriorities.contains('community')) {
      order.add('Eltern Match');
      order.add('Events & Aktivitäten');
    }
    if (_selectedPriorities.contains('sparen')) {
      order.add('Verschenkmarkt');
      order.add('GemeinsamSatt');
      order.add('Finanzen & Budget');
    }

    // Rest auffüllen
    final allTiles = [
      'Impulse & Entwicklung',
      'KI Elternberatung',
      'Kalender',
      'Organisation',
      'Eltern Match',
      'Events & Aktivitäten',
      'Verschenkmarkt',
      'GemeinsamSatt',
      'Finanzen & Budget',
    ];
    for (final tile in allTiles) {
      if (!order.contains(tile)) {
        order.add(tile);
      }
    }

    return order;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: _buildProgressBar(theme),
            ),
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                  _fadeController.reset();
                  _slideController.reset();
                  _fadeController.forward();
                  _slideController.forward();
                },
                children: [
                  OnboardingWelcomePage(
                    fadeAnimation: _fadeAnimation,
                    slideAnimation: _slideAnimation,
                  ),
                  _buildNamePage(),
                  OnboardingChildAgePage(
                    selectedAges: _selectedChildAges,
                    fadeAnimation: _fadeAnimation,
                    slideAnimation: _slideAnimation,
                    onAgeToggled: (age) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (_selectedChildAges.contains(age)) {
                          _selectedChildAges.remove(age);
                        } else {
                          _selectedChildAges.add(age);
                        }
                      });
                    },
                  ),
                  OnboardingCountryPage(
                    selectedCountry: _selectedCountry,
                    selectedRegion: _selectedRegion,
                    fadeAnimation: _fadeAnimation,
                    slideAnimation: _slideAnimation,
                    onCountrySelected: (country) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedCountry = country;
                        // Reset region to first available
                        final regions = OnboardingCountryPage.regions[country];
                        _selectedRegion = regions != null && regions.isNotEmpty
                            ? regions.first['code']!
                            : '';
                      });
                    },
                    onRegionSelected: (region) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedRegion = region);
                    },
                  ),
                  OnboardingPrioritiesPage(
                    selectedPriorities: _selectedPriorities,
                    fadeAnimation: _fadeAnimation,
                    slideAnimation: _slideAnimation,
                    onPriorityToggled: (priority) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (_selectedPriorities.contains(priority)) {
                          _selectedPriorities.remove(priority);
                        } else {
                          _selectedPriorities.add(priority);
                        }
                      });
                    },
                  ),
                  OnboardingReadyPage(
                    selectedRole: _selectedRole,
                    selectedPriorities: _selectedPriorities,
                    fadeAnimation: _fadeAnimation,
                    slideAnimation: _slideAnimation,
                  ),
                ],
              ),
            ),
            // Bottom Navigation
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: _buildBottomNav(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNamePage() {
    final theme = Theme.of(context);
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              const Center(
                child: Text('\u{1F46A}', style: TextStyle(fontSize: 48)),
              ),
              const SizedBox(height: 28),
              Text(
                'Wie heißt eure Familie?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Dein Vorname oder Familienname — damit wir dich persönlich begrüßen können.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _familyNameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'z.B. Familie Müller oder Anna',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: theme.colorScheme.primary, width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Text(
                'Wird für die Begrüßung und im Netzwerk verwendet.',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(ThemeData theme) {
    return Row(
      children: List.generate(6, (index) {
        final isActive = index <= _currentPage;
        final isCurrent = index == _currentPage;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: isCurrent ? 4 : 3,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBottomNav(ThemeData theme) {
    final isLastPage = _currentPage == 5;

    return Row(
      children: [
        // Back / Skip
        if (_currentPage > 0)
          TextButton(
            onPressed: () => _goToPage(_currentPage - 1),
            child: Text(
              'Zurück',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          )
        else
          TextButton(
            onPressed: _completeOnboarding,
            child: Text(
              'Überspringen',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        const Spacer(),
        // Next / Finish
        FilledButton(
          onPressed: _canProceed
              ? (isLastPage ? _completeOnboarding : _nextPage)
              : null,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isLastPage ? 'Los geht\'s' : 'Weiter'),
              if (!isLastPage) ...[
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
