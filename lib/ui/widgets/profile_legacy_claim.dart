import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/profile_account_store.dart';

class ProfileLegacyClaim extends StatefulWidget {
  const ProfileLegacyClaim({super.key, required this.domain, this.store});
  final ProfileLegacyDomain domain;
  final ProfileAccountStore? store;

  @override
  State<ProfileLegacyClaim> createState() => _ProfileLegacyClaimState();
}

class _ProfileLegacyClaimState extends State<ProfileLegacyClaim> {
  ProfileAccountStore get _store => widget.store ?? ProfileAccountStore.instance;
  bool _available = false;
  bool _busy = false;
  bool _failed = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _store.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    _store.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    final request = ++_request;
    final ticket = _store.ticket;
    if (mounted) setState(() { _available = false; _busy = false; _failed = false; });
    _load(ticket, request);
  }

  Future<void> _load(ProfileAccountTicket ticket, int request) async {
    try {
      final available = ticket.scope != 'guest' &&
          await _store.hasLegacy(ticket, widget.domain);
      if (mounted && request == _request && _store.isCurrent(ticket)) {
        setState(() => _available = available);
      }
    } on ProfileAccountChanged {
      // The account listener reloads the new session.
    } catch (error) {
      debugPrint('Legacy profile state failed: $error');
      if (mounted && request == _request && _store.isCurrent(ticket)) {
        setState(() => _failed = true);
      }
    }
  }

  Future<void> _claim() async {
    final ticket = _store.ticket;
    setState(() { _busy = true; _failed = false; });
    try {
      await _store.claim(ticket, widget.domain, confirmOwnership: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(ctx.tr('profile_claim_title')),
            content: Text(ctx.tr('profile_claim_explanation')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false),
                  child: Text(ctx.tr('cancel'))),
              FilledButton(onPressed: () => Navigator.pop(ctx, true),
                  child: Text(ctx.tr('profile_claim_confirm'))),
            ],
          ),
        );
        return mounted && _store.isCurrent(ticket) && confirmed == true;
      });
    } on ProfileAccountChanged {
      // Never assign a dialog result to a different session.
    } catch (error) {
      debugPrint('Legacy profile claim failed: $error');
      if (mounted && _store.isCurrent(ticket)) setState(() => _failed = true);
    } finally {
      if (mounted && _store.isCurrent(ticket)) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available && !_failed) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_available) ListTile(
          title: Text(context.tr('profile_legacy_${widget.domain.name}')),
          subtitle: Text(context.tr('profile_legacy_unassigned')),
          trailing: _busy
              ? const CircularProgressIndicator()
              : TextButton(onPressed: _claim,
                  child: Text(context.tr('profile_claim_confirm'))),
        ),
        if (_failed) Text(context.tr('profile_account_failed'),
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
    );
  }
}
