import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/auth_service.dart';

/// Einladender Hinweis nach der Registrierung: "Bitte bestätige deine E-Mail".
///
/// Zeigt das ParentPeak-Schild-Logo, die Zieladresse (damit Tippfehler sofort
/// auffallen), drei einfache Schritte und einen ruhigen Spam-Hinweis. Ist der
/// Versand fehlgeschlagen, wird "Link erneut senden" zur Hauptaktion.
///
/// [resend] ist für Tests austauschbar; standardmäßig sendet der
/// [AuthService] die Bestätigungsmail erneut.
class EmailVerificationDialog extends StatefulWidget {
  const EmailVerificationDialog({
    super.key,
    required this.email,
    required this.emailSent,
    required this.onDone,
    this.resend,
  });

  final String email;
  final bool emailSent;
  final VoidCallback onDone;
  final Future<bool> Function(String email)? resend;

  @override
  State<EmailVerificationDialog> createState() =>
      _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends State<EmailVerificationDialog> {
  bool _resent = false;
  bool _resendFailed = false;
  bool _sending = false;

  Future<void> _resend() async {
    setState(() {
      _sending = true;
      _resent = false;
      _resendFailed = false;
    });
    final send =
        widget.resend ?? AuthService.instance.resendVerificationEmail;
    final sent = await send(widget.email);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _resent = sent;
      _resendFailed = !sent;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Ohne gesendete Mail (und ohne erfolgreichen zweiten Versuch) ist der
    // erneute Versand die wichtigste Aktion.
    final resendIsPrimary = !widget.emailSent && !_resent;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      backgroundColor: scheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(scheme),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.tr('auth_verify_dialog_title'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (widget.emailSent)
                      Text(
                        context.tr('auth_verify_dialog_subtitle'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      )
                    else
                      _notice(
                        icon: Icons.error_outline_rounded,
                        text: context.tr('auth_email_delivery_failed'),
                        background: scheme.errorContainer.withValues(alpha: 0.5),
                        foreground: scheme.onErrorContainer,
                      ),
                    const SizedBox(height: 14),
                    _emailPill(theme),
                    const SizedBox(height: 20),
                    _step(theme, 1, context.tr('auth_verify_step_1')),
                    _step(theme, 2, context.tr('auth_verify_step_2')),
                    _step(theme, 3, context.tr('auth_verify_step_3')),
                    const SizedBox(height: 16),
                    _spamHint(theme),
                    if (_resent) ...[
                      const SizedBox(height: 14),
                      Text(
                        context.tr('auth_email_resent'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (_resendFailed) ...[
                      const SizedBox(height: 14),
                      Text(
                        context.tr('auth_email_delivery_failed'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (resendIsPrimary) ...[
                      _bigButton(_resendButtonChild(), _sending ? null : _resend),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: widget.onDone,
                        child: Text(context.tr('auth_to_login')),
                      ),
                    ] else ...[
                      _bigButton(
                        Text(context.tr('auth_to_login')),
                        widget.onDone,
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: _sending ? null : _resend,
                        icon: _sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(context.tr('auth_resend_link')),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resendButtonChild() {
    if (_sending) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
      );
    }
    return Text(context.tr('auth_resend_link'));
  }

  Widget _bigButton(Widget child, VoidCallback? onPressed) {
    return SizedBox(
      height: 50,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: child,
      ),
    );
  }

  /// Sanfter Verlauf mit dem Schild-Logo und einem kleinen Mail-Abzeichen.
  Widget _header(ColorScheme scheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.6),
            const Color(0xFFFBF6EB),
          ],
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Semantics(
                label: 'ParentPeak',
                image: true,
                child: ExcludeSemantics(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(3),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(23),
                      child: Image.asset(
                        'assets/images/neue logo.png',
                        fit: BoxFit.cover,
                        cacheWidth: 288,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.family_restroom_rounded,
                          size: 44,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Icon(
                    Icons.mark_email_unread_rounded,
                    size: 16,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emailPill(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.alternate_email_rounded,
                size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.email,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(ThemeData theme, int number, String text) {
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _spamHint(ThemeData theme) {
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return _notice(
      icon: Icons.lightbulb_outline_rounded,
      text: context.tr('auth_verify_spam_hint'),
      background: dark
          ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
          : const Color(0xFFFBF6EB),
      foreground: dark ? scheme.onSurfaceVariant : const Color(0xFF625844),
    );
  }

  Widget _notice({
    required IconData icon,
    required String text,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: foreground, fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
