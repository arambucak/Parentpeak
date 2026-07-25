import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/logic/parent_coin_service.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/spielfreunde_backend_service.dart';
import 'package:parentpeak/logic/location_autocomplete_service.dart';
import 'package:parentpeak/widgets/ala_rengin_flag_painter.dart';
import 'package:parentpeak/ui/widgets/location_picker_widget.dart';
import 'package:parentpeak/models/family_profile_model.dart';

class ElternNetzwerkScreen extends StatefulWidget {
  const ElternNetzwerkScreen({super.key});
  @override
  State<ElternNetzwerkScreen> createState() => _ScreenState();
}

class _ScreenState extends State<ElternNetzwerkScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _backend = SpielfreundeBackendService();
  FamilyMatchProfile? _profile;
  WaitlistStatus _waitlist =
      const WaitlistStatus(total: 0, threshold: 20, remaining: 20, progress: 0);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    ParentCoinService.instance.initialize();
    ParentCoinService.instance.addListener(_rebuild);
    _init();
  }

  @override
  void dispose() {
    _tabs.dispose();
    ParentCoinService.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _init() async {
    final p = await FamilyMatchProfile.load();
    if (mounted) setState(() => _profile = p);
    if (p != null) {
      final w = await _backend.getWaitlistCount(p.district);
      if (mounted) setState(() => _waitlist = w);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eltern-Netzwerk'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Einladen & Coins'),
            Tab(text: 'Spielfreunde')
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_inviteTab(theme), _spielfreundeTab(theme)],
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
                      const Text('ParentCoins',
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
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.star_rounded, size: 13, color: Colors.white),
                      SizedBox(width: 3),
                      Text('Community',
                          style: TextStyle(
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
              SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      onPressed: () async {
                        await coins.redeemForPremium();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('\u{1F389} Premium freigeschaltet!')),
                          );
                        }
                      },
                      icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                      label: const Text('Premium einloesen'),
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)))))
            ],
          ]),
        ),
        const SizedBox(height: 20),
        Text('Freunde einladen',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Fuer jede Registrierung: 1 ParentCoin.',
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
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Link kopiert!')));
        }),
        if (coins.history.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Verlauf',
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
    return _waitlistView(theme);
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
      Text('Spielfreunde finden',
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
        await _init();
      })),
    ]);
  }

  Widget _waitlistView(ThemeData theme) {
    return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                  GestureDetector(behavior: HitTestBehavior.opaque, 
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('spielfreunde.profile');
                        setState(() => _profile = null);
                      },
                      child: Text('Bearbeiten',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary))),
                  const SizedBox(width: 12),
                  GestureDetector(behavior: HitTestBehavior.opaque, 
                      onTap: () => _confirmDeleteProfile(theme),
                      child: Text('Loeschen',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.error))),
                ])
              ])),
          const SizedBox(height: 20),
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5))),
              child: Column(children: [
                const Text('\u{1F389}', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 14),
                Text('Dein Profil ist bereit!',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                    'Wir oeffnen die Spielfreunde-Suche sobald genug Familien in deiner Naehe sind.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant, height: 1.4),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.people_rounded,
                          size: 18, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 8),
                      Text('${_waitlist.total} Familien warten auch',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8B5CF6)))
                    ])),
                const SizedBox(height: 12),
                ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                        value: _waitlist.progress,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF8B5CF6)))),
                const SizedBox(height: 6),
                Text('Noch ${_waitlist.remaining} Familien bis Freischaltung',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ])),
          const SizedBox(height: 20),
          Text('So wird es aussehen:',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _familyCard(
              theme,
              'Familie M.',
              'Kreuzberg',
              '\u{1F467} Lina (3) \u{2022} \u{1F466} Ben (5)',
              'Wir suchen Familien fuer Spielplatz-Treffen und gemeinsames Kochen.',
              ['Beduerfnisorientiert', 'Natur'],
              'Nachmittags \u{2022} DE, TR'),
          const SizedBox(height: 10),
          _familyCard(
              theme,
              'Familie S.',
              'Mitte',
              '\u{1F476} Noah (2)',
              'Alleinerziehend, suche Austausch und spontane Treffen.',
              ['Offen', 'Spontan'],
              'Vormittags \u{2022} DE, AR'),
          const SizedBox(height: 20),
          GestureDetector(behavior: HitTestBehavior.opaque, 
              onTap: () => _tabs.animateTo(0),
              child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: const Color(0xFF0EA5A4).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color:
                              const Color(0xFF0EA5A4).withValues(alpha: 0.12))),
                  child: Row(children: [
                    const Text('\u{1F4A1}', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            'Lade Freunde ein — schneller freischalten!',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600))),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: const Color(0xFF0EA5A4),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text('Einladen',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)))
                  ]))),
        ]));
  }

  Widget _familyCard(ThemeData theme, String name, String district, String kids,
      String bio, List<String> tags, String meta) {
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
                  Text(name,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(district,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
                ])),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6)),
                child: Text('Bald',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.outline)))
          ]),
          const SizedBox(height: 10),
          Text(kids,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(bio,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant, height: 1.3)),
          const SizedBox(height: 10),
          Wrap(
              spacing: 6,
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
          const SizedBox(height: 8),
          Text(meta,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ]));
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
                size: 14, color: theme.colorScheme.outline)));
  }

  Future<void> _confirmDeleteProfile(ThemeData theme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Profil loeschen?'),
        content:
            const Text('Dein Spielfreunde-Profil wird dauerhaft geloescht. '
                'Du kannst jederzeit ein neues erstellen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error),
              child: const Text('Loeschen')),
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
        builder: (ctx) => Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Dein Einladungs-Code',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                  child: QrImageView(
                      data: coins.getInviteLink(),
                      version: QrVersions.auto,
                      size: 200)),
              const SizedBox(height: 14),
              Text(coins.referralCode,
                  style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800, letterSpacing: 2)),
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Fertig')))
            ])));
  }
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

  // Schritt 4: Aktivitaeten + Verfuegbarkeit
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
                label: const Text('Zurueck'))
          else
            const Spacer(),
          const Spacer(),
          if (_step < _totalSteps - 1)
            FilledButton.icon(
                onPressed: _next,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Weiter'),
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
            hint: 'Euer Stadtteil / PLZ waehlen',
            onLocationPicked: (loc) {
              _districtCtrl.text = loc.displayName;
            },
          ),
          const SizedBox(height: 20),
          _sectionTitle(theme, '\u{1F46A} Familienform'),
          const SizedBox(height: 8),
          Text('Waehle was am besten passt — oder schreib deine eigene:',
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
          Text('Fuer wen sucht ihr Spielfreunde?',
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
            label: const Text('Kind hinzufuegen'),
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
          Text('Alter:',
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
        Text('Geschlecht (optional):',
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
        Text('Interessen:',
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
                      'Tipp: Familien mit aehnlichen Werten verstehen sich am besten. Waehle was euch wichtig ist.',
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
              label: const Text('\u{2795} Eigener Wert',
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

  // ─── SCHRITT 4: Aktivitaeten + Verfuegbarkeit ──────────────────────────────
  Widget _step4(ThemeData theme) {
    return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          _sectionTitle(theme, '\u{1F3AF} Was sucht ihr?'),
          const SizedBox(height: 6),
          Text('Waehle Aktivitaeten die euch Spass machen:',
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
              label: const Text('\u{2795} Eigene Idee',
                  style: TextStyle(fontSize: 11)),
              onPressed: () => _showCustomInput(
                  _lookingForCustomCtrl, 'Was wuenscht ihr euch noch?'),
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
          Text('Tage:',
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
          Text('Uhrzeiten:',
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
              label: const Text('\u{2795} Andere Zeit',
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
          Text('Alle Sprachen eurer Familie — auch die der Kinder:',
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
          Text('Damit wir passende Familien vorschlagen koennen:',
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
              label: const Text('\u{2795} Eigenes',
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
                        child: const Text('Fertig'))),
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
