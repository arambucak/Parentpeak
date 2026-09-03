import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/logic/parent_coin_service.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/spielfreunde_backend_service.dart';
import 'package:parentpeak/logic/parent_matching_backend_service.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/logic/friendship_service.dart';
import 'package:parentpeak/logic/user_profile_service.dart';
import 'package:parentpeak/ui/widgets/account_suspended_notice.dart';
import 'package:parentpeak/services/location_service.dart';
import 'package:parentpeak/services/block_report_service.dart';
import 'package:parentpeak/logic/location_autocomplete_service.dart';
import 'package:parentpeak/widgets/ala_rengin_flag_painter.dart';
import 'package:parentpeak/ui/widgets/location_picker_widget.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/logic/parent_friends_service.dart';
import 'package:parentpeak/ui/match_conversation_screen.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';

String _t(String key) =>
    AppStringsManager.getString(languageService.currentLanguage, key);

/// Bringt einen Freundes-Code in die kanonische Form `pp-xxxxxx` (klein,
/// genau ein Bindestrich nach 'pp'). Akzeptiert Eingaben mit/ohne Bindestrich,
/// mit Leerzeichen oder in Grossbuchstaben. Verhindert kaputte Kanten wie
/// `pprkfns8` (ohne Bindestrich), die nie zum echten Code `pp-rkfns8` passen.
String canonicalFriendCode(String raw) {
  var s = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s]'), '');
  // Alle Bindestriche entfernen, dann genau einen nach 'pp' setzen.
  s = s.replaceAll('-', '');
  if (s.startsWith('pp')) {
    final rest = s.substring(2);
    return rest.isEmpty ? 'pp-' : 'pp-$rest';
  }
  // Falls jemand den Code ohne 'pp'-Praefix eingibt.
  return 'pp-$s';
}

class ElternNetzwerkScreen extends StatefulWidget {
  final String? initialFriendCode;

  /// 0 = Freunde, 1 = Spielfreunde, 2 = Einladen
  final int initialTab;
  const ElternNetzwerkScreen(
      {super.key, this.initialFriendCode, this.initialTab = 0});
  @override
  State<ElternNetzwerkScreen> createState() => _ScreenState();
}

