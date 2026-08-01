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
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (page < 0 || page > 3) return;
    HapticFeedback.lightImpact();
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _goToPage(_currentPage + 1);
    }
  }

  bool get _canProceed {
    switch (_currentPage) {
      case 0:
        return true; // Welcome page, immer weiter
      case 1:
        return _selectedRoles.isNotEmpty;
      case 2:
        return _selectedPriorities.isNotEmpty;
      case 3:
        return true; // Summary page
      default:
        return false;
    }
  }

  Future<void> _completeOnboarding() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
    if (_selectedRoles.isNotEmpty) {
      await prefs.setString(_roleKey, _selectedRoles.first);
      await prefs.setStringList(
          'onboarding.parent_roles', _selectedRoles.toList());
    }
    await prefs.setStringList(
      _prioritiesKey,
      _selectedPriorities.toList(),
    );

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
                  OnboardingRolePage(
                    selectedRole: _selectedRole,
                    selectedRoles: _selectedRoles,
                    fadeAnimation: _fadeAnimation,
                    slideAnimation: _slideAnimation,
                    onRoleSelected: (role) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (_selectedRoles.contains(role)) {
                          _selectedRoles.remove(role);
                        } else {
                          _selectedRoles.add(role);
                        }
                        _selectedRole = _selectedRoles.isNotEmpty
                            ? _selectedRoles.first
                            : null;
                      });
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

  Widget _buildProgressBar(ThemeData theme) {
    return Row(
      children: List.generate(4, (index) {
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
    final isLastPage = _currentPage == 3;

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
