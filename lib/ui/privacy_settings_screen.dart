import 'package:flutter/material.dart';

class PrivacySettingsScreen extends StatelessWidget {
  final bool isPrivacyModeEnabled;
  final Future<void> Function(bool value) onPrivacyModeChanged;

  const PrivacySettingsScreen({
    super.key,
    required this.isPrivacyModeEnabled,
    required this.onPrivacyModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primary = Color(0xFF2563EB);
    const accent = Color(0xFF7DD3FC);

    return Scaffold(
      appBar: AppBar(title: const Text('Datenschutz')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  primary.withValues(alpha: 0.95),
                  accent.withValues(alpha: 0.90),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lock_person_rounded, color: Colors.white, size: 28),
                    SizedBox(width: 10),
                    Text(
                      'Privatsphaere für euren Familienalltag',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Steuert hier bewusst, welche sensiblen Details im Familienprofil sichtbar sind. Parentpeak soll Orientierung geben, ohne zu viel preiszugeben.',
                  style: TextStyle(color: Colors.white, height: 1.4),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InfoPill(
                      icon: Icons.visibility_off_rounded,
                      label: isPrivacyModeEnabled
                          ? 'Privatsphaere aktiv'
                          : 'Freigabe erweitert',
                    ),
                    const _InfoPill(
                      icon: Icons.devices_rounded,
                      label: 'Vertrauensgeraete beachten',
                    ),
                    const _InfoPill(
                      icon: Icons.family_restroom,
                      label: 'Nur für euren Kreis',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: primary.withValues(alpha: 0.12)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: SwitchListTile.adaptive(
                title: const Text(
                  'Privatsphaere-Modus',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  isPrivacyModeEnabled
                      ? 'Geburtsdaten, Rollen und sensible Hinweise werden zurückhaltender dargestellt.'
                      : 'Mehr Profilinfos sind im Familienkreis sichtbar.',
                ),
                secondary: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.shield_moon_rounded, color: primary),
                ),
                value: isPrivacyModeEnabled,
                onChanged: (value) async {
                  await onPrivacyModeChanged(value);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Was Parentpeak besonders schuetzt',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          const _PrivacyFeatureCard(
            icon: Icons.badge_outlined,
            title: 'Weniger sensible Profildetails',
            body:
                'Kinderrollen, persoenliche Hinweise und interne Familienzuordnungen werden nicht unnötig prominent gezeigt.',
          ),
          const SizedBox(height: 10),
          const _PrivacyFeatureCard(
            icon: Icons.screen_lock_portrait_rounded,
            title: 'Mehr Sicherheit auf geteilten Geraeten',
            body:
                'Gerade auf Familien-iPads oder gemeinsam genutzten Smartphones reduziert der Modus das Risiko ungewollter Einblicke.',
          ),
          const SizedBox(height: 10),
          const _PrivacyFeatureCard(
            icon: Icons.emergency_share_outlined,
            title: 'Wichtige Schutzfunktionen bleiben erreichbar',
            body:
                'Notfallkontakte, Vertrauensgeraete und Sicherheitsinfos bleiben schnell verfügbar, auch wenn das Profil diskreter dargestellt wird.',
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
                    'Empfehlung für Eltern',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Lasst den Privatsphaere-Modus aktiv, wenn mehrere Personen das Geraet nutzen, Kinder mit auf den Bildschirm schauen oder ihr euer Profil bewusst reduziert halten wollt.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _PrivacyFeatureCard({
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
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF2563EB)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
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
