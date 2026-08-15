import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';

// ─── Page 1: Welcome ─────────────────────────────────────────────────────────

class OnboardingWelcomePage extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;

  const OnboardingWelcomePage({
    super.key,
    required this.fadeAnimation,
    required this.slideAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animiertes Icon
              _buildHeroIcon(theme),
              const SizedBox(height: 40),
              Text(
                'Willkommen bei\nParentpeak',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Dein Familienalltag. Eine App.\nLass uns kurz herausfinden, was dir\nam meisten hilft.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              // Drei kleine Feature-Vorschau Punkte
              _buildFeatureHints(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroIcon(ThemeData theme) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.tertiary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(
        Icons.family_restroom_rounded,
        color: Colors.white,
        size: 48,
      ),
    );
  }

  Widget _buildFeatureHints(ThemeData theme) {
    final hints = [
      (Icons.auto_awesome_rounded, 'Tipps'),
      (Icons.calendar_month_rounded, 'Planung'),
      (Icons.diversity_3_rounded, 'Community'),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: hints.map((hint) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  hint.$1,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hint.$2,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Page 2: Role Selection ──────────────────────────────────────────────────

class OnboardingRolePage extends StatelessWidget {
  final String? selectedRole;
  final Set<String> selectedRoles;
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;
  final ValueChanged<String> onRoleSelected;

  const OnboardingRolePage({
    super.key,
    required this.selectedRole,
    this.selectedRoles = const {},
    required this.fadeAnimation,
    required this.slideAnimation,
    required this.onRoleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Text(
                'In welcher Phase\nbist du gerade?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mehrfachauswahl moeglich — wähle alle die passen.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView(
                  children: [
                    _RoleCard(
                      role: 'neugeboren',
                      emoji: '\u{1F476}',
                      title: 'Schwangerschaft / Baby',
                      subtitle: '0–12 Monate',
                      isSelected: selectedRoles.contains('neugeboren'),
                      onTap: () => onRoleSelected('neugeboren'),
                    ),
                    const SizedBox(height: 12),
                    _RoleCard(
                      role: 'kleinkind',
                      emoji: '\u{1F9D2}',
                      title: 'Kleinkind',
                      subtitle: '1–5 Jahre',
                      isSelected: selectedRoles.contains('kleinkind'),
                      onTap: () => onRoleSelected('kleinkind'),
                    ),
                    const SizedBox(height: 12),
                    _RoleCard(
                      role: 'schulkind',
                      emoji: '\u{1F393}',
                      title: 'Schulkind',
                      subtitle: '6–12 Jahre',
                      isSelected: selectedRoles.contains('schulkind'),
                      onTap: () => onRoleSelected('schulkind'),
                    ),
                    const SizedBox(height: 12),
                    _RoleCard(
                      role: 'teenager',
                      emoji: '\u{1F9D1}',
                      title: 'Teenager',
                      subtitle: '13–18 Jahre',
                      isSelected: selectedRoles.contains('teenager'),
                      onTap: () => onRoleSelected('teenager'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String role;
  final String emoji;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? theme.colorScheme.onPrimaryContainer
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isSelected
                              ? theme.colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.7)
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Page 3: Priorities ──────────────────────────────────────────────────────

class OnboardingPrioritiesPage extends StatelessWidget {
  final Set<String> selectedPriorities;
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;
  final ValueChanged<String> onPriorityToggled;

  const OnboardingPrioritiesPage({
    super.key,
    required this.selectedPriorities,
    required this.fadeAnimation,
    required this.slideAnimation,
    required this.onPriorityToggled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Text(
                'Was brauchst du\nam meisten?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Wähle alles was auf dich zutrifft. Wir ordnen\ndeine App danach.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView(
                  children: [
                    _PriorityCard(
                      id: 'tipps',
                      icon: Icons.lightbulb_rounded,
                      title: 'Tipps & Wissen',
                      subtitle:
                          'Entwicklungsimpulse, KI-Beratung, Erziehungstipps',
                      color: const Color(0xFF0EA5A4),
                      isSelected: selectedPriorities.contains('tipps'),
                      onTap: () => onPriorityToggled('tipps'),
                    ),
                    const SizedBox(height: 12),
                    _PriorityCard(
                      id: 'organisation',
                      icon: Icons.event_note_rounded,
                      title: 'Organisation',
                      subtitle: 'Kalender, To-Do-Listen, Einkaufslisten',
                      color: const Color(0xFF2563EB),
                      isSelected: selectedPriorities.contains('organisation'),
                      onTap: () => onPriorityToggled('organisation'),
                    ),
                    const SizedBox(height: 12),
                    _PriorityCard(
                      id: 'community',
                      icon: Icons.people_rounded,
                      title: 'Andere Eltern finden',
                      subtitle: 'Matching, Events, Playdates',
                      color: const Color(0xFF8B5CF6),
                      isSelected: selectedPriorities.contains('community'),
                      onTap: () => onPriorityToggled('community'),
                    ),
                    const SizedBox(height: 12),
                    _PriorityCard(
                      id: 'sparen',
                      icon: Icons.savings_rounded,
                      title: 'Sparen & Teilen',
                      subtitle: 'Verschenkmarkt, Essen teilen, Budget',
                      color: const Color(0xFFE8543A),
                      isSelected: selectedPriorities.contains('sparen'),
                      onTap: () => onPriorityToggled('sparen'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityCard extends StatelessWidget {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _PriorityCard({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isSelected
            ? color.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? color : theme.colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.15)
                        : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? color : Colors.transparent,
                    border: Border.all(
                      color:
                          isSelected ? color : theme.colorScheme.outlineVariant,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Page 4: Ready / Summary ─────────────────────────────────────────────────

class OnboardingReadyPage extends StatelessWidget {
  final String? selectedRole;
  final Set<String> selectedPriorities;
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;

  const OnboardingReadyPage({
    super.key,
    required this.selectedRole,
    required this.selectedPriorities,
    required this.fadeAnimation,
    required this.slideAnimation,
  });

  String _getRoleLabel() {
    switch (selectedRole) {
      case 'neugeboren':
        return 'Baby-Phase';
      case 'kleinkind':
        return 'Kleinkind-Phase';
      case 'schulkind':
        return 'Schulkind-Phase';
      case 'teenager':
        return 'Teenager-Phase';
      default:
        return '';
    }
  }

  List<(IconData, String)> _getPersonalizedFeatures() {
    final features = <(IconData, String)>[];

    if (selectedPriorities.contains('tipps')) {
      features.add((
        Icons.auto_awesome_rounded,
        'Wochenimpulse passend zur ${_getRoleLabel()}'
      ));
      features.add((Icons.chat_rounded, 'KI-Beratung für deine Fragen'));
    }
    if (selectedPriorities.contains('organisation')) {
      features.add((Icons.calendar_month_rounded, 'Familienkalender'));
      features.add((Icons.checklist_rounded, 'To-Do & Einkaufslisten'));
    }
    if (selectedPriorities.contains('community')) {
      features.add((Icons.diversity_3_rounded, 'Eltern in deiner Nähe finden'));
      features.add((Icons.celebration_rounded, 'Events & Aktivitäten'));
    }
    if (selectedPriorities.contains('sparen')) {
      features.add((Icons.inventory_2_rounded, 'Verschenkmarkt'));
      features.add((Icons.restaurant_rounded, 'Essen teilen & sparen'));
    }

    if (features.isEmpty) {
      features.add((Icons.auto_awesome_rounded, 'Personalisierte Impulse'));
      features.add((Icons.chat_rounded, 'KI-Beratung'));
      features.add((Icons.calendar_month_rounded, 'Familienkalender'));
    }

    return features.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final features = _getPersonalizedFeatures();

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0EA5A4),
                      theme.colorScheme.primary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Alles bereit!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Deine App ist jetzt auf dich zugeschnitten.\nHier ist, was auf dich wartet:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              // Personalisierte Feature-Liste
              ...features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            f.$1,
                            color: theme.colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            f.$2,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.check_circle_rounded,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 24),
              // Beta- und Trial-Hinweis
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.card_giftcard_rounded,
                      color: theme.colorScheme.tertiary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Beta kostenlos · nach dem Start 1 Monat testen',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Page: Kind-Alter ─────────────────────────────────────────────────────────

class OnboardingChildAgePage extends StatelessWidget {
  final List<String> selectedAges;
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;
  final ValueChanged<String> onAgeToggled;

  const OnboardingChildAgePage({
    super.key,
    required this.selectedAges,
    required this.fadeAnimation,
    required this.slideAnimation,
    required this.onAgeToggled,
  });

  static const _ageOptions = [
    {'id': 'baby', 'emoji': '\u{1F476}', 'label': 'Baby', 'desc': '0–1 Jahr'},
    {
      'id': 'kleinkind',
      'emoji': '\u{1F9D2}',
      'label': 'Kleinkind',
      'desc': '1–3 Jahre'
    },
    {
      'id': 'kindergarten',
      'emoji': '\u{1F466}',
      'label': 'Kindergarten',
      'desc': '3–6 Jahre'
    },
    {
      'id': 'grundschule',
      'emoji': '\u{1F393}',
      'label': 'Grundschule',
      'desc': '6–10 Jahre'
    },
    {
      'id': 'teenager',
      'emoji': '\u{1F9D1}',
      'label': 'Teenager',
      'desc': '10+ Jahre'
    },
    {
      'id': 'schwanger',
      'emoji': '\u{1F930}',
      'label': 'Schwanger',
      'desc': 'Wir erwarten'
    },
    {
      'id': 'bezugsperson',
      'emoji': '\u{1F49B}',
      'label': 'Bezugsperson',
      'desc': 'Oma, Opa, Patenonkel, Tagesmutter'
    },
    {
      'id': 'auf_dem_weg',
      'emoji': '\u{1F331}',
      'label': 'Noch auf dem Weg',
      'desc': 'Adoption, Pflegefamilie, Kinderwunsch'
    },
    {
      'id': 'fachlich',
      'emoji': '\u{1F4DA}',
      'label': 'Fachlich interessiert',
      'desc': 'Pädagogik, Sozialarbeit, Fortbildung'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Text(
                AppStringsManager.getString(languageService.currentLanguage, 'onboarding_phase'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStringsManager.getString(languageService.currentLanguage, 'phase_multiselect'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: ListView.builder(
                  itemCount: _ageOptions.length,
                  itemBuilder: (_, i) {
                    final opt = _ageOptions[i];
                    final selected = selectedAges.contains(opt['id']);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onAgeToggled(opt['id']!),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: selected
                                ? theme.colorScheme.primary
                                    .withValues(alpha: 0.08)
                                : theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(children: [
                            Text(opt['emoji']!,
                                style: const TextStyle(fontSize: 28)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(opt['label']!,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      )),
                                  Text(opt['desc']!,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: theme
                                              .colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            if (selected)
                              Icon(Icons.check_circle_rounded,
                                  color: theme.colorScheme.primary, size: 22),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Page: Land & Region ─────────────────────────────────────────────────────

class OnboardingCountryPage extends StatelessWidget {
  final String selectedCountry;
  final String selectedRegion;
  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;
  final ValueChanged<String> onCountrySelected;
  final ValueChanged<String> onRegionSelected;

  const OnboardingCountryPage({
    super.key,
    required this.selectedCountry,
    required this.selectedRegion,
    required this.fadeAnimation,
    required this.slideAnimation,
    required this.onCountrySelected,
    required this.onRegionSelected,
  });

  static const _countries = [
    {'code': 'DE', 'flag': '\u{1F1E9}\u{1F1EA}', 'name': 'Deutschland'},
    {'code': 'AT', 'flag': '\u{1F1E6}\u{1F1F9}', 'name': 'Österreich'},
    {'code': 'CH', 'flag': '\u{1F1E8}\u{1F1ED}', 'name': 'Schweiz'},
    {'code': 'TR', 'flag': '\u{1F1F9}\u{1F1F7}', 'name': 'Türkei'},
    {'code': 'GB', 'flag': '\u{1F1EC}\u{1F1E7}', 'name': 'Großbritannien'},
  ];

  static const Map<String, List<Map<String, String>>> regions = {
    'DE': [
      {'code': 'NRW', 'name': 'Nordrhein-Westfalen'},
      {'code': 'BY', 'name': 'Bayern'},
      {'code': 'BW', 'name': 'Baden-Württemberg'},
      {'code': 'NI', 'name': 'Niedersachsen'},
      {'code': 'HE', 'name': 'Hessen'},
      {'code': 'BE', 'name': 'Berlin'},
      {'code': 'HH', 'name': 'Hamburg'},
      {'code': 'SN', 'name': 'Sachsen'},
      {'code': 'SH', 'name': 'Schleswig-Holstein'},
      {'code': 'RP', 'name': 'Rheinland-Pfalz'},
      {'code': 'TH', 'name': 'Thüringen'},
      {'code': 'BB', 'name': 'Brandenburg'},
      {'code': 'SA', 'name': 'Sachsen-Anhalt'},
      {'code': 'MV', 'name': 'Mecklenburg-Vorpommern'},
      {'code': 'HB', 'name': 'Bremen'},
      {'code': 'SL', 'name': 'Saarland'},
    ],
    'AT': [
      {'code': 'Wien', 'name': 'Wien'},
      {'code': 'NÖ', 'name': 'Niederösterreich'},
      {'code': 'OÖ', 'name': 'Oberösterreich'},
      {'code': 'Tirol', 'name': 'Tirol'},
      {'code': 'Sbg', 'name': 'Salzburg'},
      {'code': 'Stmk', 'name': 'Steiermark'},
    ],
    'CH': [
      {'code': 'ZH', 'name': 'Zürich'},
      {'code': 'BE', 'name': 'Bern'},
      {'code': 'BS', 'name': 'Basel'},
      {'code': 'AG', 'name': 'Aargau'},
    ],
    'TR': [
      {'code': 'TR', 'name': 'Türkei (national)'},
    ],
    'GB': [
      {'code': 'ENG', 'name': 'England'},
      {'code': 'SCO', 'name': 'Scotland'},
      {'code': 'WAL', 'name': 'Wales'},
    ],
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final regions = OnboardingCountryPage.regions[selectedCountry] ?? [];

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Text(
                AppStringsManager.getString(languageService.currentLanguage, 'where_family_lives'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStringsManager.getString(languageService.currentLanguage, 'for_holidays_info'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              // Country selection
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _countries.map((c) {
                  final selected = selectedCountry == c['code'];
                  return GestureDetector(
                    onTap: () => onCountrySelected(c['code']!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? theme.colorScheme.primary.withValues(alpha: 0.1)
                            : theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(c['flag']!, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(c['name']!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                            )),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              if (regions.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Region / Bundesland',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: regions.length,
                    itemBuilder: (_, i) {
                      final r = regions[i];
                      final selected = selectedRegion == r['code'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onRegionSelected(r['code']!),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: selected
                                  ? theme.colorScheme.primary
                                      .withValues(alpha: 0.08)
                                  : theme.colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(children: [
                              Expanded(
                                child: Text(r['name']!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    )),
                              ),
                              if (selected)
                                Icon(Icons.check_circle_rounded,
                                    color: theme.colorScheme.primary, size: 20),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
