import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/ads_consent_service.dart';

class AdsConsentScreen extends StatefulWidget {
  const AdsConsentScreen({super.key, this.service});

  final AdsConsentService? service;

  @override
  State<AdsConsentScreen> createState() => _AdsConsentScreenState();
}

class _AdsConsentScreenState extends State<AdsConsentScreen>
    with WidgetsBindingObserver {
  late final _service = widget.service ?? AdsConsentService.instance;
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service.addListener(_changed);
    _run(_service.refresh);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) {
      _run(_service.refresh);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _grant() async {
    final revision = _service.snapshot.revision;
    final accountGeneration = _service.accountGeneration;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AnimatedBuilder(
        animation: _service,
        builder: (context, _) {
          final current = _service.snapshot;
          final unchanged = current.state == AdsConsentState.verified &&
              _service.accountGeneration == accountGeneration &&
              current.revision == revision;
          return AlertDialog(
            scrollable: true,
            title: Text(context.tr('ads_consent_title')),
            content: Text(context.tr('ads_consent_body')),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.tr('ads_consent_deny')),
              ),
              OutlinedButton(
                onPressed:
                    unchanged ? () => Navigator.pop(context, true) : null,
                child: Text(context.tr('ads_consent_grant')),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted || accepted == null) return;
    if (_service.accountGeneration != accountGeneration ||
        (accepted && _service.snapshot.revision != revision)) {
      setState(() => _failed = true);
      return;
    }
    await _run(() => _service.decide(
        accepted ? AdsConsentDecision.granted : AdsConsentDecision.denied));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _service.snapshot;
    final status = snapshot.state == AdsConsentState.verified
        ? 'ads_consent_status_${snapshot.decision.name}'
        : 'ads_consent_status_unavailable';
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('ads_consent_title'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(context.tr('ads_consent_body')),
          const SizedBox(height: 16),
          Text(context.tr(status), key: const Key('ads-consent-status')),
          Text(context.tr('ads_consent_version', values: {
            'version': snapshot.version ?? AdsConsentService.version,
          })),
          const SizedBox(height: 16),
          Text(context.tr('ads_consent_legal_draft')),
          if (_busy) const LinearProgressIndicator(),
          if (_failed) ...[
            const SizedBox(height: 12),
            Text(context.tr('ads_consent_failed')),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton(
                key: const Key('ads-consent-deny'),
                onPressed: _busy
                    ? null
                    : () =>
                        _run(() => _service.decide(AdsConsentDecision.denied)),
                child: Text(context.tr(snapshot.isGranted
                    ? 'ads_consent_revoke'
                    : 'ads_consent_deny')),
              ),
              OutlinedButton(
                key: const Key('ads-consent-grant'),
                onPressed: !_busy &&
                        snapshot.state == AdsConsentState.verified &&
                        !snapshot.isGranted
                    ? _grant
                    : null,
                child: Text(context.tr('ads_consent_grant')),
              ),
              TextButton(
                onPressed: _busy ? null : () => _run(_service.refresh),
                child: Text(context.tr('retry')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
