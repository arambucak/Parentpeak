import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/profile_account_store.dart';

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key, this.auth, this.accounts});
  final AuthService? auth;
  final ProfileAccountStore? accounts;

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  late final _accounts = widget.accounts ?? ProfileAccountStore.instance;
  late final _ticket = _accounts.ticket;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (!_accounts.isCurrent(_ticket)) {
      setState(() => _error = 'password_change_session');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await (widget.auth ?? AuthService.instance)
        .changePassword(_current.text, _next.text);
    if (!mounted) return;
    if (error == null && _accounts.isCurrent(_ticket)) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = _accounts.isCurrent(_ticket) ? error : 'password_change_session';
    });
  }

  Widget _field(TextEditingController controller, String key,
          String? Function(String?) validator,
          {bool current = false}) =>
      TextFormField(
        controller: controller,
        enabled: !_busy,
        obscureText: _obscure,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.visiblePassword,
        autofillHints: [
          current ? AutofillHints.password : AutofillHints.newPassword
        ],
        decoration: InputDecoration(labelText: context.tr(key)),
        validator: validator,
      );

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy,
        child: AlertDialog(
          scrollable: true,
          title: Text(context.tr('password_change_title')),
          content: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('password_change_body')),
                  const SizedBox(height: 12),
                  _field(
                      _current,
                      'password_change_current',
                      (value) => value == null || value.isEmpty
                          ? context.tr('password_change_current_required')
                          : null,
                      current: true),
                  _field(_next, 'password_change_new', (value) {
                    final key = AuthService.passwordValidationKey(value ?? '');
                    if (key != null) return context.tr(key);
                    return value == _current.text
                        ? context.tr('password_change_same')
                        : null;
                  }),
                  _field(
                      _confirm,
                      'register_password_confirm_label',
                      (value) => value != _next.text
                          ? context.tr('register_password_mismatch')
                          : null),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _obscure = !_obscure),
                    child: Text(context.tr(_obscure
                        ? 'password_change_show'
                        : 'password_change_hide')),
                  ),
                  if (_error != null)
                    Text(context.tr(_error!),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  if (_busy) const Center(child: CircularProgressIndicator()),
                ],
              )),
          actions: [
            TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context, false),
                child: Text(context.tr('cancel'))),
            FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(context.tr('password_change_save'))),
          ],
        ),
      );
}
