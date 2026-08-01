import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/product_metrics_service.dart';
import 'package:parentpeak/ui/calendar_screen.dart';
import 'package:parentpeak/ui/events_activities_screen.dart';
import 'package:parentpeak/ui/event_invitations_screen.dart';
import 'package:parentpeak/ui/organization_screen.dart';
import 'package:parentpeak/ui/entwicklung_impulse_screen.dart';
import 'package:parentpeak/ui/parent_matching_screen.dart';
import 'package:parentpeak/ui/chat_screen.dart';
import 'package:parentpeak/ui/finance_budget_screen.dart';
import 'package:parentpeak/ui/gemeinsam_satt_screen.dart';
import 'package:parentpeak/ui/treasure_handover_screen.dart';
import 'package:parentpeak/l10n/app_localizations.dart';

class _FeatureAction {
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;
  final String? statusHint;

  const _FeatureAction({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.builder,
    this.statusHint,
  });
}

const String _debugOpenFeature =
    String.fromEnvironment('PP_DEBUG_OPEN_FEATURE', defaultValue: '');

class HomeScreen extends StatefulWidget {
  final String? initialInviteInput;

  const HomeScreen({super.key, this.initialInviteInput});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const String _recentTilesStorageKey = 'home.recent_tiles.v1';
  static const String _tileOrderStorageKey = 'home.tile_order.v1';
  static const String _parentMatchStorageKey = 'parent_matching.v1';
  static const int _recentTilesLimit = 3;

  bool _initialInviteHandled = false;
  bool _debugFeatureHandled = false;
  List<String> _recentTileLabels = const [];
  List<String> _customTileOrderLabels = const [];
  int _newParentMatchesCount = 0;
  late final AnimationController _attentionController;
  late final Animation<double> _attentionAnimation;

