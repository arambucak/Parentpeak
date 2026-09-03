import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/config/feature_flags.dart';
import 'package:parentpeak/logic/entitlement_service.dart';
import 'package:parentpeak/ui/calendar_screen.dart';
import 'package:parentpeak/ui/events_activities_screen.dart';
import 'package:parentpeak/ui/event_invitations_screen.dart';
import 'package:parentpeak/ui/organization_screen.dart';
import 'package:parentpeak/ui/familien_zentrale_screen.dart';
import 'package:parentpeak/ui/entwicklung_impulse_screen.dart';
import 'package:parentpeak/ui/chat_screen.dart';
import 'package:parentpeak/ui/finance_budget_screen.dart';
import 'package:parentpeak/ui/familien_geld_screen.dart';
import 'package:parentpeak/ui/gemeinsam_satt_screen.dart';
import 'package:parentpeak/ui/familien_kueche_screen.dart';
import 'package:parentpeak/ui/treasure_handover_screen.dart';
import 'package:parentpeak/ui/eltern_netzwerk_screen.dart';
import 'package:parentpeak/ui/auth/paywall_screen.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/parent_coin_service.dart';
import 'package:parentpeak/ui/widgets/home/context_home_card.dart';
import 'package:parentpeak/ui/widgets/home/quick_actions_row.dart';
import 'package:parentpeak/ui/widgets/home/events_carousel_widget.dart';
import 'package:parentpeak/services/mood_history_service.dart';
import 'package:parentpeak/ui/wochenrueckblick_screen.dart';
import 'package:parentpeak/l10n/app_localizations.dart';

class _FeatureAction {
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;
  final String? statusHint;
  final String? featureId;

  const _FeatureAction({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.builder,
    this.statusHint,
    this.featureId,
  });
}

const String _debugOpenFeature =
    String.fromEnvironment('PP_DEBUG_OPEN_FEATURE', defaultValue: '');

class HomeScreen extends StatefulWidget {
  final String? initialInviteInput;
  final String? initialFriendCode;
  final String? initialReferralCode;

