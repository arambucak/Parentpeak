import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/models/meetup_event.dart';
import 'package:parentpeak/models/payment_transaction.dart';
import 'package:parentpeak/logic/payment_service.dart';
import 'package:parentpeak/logic/event_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';

class PaymentScreen extends StatefulWidget {
  final MeetupEvent event;
  final double amount;

  const PaymentScreen({
    super.key,
    required this.event,
    required this.amount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _paymentService = PaymentService();
  final _eventService = EventService();

  String _t(String key) {
    final language = languageService.currentLanguage;
    if (AppStringsManager.hasDirectPhase1String(language, key)) {
      return AppStringsManager.phase1String(language, key);
    }
    return AppStringsManager.getString(language, key);
  }

  String _selectedPaymentMethod = 'stripe'; // stripe oder paypal
  bool _isProcessing = false;
  bool _agreeToTerms = false;

  Future<void> _openLegalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('payment_link_failed'))),
      );
    }
  }

  bool get _stripeAvailable =>
      APIConfig.isStripePaymentSheetSupportedPlatform() &&
      APIConfig.isStripePublishableKeyConfigured();

  Future<void> _processPayment() async {
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('payment_accept_terms'))),
      );
      return;
    }

    if (_selectedPaymentMethod == 'stripe' && !_stripeAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('payment_stripe_unavailable'))),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      Map<String, dynamic> initResponse;
      if (_selectedPaymentMethod == 'stripe') {
        initResponse = await _paymentService.initiateStripePayment(
          eventId: widget.event.id,
          hosterId: widget.event.hosterId,
          amount: widget.amount,
        );
      } else {
        initResponse = await _paymentService.initiatePayPalPayment(
          eventId: widget.event.id,
          hosterId: widget.event.hosterId,
          amount: widget.amount,
        );
      }

      final providerTransactionRef = _selectedPaymentMethod == 'stripe'
          ? (initResponse['clientSecret']?.toString() ?? '').trim()
          : (initResponse['token']?.toString() ?? '').trim();

      if (providerTransactionRef.isEmpty) {
        throw StateError(_t('payment_provider_reference_missing'));
      }

      // Lege Zahlung als pending an und warte auf verifiziertes Provider-Ergebnis.
      final pendingTransaction = await _paymentService.confirmPayment(
        eventId: widget.event.id,
        hosterId: widget.event.hosterId,
        amount: widget.amount,
        paymentMethod: _selectedPaymentMethod,
        providerTransactionRef: providerTransactionRef,
        initialStatus: 'pending',
      );

      final transaction = await _awaitFinalPaymentState(pendingTransaction.id);

      if (transaction == null || transaction.status != 'completed') {
        throw StateError(
          _t('payment_not_completed').replaceAll(
            '{status}',
            transaction?.status ?? _t('payment_status_unknown'),
          ),
        );
      }

      // Erstelle das Event
      final eventWithPayment = MeetupEvent(
        id: widget.event.id,
        hosterId: widget.event.hosterId,
        title: widget.event.title,
        description: widget.event.description,
        category: widget.event.category,
        ageGroups: widget.event.ageGroups,
        location: widget.event.location,
        latitude: widget.event.latitude,
        longitude: widget.event.longitude,
        eventDate: widget.event.eventDate,
        createdAt: widget.event.createdAt,
        paymentDate: DateTime.now(),
        maxParticipants: widget.event.maxParticipants,
        photoUrl: widget.event.photoUrl,
        status: EventStatus.active,
        price: widget.event.price,
        visibility: widget.event.visibility,
        shareRadiusKm: widget.event.shareRadiusKm,
        invitedUserIds: widget.event.invitedUserIds,
      );

      await _eventService.createEvent(eventWithPayment);

      setState(() => _isProcessing = false);

      if (mounted) {
        // Zeige Erfolgs-Dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            icon: Icon(Icons.check_circle, color: Colors.green[700], size: 48),
            title: Text(_t('payment_success')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _t('payment_event_live').replaceAll('{title}', widget.event.title),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _t('payment_transaction_id').replaceAll('{id}', transaction.id),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _t('payment_amount').replaceAll(
                          '{amount}', transaction.amount.toStringAsFixed(2)),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: Text(_t('done')),
              ),
            ],
          ),
        );
      }
    } on StripeException catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_mapStripeError(e)),
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('payment_error').replaceAll('{error}', '$e'))),
        );
      }
    }
  }

  String _mapStripeError(StripeException e) {
    final code = e.error.code;
    if (code == FailureCode.Canceled) {
      return _t('payment_canceled');
    }
    if (code == FailureCode.Failed) {
      return _t('payment_failed');
    }
    if (code == FailureCode.Timeout) {
      return _t('payment_timeout');
    }
    return e.error.localizedMessage?.trim().isNotEmpty == true
        ? _t('payment_stripe_error_detail')
          .replaceAll('{error}', e.error.localizedMessage!)
        : _t('payment_stripe_error');
  }

  Future<PaymentTransaction?> _awaitFinalPaymentState(
      String transactionId) async {
    const maxAttempts = 15;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final transaction = await _paymentService.getTransaction(transactionId);
      if (transaction == null) {
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }
      if (transaction.status == 'completed' || transaction.status == 'failed') {
        return transaction;
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    return await _paymentService.getTransaction(transactionId);
  }

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final contentMaxWidth = viewportWidth >= 1200
        ? 920.0
        : viewportWidth >= 900
            ? 820.0
            : double.infinity;
    final horizontalPadding = viewportWidth >= 900 ? 24.0 : 16.0;

    return PopScope(
      canPop: !_isProcessing,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_t('payment_complete')),
          elevation: 0,
          automaticallyImplyLeading: !_isProcessing,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF8FAFC), Color(0xFFF0F9FF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(horizontalPadding),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(_t('payment_intro')),
                    ),
                    const SizedBox(height: 16),
                    // Event Summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t('payment_order_summary'),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.event.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (widget.event.visibility ==
                                  EventVisibility.privateOnly)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _t('payment_visibility_private'),
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700),
                                  ),
                                )
                              else if (widget.event.visibility ==
                                  EventVisibility.familyCircle)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0E7FF),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _t('payment_visibility_family'),
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700),
                                  ),
                                )
                              else if (widget.event.visibility ==
                                  EventVisibility.inviteOnly)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEDD5),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _t('payment_visibility_invited').replaceAll(
                                      '{count}', '${widget.event.invitedUserIds.length}'),
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDBEAFE),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _t('payment_visibility_public'),
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_t('payment_publish_fee')),
                              Text(
                                '${widget.amount.toStringAsFixed(2)} €',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Zahlungsmethode
                    Text(
                      _t('payment_method'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),

                    // Stripe Option
                    _PaymentMethodOptionTile(
                      title: _t('payment_stripe_name'),
                      subtitle: _t('payment_stripe_subtitle'),
                      icon: Icons.credit_card,
                      selected: _selectedPaymentMethod == 'stripe',
                      enabled: !_isProcessing,
                      onTap: () =>
                          setState(() => _selectedPaymentMethod = 'stripe'),
                    ),
                    const SizedBox(height: 12),

                    // PayPal Option
                    _PaymentMethodOptionTile(
                      title: _t('payment_paypal_name'),
                      subtitle: _t('payment_paypal_subtitle'),
                      icon: Icons.payment,
                      selected: _selectedPaymentMethod == 'paypal',
                      enabled: !_isProcessing,
                      onTap: () =>
                          setState(() => _selectedPaymentMethod = 'paypal'),
                    ),
                    const SizedBox(height: 24),

                    // Sicherheits-Hinweis
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        border: Border.fromBorderSide(
                          BorderSide(color: Color(0xFFBFDBFE)),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.lock,
                                color: Color(0xFF1D4ED8), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _t('payment_security_note'),
                                style: const TextStyle(
                                  color: Color(0xFF1D4ED8),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Terms & Conditions
                    CheckboxListTile(
                      title: Text(_t('payment_accept_agb')),
                      subtitle: Text(_t('payment_terms_subtitle')),
                      value: _agreeToTerms,
                      onChanged: _isProcessing
                          ? null
                          : (value) {
                              setState(() => _agreeToTerms = value ?? false);
                            },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    Builder(
                      builder: (context) {
                        final termsUrl = APIConfig.getTermsOfServiceUrl();
                        final privacyUrl = APIConfig.getPrivacyPolicyUrl();
                        if ((termsUrl == null || termsUrl.isEmpty) &&
                            (privacyUrl == null || privacyUrl.isEmpty)) {
                          return const SizedBox.shrink();
                        }
                        return Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (termsUrl != null && termsUrl.isNotEmpty)
                              TextButton.icon(
                                onPressed: () => _openLegalUrl(termsUrl),
                                icon: const Icon(Icons.description_outlined,
                                    size: 16),
                                label: Text(_t('payment_view_agb')),
                              ),
                            if (privacyUrl != null && privacyUrl.isNotEmpty)
                              TextButton.icon(
                                onPressed: () => _openLegalUrl(privacyUrl),
                                icon: const Icon(Icons.privacy_tip_outlined,
                                    size: 16),
                                label: Text(_t('payment_view_privacy')),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Pay Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: (!_agreeToTerms || _isProcessing)
                            ? null
                            : _processPayment,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.payment),
                        label: Text(
                          _isProcessing
                                ? _t('payment_processing')
                                : _t('payment_pay_now').replaceAll(
                                  '{amount}', widget.amount.toStringAsFixed(2)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodOptionTile extends StatelessWidget {
  const _PaymentMethodOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor =
        selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant;

    return Card(
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