  @override
  void initState() {
    super.initState();
    _attentionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _attentionAnimation = CurvedAnimation(
      parent: _attentionController,
      curve: Curves.easeInOut,
    );
    languageService.addListener(_onLanguageChanged);
    _restoreRecentTiles();
    _restoreTileOrder();
    _restoreParentMatchStatusHint();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openInitialInviteIfNeeded();
      _openDebugFeatureIfNeeded();
    });
  }

  @override
  void dispose() {
    _attentionController.dispose();
    languageService.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _openInitialInviteIfNeeded() {
    if (_initialInviteHandled) return;
    final input = widget.initialInviteInput?.trim();
    if (input == null || input.isEmpty || !mounted) return;

    _initialInviteHandled = true;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventInvitationsScreen(initialInviteInput: input),
      ),
    );
  }

  void _openDebugFeatureIfNeeded() {
    if (_debugFeatureHandled || !mounted) return;
    final target = _debugOpenFeature.trim().toLowerCase();
    if (target.isEmpty) return;

    _debugFeatureHandled = true;
    if (target == 'entwicklung' || target == 'impulse') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const EntwicklungImpulseScreen()),
      );
      return;
    }

    if (target == 'entwicklung-tab') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const EntwicklungImpulseScreen(initialTabIndex: 1),
        ),
      );
    }
  }

  Future<void> _restoreRecentTiles() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_recentTilesStorageKey) ?? const [];
    if (!mounted) return;
    setState(() {
      _recentTileLabels = stored;
    });
  }

  Future<void> _storeRecentTileTap(String label) async {
    final normalized = label.trim();
    if (normalized.isEmpty) return;

    final updated = <String>[normalized];
    for (final item in _recentTileLabels) {
      if (item != normalized && updated.length < _recentTilesLimit) {
        updated.add(item);
      }
    }

    if (mounted) {
      setState(() {
        _recentTileLabels = updated;
      });
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentTilesStorageKey, updated);
  }

  Future<void> _restoreTileOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_tileOrderStorageKey) ?? const [];
    if (!mounted) return;
    setState(() {
      _customTileOrderLabels = stored;
    });
  }

  Future<void> _prioritizeTile(String label) async {
    final normalized = label.trim();
    if (normalized.isEmpty) return;

    final updated = <String>[normalized];
    for (final item in _customTileOrderLabels) {
      if (item != normalized) {
        updated.add(item);
      }
    }

    if (mounted) {
      setState(() {
        _customTileOrderLabels = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$normalized" ist jetzt weiter oben angeordnet.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_tileOrderStorageKey, updated);
  }

  Future<void> _resetTileOrder() async {
    if (_customTileOrderLabels.isEmpty) return;

    if (mounted) {
      setState(() {
        _customTileOrderLabels = const [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kachel-Sortierung wurde zurueckgesetzt.'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tileOrderStorageKey);
  }

  List<_FeatureAction> _applyCustomOrder(List<_FeatureAction> actions) {
    if (_customTileOrderLabels.isEmpty) {
      return actions;
    }

    final byLabel = <String, _FeatureAction>{
      for (final action in actions) action.label: action,
    };
    final ordered = <_FeatureAction>[];
    final used = <String>{};

    for (final label in _customTileOrderLabels) {
      final action = byLabel[label];
      if (action != null) {
        ordered.add(action);
        used.add(label);
      }
    }

    for (final action in actions) {
      if (!used.contains(action.label)) {
        ordered.add(action);
      }
    }

    return ordered;
  }

  Future<void> _openFeature(_FeatureAction action) async {
    await _storeRecentTileTap(action.label);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: action.builder),
    );
    if (!mounted) return;
    if (action.label == 'Eltern Match') {
      await _restoreParentMatchStatusHint();
    }
  }

  Future<void> _restoreParentMatchStatusHint() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_parentMatchStorageKey);
    if (raw == null || raw.isEmpty) {
      if (!mounted) return;
      setState(() => _newParentMatchesCount = 0);
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        if (!mounted) return;
        setState(() => _newParentMatchesCount = 0);
        return;
      }

      final matchedIds =
          (decoded['matchedIds'] as List?)?.map((e) => e.toString()).toSet() ??
              <String>{};
      final seenIds = (decoded['seenMatchedProfileIds'] as List?)
              ?.map((e) => e.toString())
              .toSet() ??
          matchedIds;
      final unseenCount = matchedIds.difference(seenIds).length;

      if (!mounted) return;
      setState(() => _newParentMatchesCount = unseenCount);
    } catch (_) {
      if (!mounted) return;
      setState(() => _newParentMatchesCount = 0);
    }
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {
        // Erzwinge Rebuild wenn Sprache wechselt
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final contentMaxWidth = viewportWidth >= 1400
        ? 1260.0
        : viewportWidth >= 1024
            ? 1120.0
            : double.infinity;
    final horizontalPadding = viewportWidth >= 1024 ? 24.0 : 20.0;
    final gridCrossAxisCount = viewportWidth >= 1220
        ? 4
        : viewportWidth >= 860
            ? 3
            : 2;
    final gridAspectRatio = viewportWidth >= 1220
        ? 1.42
        : viewportWidth >= 860
            ? 1.36
            : 1.38;

    final featureActions = <_FeatureAction>[
      _FeatureAction(
        label: 'Impulse & Entwicklung',
        description: 'Wochenimpuls und Entwicklung in einem Bereich',
        icon: Icons.auto_awesome_mosaic_rounded,
        color: const Color(0xFF0EA5A4),
        builder: (_) => const EntwicklungImpulseScreen(),
      ),
      _FeatureAction(
        label: 'Kalender',
        description: 'Termine und Familienplan',
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF2563EB),
        builder: (_) => const CalendarScreen(),
      ),
      _FeatureAction(
        label: 'Events & Aktivitäten',
        description: 'Events finden und selbst anbieten',
        icon: Icons.celebration_rounded,
        color: const Color(0xFF8B5CF6),
        builder: (_) => const EventsActivitiesScreen(),
      ),
      _FeatureAction(
        label: l10n.t('treasureTileTitle', fallback: 'Verschenkmarkt'),
        description: l10n.t('treasureTileSubtitle',
            fallback: 'Verschenken, austauschen, Eltern verbinden'),
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFF1E5CD7),
        builder: (_) => const TreasureHandoverScreen(),
      ),
      _FeatureAction(
        label: 'Eltern Match',
        description: 'Eltern finden fuer Playdates und Austausch',
        icon: Icons.diversity_3_rounded,
        color: const Color(0xFF0EA5A4),
        builder: (_) => const ParentMatchingScreen(),
        statusHint: _newParentMatchesCount > 0
            ? (_newParentMatchesCount == 1
                ? '1 neu bestaetigt'
                : '$_newParentMatchesCount neu bestaetigt')
            : null,
      ),
      _FeatureAction(
        label: 'KI Elternberatung',
        description: 'Schnelle Hilfe und Tipps rund um Erziehung',
        icon: Icons.tips_and_updates_rounded,
        color: const Color(0xFF0284C7),
        builder: (_) => const ChatScreen(),
      ),
      _FeatureAction(
        label: 'Organisation',
        description: 'To-do und Einkauf in einem Bereich',
        icon: Icons.fact_check_rounded,
        color: const Color(0xFF16A34A),
        builder: (_) => const OrganizationScreen(),
      ),
      _FeatureAction(
        label: 'GemeinsamSatt',
        description: 'Essen teilen · Zusammen satt werden',
        icon: Icons.favorite_rounded,
        color: const Color(0xFFE8543A),
        builder: (_) => const GemeinsamSattScreen(),
      ),
      _FeatureAction(
        label: 'Finanzen & Budget',
        description: 'Ausgaben fair teilen und smarter sparen',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF1D4ED8),
        builder: (_) => const FinanceBudgetScreen(),
      ),
    ];

    final visibleGridActions = _applyCustomOrder(featureActions);
    final actionByLabel = <String, _FeatureAction>{
      for (final action in visibleGridActions) action.label: action,
    };
    final developmentAction = actionByLabel['Impulse & Entwicklung'];
    final chatAction = actionByLabel['KI Elternberatung'];
    final calendarAction = actionByLabel['Kalender'];
    final recentActions = _recentTileLabels
        .map((label) => actionByLabel[label])
        .whereType<_FeatureAction>()
        .toList();

    final displayName =
        AuthService.instance.currentUser?.displayName.trim() ?? '';
    final familyGreeting = displayName.isEmpty
        ? 'Hallo Familie 👋'
        : 'Hallo Familie $displayName 👋';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        horizontalPadding, 10, horizontalPadding, 8),
                    child: _buildHeroCard(
                      theme,
                      familyGreeting,
                      showResetTileOrder: _customTileOrderLabels.isNotEmpty,
                      onResetTileOrder: _resetTileOrder,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        horizontalPadding, 0, horizontalPadding, 8),
                    child: _buildTodayFlowCard(
                      theme,
                      developmentAction: developmentAction,
                      chatAction: chatAction,
                      calendarAction: calendarAction,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.outline.withValues(alpha: 0),
                            theme.colorScheme.outline.withValues(alpha: 0.2),
                            theme.colorScheme.outline.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        horizontalPadding, 2, horizontalPadding, 10),
                    child: Text(
                      'Alle Bereiche',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                      horizontalPadding, 14, horizontalPadding, 24),
                  sliver: recentActions.isEmpty
                      ? const SliverToBoxAdapter(child: SizedBox.shrink())
                      : SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final action in recentActions)
                                  ActionChip(
                                    avatar: Icon(action.icon,
                                        size: 16, color: action.color),
                                    label: Text(action.label),
                                    onPressed: () => _openFeature(action),
                                  ),
                              ],
                            ),
                          ),
                        ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                      horizontalPadding, 0, horizontalPadding, 24),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final action = visibleGridActions[index];
                        final isParentMatchTile =
                            action.label == 'Eltern Match';
                        return _buildFeatureTile(
                          context,
                          title: action.label,
                          subtitle: action.description,
                          statusHint: action.statusHint,
                          quickActionLabel: null,
                          quickActionHelperText: null,
                          onQuickAction: null,
                          attentionAnimation:
                              isParentMatchTile && _newParentMatchesCount > 0
                                  ? _attentionAnimation
                                  : null,
                          icon: action.icon,
                          color: action.color,
                          compact: true,
                          onTap: () => _openFeature(action),
                          onLongPress: () => _prioritizeTile(action.label),
                        );
                      },
                      childCount: visibleGridActions.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridCrossAxisCount,
                      mainAxisSpacing: 7,
                      crossAxisSpacing: 7,
                      childAspectRatio: gridAspectRatio,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(
    ThemeData theme,
    String familyGreeting, {
    required bool showResetTileOrder,
    required VoidCallback onResetTileOrder,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Parentpeak',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    fontFamily: 'SF Pro Rounded',
                  ),
                ),
              ),
              if (showResetTileOrder)
                IconButton(
                  tooltip: 'Kachel-Sortierung zuruecksetzen',
                  onPressed: onResetTileOrder,
                  icon: const Icon(Icons.restart_alt_rounded,
                      color: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/neue logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      familyGreeting,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.97),
                        fontWeight: FontWeight.w500,
                        height: 1.18,
                        letterSpacing: 0.15,
                        fontFamily: 'SF Pro Rounded',
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Alles Wichtige für euren Alltag.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Gemeinsam planen, teilen und verbunden bleiben.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayFlowCard(
    ThemeData theme, {
    required _FeatureAction? developmentAction,
    required _FeatureAction? chatAction,
    required _FeatureAction? calendarAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surface,
        border:
            Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5A4).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.flag_rounded,
                    color: Color(0xFF0F766E), size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Heute starten',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Ein Schritt reicht: Kurzcheck in Impulse & Entwicklung und danach nur eine konkrete Alltagsaktion.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: developmentAction == null
                    ? null
                    : () async {
                        await ProductMetricsService.instance
                            .recordHomeQuickCheckCtaTap(
                          userId: AuthService.instance.currentUser?.uid,
                        );
                        await _openFeature(developmentAction);
                      },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Jetzt Kurzcheck'),
              ),
              OutlinedButton.icon(
                onPressed:
                    chatAction == null ? null : () => _openFeature(chatAction),
                icon: const Icon(Icons.tips_and_updates_rounded),
                label: const Text('Frage die KI'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await ProductMetricsService.instance
                      .recordHomeDevelopmentDirectCtaTap(
                    userId: AuthService.instance.currentUser?.uid,
                  );
                  if (!mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const EntwicklungImpulseScreen(initialTabIndex: 1),
                    ),
                  );
                },
                icon: const Icon(Icons.insights_rounded),
                label: const Text('Direkt Entwicklung'),
              ),
              OutlinedButton.icon(
                onPressed: calendarAction == null
                    ? null
                    : () => _openFeature(calendarAction),
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text('Zum Kalender'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Fallback: Wenn der Wochenimpuls gerade nicht laedt, starte direkt mit Entwicklung.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: chatAction == null
                      ? null
                      : () async {
                          await ProductMetricsService.instance
                              .recordHomeFallbackRouteTap(
                            from: 'calendar',
                            to: 'chat',
                            userId: AuthService.instance.currentUser?.uid,
                          );
                          if (!mounted) return;
                          await _openFeature(chatAction);
                        },
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Fallback Kalender → KI'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await ProductMetricsService.instance
                        .recordHomeFallbackRouteTap(
                      from: 'chat',
                      to: 'development',
                      userId: AuthService.instance.currentUser?.uid,
                    );
                    if (!mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const EntwicklungImpulseScreen(initialTabIndex: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Fallback KI → Entwicklung'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hinweis: Die App liefert Orientierung, keine medizinische Diagnose.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    String? statusHint,
    String? quickActionLabel,
    String? quickActionHelperText,
    required Color color,
    required IconData icon,
    bool compact = false,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    VoidCallback? onQuickAction,
    Animation<double>? attentionAnimation,
  }) {
    final theme = Theme.of(context);
    final tileCard = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactTile = compact ||
                constraints.maxWidth < 150 ||
                constraints.maxHeight < 210;
            final ultraCompactTile =
                compactTile || constraints.maxWidth < 132;
            return Container(
              padding: EdgeInsets.all(ultraCompactTile ? 8 : (compactTile ? 9 : 14)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.16),
                    color.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: ultraCompactTile ? 26 : (compactTile ? 28 : 42),
                    height: ultraCompactTile ? 26 : (compactTile ? 28 : 42),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius:
                          BorderRadius.circular(ultraCompactTile ? 9 : (compactTile ? 10 : 14)),
                    ),
                    child: Icon(icon,
                        color: Colors.white, size: ultraCompactTile ? 14 : (compactTile ? 15 : 22)),
                  ),
                  SizedBox(height: ultraCompactTile ? 3 : (compactTile ? 4 : 8)),
                  Text(
                    title,
                    maxLines: ultraCompactTile ? 1 : (compactTile ? 1 : 2),
                    overflow: TextOverflow.ellipsis,
                    style: (compactTile
                            ? theme.textTheme.labelLarge
                            : theme.textTheme.titleMedium)
                        ?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: ultraCompactTile ? 11.8 : (compactTile ? 12.5 : null),
                    ),
                  ),
                  SizedBox(height: ultraCompactTile ? 0.5 : (compactTile ? 1 : 3)),
                  Text(
                    subtitle,
                    style: (compactTile
                            ? theme.textTheme.bodySmall
                            : theme.textTheme.bodyMedium)
                        ?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: ultraCompactTile ? 1.15 : (compactTile ? 1.2 : 1.3),
                      fontSize: ultraCompactTile ? 9.9 : (compactTile ? 10.5 : null),
                    ),
                    maxLines: ultraCompactTile ? 1 : (compactTile ? 1 : 2),
                    overflow: TextOverflow.ellipsis,
                  ),
                    if (!compactTile &&
                      constraints.maxWidth >= 175 &&
                      statusHint != null &&
                      statusHint.trim().isNotEmpty) ...[
                    SizedBox(height: compactTile ? 4 : 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFF86EFAC),
                        ),
                      ),
                      child: Text(
                        statusHint,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF166534),
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (!compactTile) ...[
                    const Spacer(),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Icon(Icons.arrow_forward_ios_rounded,
                          size: 14, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );

    if (attentionAnimation == null) {
      return tileCard;
    }

    return AnimatedBuilder(
      animation: attentionAnimation,
      child: tileCard,
      builder: (context, child) {
        final t = attentionAnimation.value;
        final scale = 1 + (0.012 * t);
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.08 + (0.10 * t)),
                  blurRadius: 8 + (10 * t),
                  spreadRadius: 0.2 + (0.6 * t),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }
}