  const HomeScreen(
      {super.key,
      this.initialInviteInput,
      this.initialFriendCode,
      this.initialReferralCode});

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
  bool _initialFriendHandled = false;
  bool _initialReferralHandled = false;
  bool _debugFeatureHandled = false;
  StreamSubscription<User?>? _authSub;
  List<String> _recentTileLabels = const [];
  List<String> _customTileOrderLabels = const [];
  int _newParentMatchesCount = 0;
  DateTime? _lastParentMatchHapticAt;
  bool _isOpeningParentMatchQuickAction = false;
  late final AnimationController _attentionController;
  late final Animation<double> _attentionAnimation;
  List<Map<String, dynamic>> _todayEvents = [];

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
    if (kIsWeb) _loadTodayEvents();
    languageService.addListener(_onLanguageChanged);
    _restoreRecentTiles();
    _restoreTileOrder();
    _restoreParentMatchStatusHint();
    // Retry pending referral + coin claim whenever auth state changes
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && mounted) {
        _processPendingReferral();
        ParentCoinService.instance.claimPendingReferrals(context);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openInitialInviteIfNeeded();
      _openInitialFriendIfNeeded();
      _handleStartupReferralIfNeeded();
      _processPendingReferral(); // also covers post-login case
      _openDebugFeatureIfNeeded();
      ParentCoinService.instance.claimPendingReferrals(context);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _attentionController.dispose();
    languageService.removeListener(_onLanguageChanged);
    super.dispose();
  }

  Future<void> _loadTodayEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('calendar.events');
    if (raw == null || raw.isEmpty) return;
    try {
      final all = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayEnd = today.add(const Duration(days: 1));
      final upcoming = all.where((e) {
        final start = DateTime.tryParse(e['start']?.toString() ?? '');
        if (start == null) return false;
        return !start.isBefore(now) && start.isBefore(todayEnd);
      }).toList()
        ..sort((a, b) {
          final sa = DateTime.parse(a['start'].toString());
          final sb = DateTime.parse(b['start'].toString());
          return sa.compareTo(sb);
        });
      if (mounted) setState(() => _todayEvents = upcoming);
    } catch (_) {}
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

  void _openInitialFriendIfNeeded() {
    if (_initialFriendHandled) return;
    final code = widget.initialFriendCode?.trim();
    if (code == null || code.isEmpty || !mounted) return;

    _initialFriendHandled = true;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ElternNetzwerkScreen(initialFriendCode: code),
      ),
    );
  }

  void _handleStartupReferralIfNeeded() {
    if (_initialReferralHandled) return;
    final code = widget.initialReferralCode?.trim();
    if (code == null || code.isEmpty || !mounted) return;
    _initialReferralHandled = true;

    SharedPreferences.getInstance().then((prefs) {
      final existing = prefs.getString('pending_referral_code');
      if (existing != null) return; // already stored → welcome shown, skip
      prefs.setString('pending_referral_code', code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStringsManager.getString(
              languageService.currentLanguage, 'welcome_invite')),
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  Future<void> _processPendingReferral() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('pending_referral_code');
    if (code == null || code.isEmpty) return;
    final name = AuthService.instance.currentUser?.displayName ??
        AppStringsManager.getString(
            languageService.currentLanguage, 'new_member');
    final sent =
        await ParentCoinService.instance.recordReferral(code, uid, name);
    if (sent) await prefs.remove('pending_referral_code');
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
          content: Text(
              '"$normalized" ${AppStringsManager.getString(languageService.currentLanguage, 'tile_moved_up')}'),
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
        SnackBar(
          content: Text(AppStringsManager.getString(
              languageService.currentLanguage, 'tile_order_reset')),
          duration: const Duration(seconds: 2),
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
    // Feature-Flag Check
    if (action.featureId != null) {
      final featureFlags = FeatureFlagService.instance;
      final featureState = featureFlags.getFeatureState(action.featureId!);

      if (featureState == FeatureState.comingSoon) {
        // Track Tap und zeige Coming-Soon Dialog
        await featureFlags.recordLockedFeatureTap(action.featureId!);
        if (!mounted) return;
        _showComingSoonDialog(action);
        return;
      }

      if (featureState == FeatureState.hidden) {
        return; // Sollte nicht passieren, aber Safety
      }

      // Entitlement-Check (Free vs Premium)
      final entitlement = EntitlementService.instance;
      if (!entitlement.canAccessSync(action.featureId!)) {
        if (!mounted) return;
        _showPremiumRequiredDialog(action);
        return;
      }
    }

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

  void _showComingSoonDialog(_FeatureAction action) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(action.icon, color: action.color, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'coming_soon'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${action.label} ${AppStringsManager.getString(languageService.currentLanguage, 'coming_soon_desc')}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_active_rounded,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    AppStringsManager.getString(
                        languageService.currentLanguage, 'will_notify'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(AppStringsManager.getString(
                    languageService.currentLanguage, 'understood')),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showPremiumRequiredDialog(_FeatureAction action) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.tertiary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'premium_feature'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${action.label} ${AppStringsManager.getString(languageService.currentLanguage, 'premium_feature_desc')}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaywallScreen(
                        onSubscribed: () {
                          Navigator.pop(context);
                          setState(() {});
                        },
                      ),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(AppStringsManager.getString(
                    languageService.currentLanguage, 'discover_premium')),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppStringsManager.getString(
                  languageService.currentLanguage, 'not_now')),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _openParentMatchQuickAction({
    required bool openNewConnections,
  }) async {
    if (_isOpeningParentMatchQuickAction) return;
    _isOpeningParentMatchQuickAction = true;

    final now = DateTime.now();
    final shouldHaptic = _lastParentMatchHapticAt == null ||
        now.difference(_lastParentMatchHapticAt!) >= const Duration(seconds: 1);
    if (shouldHaptic) {
      await HapticFeedback.lightImpact();
      _lastParentMatchHapticAt = now;
    }
    try {
      await _storeRecentTileTap('Eltern Match');
      if (!mounted) return;
      // Prio 3: 'Eltern Match' fuehrt jetzt in das vereinheitlichte
      // Eltern-Netzwerk (echte Spielfreunde-Discovery), nicht mehr in den
      // separaten ParentMatchingScreen.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ElternNetzwerkScreen(initialTab: 1),
        ),
      );
      if (!mounted) return;
      await _restoreParentMatchStatusHint();
    } finally {
      _isOpeningParentMatchQuickAction = false;
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

  String _getTimeGreeting(String lang) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return AppStringsManager.getString(lang, 'greeting_morning');
    } else if (hour < 18) {
      return AppStringsManager.getString(lang, 'greeting_afternoon');
    } else {
      return AppStringsManager.getString(lang, 'greeting_evening');
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

    final lang = languageService.currentLanguage;

    final featureActions = <_FeatureAction>[
      _FeatureAction(
        label: AppStringsManager.getString(lang, 'tile_impulse'),
        description: AppStringsManager.getString(lang, 'tile_impulse_desc'),
        icon: Icons.auto_awesome_mosaic_rounded,
        color: const Color(0xFF0EA5A4),
        builder: (_) => const EntwicklungImpulseScreen(),
        featureId: 'impulse_entwicklung',
      ),
      _FeatureAction(
        label: AppStringsManager.getString(lang, 'tile_calendar'),
        description: AppStringsManager.getString(lang, 'tile_calendar_desc'),
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF2563EB),
        builder: (_) => const CalendarScreen(),
        featureId: 'kalender',
      ),
      _FeatureAction(
        label: AppStringsManager.getString(lang, 'tile_events'),
        description: AppStringsManager.getString(lang, 'tile_events_desc'),
        icon: Icons.celebration_rounded,
        color: const Color(0xFF8B5CF6),
        builder: (_) => const EventsActivitiesScreen(),
        featureId: 'events_aktivitaeten',
      ),
      _FeatureAction(
        label: l10n.t('treasureTileTitle', fallback: 'Verschenkmarkt'),
        description: l10n.t('treasureTileSubtitle',
            fallback: 'Verschenken, austauschen, Eltern verbinden'),
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFF1E5CD7),
        builder: (_) => const TreasureHandoverScreen(),
        featureId: 'verschenkmarkt',
      ),
      _FeatureAction(
        label: AppStringsManager.getString(lang, 'tile_network'),
        description: AppStringsManager.getString(lang, 'tile_network_desc'),
        icon: Icons.people_rounded,
        color: const Color(0xFF0EA5A4),
        builder: (_) => const ElternNetzwerkScreen(),
        featureId: 'eltern_match',
        statusHint: _newParentMatchesCount > 0
            ? (_newParentMatchesCount == 1
                ? '1 neu bestaetigt'
                : '$_newParentMatchesCount neu bestaetigt')
            : null,
      ),
      _FeatureAction(
        label: AppStringsManager.getString(lang, 'tile_chat'),
        description: AppStringsManager.getString(lang, 'tile_chat_desc'),
        icon: Icons.tips_and_updates_rounded,
        color: const Color(0xFF0284C7),
        builder: (_) => const ChatScreen(),
        featureId: 'ki_elternberatung',
      ),
      _FeatureAction(
        label: AppStringsManager.getString(lang, 'tile_zentrale'),
        description: AppStringsManager.getString(lang, 'tile_zentrale_desc'),
        icon: Icons.home_rounded,
        color: const Color(0xFF2563EB),
        builder: (_) => const FamilienZentraleScreen(),
        featureId: 'organisation',
      ),
      _FeatureAction(
        label: AppStringsManager.getString(lang, 'tile_kueche'),
        description: AppStringsManager.getString(lang, 'tile_kueche_desc'),
        icon: Icons.restaurant_rounded,
        color: const Color(0xFFF97316),
        builder: (_) => const FamilienKuecheScreen(),
        featureId: 'gemeinsam_satt',
      ),
      _FeatureAction(
        label: AppStringsManager.getString(lang, 'tile_geld'),
        description: AppStringsManager.getString(lang, 'tile_geld_desc'),
        icon: Icons.savings_rounded,
        color: const Color(0xFF16A34A),
        builder: (_) => const FamilienGeldScreen(),
        featureId: 'finanzen_budget',
      ),
    ];

    final visibleGridActions =
        _applyCustomOrder(featureActions).where((action) {
      if (action.featureId == null) return true;
      return !FeatureFlagService.instance.isHidden(action.featureId!);
    }).toList();

    // Features already accessible via Quick-Actions or Smart-Card
    const _quickAccessIds = {
      'kalender',
      'ki_elternberatung',
      'gemeinsam_satt',
      'organisation',
      'events_aktivitaeten'
    };
    final gridActions = visibleGridActions
        .where((a) =>
            a.featureId == null || !_quickAccessIds.contains(a.featureId))
        .toList();

    final displayName =
        AuthService.instance.currentUser?.displayName.trim() ?? '';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: CustomScrollView(
              slivers: [
                // ─── Context Card (Tageszeit-basiert) ────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        horizontalPadding, 10, horizontalPadding, 16),
                    child: ContextHomeCard(
                      onExpandTip: () {
                        final chatAction = visibleGridActions
                            .where((a) => a.featureId == 'ki_elternberatung')
                            .firstOrNull;
                        if (chatAction != null) _openFeature(chatAction);
                      },
                      onOpenChat: () {
                        final chatAction = visibleGridActions
                            .where((a) => a.featureId == 'ki_elternberatung')
                            .firstOrNull;
                        if (chatAction != null) _openFeature(chatAction);
                      },
                      onOpenCalendar: () {
                        final calAction = visibleGridActions
                            .where((a) => a.featureId == 'kalender')
                            .firstOrNull;
                        if (calAction != null) _openFeature(calAction);
                      },
                      onOpenActivity: () {
                        final impulseAction = visibleGridActions
                            .where((a) => a.featureId == 'gemeinsam_satt')
                            .firstOrNull;
                        if (impulseAction != null) _openFeature(impulseAction);
                      },
                      onMoodSelected: (mood, moment) {
                        MoodHistoryService.saveMood(mood, moment: moment);
                      },
                      onOpenWeeklyReview: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WochenrueckblickScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // ─── Quick Actions (4 Icons) ────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        horizontalPadding, 0, horizontalPadding, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _quickAction(
                          icon: Icons.calendar_month_rounded,
                          label: 'Kalender',
                          color: const Color(0xFF2563EB),
                          onTap: () {
                            final a = visibleGridActions
                                .where((a) => a.featureId == 'kalender')
                                .firstOrNull;
                            if (a != null) _openFeature(a);
                          },
                        ),
                        _quickAction(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Frag mich',
                          color: const Color(0xFF0EA5E9),
                          onTap: () {
                            final a = visibleGridActions
                                .where(
                                    (a) => a.featureId == 'ki_elternberatung')
                                .firstOrNull;
                            if (a != null) _openFeature(a);
                          },
                        ),
                        _quickAction(
                          icon: Icons.restaurant_rounded,
                          label: 'Rezepte',
                          color: const Color(0xFFEA580C),
                          onTap: () {
                            final a = visibleGridActions
                                .where((a) => a.featureId == 'gemeinsam_satt')
                                .firstOrNull;
                            if (a != null) _openFeature(a);
                          },
                        ),
                        _quickAction(
                          icon: Icons.checklist_rounded,
                          label: 'Listen',
                          color: const Color(0xFF16A34A),
                          onTap: () {
                            final a = visibleGridActions
                                .where((a) => a.featureId == 'organisation')
                                .firstOrNull;
                            if (a != null) _openFeature(a);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // ─── Smart Context Card ────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        horizontalPadding, 0, horizontalPadding, 16),
                    child: _buildSmartCard(visibleGridActions),
                  ),
                ),
                // ─── Feature Grid Header ─────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        horizontalPadding, 0, horizontalPadding, 10),
                    child: Row(
                      children: [
                        Text(
                          'Deine Features',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        if (visibleGridActions.length > 4)
                          GestureDetector(
                            onTap: () => _showAllFeatures(visibleGridActions),
                            child: Text(
                              'Alle \u{2192}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // ─── Feature Grid (2x2, sauber) ─────────────────
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                      horizontalPadding, 0, horizontalPadding, 24),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final action = gridActions[index];
                        final isParentMatchTile =
                            action.label == 'Eltern Match';
                        final featureState = action.featureId != null
                            ? FeatureFlagService.instance
                                .getFeatureState(action.featureId!)
                            : FeatureState.enabled;
                        final isLocked =
                            featureState == FeatureState.comingSoon;
                        final isPremiumLocked = action.featureId != null &&
                            featureState == FeatureState.enabled &&
                            !EntitlementService.instance
                                .canAccessSync(action.featureId!);

                        return _buildFeatureTileWithState(
                          context,
                          action: action,
                          isComingSoon: isLocked,
                          isPremiumLocked: isPremiumLocked,
                          isParentMatchTile: isParentMatchTile,
                        );
                      },
                      childCount: visibleGridActions.length > 4
                          ? 4
                          : visibleGridActions.length,
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
                  tooltip: AppStringsManager.getString(
                      languageService.currentLanguage, 'reset_tile_order'),
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
                      AppStringsManager.getString(
                          languageService.currentLanguage, 'all_important'),
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
                      AppStringsManager.getString(
                          languageService.currentLanguage, 'plan_together'),
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

  Widget _quickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildSmartCard(List<_FeatureAction> actions) {
    final hour = DateTime.now().hour;
    final theme = Theme.of(context);

    // Morning: Reminder for today's events
    if (hour < 12 && _todayEvents.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.1)),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded,
              color: const Color(0xFF2563EB), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Heute ${_todayEvents.length} ${_todayEvents.length == 1 ? "Termin" : "Termine"}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                Text('Tippe um den Kalender zu öffnen',
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20),
        ]),
      );
    }

    // Afternoon/Evening: Weekly review prompt
    if (hour >= 18) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const WochenrueckblickScreen())),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12)),
          ),
          child: Row(children: [
            Icon(Icons.self_improvement_rounded,
                color: const Color(0xFF7C3AED), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      AppStringsManager.getString(
                          languageService.currentLanguage,
                          'your_weekly_review'),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B21A8))),
                  Text('Wie war deine Woche?',
                      style: TextStyle(
                          fontSize: 11,
                          color:
                              const Color(0xFF7C3AED).withValues(alpha: 0.7))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey[400], size: 20),
          ]),
        ),
      );
    }

    // Default: Events teaser
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final a = actions
            .where((a) => a.featureId == 'events_aktivitaeten')
            .firstOrNull;
        if (a != null) _openFeature(a);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.1)),
        ),
        child: Row(children: [
          Icon(Icons.explore_rounded, color: const Color(0xFF8B5CF6), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
                AppStringsManager.getString(
                    languageService.currentLanguage, 'events_near_you'),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B21A8))),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20),
        ]),
      ),
    );
  }

  void _showAllFeatures(List<_FeatureAction> actions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Alle Features',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                itemCount: actions.length,
                itemBuilder: (_, i) {
                  final action = actions[i];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _openFeature(action);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: action.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child:
                              Icon(action.icon, color: action.color, size: 22),
                        ),
                        const SizedBox(height: 6),
                        Text(action.label,
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTileWithState(
    BuildContext context, {
    required _FeatureAction action,
    required bool isComingSoon,
    required bool isPremiumLocked,
    required bool isParentMatchTile,
  }) {
    final theme = Theme.of(context);

    Widget tile = _buildFeatureTile(
      context,
      title: action.label,
      subtitle: isComingSoon
          ? AppStringsManager.getString(
              languageService.currentLanguage, 'soon_available')
          : action.description,
      statusHint: isComingSoon ? null : action.statusHint,
      quickActionLabel: (!isComingSoon && !isPremiumLocked && isParentMatchTile)
          ? (_newParentMatchesCount > 0
              ? AppStringsManager.getString(
                  languageService.currentLanguage, 'open_new_connections')
              : AppStringsManager.getString(
                  languageService.currentLanguage, 'open_parent_match'))
          : null,
      quickActionHelperText: (!isComingSoon &&
              !isPremiumLocked &&
              isParentMatchTile &&
              _newParentMatchesCount == 0)
          ? AppStringsManager.getString(
              languageService.currentLanguage, 'no_new_connections')
          : null,
      onQuickAction: (!isComingSoon && !isPremiumLocked && isParentMatchTile)
          ? () => _openParentMatchQuickAction(
                openNewConnections: _newParentMatchesCount > 0,
              )
          : null,
      attentionAnimation: (!isComingSoon &&
              !isPremiumLocked &&
              isParentMatchTile &&
              _newParentMatchesCount > 0)
          ? _attentionAnimation
          : null,
      icon: action.icon,
      color: isComingSoon ? action.color.withValues(alpha: 0.5) : action.color,
      compact: true,
      onTap: () => _openFeature(action),
      onLongPress: isComingSoon ? null : () => _prioritizeTile(action.label),
    );

    // Coming Soon Overlay
    if (isComingSoon) {
      tile = Stack(
        children: [
          Opacity(opacity: 0.55, child: tile),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 12, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    AppStringsManager.getString(
                        languageService.currentLanguage, 'soon_badge'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Premium Lock Badge
    if (isPremiumLocked && !isComingSoon) {
      tile = Stack(
        children: [
          tile,
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.tertiary,
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.workspace_premium_rounded,
                      size: 11, color: Colors.white),
                  const SizedBox(width: 3),
                  Text(
                    'PRO',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return tile;
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
      child: Semantics(
        button: true,
        label: '$title. $subtitle',
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compactTile = compact ||
                  constraints.maxWidth < 150 ||
                  constraints.maxHeight < 210;

              return Container(
                padding: EdgeInsets.all(compactTile ? 9 : 14),
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
                      width: compactTile ? 28 : 42,
                      height: compactTile ? 28 : 42,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius:
                            BorderRadius.circular(compactTile ? 10 : 14),
                      ),
                      child: Icon(icon,
                          color: Colors.white, size: compactTile ? 15 : 22),
                    ),
                    SizedBox(height: compactTile ? 4 : 8),
                    Text(
                      title,
                      maxLines: compactTile ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: (compactTile
                              ? theme.textTheme.labelLarge
                              : theme.textTheme.titleMedium)
                          ?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: compactTile ? 12.5 : null,
                      ),
                    ),
                    SizedBox(height: compactTile ? 1 : 3),
                    Text(
                      subtitle,
                      style: (compactTile
                              ? theme.textTheme.bodySmall
                              : theme.textTheme.bodyMedium)
                          ?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: compactTile ? 1.2 : 1.3,
                        fontSize: compactTile ? 10.5 : null,
                      ),
                      maxLines: compactTile ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (statusHint != null && statusHint.trim().isNotEmpty) ...[
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
                    if (quickActionLabel != null &&
                        quickActionLabel.trim().isNotEmpty &&
                        onQuickAction != null) ...[
                      SizedBox(height: compactTile ? 4 : 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: onQuickAction,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: color.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.open_in_new_rounded,
                                  size: 12,
                                  color: color,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  quickActionLabel,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (quickActionHelperText != null &&
                          quickActionHelperText.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          quickActionHelperText,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                    if (!compactTile) ...[
                      const Spacer(),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Icon(Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
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