class _ScreenState extends State<ElternNetzwerkScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _backend = SpielfreundeBackendService();
  final _matching = ParentMatchingBackendService(
      apiClient: BackendServiceFactory.createApiClient());
  FamilyMatchProfile? _profile;
  Set<String> _dismissedSuggestions = {};
  List<_SuggestedParent> _suggestedProfiles = [];
  bool _loadingSuggestions = true;

  // Echte Spielfreunde-Discovery (nutzt /api/parent-matching/find)
  List<MatchResult> _matches = [];
  bool _loadingMatches = false;
  String _matchScope = '10km';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
        length: 3, vsync: this, initialIndex: widget.initialTab.clamp(0, 2));
    ParentCoinService.instance.initialize();
    ParentCoinService.instance.addListener(_rebuild);
    ParentFriendsService.instance.addListener(_rebuild);
    FriendshipService.instance.addListener(_rebuild);
    _init();
    final incoming = widget.initialFriendCode;
    if (incoming != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (incoming.startsWith('invite:')) {
          // NEU: UID-Einladungslink -> Anfrage-Flow (1 Tap).
          _handleInviteToken(incoming.substring('invite:'.length));
        } else {
          _showAddFriendSheet(Theme.of(context), prefillCode: incoming);
        }
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    ParentCoinService.instance.removeListener(_rebuild);
    ParentFriendsService.instance.removeListener(_rebuild);
    FriendshipService.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  /// Einladungslink (/f/<token>) verarbeiten: Einladenden auflösen und eine
  /// Freundschaftsanfrage senden — 1 Tap, kein Code-Abtippen.
  Future<void> _handleInviteToken(String token) async {
    final resolved = await FriendshipService.instance.resolveInvite(token);
    if (!mounted) return;
    if (resolved == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Einladung ungültig oder abgelaufen.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final name = resolved['name']?.isNotEmpty == true
        ? resolved['name']!
        : 'diese Familie';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Verbinden?'),
        content: Text('Möchtest du dich mit $name verbinden?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Verbinden')),
        ],
      ),
    );
    if (ok != true) return;
    final sent = await FriendshipService.instance.sendRequest(resolved['uid']!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(sent
          ? 'Anfrage an $name gesendet. 👋'
          : 'Konnte nicht verbinden — bitte später erneut versuchen.'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: sent ? const Color(0xFF16A34A) : null,
    ));
  }

  Future<void> _init() async {
    await ParentFriendsService.instance.load();
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getStringList('friends.dismissed') ?? [];
    if (mounted) setState(() => _dismissedSuggestions = dismissed.toSet());
    final p = await FamilyMatchProfile.load();
    if (mounted) setState(() => _profile = p);
    if (p != null) {
      unawaited(_loadMatches());
    }

    // Sicherstellen, dass der Freundes-Code zur aktuellen Firebase-UID passt
    // (account-stabil, gleich auf App + Web). Wichtig, falls der Login erst
    // nach dem ersten initialize() erfolgte.
    await ParentCoinService.instance.refreshReferralCodeForCurrentUser();

    // NEUES FUNDAMENT: den app-weiten Anzeigenamen serverseitig sichern
    // (uid -> displayName). Kommt aus der Registrierung; hier nur gespiegelt.
    final myName = AuthService.instance.currentUser?.displayName ??
        _profile?.displayName ??
        'Familie';
    final myUserId = AuthService.instance.currentUser?.uid ?? '';
    unawaited(UserProfileService.instance.setDisplayName(myName));
    // Neue UID-Freundschaften + offene Anfragen laden.
    unawaited(FriendshipService.instance.load());

    // (Legacy, uebergangsweise) alte Code-Registrierung — schadet nicht.
    final myCode = ParentFriendsService.instance.myCode;
    unawaited(_backend.registerFriendCode(myCode, myName, userId: myUserId));

    // Auto-add anyone who connected with us since last open. Ueber
    // connectMutual, damit beide Kanten + geteilte roomId sauber gesetzt sind.
    final pending = await _backend.claimPendingFriendConnections(myCode);
    for (final conn in pending) {
      final code = (conn['fromCode'] as String? ?? '').toLowerCase();
      if (code.isNotEmpty) {
        await ParentFriendsService.instance.connectMutual(
          friendCode: code,
          myName: myName,
          myUserId: myUserId,
        );
      }
    }
    // Show notification if new friends were auto-added
    if (pending.isNotEmpty && mounted) {
      final names =
          pending.map((c) => c['fromName']?.toString() ?? 'Jemand').join(', ');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.people_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pending.length == 1
                  ? '$names hat sich mit dir verbunden! 🎉'
                  : '${pending.length} neue Verbindungen: $names 🎉',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ]),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF16A34A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
      ));
    }
    try {
      final sug = await _backend.getProfiles();
      if (mounted) {
        final myCode = ParentFriendsService.instance.myCode;
        final friendCodes =
            ParentFriendsService.instance.friends.map((f) => f.code).toSet();
        final suggestions = sug
            .where((mp) =>
                mp['userId'] != null &&
                !(mp['userId'] as String).startsWith(myCode) &&
                !friendCodes.contains(mp['userId'] as String) &&
                !_dismissedSuggestions.contains(mp['userId'] as String? ?? ''))
            .take(6)
            .map((mp) {
          final name = mp['displayName'] as String? ?? 'Familie';
          final district = mp['district'] as String? ?? '';
          final children =
              (mp['children'] as List? ?? []).cast<Map<String, dynamic>>();
          final kidsText = children.isEmpty
              ? ''
              : children.map((c) => '${c['name']} (${c['age']})').join(' · ');
          final reason = (_profile?.district != null &&
                  district.isNotEmpty &&
                  district == _profile!.district)
              ? '📍 Gleicher Bezirk'
              : district.isNotEmpty
                  ? '🌍 $district'
                  : '👥 In deiner Nähe';
          return _SuggestedParent(
              id: mp['userId'] as String,
              name: name,
              kids: kidsText,
              reason: reason);
        }).toList();
        setState(() {
          _suggestedProfiles = suggestions;
          _loadingSuggestions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStringsManager.getString(
            languageService.currentLanguage, 'eltern_netzwerk_title')),
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Freunde'),
            Tab(text: 'Spielfreunde'),
            Tab(text: 'Einladen'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _freundeTab(theme),
          _spielfreundeTab(theme),
          _inviteTab(theme)
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: EINLADEN & COINS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _inviteTab(ThemeData theme) {
    final coins = ParentCoinService.instance;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ─── ParentCoin Card ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF7ED),
                  Color(0xFFFFF1E6),
                  Color(0xFFFFEDD5)
                ]),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: const Color(0xFFFDBA74).withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFFF97316).withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8))
            ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              // Custom ParentCoin Icon
              Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFF97316), Color(0xFFFB923C)]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color:
                                const Color(0xFFF97316).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ]),
                  child: const Center(
                      child:
                          Text('\u{1F9E1}', style: TextStyle(fontSize: 26)))),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Text('${coins.balance}',
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFC2410C))),
                      const SizedBox(width: 6),
                      Text(
                          AppStringsManager.getString(
                              languageService.currentLanguage, 'parent_coins'),
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEA580C))),
                    ]),
                    const SizedBox(height: 2),
                    Text(
                        'Noch ${coins.coinsUntilFreePremium} bis Gratis-Premium \u{1F381}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF9A3412)
                                .withValues(alpha: 0.7))),
                  ])),
              if (coins.hasCommunityBadge)
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFF97316), Color(0xFFEAB308)]),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star_rounded,
                          size: 13, color: Colors.white),
                      const SizedBox(width: 3),
                      Text(
                          AppStringsManager.getString(
                              languageService.currentLanguage, 'community_tab'),
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white))
                    ])),
            ]),
            const SizedBox(height: 18),
            // Progress mit Coin-Steps
            Row(
                children:
                    List.generate(ParentCoinService.coinsForFreePremium, (i) {
              final filled = i < coins.balance;
              return Expanded(
                  child: Container(
                margin: EdgeInsets.only(
                    right:
                        i < ParentCoinService.coinsForFreePremium - 1 ? 4 : 0),
                height: 8,
                decoration: BoxDecoration(
                  color: filled
                      ? const Color(0xFFF97316)
                      : const Color(0xFFFDBA74).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ));
            })),
            const SizedBox(height: 10),
            Row(children: [
              Text('${coins.successfulInvites} Einladungen erfolgreich',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9A3412).withValues(alpha: 0.6))),
              const Spacer(),
              Text('1 Coin = 1\u{20AC}',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFF97316).withValues(alpha: 0.7))),
            ]),
            if (coins.balance >= ParentCoinService.coinsForFreePremium) ...[
              const SizedBox(height: 14),
              // Prio 5: Einloesen ist noch nicht scharf geschaltet. Statt einer
              // Schein-Einloesung zeigen wir ehrlich 'Bald verfuegbar' — die
              // gesammelten Coins bleiben natuerlich erhalten.
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.35)),
                ),
                child: Row(children: [
                  const Icon(Icons.hourglass_top_rounded,
                      size: 18, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Bald verfügbar',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          SizedBox(height: 2),
                          Text(
                              'Deine Coins sind gesichert. Bald kannst du damit Features freischalten. 🎁',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  height: 1.3)),
                        ]),
                  ),
                ]),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 20),
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'invite_friends'),
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(_t('network_coin_per_registration'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 14),
        _inviteRow(theme, Icons.share_rounded, const Color(0xFF0EA5A4),
            'Einladung teilen', 'WhatsApp, SMS, E-Mail', () async {
          try {
            final box = context.findRenderObject() as RenderBox?;
            await Share.share(
              coins.getInviteMessage(),
              sharePositionOrigin: box != null
                  ? box.localToGlobal(Offset.zero) & box.size
                  : const Rect.fromLTWH(100, 100, 200, 200),
            );
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Teilen fehlgeschlagen: $e')),
              );
            }
          }
        }),
        const SizedBox(height: 10),
        _inviteRow(
            theme,
            Icons.qr_code_rounded,
            const Color(0xFF8B5CF6),
            'QR-Code zeigen',
            'Am Spielplatz scannen',
            () => _showQR(theme, coins)),
        const SizedBox(height: 10),
        _inviteRow(theme, Icons.link_rounded, const Color(0xFF2563EB),
            'Link kopieren', coins.getInviteLink(), () {
          Clipboard.setData(ClipboardData(text: coins.getInviteLink()));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(AppStringsManager.getString(
                  languageService.currentLanguage, 'link_copied'))));
        }),
        const SizedBox(height: 10),
        _inviteRow(
            theme,
            Icons.refresh_rounded,
            const Color(0xFF16A34A),
            'Coins jetzt prüfen',
            'Neue Einladungen gutschreiben',
            () => ParentCoinService.instance.claimPendingReferrals(context)),
        if (coins.history.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'history_tab'),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...coins.history.take(5).map((tx) {
            final e = tx.type != CoinTransactionType.spent;
            return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Icon(
                          e
                              ? Icons.add_circle_rounded
                              : Icons.remove_circle_rounded,
                          size: 18,
                          color: e
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFEF4444)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(tx.reason,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                      Text('${e ? "+" : "-"}${tx.amount}',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: e
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFEF4444)))
                    ])));
          })
        ],
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: SPIELFREUNDE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _spielfreundeTab(ThemeData theme) {
    if (_profile == null) return _profileSetup(theme);
    return _discoveryView(theme);
  }

  Widget _profileSetup(ThemeData theme) {
    return Column(children: [
      const SizedBox(height: 16),
      Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)]),
              borderRadius: BorderRadius.circular(18)),
          child: const Center(
              child: Text('\u{1F46A}', style: TextStyle(fontSize: 28)))),
      const SizedBox(height: 12),
      Text(
          AppStringsManager.getString(
              languageService.currentLanguage, 'find_playmates'),
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
            'In 5 kurzen Schritten findet ihr Familien die so ticken wie ihr.',
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, height: 1.3),
            textAlign: TextAlign.center),
      ),
      const SizedBox(height: 16),
      Expanded(child: _ProfileForm(onSave: (p) async {
        await p.save();
        final uid = AuthService.instance.currentUser?.uid ?? 'guest';
        await _backend.saveProfile(p, uid);
        // In den echten Matching-Store schreiben, damit andere Familien uns
        // per Standort + Interessen finden koennen (echtes Matching).
        try {
          await _syncProfileToMatching(p, uid);
        } on SuspendedAccountException {
          if (mounted) await showAccountSuspendedNotice(context);
          return;
        }
        await _init();
        await _loadMatches();
      })),
    ]);
  }

  /// Mappt das Spielfreunde-Wizard-Profil auf den echten Matching-Store
  /// (/api/parent-matching/find nutzt genau diese Felder inkl. GPS + Interessen).
  Future<void> _syncProfileToMatching(FamilyMatchProfile p, String uid) async {
    // Standort: bevorzugt echte GPS-Koordinaten aus dem LocationService.
    final loc = LocationService.instance;
    if (!loc.hasLocation) {
      // Versuch, GPS zu holen (Web/Native). Schlaegt es fehl, bleibt es ohne
      // Koordinaten – dann matcht der Server ueber Interessen/Alter/Werte.
      await loc.requestGPSLocation();
    }

    // Kinder-Alter als lesbare Tags ("3J", "8M") fuer das Matching.
    final childAges = p.children.map((c) {
      final years = c.ageMonths ~/ 12;
      final months = c.ageMonths % 12;
      return years >= 1 ? '${years}J' : '${months}M';
    }).toList();

    // Interessen = wonach die Familie sucht + besondere Merkmale.
    final interests = <String>{
      ...p.lookingFor,
      ...p.specials,
    }.where((e) => e.trim().isNotEmpty).toList();

    await _matching.createProfile(
      userId: uid,
      name: p.displayName.isNotEmpty ? 'Familie ${p.displayName}' : 'Familie',
      city: (loc.city != null && loc.city!.isNotEmpty)
          ? loc.city!
          : (p.district.isNotEmpty ? p.district : 'Deutschland'),
      latitude: loc.latitude,
      longitude: loc.longitude,
      interests: interests,
      languages: p.languages,
      valuesFocus: p.values,
      childAges: childAges,
      familyForm: p.familyForm,
      bio: p.bio,
    );
  }

  /// Laedt echte Familien in der Naehe ueber das bestehende Matching-Backend.
  Future<void> _loadMatches() async {
    if (_profile == null) return;
    if (mounted) setState(() => _loadingMatches = true);
    final uid = AuthService.instance.currentUser?.uid ?? 'guest';
    final childAges = _profile!.children.map((c) {
      final years = c.ageMonths ~/ 12;
      return years >= 1 ? '${years}J' : '${c.ageMonths % 12}M';
    }).toList();
    try {
      final result = await _matching.findMatchesWithFallback(
        userId: uid,
        limit: 20,
        childAges: childAges,
      );
      // Prio 4: blockierte Familien zusätzlich clientseitig ausblenden
      // (Server filtert bereits, das hier ist Absicherung + sofortige Wirkung).
      final visible = result.matches.where((m) {
        final ownerId = m.profile.userId;
        if (ownerId == null || ownerId.isEmpty) return true;
        return !BlockReportService.instance.isBlocked(ownerId);
      }).toList();
      if (mounted) {
        setState(() {
          _matches = visible;
          _matchScope = result.scope;
          _loadingMatches = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMatches = false);
    }
  }

  Widget _discoveryView(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadMatches,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Eigenes Profil (Header) ──────────────────────────────────────
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.12))),
              child: Row(children: [
                const Text('\u{1F46A}', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Familie ${_profile!.displayName}',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                          _profile!.bio.isNotEmpty
                              ? _profile!.bio
                              : 'Profil aktiv \u{2714}',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)
                    ])),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('spielfreunde.profile');
                        setState(() => _profile = null);
                      },
                      child: Text(
                          AppStringsManager.getString(
                              languageService.currentLanguage, 'edit_btn'),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary))),
                  const SizedBox(width: 12),
                  GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _confirmDeleteProfile(theme),
                      child: Text(_t('delete'),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.error))),
                ])
              ])),
          const SizedBox(height: 20),

          // ── Titelzeile Discovery ─────────────────────────────────────────
          Row(children: [
            const Text('\u{1F50D}', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Familien in deiner Nähe',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
            if (_loadingMatches)
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _loadMatches,
                child: Icon(Icons.refresh_rounded,
                    size: 20, color: theme.colorScheme.primary),
              ),
          ]),
          if (!_loadingMatches && _matches.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
                _matchScope == '10km'
                    ? 'Im Umkreis von ~10 km'
                    : _matchScope == '50km'
                        ? 'Im Umkreis von ~50 km'
                        : _matchScope == '100km'
                            ? 'Im Umkreis von ~100 km'
                            : 'Deutschlandweit',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
          const SizedBox(height: 12),

          // ── Ergebnis: Liste, Loading oder ehrlicher Empty-State ──────────
          if (_loadingMatches)
            _matchesLoadingSkeleton(theme)
          else if (_matches.isEmpty)
            _emptyDiscoveryState(theme)
          else
            ..._matches.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _matchCard(theme, m),
                )),
        ]),
      ),
    );
  }

  /// Ehrlicher Empty-State: keine Fake-Familien, echter Aufruf zum Mitmachen.
  Widget _emptyDiscoveryState(ThemeData theme) {
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color:
                    theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
        child: Column(children: [
          const Text('\u{1F331}', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 14),
          Text('Sei die erste Familie in deiner Gegend',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
              'Dein Profil ist aktiv und sichtbar. Sobald andere Familien in '
              'deiner Nähe dabei sind, erscheinen sie hier automatisch. '
              'Lade Nachbarn & Freunde ein – so wächst euer Netzwerk am schnellsten.',
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant, height: 1.4),
              textAlign: TextAlign.center),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _tabs.animateTo(2),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Spielkameraden einladen'),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ]));
  }

  Widget _matchesLoadingSkeleton(ThemeData theme) {
    return Column(
      children: List.generate(
          2,
          (_) => Container(
                height: 120,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18)),
              )),
    );
  }

  /// Karte einer echten gematchten Familie mit Verbinden-Aktion.
  Widget _matchCard(ThemeData theme, MatchResult m) {
    final p = m.profile;
    final kids = p.childAges.isEmpty
        ? ''
        : '\u{1F9D2} ${p.childAges.join(' \u{2022} ')}';
    final distanceKm = m.breakdown['distanceKm'];
    final meta = <String>[
      if (distanceKm != null) '\u{1F4CD} $distanceKm km',
      if (p.languages.isNotEmpty) p.languages.take(3).join(', '),
    ].join('  \u{2022}  ');
    final tags = <String>[
      ...p.valuesFocus.take(2),
      ...p.interests.take(2),
    ];

    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(11)),
                child: const Center(
                    child: Text('\u{1F46A}', style: TextStyle(fontSize: 18)))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(p.name,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  if (p.city.isNotEmpty)
                    Text(p.city,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant))
                ])),
            if (m.score > 0)
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('${m.score}% Match',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A)))),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  size: 18, color: theme.colorScheme.outline),
              padding: EdgeInsets.zero,
              onSelected: (v) {
                if (v == 'report') {
                  showReportSheet(
                    context,
                    userId: m.profile.userId ?? m.profile.id,
                    userName: m.profile.name,
                    contentType: 'profile',
                  );
                } else if (v == 'block') {
                  _blockMatch(m);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'report',
                    child: Row(children: [
                      Icon(Icons.flag_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Melden'),
                    ])),
                PopupMenuItem(
                    value: 'block',
                    child: Row(children: [
                      Icon(Icons.block_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Blockieren'),
                    ])),
              ],
            ),
          ]),
          if (kids.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(kids,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
          if (p.bio != null && p.bio!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(p.bio!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant, height: 1.3)),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tags
                    .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color:
                                const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(t,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF7C3AED)))))
                    .toList()),
          ],
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(meta,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _connectWithMatch(m),
              icon: const Icon(Icons.waving_hand_rounded, size: 16),
              label: const Text('Hallo sagen'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  side: const BorderSide(color: Color(0xFF8B5CF6)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ]));
  }

  /// Verbindungswunsch senden (echte Aktion im Matching-Backend).
  Future<void> _connectWithMatch(MatchResult m) async {
    final uid = AuthService.instance.currentUser?.uid ?? 'guest';
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final ok = await _matching.recordAction(
      userId: uid,
      matchedProfileId: m.profile.id,
      action: 'like',
    );
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Dein Hallo ist unterwegs zu ${m.profile.name} 👋'
          : 'Konnte gerade nicht senden – bitte später erneut versuchen.'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: ok ? const Color(0xFF16A34A) : errorColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  /// Familie blockieren (lokal + serverseitig) und sofort ausblenden.
  Future<void> _blockMatch(MatchResult m) async {
    final messenger = ScaffoldMessenger.of(context);
    final ownerId = m.profile.userId ?? m.profile.id;
    await BlockReportService.instance.blockUser(ownerId, m.profile.name);
    if (!mounted) return;
    setState(() {
      _matches = _matches
          .where((x) => (x.profile.userId ?? x.profile.id) != ownerId)
          .toList();
    });
    messenger.showSnackBar(SnackBar(
      content: Text('${m.profile.name} wurde blockiert.'),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 3: FREUNDE & CHAT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _freundeTab(ThemeData theme) {
    final myCode = ParentFriendsService.instance.myCode.toUpperCase();
    final shareMsg = 'Hey! 👋 Ich bin auf ParentPeak – verbinde dich mit mir:\n'
        'parentpeak.de/freund/$myCode';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Code card mit OTP-Style Zeichen ────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF5B21B6), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
              stops: [0.0, 0.55, 1.0],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                  blurRadius: 28,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: Column(children: [
            Text(
                AppStringsManager.getString(
                    languageService.currentLanguage, 'your_friend_code'),
                style: TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5)),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                ...myCode.split('').map((ch) => Container(
                      width: 38,
                      height: 46,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 1.5),
                      ),
                      child: Center(
                          child: Text(ch,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900))),
                    )),
              ]),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                  child:
                      _shareActionBtn(Icons.copy_all_rounded, 'Kopieren', () {
                Clipboard.setData(ClipboardData(text: myCode));
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_t('network_code_copied'))));
              })),
              const SizedBox(width: 8),
              Expanded(
                  child: _shareActionBtn(Icons.ios_share_rounded, 'Teilen',
                      () async {
                final box = context.findRenderObject() as RenderBox?;
                // Frischen Einladungslink erzeugen (1-Tap-Verbinden fuer den
                // Empfaenger). Fallback: alte Code-Nachricht.
                final link =
                    await FriendshipService.instance.createInviteLink();
                final msg = link != null
                    ? 'Hey! 👋 Verbinde dich mit mir auf ParentPeak:\n$link'
                    : shareMsg;
                await Share.share(msg,
                    sharePositionOrigin: box != null
                        ? box.localToGlobal(Offset.zero) & box.size
                        : null);
              })),
              const SizedBox(width: 8),
              Expanded(
                  child: _shareActionBtn(Icons.qr_code_2_rounded, 'QR-Code',
                      () async {
                final link =
                    await FriendshipService.instance.createInviteLink();
                if (!mounted) return;
                _showFriendQR(theme, link ?? 'parentpeak.de/freund/$myCode');
              })),
            ]),
          ]),
        ),
        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: () => _showAddFriendSheet(theme),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
          label: Text(AppStringsManager.getString(
              languageService.currentLanguage, 'add_friend_code')),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF7C3AED),
            side: BorderSide(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.5)),
            minimumSize: const Size(double.infinity, 48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 32),

        _suggestedParentsSection(theme),
        const SizedBox(height: 32),

        // NEUES UID-Fundament: offene Anfragen + Freundesliste vom Server.
        _friendRequestsSection(theme),
        _uidFriendsSection(theme),
      ]),
    );
  }

  // ── Eingehende Freundschaftsanfragen (annehmen/ablehnen) ──────────────────
  Widget _friendRequestsSection(ThemeData theme) {
    final incoming = FriendshipService.instance.incoming;
    if (incoming.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Anfragen (${incoming.length})',
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      ...incoming.map((f) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15)),
            ),
            child: Row(children: [
              CircleAvatar(
                  backgroundColor: _avatarColor(f.name),
                  child: Text(f.name.isNotEmpty ? f.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800))),
              const SizedBox(width: 12),
              Expanded(
                  child: Text('${f.name} möchte sich verbinden',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600))),
              IconButton(
                icon: const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF16A34A)),
                tooltip: 'Annehmen',
                onPressed: () async {
                  await FriendshipService.instance.accept(f.uid);
                },
              ),
              IconButton(
                icon: Icon(Icons.cancel_rounded,
                    color: theme.colorScheme.outline),
                tooltip: 'Ablehnen',
                onPressed: () async {
                  await FriendshipService.instance.remove(f.uid);
                },
              ),
            ]),
          )),
      const SizedBox(height: 20),
    ]);
  }

  // ── Bestätigte Freunde (UID-basiert) ──────────────────────────────────────
  Widget _uidFriendsSection(ThemeData theme) {
    final friends = FriendshipService.instance.friends;
    final outgoing = FriendshipService.instance.outgoing;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'my_friends'),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        if (friends.isNotEmpty)
          Text('${friends.length} verbunden',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: const Color(0xFF7C3AED))),
      ]),
      const SizedBox(height: 12),
      if (friends.isEmpty)
        _emptyFriendsState(theme)
      else
        ...friends.map((f) => _uidFriendCard(theme, f)),
      if (outgoing.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Gesendete Anfragen',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.outline)),
        const SizedBox(height: 8),
        ...outgoing.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(Icons.hourglass_top_rounded,
                    size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('${f.name} — wartet auf Bestätigung',
                        style: theme.textTheme.bodySmall)),
                TextButton(
                    onPressed: () => FriendshipService.instance.remove(f.uid),
                    child: const Text('Zurückziehen')),
              ]),
            )),
      ],
    ]);
  }

  // Freundes-Karte (UID-basiert) mit Chat, Melden, Entfernen.
  Widget _uidFriendCard(ThemeData theme, Friend f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        CircleAvatar(
            radius: 23,
            backgroundColor: _avatarColor(f.name),
            child: Text(f.name.isNotEmpty ? f.name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800))),
        const SizedBox(width: 12),
        Expanded(
            child: Text(f.name,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700))),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MatchConversationScreen(
                profileId: f.roomId,
                profileName: f.name,
                isFriendChat: true,
              ),
            ),
          ),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
          label: Text(AppStringsManager.getString(
              languageService.currentLanguage, 'chat_btn')),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF8B5CF6),
            side: const BorderSide(color: Color(0xFF8B5CF6)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded,
              size: 18, color: theme.colorScheme.outline),
          onSelected: (v) async {
            if (v == 'remove') {
              await FriendshipService.instance.remove(f.uid);
            } else if (v == 'block') {
              await BlockReportService.instance.blockUser(f.uid, f.name);
              await FriendshipService.instance.remove(f.uid);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('${f.name} wurde blockiert.'),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            } else if (v == 'report') {
              showReportSheet(context,
                  userId: f.uid, userName: f.name, contentType: 'profile');
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'report', child: Text('Melden')),
            PopupMenuItem(value: 'block', child: Text('Blockieren')),
            PopupMenuItem(value: 'remove', child: Text('Entfernen')),
          ],
        ),
      ]),
    );
  }

  Widget _emptyFriendsState(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Center(
              child: Icon(Icons.group_add_rounded,
                  size: 28, color: Color(0xFF8B5CF6))),
        ),
        const SizedBox(height: 14),
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'no_friends_yet'),
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(_t('network_share_code_hint'),
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, height: 1.5),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _shareActionBtn(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.white.withValues(alpha: 0.2),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 5),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _suggestedParentsSection(ThemeData theme) {
    if (_loadingSuggestions) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                  color: Color(0xFF8B5CF6), strokeWidth: 2)));
    }
    if (_suggestedProfiles.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'maybe_you_know'),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'real_parents_nearby'),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ]),
        Text('${_suggestedProfiles.length} Vorschläge',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: const Color(0xFF8B5CF6))),
      ]),
      const SizedBox(height: 14),
      SizedBox(
        height: 240,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: _suggestedProfiles.length,
          itemBuilder: (ctx, i) =>
              _suggestionCard(theme, _suggestedProfiles[i]),
        ),
      ),
    ]);
  }

  Widget _suggestionCard(ThemeData theme, _SuggestedParent s) {
    final color = _avatarColor(s.name);
    final initial = s.name.isNotEmpty ? s.name[0].toUpperCase() : '?';

    return Container(
      width: 168,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(
              child: Text(initial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(s.name,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        if (s.kids.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(s.kids,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(s.reason,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        const Spacer(),
        Row(children: [
          Expanded(
            child: FilledButton(
              onPressed: () async {
                final code = s.id.length >= 6
                    ? s.id.substring(0, 6).toLowerCase()
                    : s.id.toLowerCase();
                await ParentFriendsService.instance.addFriend(ParentFriend(
                    code: code, name: s.name, addedAt: DateTime.now()));
                if (mounted) {
                  setState(() {
                    _dismissedSuggestions.add(s.id);
                    _suggestedProfiles.removeWhere((x) => x.id == s.id);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${s.name} verbunden! 🎉')));
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              child: Text(AppStringsManager.getString(
                  languageService.currentLanguage, 'connect_btn')),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              if (mounted) {
                setState(() {
                  _dismissedSuggestions.add(s.id);
                  _suggestedProfiles.removeWhere((x) => x.id == s.id);
                });
                await prefs.setStringList(
                    'friends.dismissed', _dismissedSuggestions.toList());
              }
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded,
                  size: 16, color: theme.colorScheme.outline),
            ),
          ),
        ]),
      ]),
    );
  }

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFF7C3AED),
      Color(0xFF0EA5E9),
      Color(0xFF059669),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
      Color(0xFF6366F1),
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  void _showFriendQR(ThemeData theme, String qrData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'show_this_code'),
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(_t('network_scan_to_connect'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline, height: 1.4),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 6)),
              ],
            ),
            child:
                QrImageView(data: qrData, version: QrVersions.auto, size: 200),
          ),
          const SizedBox(height: 16),
          Text('Scannen & mit einem Tap verbinden',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                  AppStringsManager.getString(
                      languageService.currentLanguage, 'done_btn'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  /// Looks up a display name for the given code via getProfiles().
  Future<String?> _lookupNameByCode(String rawCode) async {
    final normalized = canonicalFriendCode(rawCode);
    if (normalized == 'pp-') return null;
    return _backend.lookupFriendName(normalized);
  }

  void _showAddFriendSheet(ThemeData theme, {String? prefillCode}) {
    final codeCtrl = TextEditingController(text: prefillCode ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String? resolvedName;
        String? errorMsg;
        bool isLooking = false;

        return StatefulBuilder(builder: (ctx, setSheet) {
          final myCode = ParentFriendsService.instance.myCode.toUpperCase();

          Future<void> onCodeChanged(String val) async {
            final normalized = val.trim().toUpperCase();
            // Trigger lookup once input looks complete (PP-XXXXXX = 9 chars)
            if (normalized.length < 6) {
              setSheet(() {
                resolvedName = null;
                errorMsg = null;
              });
              return;
            }
            if (canonicalFriendCode(val) == canonicalFriendCode(myCode)) {
              setSheet(() {
                resolvedName = null;
                errorMsg = 'Das ist dein eigener Code!';
              });
              return;
            }
            setSheet(() {
              isLooking = true;
              resolvedName = null;
              errorMsg = null;
            });
            final name = await _lookupNameByCode(normalized);
            setSheet(() {
              isLooking = false;
              resolvedName = name;
              errorMsg = null;
            });
          }

          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                Text(
                    AppStringsManager.getString(
                        languageService.currentLanguage, 'connect_by_code'),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                    AppStringsManager.getString(
                        languageService.currentLanguage, 'enter_friend_code'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: onCodeChanged,
                  decoration: InputDecoration(
                    labelText: 'Freundschafts-Code',
                    hintText: 'PP-XXXXXX',
                    suffixIcon: isLooking
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFF8B5CF6))))
                        : resolvedName != null
                            ? const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF059669))
                            : null,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: Color(0xFF8B5CF6), width: 1.5)),
                    errorText: errorMsg,
                  ),
                ),
                // Name preview after lookup
                if (resolvedName != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _avatarColor(resolvedName!),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            resolvedName![0].toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(resolvedName!,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              Text(_t('network_found'),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF059669),
                                      fontWeight: FontWeight.w600)),
                            ]),
                      ),
                    ]),
                  ),
                ] else if (!isLooking &&
                    codeCtrl.text.trim().length >= 6 &&
                    errorMsg == null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Kein Profil gefunden \u2013 du kannst trotzdem verbinden.',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    // Nur verbinden, wenn der Code auf einen echten Nutzer
                    // aufgeloest wurde (resolvedName != null). Das verhindert
                    // kaputte Kanten zu Phantom-/Tippfehler-Codes.
                    onPressed: errorMsg != null ||
                            codeCtrl.text.trim().isEmpty ||
                            isLooking ||
                            resolvedName == null
                        ? null
                        : () async {
                            // Kanonischer Code (immer pp-xxxxxx, ein Bindestrich).
                            final code = canonicalFriendCode(codeCtrl.text);
                            final myName = _profile?.displayName ??
                                AuthService.instance.currentUser?.displayName ??
                                'Familien-Kontakt';
                            final myUserId =
                                AuthService.instance.currentUser?.uid ?? '';
                            // Atomare beidseitige Verbindung (beide sofort
                            // befreundet, echter Name + geteilte roomId).
                            await ParentFriendsService.instance.connectMutual(
                              friendCode: code,
                              myName: myName,
                              myUserId: myUserId,
                            );
                            // Fallback: alte Ping-Mechanik, falls die Gegenseite
                            // gerade nicht erreichbar war.
                            final myCode = ParentFriendsService.instance.myCode;
                            unawaited(_backend.notifyFriendConnect(
                                myCode, myName, code));
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(resolvedName != null
                        ? 'Mit $resolvedName verbinden'
                        : 'Verbinden'),
                  ),
                ),
              ]),
            ),
          );
        });
      },
    );
  }

  Widget _inviteRow(ThemeData theme, IconData icon, Color color, String title,
      String sub, VoidCallback onTap) {
    return Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color:
                    theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
        color: theme.colorScheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        child: Material(
            color: Colors.transparent,
            child: ListTile(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTap();
                },
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: color, size: 20)),
                title: Text(title,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                subtitle: Text(sub,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis),
                trailing: Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: theme.colorScheme.outline))));
  }

  Future<void> _confirmDeleteProfile(ThemeData theme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppStringsManager.getString(
            languageService.currentLanguage, 'delete_profile')),
        content: Text(_t('network_delete_profile_confirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error),
              child: Text(_t('delete'))),
        ],
      ),
    );
    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('spielfreunde.profile');
      // Server-seitig loeschen
      final uid = AuthService.instance.currentUser?.uid ?? 'guest';
      await _backend.deleteProfile(uid);
      if (mounted) setState(() => _profile = null);
    }
  }

  void _showQR(ThemeData theme, ParentCoinService coins) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          // Teal badge: visually distinct from the purple Freunde-QR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
                AppStringsManager.getString(
                    languageService.currentLanguage, 'app_invitation'),
                style: TextStyle(
                    color: Color(0xFF0D9488),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 10),
          Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'invite_parents'),
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'scan_download_earn'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline, height: 1.4),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                  width: 2),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: QrImageView(
                data: coins.getInviteLink(),
                version: QrVersions.auto,
                size: 190,
                eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square, color: Color(0xFF0D9488)),
                dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF134E4A))),
          ),
          const SizedBox(height: 10),
          Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'just_scan_no_code'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(_t('done'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
class _SuggestedParent {
  final String id;
  final String name;
  final String kids;
  final String reason;

  const _SuggestedParent({
    required this.id,
    required this.name,
    required this.kids,
    required this.reason,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROFIL-WIZARD (5 Schritte)
// ═══════════════════════════════════════════════════════════════════════════════

class _ProfileForm extends StatefulWidget {
  final Future<void> Function(FamilyMatchProfile) onSave;
  const _ProfileForm({required this.onSave});
  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final _pageCtrl = PageController();
  int _step = 0;
  static const _totalSteps = 5;
  bool _saving = false;

  // Schritt 1: Grundinfos
  final _nameCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  String _familyForm = 'kernfamilie';
  final _familyFormCustomCtrl = TextEditingController();

  // Schritt 2: Kinder
  final List<_ChildData> _children = [_ChildData()];

  // Schritt 3: Werte
  final Set<String> _values = {};
  final _valuesCustomCtrl = TextEditingController();

  // Schritt 4: Aktivitäten + Verfügbarkeit
  final Set<String> _lookingFor = {};
  final _lookingForCustomCtrl = TextEditingController();
  final Set<String> _availDays = {};
  final Set<String> _availTimes = {};
  final _availCustomCtrl = TextEditingController();

  // Schritt 5: Sprachen + Bio + Besonderheiten
  final Set<String> _langs = {'de'};
  final _bioCtrl = TextEditingController();
  final Set<String> _specials = {};
  final _specialsCustomCtrl = TextEditingController();

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _districtCtrl.dispose();
    _familyFormCustomCtrl.dispose();
    _valuesCustomCtrl.dispose();
    _lookingForCustomCtrl.dispose();
    _availCustomCtrl.dispose();
    _bioCtrl.dispose();
    _specialsCustomCtrl.dispose();
    for (final c in _children) {
      c.dispose();
    }
    super.dispose();
  }

  void _next() {
    if (_step < _totalSteps - 1) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _step++);
    }
  }

  void _prev() {
    if (_step > 0) {
      _pageCtrl.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _step--);
    }
  }

  Future<void> _submit() async {
    // Validierung mit Feedback
    if (_nameCtrl.text.trim().isEmpty) {
      _showValidationError('Bitte gib euren Namen ein (Schritt 1)');
      return;
    }
    if (_districtCtrl.text.trim().isEmpty) {
      _showValidationError('Bitte gib euren Stadtteil ein (Schritt 1)');
      return;
    }
    setState(() => _saving = true);
    try {
      final children = _children
          .map((c) => ChildEntry(
                name: c.nameCtrl.text.trim(),
                ageMonths: c.ageMonths,
                gender: c.gender,
                interests: c.interests.toList(),
                interestsCustom: c.interestsCustomCtrl.text.trim().isEmpty
                    ? null
                    : c.interestsCustomCtrl.text.trim(),
              ))
          .toList();

      final profile = FamilyMatchProfile(
        displayName: _nameCtrl.text.trim(),
        district: _districtCtrl.text.trim(),
        children: children,
        languages: _langs.toList(),
        familyForm: _familyForm,
        familyFormCustom: _familyFormCustomCtrl.text.trim().isEmpty
            ? null
            : _familyFormCustomCtrl.text.trim(),
        values: _values.toList(),
        valuesCustom: _valuesCustomCtrl.text.trim().isEmpty
            ? null
            : _valuesCustomCtrl.text.trim(),
        lookingFor: _lookingFor.toList(),
        lookingForCustom: _lookingForCustomCtrl.text.trim().isEmpty
            ? null
            : _lookingForCustomCtrl.text.trim(),
        availDays: _availDays.toList(),
        availTimes: _availTimes.toList(),
        availCustom: _availCustomCtrl.text.trim().isEmpty
            ? null
            : _availCustomCtrl.text.trim(),
        specials: _specials.toList(),
        specialsCustom: _specialsCustomCtrl.text.trim().isEmpty
            ? null
            : _specialsCustomCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        createdAt: DateTime.now(),
      );
      await widget.onSave(profile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showValidationError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(children: [
      // Progress dots
      Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalSteps, (i) {
              final active = i == _step;
              final done = i < _step;
              return Container(
                width: active ? 28 : 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: done
                      ? const Color(0xFF16A34A)
                      : active
                          ? const Color(0xFF8B5CF6)
                          : theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(5),
                ),
              );
            })),
      ),
      // Step label
      Text(_stepLabels[_step],
          style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800, color: const Color(0xFF8B5CF6))),
      const SizedBox(height: 16),
      // Pages
      Expanded(
        child: PageView(
          controller: _pageCtrl,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _step1(theme),
            _step2(theme),
            _step3(theme),
            _step4(theme),
            _step5(theme)
          ],
        ),
      ),
      // Navigation
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(children: [
          if (_step > 0)
            TextButton.icon(
                onPressed: _prev,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text(_t('network_back')))
          else
            const Spacer(),
          const Spacer(),
          if (_step < _totalSteps - 1)
            FilledButton.icon(
                onPressed: _next,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(AppStringsManager.getString(
                    languageService.currentLanguage, 'next_btn_wizard')),
                style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))))
          else
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(_saving ? 'Speichern...' : 'Profil erstellen'),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
            ),
        ]),
      ),
    ]);
  }

  static const _stepLabels = [
    'Schritt 1: Eure Familie',
    'Schritt 2: Eure Kinder',
    'Schritt 3: Werte & Stil',
    'Schritt 4: Was sucht ihr?',
    'Schritt 5: Sprachen & Mehr',
  ];

  // ─── SCHRITT 1: Grundinfos ─────────────────────────────────────────────────
  Widget _step1(ThemeData theme) {
    return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          _inputField(_nameCtrl, 'Euer Vorname / Spitzname',
              'z.B. Sarah, Die Muellers', Icons.person_rounded),
          const SizedBox(height: 14),
          LocationPickerWidget(
            hint: 'Euer Stadtteil / PLZ wählen',
            onLocationPicked: (loc) {
              _districtCtrl.text = loc.displayName;
            },
          ),
          const SizedBox(height: 20),
          _sectionTitle(theme, '\u{1F46A} Familienform'),
          const SizedBox(height: 8),
          Text(_t('network_wizard_choose'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ...MatchOptions.familyForms.map((f) => ChoiceChip(
                  label: Text(MatchOptions.familyFormLabels[f] ?? f,
                      style: const TextStyle(fontSize: 12)),
                  selected: _familyForm == f,
                  onSelected: (_) => setState(() => _familyForm = f),
                  avatar: null,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                )),
            ActionChip(
              label:
                  const Text('\u{2795} Eigene', style: TextStyle(fontSize: 12)),
              onPressed: () => setState(() => _familyForm = 'custom'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              side: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
            ),
          ]),
          if (_familyForm == 'custom') ...[
            const SizedBox(height: 10),
            _inputField(_familyFormCustomCtrl, 'Eure Familienform',
                'z.B. Wahlfamilie, Mehrgenerationen...', Icons.edit_rounded),
          ],
        ]));
  }

  // ─── SCHRITT 2: Kinder ─────────────────────────────────────────────────────
  Widget _step2(ThemeData theme) {
    return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Text(_t('network_wizard_for_whom'),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          ..._children
              .asMap()
              .entries
              .map((entry) => _childCard(theme, entry.key, entry.value)),
          const SizedBox(height: 12),
          Center(
              child: TextButton.icon(
            onPressed: () => setState(() => _children.add(_ChildData())),
            icon: const Icon(Icons.add_rounded),
            label: Text(AppStringsManager.getString(
                languageService.currentLanguage, 'add_child_btn')),
          )),
        ]));
  }

  Widget _childCard(ThemeData theme, int index, _ChildData child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('\u{1F476} Kind ${index + 1}',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          if (_children.length > 1)
            IconButton(
                icon: Icon(Icons.close_rounded,
                    size: 18, color: theme.colorScheme.error),
                onPressed: () => setState(() {
                      _children[index].dispose();
                      _children.removeAt(index);
                    })),
        ]),
        const SizedBox(height: 10),
        TextField(
            controller: child.nameCtrl,
            decoration: InputDecoration(
                labelText: 'Name / Spitzname',
                hintText: 'z.B. Mia',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true)),
        const SizedBox(height: 12),
        // Alter Slider
        Row(children: [
          Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'age_label'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
              child: Slider(
            value: child.ageMonths.toDouble(),
            min: 0, max: 216, // 0 bis 18 Jahre
            divisions: 216,
            label: _ageLabel(child.ageMonths),
            onChanged: (v) => setState(() => child.ageMonths = v.round()),
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text(_ageLabel(child.ageMonths),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8B5CF6))),
          ),
        ]),
        const SizedBox(height: 10),
        // Geschlecht
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'gender_optional'),
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
            spacing: 8,
            children: [null, ...MatchOptions.genderLabels.keys]
                .map((g) => ChoiceChip(
                      label: Text(
                          g == null
                              ? 'Keine Angabe'
                              : MatchOptions.genderLabels[g]!,
                          style: const TextStyle(fontSize: 11)),
                      selected: child.gender == g,
                      onSelected: (_) => setState(() => child.gender = g),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ))
                .toList()),
        const SizedBox(height: 12),
        // Interessen
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'interests_label'),
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          ...MatchOptions.childInterests.map((i) => FilterChip(
                label: Text(MatchOptions.childInterestLabels[i] ?? i,
                    style: const TextStyle(fontSize: 10)),
                selected: child.interests.contains(i),
                onSelected: (s) => setState(() =>
                    s ? child.interests.add(i) : child.interests.remove(i)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                visualDensity: VisualDensity.compact,
              )),
          ActionChip(
            label:
                const Text('\u{2795} Eigenes', style: TextStyle(fontSize: 10)),
            onPressed: () => _showCustomInput(
                child.interestsCustomCtrl, 'Was mag dein Kind noch?'),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            side: const BorderSide(color: Color(0xFF8B5CF6)),
            visualDensity: VisualDensity.compact,
          ),
        ]),
        if (child.interestsCustomCtrl.text.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('\u{2728} ${child.interestsCustomCtrl.text}',
                  style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.primary,
                      fontStyle: FontStyle.italic))),
      ]),
    );
  }

  String _ageLabel(int months) {
    if (months < 12) return '$months Mon.';
    final y = months ~/ 12;
    final m = months % 12;
    return m == 0 ? '$y Jahre' : '$y J. $m M.';
  }

  // ─── SCHRITT 3: Werte & Erziehungsstil ─────────────────────────────────────
  Widget _step3(ThemeData theme) {
    return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.15))),
            child: Row(children: [
              const Text('\u{1F49A}', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      'Tipp: Familien mit ähnlichen Werten verstehen sich am besten. Wähle was euch wichtig ist.',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF16A34A),
                          fontWeight: FontWeight.w500,
                          height: 1.3)))
            ]),
          ),
          const SizedBox(height: 16),
          _sectionTitle(theme, '\u{2728} Was lebt ihr?'),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ...MatchOptions.valueOptions.map((v) => FilterChip(
                  label: Text(MatchOptions.valueLabels[v] ?? v,
                      style: const TextStyle(fontSize: 11)),
                  selected: _values.contains(v),
                  onSelected: (s) =>
                      setState(() => s ? _values.add(v) : _values.remove(v)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  selectedColor: v == 'gfk'
                      ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                      : null,
                  checkmarkColor: v == 'gfk' ? const Color(0xFF16A34A) : null,
                )),
            ActionChip(
              label: Text(
                  AppStringsManager.getString(
                      languageService.currentLanguage, 'custom_value'),
                  style: TextStyle(fontSize: 11)),
              onPressed: () => _showCustomInput(
                  _valuesCustomCtrl, 'Was ist euch noch wichtig?'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              side: const BorderSide(color: Color(0xFF8B5CF6)),
            ),
          ]),
          if (_valuesCustomCtrl.text.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('\u{2728} ${_valuesCustomCtrl.text}',
                        style: TextStyle(
                            fontSize: 12, color: theme.colorScheme.primary)))),
        ]));
  }

  // ─── SCHRITT 4: Aktivitaeten + Verfügbarkeit ──────────────────────────────
  Widget _step4(ThemeData theme) {
    return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          _sectionTitle(theme, '\u{1F3AF} Was sucht ihr?'),
          const SizedBox(height: 6),
          Text(_t('network_wizard_activities'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ...MatchOptions.lookingForOptions.map((l) => FilterChip(
                  label: Text(MatchOptions.lookingForLabels[l] ?? l,
                      style: const TextStyle(fontSize: 11)),
                  selected: _lookingFor.contains(l),
                  onSelected: (s) => setState(
                      () => s ? _lookingFor.add(l) : _lookingFor.remove(l)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                )),
            ActionChip(
              label: Text(
                  AppStringsManager.getString(
                      languageService.currentLanguage, 'custom_idea'),
                  style: TextStyle(fontSize: 11)),
              onPressed: () => _showCustomInput(
                  _lookingForCustomCtrl, 'Was wünscht ihr euch noch?'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              side: const BorderSide(color: Color(0xFF8B5CF6)),
            ),
          ]),
          if (_lookingForCustomCtrl.text.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('\u{2728} ${_lookingForCustomCtrl.text}',
                        style: TextStyle(
                            fontSize: 12, color: theme.colorScheme.primary)))),
          const SizedBox(height: 22),
          _sectionTitle(theme, '\u{1F4C5} Wann habt ihr Zeit?'),
          const SizedBox(height: 10),
          Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'days_label'),
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MatchOptions.dayOptions
                  .map((d) => FilterChip(
                        label: Text(MatchOptions.dayLabels[d] ?? d,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        selected: _availDays.contains(d),
                        onSelected: (s) => setState(
                            () => s ? _availDays.add(d) : _availDays.remove(d)),
                        shape: const CircleBorder(),
                        showCheckmark: false,
                        padding: const EdgeInsets.all(4),
                      ))
                  .toList()),
          const SizedBox(height: 14),
          Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'times_label'),
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ...MatchOptions.timeOptions.map((t) => FilterChip(
                  label: Text(MatchOptions.timeLabels[t] ?? t,
                      style: const TextStyle(fontSize: 11)),
                  selected: _availTimes.contains(t),
                  onSelected: (s) => setState(
                      () => s ? _availTimes.add(t) : _availTimes.remove(t)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                )),
            ActionChip(
              label: Text(
                  AppStringsManager.getString(
                      languageService.currentLanguage, 'other_time'),
                  style: TextStyle(fontSize: 11)),
              onPressed: () => _showCustomInput(
                  _availCustomCtrl, 'z.B. Nur in Ferien, Nur Feiertage...'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              side: const BorderSide(color: Color(0xFF8B5CF6)),
            ),
          ]),
          if (_availCustomCtrl.text.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('\u{2728} ${_availCustomCtrl.text}',
                        style: TextStyle(
                            fontSize: 12, color: theme.colorScheme.primary)))),
        ]));
  }

  // ─── SCHRITT 5: Sprachen + Bio + Besonderheiten ────────────────────────────
  Widget _step5(ThemeData theme) {
    return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          _sectionTitle(theme, '\u{1F30D} Welche Sprachen sprecht ihr?'),
          const SizedBox(height: 6),
          Text(_t('network_wizard_languages'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MatchOptions.languageLabels.entries
                  .map((e) => FilterChip(
                        label:
                            Text(e.value, style: const TextStyle(fontSize: 11)),
                        selected: _langs.contains(e.key),
                        onSelected: (s) => setState(
                            () => s ? _langs.add(e.key) : _langs.remove(e.key)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        avatar: e.key == 'ku'
                            ? const AlaRenginFlag(width: 20, height: 14)
                            : null,
                      ))
                  .toList()),
          const SizedBox(height: 22),
          _sectionTitle(theme, '\u{1F4AC} Kurze Bio'),
          const SizedBox(height: 6),
          TextField(
              controller: _bioCtrl,
              maxLength: 200,
              maxLines: 3,
              decoration: InputDecoration(
                  hintText:
                      'Erzaehlt kurz von euch: Was macht eure Familie besonders? Was wuenscht ihr euch?',
                  hintStyle:
                      TextStyle(fontSize: 13, color: theme.colorScheme.outline),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: Color(0xFF8B5CF6), width: 1.5)))),
          const SizedBox(height: 22),
          _sectionTitle(theme, '\u{1F49C} Besonderheiten (optional)'),
          const SizedBox(height: 6),
          Text(_t('network_wizard_location'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ...MatchOptions.specialOptions.map((s) => FilterChip(
                  label: Text(MatchOptions.specialLabels[s] ?? s,
                      style: const TextStyle(fontSize: 11)),
                  selected: _specials.contains(s),
                  onSelected: (sel) => setState(
                      () => sel ? _specials.add(s) : _specials.remove(s)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                )),
            ActionChip(
              label: Text(
                  AppStringsManager.getString(
                      languageService.currentLanguage, 'custom_entry'),
                  style: TextStyle(fontSize: 11)),
              onPressed: () => _showCustomInput(_specialsCustomCtrl,
                  'Was sollten andere Familien noch wissen?'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              side: const BorderSide(color: Color(0xFF8B5CF6)),
            ),
          ]),
          if (_specialsCustomCtrl.text.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('\u{2728} ${_specialsCustomCtrl.text}',
                        style: TextStyle(
                            fontSize: 12, color: theme.colorScheme.primary)))),
          const SizedBox(height: 20),
        ]));
  }

  // ─── Hilfsmethoden ─────────────────────────────────────────────────────────
  Widget _sectionTitle(ThemeData theme, String text) {
    return Text(text,
        style:
            theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800));
  }

  Widget _inputField(
      TextEditingController ctrl, String label, String hint, IconData icon) {
    return TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFF8B5CF6), width: 1.5)),
        ));
  }

  void _showCustomInput(TextEditingController ctrl, String hint) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  maxLength: 60,
                  decoration: InputDecoration(
                      hintText: hint,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onSubmitted: (_) {
                    Navigator.pop(ctx);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {});
                        },
                        child: Text(_t('done')))),
              ]),
            ),
          );
        });
  }
}

