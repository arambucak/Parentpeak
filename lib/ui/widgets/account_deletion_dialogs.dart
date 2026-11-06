import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';

/// Bottom sheet with typed confirmation for account deletion.
class DeleteAccountSheet extends StatefulWidget {
  final ThemeData theme;
  const DeleteAccountSheet({super.key, required this.theme});

  @override
  State<DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<DeleteAccountSheet> {
  final _ctrl = TextEditingController();
  String _normalizeConfirmation(String value) {
    final upper = value.trim().toUpperCase();
    return Localizations.localeOf(context).languageCode == 'tr'
        ? upper.replaceAll('İ', 'I')
        : upper;
  }

  bool get _confirmed =>
      _normalizeConfirmation(_ctrl.text) ==
      _normalizeConfirmation(context.tr('delete_confirmation_word'));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final insets = MediaQuery.of(context).viewInsets;
    return SingleChildScrollView(
        child: Container(
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
              child: Icon(
                Icons.delete_forever_rounded,
                size: 28,
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              context.tr('delete_account'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              context.tr('delete_account_permanent_warning'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.tr(
              'delete_confirmation_prompt',
              values: {'word': context.tr('delete_confirmation_word')},
            ),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: context.tr('delete_confirmation_word'),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(context.tr('cancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed:
                      _confirmed ? () => Navigator.pop(context, true) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    disabledBackgroundColor: theme.colorScheme.error.withValues(
                      alpha: 0.3,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    context.tr('profile_delete_final'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ));
  }
}

// ─── Re-authentication dialog ─────────────────────────────────────────────────

class DeleteAccountPasswordDialog extends StatefulWidget {
  final ThemeData theme;
  const DeleteAccountPasswordDialog({super.key, required this.theme});

  @override
  State<DeleteAccountPasswordDialog> createState() =>
      _DeleteAccountPasswordDialogState();
}

class _DeleteAccountPasswordDialogState
    extends State<DeleteAccountPasswordDialog> {
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
      scrollable: true,
      title: Text(context.tr('profile_confirm_login')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('delete_reauth_password_body'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.tr('auth_password_label'),
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
          child: Text(context.tr('cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          onPressed: () {
            final pw = _ctrl.text;
            if (pw.isNotEmpty) Navigator.pop(context, pw);
          },
          child: Text(
            context.tr('profile_confirm'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// Bestätigungsschritt für Google-/Apple-Konten, die kein Passwort haben:
/// Statt eines Passwort-Felds muss sich der Nutzer erneut über seinen Anbieter
/// anmelden, bevor das Konto gelöscht wird. Gibt true zurück, wenn der Nutzer
/// fortfahren möchte.
class DeleteAccountProviderDialog extends StatelessWidget {
  final ThemeData theme;
  final String providerId;
  const DeleteAccountProviderDialog(
      {super.key, required this.theme, required this.providerId});

  @override
  Widget build(BuildContext context) {
    final isGoogle = providerId == 'google.com';
    final providerName = isGoogle ? 'Google' : 'Apple';
    return AlertDialog(
      scrollable: true,
      title: Text(context.tr('profile_confirm_login')),
      content: Text(
        context
            .tr('delete_reauth_provider_body')
            .replaceAll('{provider}', providerName),
        style: theme.textTheme.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.tr('cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            context
                .tr('delete_reauth_provider_confirm')
                .replaceAll('{provider}', providerName),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
