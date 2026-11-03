import 'package:flutter/material.dart';
import 'package:parentpeak/services/block_report_service.dart';

/// Drei-Punkte-Menü mit „Melden" und „Blockieren" für eine Familie/ein Profil.
///
/// Kapselt das zuvor in der Match-Karte handgebaute `PopupMenuButton` und
/// nutzt die bestehende [showReportSheet]-Hilfe für das Melden. Soll laut
/// Redesign auf JEDER Karte verfügbar sein (auch im Karussell, wo es bisher
/// fehlte).
class SafetyMenu extends StatelessWidget {
  const SafetyMenu({
    super.key,
    required this.userId,
    required this.userName,
    required this.onBlock,
    this.reportLabel = 'Melden',
    this.blockLabel = 'Blockieren',
    this.contentType = 'profile',
  });

  /// Konto-/Profil-ID der zu meldenden bzw. zu blockierenden Familie.
  final String userId;
  final String userName;

  /// Wird ausgelöst, wenn der Nutzer „Blockieren" wählt.
  final VoidCallback onBlock;

  final String reportLabel;
  final String blockLabel;
  final String contentType;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, size: 20, color: scheme.outline),
      padding: EdgeInsets.zero,
      tooltip: reportLabel,
      onSelected: (value) {
        if (value == 'report') {
          showReportSheet(
            context,
            userId: userId,
            userName: userName,
            contentType: contentType,
          );
        } else if (value == 'block') {
          onBlock();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              const Icon(Icons.flag_outlined, size: 18),
              const SizedBox(width: 10),
              Text(reportLabel),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'block',
          child: Row(
            children: [
              const Icon(Icons.block_rounded, size: 18),
              const SizedBox(width: 10),
              Text(blockLabel),
            ],
          ),
        ),
      ],
    );
  }
}
