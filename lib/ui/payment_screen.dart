import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/models/meetup_event.dart';
import 'package:parentpeak/models/payment_transaction.dart';
import 'package:parentpeak/logic/payment_service.dart';
import 'package:parentpeak/logic/event_service.dart';
import 'package:url_launcher/url_launcher.dart';

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

  String _selectedPaymentMethod = 'stripe'; // stripe oder paypal
  bool _isProcessing = false;
  bool _agreeToTerms = false;

  Future<void> _openLegalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link konnte nicht geoeffnet werden.')),
      );
    }
  }

  bool get _stripeAvailable =>
      APIConfig.isStripePaymentSheetSupportedPlatform() &&
      APIConfig.isStripePublishableKeyConfigured();

  Future<void> _processPayment() async {
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte akzeptiere die Bedingungen')),
      );
      return;
    }

    if (_selectedPaymentMethod == 'stripe' && !_stripeAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Stripe ist aktuell nicht konfiguriert. Bitte wähle PayPal oder kontaktiere den Support.',
          ),
        ),
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
        throw StateError('Provider-Referenz fehlt. Zahlung kann nicht fortgesetzt werden.');
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
        throw StateError('Zahlung ist noch nicht abgeschlossen (Status: ${transaction?.status ?? 'unknown'}).');
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
            title: const Text('Zahlung erfolgreich!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Deine Aktivität "${widget.event.title}" ist nun live!',
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
                        'Transaktions-ID: ${transaction.id}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Betrag: ${transaction.amount.toStringAsFixed(2)} €',
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
                child: const Text('Fertig'),
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
          SnackBar(content: Text('Zahlungsfehler: $e')),
        );
      }
    }
  }

  String _mapStripeError(StripeException e) {
    final code = e.error.code;
    if (code == FailureCode.Canceled) {
      return 'Zahlung abgebrochen';
    }
    if (code == FailureCode.Failed) {
      return 'Zahlung fehlgeschlagen. Bitte versuche es erneut.';
    }
    if (code == FailureCode.Timeout) {
      return 'Zeitueberschreitung bei der Zahlung. Bitte erneut versuchen.';
    }
    return e.error.localizedMessage?.trim().isNotEmpty == true
        ? 'Stripe-Fehler: ${e.error.localizedMessage}'
        : 'Stripe-Fehler. Bitte versuche es erneut.';
  }

  Future<PaymentTransaction?> _awaitFinalPaymentState(String transactionId) async {
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
          title: const Text('Zahlung abschließen'),
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
                  child: const Text(
                    'Prüfe deine Angaben und bestätige die Zahlungsart, um dein Event zu veröffentlichen.',
                  ),
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
                        'Bestellübersicht',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (widget.event.visibility == EventVisibility.privateOnly)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'PRIVAT',
                                style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w700),
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
                              child: const Text(
                                'FAMILIENKREIS',
                                style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w700),
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
                                'NUR EINGELADEN (${widget.event.invitedUserIds.length})',
                                style: const TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w700),
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
                              child: const Text(
                                'ÖFFENTLICH',
                                style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Veröffentlichungsgebühr'),
                          Text(
                            '${widget.amount.toStringAsFixed(2)} €',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Zahlungsmethode
                Text(
                  'Zahlungsmethode',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),

                // Stripe Option
                _PaymentMethodOptionTile(
                  title: 'Stripe',
                  subtitle: 'Visa, Mastercard, etc.',
                  icon: Icons.credit_card,
                  selected: _selectedPaymentMethod == 'stripe',
                  enabled: !_isProcessing,
                  onTap: () => setState(() => _selectedPaymentMethod = 'stripe'),
                ),
                const SizedBox(height: 12),

                // PayPal Option
                _PaymentMethodOptionTile(
                  title: 'PayPal',
                  subtitle: 'Bezahl mit deinem PayPal-Konto',
                  icon: Icons.payment,
                  selected: _selectedPaymentMethod == 'paypal',
                  enabled: !_isProcessing,
                  onTap: () => setState(() => _selectedPaymentMethod = 'paypal'),
                ),
                const SizedBox(height: 24),

                // Sicherheits-Hinweis
                const DecoratedBox(
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
                        Icon(Icons.lock, color: Color(0xFF1D4ED8), size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Deine Zahlungsdaten sind sicher verschlüsselt',
                            style: TextStyle(
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
                  title: const Text('AGB & Datenschutz akzeptieren'),
                  subtitle:
                      const Text(
                        'Ich akzeptiere die AGB und Datenschutzhinweise. Zahlungen werden ueber Stripe/PayPal abgewickelt.',
                      ),
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
                            icon: const Icon(Icons.description_outlined, size: 16),
                            label: const Text('AGB ansehen'),
                          ),
                        if (privacyUrl != null && privacyUrl.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => _openLegalUrl(privacyUrl),
                            icon: const Icon(Icons.privacy_tip_outlined, size: 16),
                            label: const Text('Datenschutz ansehen'),
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
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.payment),
                    label: Text(
                      _isProcessing
                          ? 'Wird verarbeitet...'
                          : 'Jetzt ${widget.amount.toStringAsFixed(2)} € zahlen',
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
    final borderColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;

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
