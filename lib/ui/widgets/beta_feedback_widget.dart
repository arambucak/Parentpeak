import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';

/// Beta-Feedback Widget — Eltern können Feedback, Wuensche und Bugs melden.
/// Sendet per E-Mail an support@parentpeak.com.
class BetaFeedbackWidget extends StatelessWidget {
  const BetaFeedbackWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
        ),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('\u{1F4AC}', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  AppStringsManager.getString(
                      languageService.currentLanguage, 'feedback_title'),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Text(
                  AppStringsManager.getString(
                      languageService.currentLanguage, 'feedback_subtitle'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
          )),
        ]),
        const SizedBox(height: 14),
        _FeedbackButton(
          emoji: '\u{2B50}',
          label: AppStringsManager.getString(
              languageService.currentLanguage, 'feedback_like'),
          hint: AppStringsManager.getString(
              languageService.currentLanguage, 'feedback_like_hint'),
          color: const Color(0xFF16A34A),
          onTap: () => _openFeedback(context, 'gefaellt'),
        ),
        const SizedBox(height: 8),
        _FeedbackButton(
          emoji: '\u{1F4A1}',
          label: AppStringsManager.getString(
              languageService.currentLanguage, 'feedback_wish'),
          hint: AppStringsManager.getString(
              languageService.currentLanguage, 'feedback_wish_hint'),
          color: const Color(0xFF8B5CF6),
          onTap: () => _openFeedback(context, 'wunsch'),
        ),
        const SizedBox(height: 8),
        _FeedbackButton(
          emoji: '\u{1F41B}',
          label: AppStringsManager.getString(
              languageService.currentLanguage, 'feedback_bug'),
          hint: AppStringsManager.getString(
              languageService.currentLanguage, 'feedback_bug_hint'),
          color: const Color(0xFFDC2626),
          onTap: () => _openFeedback(context, 'bug'),
        ),
      ]),
    );
  }

  void _openFeedback(BuildContext context, String type) {
    final theme = Theme.of(context);
    final controller = TextEditingController();
    String title;
    String hint;

    switch (type) {
      case 'gefaellt':
        title = '\u{2B50} Was gefällt dir?';
        hint =
            'z.B. Die Spielideen sind toll! Der KI-Chat hilft mir wirklich...';
        break;
      case 'wunsch':
        title = '\u{1F4A1} Was wünschst du dir?';
        hint = 'z.B. Ich wünsche mir eine Schlaftracker-Funktion...';
        break;
      default:
        title = '\u{1F41B} Was funktioniert nicht?';
        hint = 'z.B. Wenn ich auf Events tippe passiert nichts...';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 4,
              maxLength: 500,
              autofocus: true,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    TextStyle(fontSize: 13, color: theme.colorScheme.outline),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFF16A34A), width: 1.5)),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final text = controller.text.trim();
                    if (text.isEmpty) return;
                    Navigator.pop(ctx);
                    await _sendFeedback(type, text);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content:
                            Text('\u{2764}\u{FE0F} Danke für dein Feedback!'),
                      ));
                    }
                  },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Absenden'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                )),
          ]),
        ),
      ),
    );
  }

  Future<void> _sendFeedback(String type, String message) async {
    final subject = Uri.encodeComponent('ParentPeak Beta-Feedback: $type');
    final body = Uri.encodeComponent(message);
    final url =
        Uri.parse('mailto:support@parentpeak.com?subject=$subject&body=$body');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}

class _FeedbackButton extends StatelessWidget {
  final String emoji;
  final String label;
  final String hint;
  final Color color;
  final VoidCallback onTap;

  const _FeedbackButton({
    required this.emoji,
    required this.label,
    required this.hint,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.06),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            Text(hint,
                style: TextStyle(
                    fontSize: 10, color: color.withValues(alpha: 0.7))),
          ],
        )),
        Icon(Icons.arrow_forward_ios_rounded,
            size: 14, color: color.withValues(alpha: 0.5)),
      ]),
    );
  }
}
