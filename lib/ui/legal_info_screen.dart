import 'package:flutter/material.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/main.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalInfoScreen extends StatelessWidget {
  const LegalInfoScreen({super.key});

  String _t(String key) =>
      AppStringsManager.phase1String(languageService.currentLanguage, key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primary = Color(0xFF0F172A);
    const accent = Color(0xFF38BDF8);

    return Scaffold(
      appBar: AppBar(title: Text(_t('legal_title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  primary.withValues(alpha: 0.96),
                  accent.withValues(alpha: 0.90),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.gavel_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      _t('legal_hero_title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _t('legal_hero_body'),
                  style: const TextStyle(color: Colors.white, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _t('legal_guidelines_title'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _LegalSection(
            icon: Icons.home_outlined,
            title: _t('legal_private_title'),
            body: _t('legal_private_body'),
          ),
          const SizedBox(height: 10),
          _LegalSection(
            icon: Icons.shield_outlined,
            title: _t('legal_data_title'),
            body: _t('legal_data_body'),
          ),
          const SizedBox(height: 10),
          _LegalSection(
            icon: Icons.privacy_tip_outlined,
            title: _t('legal_privacy_title'),
            body: _t('legal_privacy_body'),
          ),
          const SizedBox(height: 10),
          _LegalSection(
            icon: Icons.emergency_outlined,
            title: _t('legal_help_title'),
            body: _t('legal_help_body'),
          ),
          const SizedBox(height: 10),
          _LegalSection(
            icon: Icons.storefront_outlined,
            title: _t('legal_market_title'),
            body: _t('legal_market_body'),
          ),
          const SizedBox(height: 10),
          _LegalSection(
            icon: Icons.handshake_outlined,
            title: _t('legal_respect_title'),
            body: _t('legal_respect_body'),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: const Color(0xFFF8FAFC),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('legal_summary_title'),
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t('legal_summary_body'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _ComplianceLinksSection(),
        ],
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _LegalSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF0369A1)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComplianceLinksSection extends StatelessWidget {
  String _t(String key) =>
      AppStringsManager.phase1String(languageService.currentLanguage, key);

  Future<void> _openUrl(BuildContext context, String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('common_link_open_failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final privacyUrl = APIConfig.getPrivacyPolicyUrl();
    final termsUrl = APIConfig.getTermsOfServiceUrl();
    final contactEmail = APIConfig.getContactEmail();

    return Card(
      elevation: 0,
      color: const Color(0xFFF0F9FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(
          color: Color(0xFF0369A1),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('legal_links_title'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (privacyUrl != null && privacyUrl.isNotEmpty)
              _ComplianceLink(
                label: _t('legal_privacy_link'),
                url: privacyUrl,
              )
            else
              Text(
                _t('legal_privacy_not_configured'),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 8),
            if (termsUrl != null && termsUrl.isNotEmpty)
              _ComplianceLink(
                label: _t('legal_terms_link'),
                url: termsUrl,
              )
            else
              Text(
                _t('legal_terms_not_configured'),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            if (contactEmail != null && contactEmail.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openUrl(context, 'mailto:$contactEmail'),
                child: Row(
                  children: [
                    const Icon(Icons.email_outlined,
                        size: 16, color: Color(0xFF0369A1)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        contactEmail,
                        style: const TextStyle(
                          color: Color(0xFF0369A1),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComplianceLink extends StatelessWidget {
  final String label;
  final String url;

  const _ComplianceLink({required this.label, required this.url});

  Future<void> _openUrl(BuildContext context) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('common_link_open_failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openUrl(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.link_outlined, size: 16, color: Color(0xFF0369A1)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF0369A1),
                  decoration: TextDecoration.underline,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
