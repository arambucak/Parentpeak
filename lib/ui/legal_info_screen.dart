import 'package:flutter/material.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalInfoScreen extends StatelessWidget {
  const LegalInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primary = Color(0xFF0F172A);
    const accent = Color(0xFF38BDF8);

    return Scaffold(
      appBar: AppBar(title: const Text('Rechtliches')),
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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.gavel_rounded, color: Colors.white, size: 28),
                    SizedBox(width: 10),
                    Text(
                      'Klarheit für euren Familienraum',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  'Hier geht es nicht um juristische Floskeln, sondern darum, wie Parentpeak fair, sicher und verantwortungsvoll im Familienalltag genutzt werden soll.',
                  style: TextStyle(color: Colors.white, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Wichtige Leitlinien',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          const _LegalSection(
            icon: Icons.home_outlined,
            title: 'Private Nutzung im Familienkontext',
            body:
                'Parentpeak ist für euren privaten Familienalltag gedacht. Inhalte, Rollen und Profile sollten nur für euren echten Vertrauenskreis gepflegt werden.',
          ),
          const SizedBox(height: 10),
          const _LegalSection(
            icon: Icons.shield_outlined,
            title: 'Sorgfalt bei Daten und Rollen',
            body:
                'Bitte haltet Angaben aktuell und vergebt Rollen bewusst. Vertrauensprofile, Kinderprofile und Backup-Daten sollten nur mit passenden Personen geteilt werden.',
          ),
          const SizedBox(height: 10),
          const _LegalSection(
            icon: Icons.privacy_tip_outlined,
            title: 'DSGVO & Privacy by Design',
            body:
                'KI-Anfragen werden datensparsam verarbeitet. Keine echten Kindernamen, Kontaktdaten oder exakten Adressen in Freitext eingeben. Der Privacy-Modus minimiert sensible Details.',
          ),
          const SizedBox(height: 10),
          const _LegalSection(
            icon: Icons.emergency_outlined,
            title: 'Schutz vor Ersatz von echten Hilfsstellen',
            body:
                'Sicherheits- und Notfallhinweise in Parentpeak helfen bei Orientierung, ersetzen aber keine professionelle medizinische, rechtliche oder akute Hilfe.',
          ),
          const SizedBox(height: 10),
          const _LegalSection(
            icon: Icons.storefront_outlined,
            title: 'Verschenkmarkt: Rolle von Parentpeak',
            body:
                'Parentpeak stellt im Verschenkmarkt nur die Plattform zur Vermittlung bereit. Verantwortung für Zustand, Sicherheit, Rechtmäßigkeit und Übergabe der Artikel liegt bei den beteiligten Nutzern.',
          ),
          const SizedBox(height: 10),
          const _LegalSection(
            icon: Icons.handshake_outlined,
            title: 'Respektvoller Familienraum',
            body:
                'Die App soll Zusammenarbeit erleichtern. Profile, Hinweise und Funktionen dürfen nicht genutzt werden, um Familienmitglieder zu kontrollieren oder bloßzustellen.',
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: const Color(0xFFF8FAFC),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kurz gesagt',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Parentpeak soll Struktur, Schutz und Vertrauen in Familien unterstuetzen. Nutzt die App nur dort, wo sie Beziehungen staerkt und nicht ersetzt.',
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
            const Text(
              'Wichtige Links & Kontakt',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (privacyUrl != null && privacyUrl.isNotEmpty)
              _ComplianceLink(
                label: 'Datenschutzerklärung (Privacy Policy)',
                url: privacyUrl,
              )
            else
              const Text(
                '🔒 Privacy Policy: Nicht konfiguriert (bitte PRIVACY_POLICY_URL setzen)',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 8),
            if (termsUrl != null && termsUrl.isNotEmpty)
              _ComplianceLink(
                label: 'Nutzungsbedingungen (Terms of Service)',
                url: termsUrl,
              )
            else
              const Text(
                '📋 Terms: Nicht konfiguriert (bitte TERMS_OF_SERVICE_URL setzen)',
                style: TextStyle(fontSize: 12, color: Colors.grey),
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