// ─── Kind-Daten Helfer ───────────────────────────────────────────────────────
class _ChildData {
  final nameCtrl = TextEditingController();
  final interestsCustomCtrl = TextEditingController();
  int ageMonths = 36; // default 3 Jahre
  String? gender;
  final Set<String> interests = {};

  void dispose() {
    nameCtrl.dispose();
    interestsCustomCtrl.dispose();
  }
}

// ─── Location Autocomplete Widget ────────────────────────────────────────────

class _LocationAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final void Function(LocationSuggestion) onSelected;

  const _LocationAutocompleteField({
    required this.controller,
    required this.onSelected,
  });

  @override
  State<_LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState
    extends State<_LocationAutocompleteField> {
  final _service = LocationAutocompleteService.instance;
  List<LocationSuggestion> _suggestions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged() {
    final text = widget.controller.text.trim();
    if (text.length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      setState(() => _isLoading = true);
      final results = await _service.searchImmediate(text);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _showSuggestions = results.isNotEmpty;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: widget.controller,
        decoration: InputDecoration(
          labelText: 'Stadtteil oder PLZ',
          hintText: 'Tippe z.B. Kreuzberg, 10997...',
          prefixIcon: const Icon(Icons.location_on_rounded, size: 20),
          suffixIcon: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        widget.controller.clear();
                        setState(() {
                          _suggestions = [];
                          _showSuggestions = false;
                        });
                      })
                  : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
          ),
        ),
      ),
      if (_showSuggestions) ...[
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _suggestions.length,
            separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 44,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
            itemBuilder: (ctx, i) {
              final s = _suggestions[i];
              return ListTile(
                dense: true,
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.place_rounded,
                      size: 16, color: Color(0xFF8B5CF6)),
                ),
                title: Text(s.shortLabel,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                subtitle: s.postcode.isNotEmpty
                    ? Text(s.postcode,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline))
                    : null,
                onTap: () {
                  widget.controller.text = s.shortLabel;
                  widget.controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: s.shortLabel.length));
                  setState(() => _showSuggestions = false);
                  widget.onSelected(s);
                },
              );
            },
          ),
        ),
      ],
    ]);
  }
}
