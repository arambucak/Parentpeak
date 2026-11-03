import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/ui/widgets/network/family_avatar.dart';

/// Ruhiger „Es passt"-Bildschirm nach einem gegenseitigen Interesse.
///
/// Bewusst ohne Konfetti, ohne Countdown (Redesign-Ton): zwei Familien-
/// Avatare, eine freundliche Zeile, antippbare Eisbrecher-Vorschläge
/// (statische, lokalisierte Texte – keine KI) und ein Sicherheitshinweis.
/// Wird als modales Bottom-Sheet gezeigt.
///
/// [onWrite] bekommt den gewählten Eisbrecher-Text (oder null, wenn der Nutzer
/// „Nachricht schreiben" ohne Vorauswahl tippt). [onLater] schließt ruhig.
class MatchCelebrationSheet extends StatefulWidget {
  const MatchCelebrationSheet({
    super.key,
    required this.ownName,
    required this.otherName,
    required this.onWrite,
    required this.onLater,
  });

  final String ownName;
  final String otherName;
  final void Function(String? icebreaker) onWrite;
  final VoidCallback onLater;

  /// Zeigt das Sheet modal an.
  static Future<void> show(
    BuildContext context, {
    required String ownName,
    required String otherName,
    required void Function(String? icebreaker) onWrite,
    required VoidCallback onLater,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MatchCelebrationSheet(
        ownName: ownName,
        otherName: otherName,
        onWrite: onWrite,
        onLater: onLater,
      ),
    );
  }

  @override
  State<MatchCelebrationSheet> createState() => _MatchCelebrationSheetState();
}

class _MatchCelebrationSheetState extends State<MatchCelebrationSheet> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final icebreakers = [
      context.tr('network_match_icebreaker_1'),
      context.tr('network_match_icebreaker_2'),
      context.tr('network_match_icebreaker_3'),
    ];
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FamilyAvatar(name: widget.ownName, size: FamilyAvatarSize.l),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.favorite_rounded,
                        color: scheme.primary, size: 28),
                  ),
                  FamilyAvatar(name: widget.otherName, size: FamilyAvatarSize.l),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                context.tr('network_match_title'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('network_match_subtitle'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Antippbare Eisbrecher: Auswahl füllt die erste Nachricht vor.
              ...icebreakers.map((text) {
                final selected = _selected == text;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selected = selected ? null : text),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? scheme.primary
                              : scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 18,
                            color: selected ? scheme.primary : scheme.outline,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(text, style: theme.textTheme.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: scheme.tertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('network_match_safety'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => widget.onWrite(_selected),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(context.tr('network_match_write')),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: widget.onLater,
                child: Text(context.tr('network_match_later')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
