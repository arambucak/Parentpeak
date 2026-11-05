import 'dart:async';

import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/profile_account_store.dart';
import 'package:parentpeak/services/feature_quota_service.dart';

Future<void> showFeatureQuotaNotice(
        BuildContext context, QuotaFeature feature) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FeatureQuotaNotice(feature: feature),
        ),
      ),
    );

class FeatureQuotaNotice extends StatelessWidget {
  const FeatureQuotaNotice({super.key, required this.feature});
  final QuotaFeature feature;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite_outline,
              size: 40, color: Color(0xFF8B5CF6)),
          const SizedBox(height: 16),
          Text(context.tr('quota_title'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(context.tr('quota_${feature.name}'),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(context.tr('quota_free_stays'), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(context.tr('quota_premium')),
                content: Text(context.tr('quota_premium_info')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.tr('quota_close'))),
                ],
              ),
            ),
            child: Text(context.tr('quota_premium')),
          ),
        ],
      );
}

class FeatureQuotaGate extends StatefulWidget {
  const FeatureQuotaGate(
      {super.key,
      required this.feature,
      required this.child,
      this.eventKey,
      this.service,
      this.embedded = false});
  final QuotaFeature feature;
  final String? eventKey;
  final Widget child;
  final FeatureQuotaService? service;
  final bool embedded;

  @override
  State<FeatureQuotaGate> createState() => _FeatureQuotaGateState();
}

class _FeatureQuotaGateState extends State<FeatureQuotaGate> {
  late Future<void> _access;
  bool _reloadScheduled = false;

  @override
  void initState() {
    super.initState();
    _access = Future<void>(_check);
    ProfileAccountStore.instance.addListener(_reload);
  }

  Future<void> _check() {
    final service = widget.service ?? FeatureQuotaService.instance;
    return widget.feature == QuotaFeature.events
        ? service.viewEvent(widget.eventKey!)
        : service.financeAccess();
  }

  void _reload() {
    if (!mounted || _reloadScheduled) return;
    _reloadScheduled = true;
    scheduleMicrotask(() {
      _reloadScheduled = false;
      if (mounted) {
        setState(() {
          _access = Future<void>(_check);
        });
      }
    });
  }

  @override
  void didUpdateWidget(FeatureQuotaGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.eventKey != oldWidget.eventKey ||
        widget.feature != oldWidget.feature) {
      _access = Future<void>(_check);
    }
  }

  @override
  void dispose() {
    ProfileAccountStore.instance.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: _access,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            if (widget.embedded) {
              return const Center(child: CircularProgressIndicator());
            }
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (!snapshot.hasError) return widget.child;
          final error = snapshot.error;
          if (widget.embedded) {
            return Padding(
                padding: const EdgeInsets.all(16),
                child: error is FeatureQuotaException
                    ? FeatureQuotaNotice(feature: widget.feature)
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(context.tr('quota_access_failed')),
                        TextButton(
                            onPressed: _reload,
                            child: Text(context.tr('quota_retry'))),
                      ]));
          }
          return Scaffold(
            appBar: AppBar(),
            body: Center(
                child: Padding(
              padding: const EdgeInsets.all(24),
              child: error is FeatureQuotaException
                  ? FeatureQuotaNotice(feature: widget.feature)
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(context.tr('quota_access_failed'),
                          textAlign: TextAlign.center),
                      TextButton(
                          onPressed: _reload,
                          child: Text(context.tr('quota_retry'))),
                    ]),
            )),
          );
        },
      );
}
