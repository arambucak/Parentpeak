import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/treasure_account_store.dart';
import 'package:parentpeak/ui/widgets/treasure_account_boundary.dart';

class TreasureLegacyCard extends StatefulWidget {
  const TreasureLegacyCard({super.key, required this.store, required this.onClaimed});
  final TreasureAccountStore store;
  final Future<void> Function() onClaimed;
  @override
  State<TreasureLegacyCard> createState() => _TreasureLegacyCardState();
}

class _TreasureLegacyCardState extends State<TreasureLegacyCard> {
  late final String _scope = widget.store.scope;
  bool _available = false;
  bool _busy = false;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final available = await widget.store.hasUnassignedLegacy(expectedScope: _scope);
      if (mounted) setState(() => _available = available);
    } catch (error) {
      debugPrint('Treasure legacy load: $error');
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _claim() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => TreasureAccountModal(
        store: widget.store, scope: _scope,
        builder: (_) => AlertDialog(
          title: Text(context.tr('treasure_legacy_title')),
          content: Text(context.tr('treasure_legacy_confirm')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(context.tr('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(context.tr('treasure_legacy_claim'))),
          ],
        ),
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() { _busy = true; _failed = false; });
    try {
      await widget.store.claimLegacy(expectedScope: _scope);
      if (!mounted) return;
      await widget.onClaimed();
      if (mounted) setState(() => _available = false);
    } catch (error) {
      debugPrint('Treasure legacy claim: $error');
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available && !_failed) return const SizedBox.shrink();
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.tr('treasure_legacy_title')),
        Text(context.tr('treasure_legacy_body')),
        if (_failed) Text(context.tr('treasure_storage_failed')),
        if (_available) TextButton(
          onPressed: _busy || widget.store.userId == null ? null : _claim,
          child: Text(context.tr('treasure_legacy_claim')),
        ),
        if (_failed && !_available) TextButton(onPressed: _load, child: Text(context.tr('try_again'))),
      ]),
    ));
  }
}
