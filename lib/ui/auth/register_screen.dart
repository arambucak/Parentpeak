import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/logic/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback? onRegisterSuccess;

  const RegisterScreen({super.key, this.onRegisterSuccess});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;
  String? _errorMessage;

  void _clearError() {
    if (_errorMessage == null) return;
    setState(() => _errorMessage = null);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_agreedToTerms) {
      setState(
          () => _errorMessage = 'Bitte akzeptiere die Nutzungsbedingungen.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await AuthService.instance.register(
        email: _emailCtrl.text.trim().toLowerCase(),
        password: _passCtrl.text,
        displayName: _nameCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result.success) {
        // Sign out immediately — user must verify email first
        await AuthService.instance.logout();
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _EmailVerificationDialog(
            email: _emailCtrl.text.trim().toLowerCase(),
            onDone: () {
              Navigator.of(context).pop(); // close dialog
              Navigator.of(context).pop(); // go back to login
            },
          ),
        );
      } else {
        setState(
          () => _errorMessage = result.errorMessage ??
              'Registrierung fehlgeschlagen. Bitte erneut versuchen.',
        );
      }
    } catch (e) {
      debugPrint('RegisterScreen._submit(): unexpected register error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Technischer Fehler bei der Registrierung. Bitte erneut versuchen.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final cardPadding = width < 380 ? 18.0 : 24.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: const Color(0xFF122220),
                    tooltip: 'Zurück zum Login',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -130,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x664FC3B4), Color(0x004FC3B4)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x55FFA970), Color(0x00FFA970)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTrialBanner(theme),
                      const SizedBox(height: 18),
                      Container(
                        padding: EdgeInsets.all(cardPadding),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFDCE9E6)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF103A35)
                                  .withValues(alpha: 0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Konto erstellen',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF122220),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'In 2 Minuten startklar fur deinen Familienalltag.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF5A6B68),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildForm(theme),
                            const SizedBox(height: 14),
                            if (_errorMessage != null) ...[
                              _buildError(theme),
                              const SizedBox(height: 12),
                            ],
                            _buildTerms(theme),
                            const SizedBox(height: 16),
                            _buildRegisterButton(theme),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Bereits registriert? ',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF5A6B68),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Text(
                                    'Jetzt einloggen',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF166A61),
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                      decorationColor: const Color(0xFF166A61),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordHints(theme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C1B1F), Color(0xFF14504E), Color(0xFF2A8A7F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.star_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '30 Tage kostenlos',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Alle Funktionen, keine Kreditkarte nötig.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nameCtrl,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => _clearError(),
            decoration: _fieldDecoration(
              labelText: 'Dein Name',
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Name ist erforderlich.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) => _clearError(),
            decoration: _fieldDecoration(
              labelText: 'E-Mail-Adresse',
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'E-Mail ist erforderlich.';
              }
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
                return 'Bitte gib eine gültige E-Mail-Adresse ein.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passCtrl,
            obscureText: _obscurePass,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearError(),
            decoration: _fieldDecoration(
              labelText: 'Passwort',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscurePass
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscurePass = !_obscurePass),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Passwort ist erforderlich.';
              if (v.length < 8) return 'Mindestens 8 Zeichen.';
              if (!v.contains(RegExp(r'[A-Z]'))) {
                return 'Mindestens ein Großbuchstabe.';
              }
              if (!v.contains(RegExp(r'[0-9]'))) return 'Mindestens eine Zahl.';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passConfirmCtrl,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            onChanged: (_) => _clearError(),
            decoration: _fieldDecoration(
              labelText: 'Passwort bestätigen',
              prefixIcon: const Icon(Icons.lock_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v != _passCtrl.text) {
                return 'Die Passwörter stimmen nicht überein.';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String labelText,
    required Widget prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF7FAF9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD6E3E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD6E3E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1F7A71), width: 1.4),
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD1C3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFB14D2F), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF8C3E28),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerms(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE9E6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _agreedToTerms,
            onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            activeColor: const Color(0xFF166A61),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: RichText(
                text: TextSpan(
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF546663),
                  ),
                  children: [
                    const TextSpan(text: 'Ich akzeptiere die '),
                    TextSpan(
                      text: 'Nutzungsbedingungen',
                      style: const TextStyle(
                        color: Color(0xFF145D55),
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap =
                            () => _openUrl(APIConfig.getTermsOfServiceUrl()),
                    ),
                    const TextSpan(text: ' und '),
                    TextSpan(
                      text: 'Datenschutzrichtlinie',
                      style: const TextStyle(
                        color: Color(0xFF145D55),
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap =
                            () => _openUrl(APIConfig.getPrivacyPolicyUrl()),
                    ),
                    const TextSpan(text: ' von Parentpeak.'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String? rawUrl) async {
    final urlStr = (rawUrl ?? '').trim();
    if (urlStr.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('URL noch nicht konfiguriert.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final uri = Uri.tryParse(urlStr);
    if (uri == null || !await canLaunchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Konnte $urlStr nicht öffnen.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildRegisterButton(ThemeData theme) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: _isLoading ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF166A61),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Kostenlos starten',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  Widget _buildPasswordHints(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1ECEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Passwort-Anforderungen',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...[
            'Mindestens 8 Zeichen',
            'Mindestens ein Großbuchstabe (A–Z)',
            'Mindestens eine Zahl (0–9)',
          ].map(
            (hint) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      size: 16, color: Color(0xFF5E6F6B)),
                  const SizedBox(width: 8),
                  Text(hint, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailVerificationDialog extends StatefulWidget {
  const _EmailVerificationDialog({required this.email, required this.onDone});
  final String email;
  final VoidCallback onDone;

  @override
  State<_EmailVerificationDialog> createState() =>
      _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends State<_EmailVerificationDialog> {
  bool _resent = false;
  bool _sending = false;

  Future<void> _resend() async {
    setState(() { _sending = true; _resent = false; });
    await AuthService.instance.resendVerificationEmail(widget.email);
    if (mounted) setState(() { _sending = false; _resent = true; });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('E-Mail bestätigen 📬'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wir haben eine Bestätigungs-E-Mail an\n${widget.email}\ngesendet.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Bitte klicke auf den Link in der E-Mail. Danach kannst du dich einloggen.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          if (_resent) ...[
            const SizedBox(height: 10),
            const Text(
              '✅ Neuer Link wurde gesendet.',
              style: TextStyle(color: Color(0xFF059669), fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : _resend,
          child: _sending
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Link erneut senden'),
        ),
        FilledButton(
          onPressed: widget.onDone,
          child: const Text('Zum Login'),
        ),
      ],
    );
  }
}
