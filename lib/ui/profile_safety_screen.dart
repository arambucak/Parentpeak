import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/models/trusted_device.dart';
import 'package:parentpeak/ui/auth/paywall_screen.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:parentpeak/widgets/ala_rengin_flag_painter.dart';
import 'package:parentpeak/ui/widgets/beta_feedback_widget.dart';
import 'package:parentpeak/config/access_config.dart';

/// Profil-Screen — modern, warm, spielerisch-elternfreundlich.
class ProfileSafetyScreen extends StatefulWidget {
  const ProfileSafetyScreen({
    super.key,
    required this.devices,
    required this.onRevoke,
    this.onBack,
  });

  final List<TrustedDevice> devices;
  final Future<bool> Function(String deviceUuid, String deviceName) onRevoke;
  final VoidCallback? onBack;

  @override
  State<ProfileSafetyScreen> createState() => _ProfileSafetyScreenState();
}

class _ProfileSafetyScreenState extends State<ProfileSafetyScreen> {
  List<_ChildInfo> _children = [];
  String _appVersion = '';

  String _t(String key) =>
      AppStringsManager.getString(languageService.currentLanguage, key);

  @override
  void initState() {
    super.initState();
    _loadChildren();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = '${info.version}+${info.buildNumber}');
      }
    } catch (_) {
      if (mounted) setState(() => _appVersion = '1.0.0');
    }
  }

  Future<void> _loadChildren() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('profile.children') ?? [];
    final children = <_ChildInfo>[];
    for (final raw in saved) {
      final parts = raw.split('|');
      if (parts.length >= 2) {
        children.add(_ChildInfo(name: parts[0], age: parts[1]));
      }
    }
    if (mounted) setState(() => _children = children);
  }

  Future<void> _addChild() async {
    final result = await _showAddChildDialog();
    if (result == null) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('profile.children') ?? [];
    saved.add('${result.name}|${result.age}');
    await prefs.setStringList('profile.children', saved);
    await _loadChildren();
  }

  Future<_ChildInfo?> _showAddChildDialog() async {
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    return showModalBottomSheet<_ChildInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final insets = MediaQuery.of(ctx).viewInsets;
        return Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + insets.bottom),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('\u{1F476}', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Text(_t('add_child'),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: 'z.B. Emma',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ageCtrl,
                decoration: InputDecoration(
                  labelText: 'Alter',
                  hintText: 'z.B. 4 Jahre',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final age = ageCtrl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(ctx,
                        _ChildInfo(name: name, age: age.isEmpty ? '' : age));
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(_t('kind_hinzufuegen')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = AuthService.instance.currentUser;
    final name = (user?.displayName.trim().isNotEmpty ?? false)
        ? user!.displayName.trim()
        : user?.friendlyName ?? 'Familien-Kontakt';
    final email = user?.email ?? '';
    final isPremium = user?.isPremium ?? false;
    final trialDays = user?.trialDaysRemaining ?? 0;
    final hasAccess = user?.hasFullAccess ?? false;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_t('profile_title')),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Avatar + Name (groß, zentral) ─────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.tertiary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    // Abo Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isPremium
                            ? const Color(0xFF16A34A).withValues(alpha: 0.1)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isPremium
                              ? const Color(0xFF16A34A).withValues(alpha: 0.3)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPremium
                                ? Icons.workspace_premium_rounded
                                : Icons.card_giftcard_rounded,
                            size: 16,
                            color: isPremium
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isPremium
                                ? 'Premium'
                                : AccessConfig.isBetaFreeAccess
                                    ? 'Beta · kostenlos'
                                    : hasAccess
                                        ? _t('trial_days_template')
                                            .replaceAll('{days}', '$trialDays')
                                        : 'Free',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isPremium
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ─── Kinder ────────────────────────────────────────────
              _buildSectionHeader(theme, '\u{1F9D2}', _t('children_title'),
                  action: GestureDetector(
                    onTap: _addChild,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded,
                              size: 14, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(_t('kind_hinzufuegen'),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              )),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: 10),
              if (_children.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    _t('children_hint'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              if (_children.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _children.map((child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('\u{1F9D2}',
                              style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(child.name,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          if (child.age.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(child.age,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 28),

              // ─── Upgrade (nur für Free-User) ───────────────────────
              if (!isPremium) ...[
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaywallScreen(
                        onSubscribed: () {
                          Navigator.pop(context);
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.08),
                          theme.colorScheme.tertiary.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.tertiary,
                            ]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.rocket_launch_rounded,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_t('upgrade_premium'),
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              Text(_t('unlock_all_features'),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  )),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 16, color: theme.colorScheme.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // ─── Einstellungen ─────────────────────────────────────
              _buildSectionHeader(theme, '\u{2699}\u{FE0F}', _t('settings')),
              const SizedBox(height: 10),
              _buildTile(theme,
                  icon: Icons.dark_mode_rounded,
                  title: _t('dark_mode'),
                  trailing: Switch.adaptive(
                    value: themeService.isDarkMode,
                    onChanged: (v) {
                      themeService.setDarkMode(v);
                      DemoApp.setThemeMode(
                          v ? ThemeMode.dark : ThemeMode.light);
                      setState(() {});
                    },
                  )),
              _buildTile(theme,
                  icon: Icons.language_rounded,
                  title: _t('language'),
                  value: _getLanguageLabel(languageService.currentLanguage),
                  onTap: _showLanguagePicker),
              _buildTile(theme,
                  icon: Icons.notifications_rounded,
                  title: _t('notifications'),
                  value: 'Aktiv',
                  onTap: () {}),
              const SizedBox(height: 28),

              // ─── Rechtliches ───────────────────────────────────────
              _buildSectionHeader(theme, '\u{1F4C4}', _t('legal')),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  _buildCompactTile(theme,
                      icon: Icons.shield_rounded,
                      title: _t('privacy'),
                      subtitle: 'DSGVO-konform',
                      onTap: () => _openUrl(APIConfig.getPrivacyPolicyUrl())),
                  _thinDivider(theme),
                  _buildCompactTile(theme,
                      icon: Icons.gavel_rounded,
                      title: _t('terms'),
                      subtitle: 'AGB & Nutzung',
                      onTap: () => _openUrl(APIConfig.getTermsOfServiceUrl())),
                  _thinDivider(theme),
                  _buildCompactTile(theme,
                      icon: Icons.business_rounded,
                      title: 'Impressum',
                      subtitle: '§5 TMG',
                      onTap: _showImpressum),
                  _thinDivider(theme),
                  _buildCompactTile(theme,
                      icon: Icons.auto_awesome_rounded,
                      title: 'KI-Nutzungshinweis',
                      subtitle: 'EU AI Act',
                      onTap: _showAIDisclosure),
                  _thinDivider(theme),
                  _buildCompactTile(theme,
                      icon: Icons.download_rounded,
                      title: 'Meine Daten exportieren',
                      subtitle: 'DSGVO Art. 20',
                      onTap: _exportUserData),
                  _thinDivider(theme),
                  _buildCompactTile(theme,
                      icon: Icons.code_rounded,
                      title: 'Open-Source-Lizenzen',
                      subtitle: 'Verwendete Packages',
                      onTap: () => showLicensePage(
                            context: context,
                            applicationName: 'Parentpeak',
                            applicationVersion: _appVersion,
                            applicationLegalese:
                                '\u{00A9} 2026 Parentpeak. Alle Rechte vorbehalten.',
                          )),
                  _thinDivider(theme),
                  _buildCompactTile(theme,
                      icon: Icons.mail_rounded,
                      title: 'Kontakt & Support',
                      subtitle: APIConfig.getContactEmail() ?? 'E-Mail',
                      onTap: () => _openUrl(APIConfig.getContactSupportUrl())),
                ]),
              ),
              const SizedBox(height: 20),

              // ─── Beta-Feedback ─────────────────────────────────
              const BetaFeedbackWidget(),
              const SizedBox(height: 20),

              // ─── Logout & Delete ───────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: Text(_t('logout')),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: _showDeleteDialog,
                  child: Text(_t('delete_account'),
                      style: TextStyle(
                          color: theme.colorScheme.error, fontSize: 13)),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                    _appVersion.isNotEmpty
                        ? 'Parentpeak v$_appVersion'
                        : 'Parentpeak',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(ThemeData theme, String emoji, String title,
      {Widget? action}) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ),
        if (action != null) action,
      ],
    );
  }

  Widget _buildTile(ThemeData theme,
      {required IconData icon,
      required String title,
      String? value,
      Widget? trailing,
      VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(title,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (value != null)
                  Text(value,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                if (trailing != null) trailing,
                if (trailing == null && onTap != null)
                  Icon(Icons.chevron_right_rounded,
                      size: 20, color: theme.colorScheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final theme = Theme.of(context);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.logout_rounded,
                  size: 28, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text('Abmelden?',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Du kannst dich jederzeit wieder anmelden.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Abbrechen'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Abmelden'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await AuthService.instance.logout();
    // AuthService notifies AuthGate via ChangeNotifier → rebuilds to LoginScreen
  }

  Future<void> _showDeleteDialog() async {
    final theme = Theme.of(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _DeleteAccountSheet(theme: theme),
    );
    if (confirmed != true) return;

    // Show loading while deleting
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    var error = await AuthService.instance.deleteAccount();

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close loading

    if (error == 'requires-recent-login') {
      // Firebase requires a recent login for account deletion – ask for password.
      if (!mounted) return;
      final password = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _ReauthDialog(theme: theme),
      );
      if (password == null || !mounted) return;

      // Show loading again while re-authenticating + deleting
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      error =
          await AuthService.instance.reauthenticateAndDeleteAccount(password);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // close loading
    }

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: theme.colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    // On success: AuthService notifies AuthGate → navigates to LoginScreen automatically
  }

  // ─── Sprach-Auswahl ─────────────────────────────────────────────────────────

  static const List<_LanguageOption> _allLanguages = [
    _LanguageOption('de', 'Deutsch', '\u{1F1E9}\u{1F1EA}'),
    _LanguageOption('en', 'English', '\u{1F1EC}\u{1F1E7}'),
    _LanguageOption('tr', 'Türkçe', '\u{1F1F9}\u{1F1F7}'),
    _LanguageOption(
        'ar',
        '\u{0627}\u{0644}\u{0639}\u{0631}\u{0628}\u{064A}\u{0629}',
        '\u{1F1F8}\u{1F1E6}'),
    _LanguageOption('fr', 'Français', '\u{1F1EB}\u{1F1F7}'),
    _LanguageOption('es', 'Español', '\u{1F1EA}\u{1F1F8}'),
    _LanguageOption('it', 'Italiano', '\u{1F1EE}\u{1F1F9}'),
    _LanguageOption('pt', 'Português', '\u{1F1F5}\u{1F1F9}'),
    _LanguageOption('nl', 'Nederlands', '\u{1F1F3}\u{1F1F1}'),
    _LanguageOption('pl', 'Polski', '\u{1F1F5}\u{1F1F1}'),
    _LanguageOption(
        'ru',
        '\u{0420}\u{0443}\u{0441}\u{0441}\u{043A}\u{0438}\u{0439}',
        '\u{1F1F7}\u{1F1FA}'),
    _LanguageOption(
        'uk',
        '\u{0423}\u{043A}\u{0440}\u{0430}\u{0457}\u{043D}\u{0441}\u{044C}\u{043A}\u{0430}',
        '\u{1F1FA}\u{1F1E6}'),
    _LanguageOption('hr', 'Hrvatski', '\u{1F1ED}\u{1F1F7}'),
    _LanguageOption('sr', '\u{0421}\u{0440}\u{043F}\u{0441}\u{043A}\u{0438}',
        '\u{1F1F7}\u{1F1F8}'),
    _LanguageOption('fi', 'Suomi', '\u{1F1EB}\u{1F1EE}'),
    _LanguageOption('da', 'Dansk', '\u{1F1E9}\u{1F1F0}'),
    _LanguageOption(
        'fa', '\u{0641}\u{0627}\u{0631}\u{0633}\u{06CC}', '\u{1F1EE}\u{1F1F7}'),
    _LanguageOption('ku', 'Kurdî', 'ala_rengin'),
    _LanguageOption('ja', '\u{65E5}\u{672C}\u{8A9E}', '\u{1F1EF}\u{1F1F5}'),
    _LanguageOption('zh', '\u{4E2D}\u{6587}', '\u{1F1E8}\u{1F1F3}'),
    _LanguageOption('hi', '\u{0939}\u{093F}\u{0928}\u{094D}\u{0926}\u{0940}',
        '\u{1F1EE}\u{1F1F3}'),
    _LanguageOption(
        'el',
        '\u{0395}\u{03BB}\u{03BB}\u{03B7}\u{03BD}\u{03B9}\u{03BA}\u{03AC}',
        '\u{1F1EC}\u{1F1F7}'),
    _LanguageOption('sw', 'Kiswahili', '\u{1F1F0}\u{1F1EA}'),
    _LanguageOption(
        'am', '\u{12A0}\u{121B}\u{122D}\u{129B}', '\u{1F1EA}\u{1F1F9}'),
    _LanguageOption('ha', 'Hausa', '\u{1F1F3}\u{1F1EC}'),
    _LanguageOption('so', 'Soomaali', '\u{1F1F8}\u{1F1F4}'),
    _LanguageOption(
        'ti', '\u{1275}\u{130D}\u{122D}\u{129B}', '\u{1F1EA}\u{1F1F7}'),
  ];

  String _getLanguageLabel(String code) {
    final match = _allLanguages.where((l) => l.code == code).firstOrNull;
    return match?.label ?? code;
  }

  void _showLanguagePicker() {
    final theme = Theme.of(context);
    final current = languageService.currentLanguage;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  const Text('\u{1F310}', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Text('Sprache wählen',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Icon(Icons.close_rounded,
                        color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _allLanguages.length,
                itemBuilder: (_, i) {
                  final lang = _allLanguages[i];
                  final isActive = lang.code == current;
                  return ListTile(
                    leading: (lang.code == 'ku' || lang.code == 'ckb')
                        ? const AlaRenginFlag(width: 30, height: 20)
                        : Text(lang.flag, style: const TextStyle(fontSize: 22)),
                    title: Text(
                      lang.label,
                      style: TextStyle(
                        fontWeight:
                            isActive ? FontWeight.w800 : FontWeight.w500,
                        color: isActive ? theme.colorScheme.primary : null,
                      ),
                    ),
                    trailing: isActive
                        ? Icon(Icons.check_circle_rounded,
                            color: theme.colorScheme.primary, size: 22)
                        : null,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onTap: () async {
                      await languageService.setLanguage(lang.code);
                      if (mounted) setState(() {});
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImpressum() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Row(children: [
                Icon(Icons.business_rounded, size: 22),
                SizedBox(width: 10),
                Text('Impressum',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 16),
              const Text('Angaben gemäß § 5 TMG / § 25 MStV',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF6B7280))),
              const SizedBox(height: 14),
              _impressumRow('Anbieter', 'Fatih Bucak – Parentpeak'),
              _impressumRow('Inhaber', 'Fatih Bucak'),
              _impressumRow('Adresse', 'Alexandrinenstraße 93, 10969 Berlin'),
              _impressumRow('E-Mail',
                  APIConfig.getContactEmail() ?? 'support@parentpeak.com'),
              _impressumRow('Verantwortlich für Inhalte', 'Fatih Bucak'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Hinweis: Parentpeak befindet sich in der Beta-Phase.',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF6B7280), height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _impressumRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
          ),
        ],
      ),
    );
  }

  void _showAIDisclosure() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Row(children: [
                Text('\u{1F916}', style: TextStyle(fontSize: 22)),
                SizedBox(width: 10),
                Text('KI-Nutzungshinweis',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 16),
              const Text(
                'Parentpeak nutzt Künstliche Intelligenz (Google Gemini) in folgenden Bereichen:',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 14),
              _aiFeatureItem('\u{1F4AC}', 'KI-Elternberatung',
                  'Integrativer pädagogischer Ansatz'),
              _aiFeatureItem('\u{1F372}', 'Rezept-Generator',
                  'Altersgerechte Familienrezepte'),
              _aiFeatureItem('\u{1F4C5}', 'Events-Suche',
                  'Lokale Aktivitäten in deiner Nähe'),
              _aiFeatureItem('\u{1F4DC}', 'Wochenrückblick-Feedback',
                  'Empathische Rückmeldung'),
              const SizedBox(height: 14),
              const Text(
                'Pädagogische Basis:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                '\u{2022} Gewaltfreie Kommunikation (Rosenberg)\n'
                '\u{2022} Neurobiologie (Gerald Hüther)\n'
                '\u{2022} Montessori — "Hilf mir, es selbst zu tun"\n'
                '\u{2022} Reggio — Das Kind hat 100 Sprachen\n'
                '\u{2022} Freinet — Lernen am realen Leben\n'
                '\u{2022} Fröbel — Spielen ist die höchste Form des Lernens\n'
                '\u{2022} Situationsansatz\n'
                '\u{2022} Jesper Juul — Beziehung vor Erziehung',
                style: TextStyle(
                    fontSize: 12, height: 1.6, color: Color(0xFF4B5563)),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wichtig zu wissen:',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    SizedBox(height: 6),
                    Text(
                      '\u{2022} KI-Antworten sind keine professionelle Beratung\n'
                      '\u{2022} Keine Speicherung von Chatverläufen auf externen Servern\n'
                      '\u{2022} Keine echten Kindernamen an die KI übermitteln\n'
                      '\u{2022} Bei Notfällen immer professionelle Hilfe suchen',
                      style: TextStyle(
                          fontSize: 12, height: 1.6, color: Color(0xFF92400E)),
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

  Widget _aiFeatureItem(String emoji, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(desc,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final data = <String, dynamic>{};
    for (final key in keys) {
      final val = prefs.get(key);
      data[key] = val;
    }
    final jsonStr = const JsonEncoder.withIndent('  ').convert({
      'exportDate': DateTime.now().toIso8601String(),
      'app': 'Parentpeak',
      'version': _appVersion,
      'dataKeys': data.length,
      'data': data,
    });

    await Clipboard.setData(ClipboardData(text: jsonStr));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Daten exportiert (${data.length} Einträge in Zwischenablage kopiert)',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ]),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF16A34A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildCompactTile(ThemeData theme,
      {required IconData icon,
      required String title,
      String? subtitle,
      VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  if (subtitle != null)
                    Text(subtitle,
                        style:
                            TextStyle(fontSize: 10, color: Colors.grey[400])),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 15, color: Colors.grey[350]),
          ],
        ),
      ),
    );
  }

  Widget _thinDivider(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Divider(height: 1, color: Colors.grey[200]),
    );
  }

  void _openUrl(String? url) {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _LanguageOption {
  final String code;
  final String label;
  final String flag;
  const _LanguageOption(this.code, this.label, this.flag);
}

class _ChildInfo {
  final String name;
  final String age;
  const _ChildInfo({required this.name, required this.age});
}

/// Bottom sheet with typed confirmation for account deletion.
class _DeleteAccountSheet extends StatefulWidget {
  final ThemeData theme;
  const _DeleteAccountSheet({required this.theme});

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final _ctrl = TextEditingController();
  bool get _confirmed => _ctrl.text.trim().toUpperCase() == 'LÖSCHEN';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final insets = MediaQuery.of(context).viewInsets;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 36 + insets.bottom),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_forever_rounded,
                  size: 28, color: theme.colorScheme.onErrorContainer),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('Konto löschen',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Alle deine Daten werden unwiderruflich gelöscht.\nDiese Aktion kann nicht rückgängig gemacht werden.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          Text('Zur Bestätigung "LÖSCHEN" eingeben:',
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'LÖSCHEN',
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Abbrechen'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed:
                    _confirmed ? () => Navigator.pop(context, true) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  disabledBackgroundColor:
                      theme.colorScheme.error.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Endgültig löschen',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─── Re-authentication dialog ─────────────────────────────────────────────────

class _ReauthDialog extends StatefulWidget {
  final ThemeData theme;
  const _ReauthDialog({required this.theme});

  @override
  State<_ReauthDialog> createState() => _ReauthDialogState();
}

class _ReauthDialogState extends State<_ReauthDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return AlertDialog(
      title: const Text('Anmeldung bestätigen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bitte gib dein Passwort ein, um das Konto endgültig zu löschen.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Passwort',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          onPressed: () {
            final pw = _ctrl.text;
            if (pw.isNotEmpty) Navigator.pop(context, pw);
          },
          child:
              const Text('Bestätigen', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
