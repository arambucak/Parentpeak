import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/treasure_account_store.dart';

class TreasureAccountBoundary extends StatelessWidget {
  const TreasureAccountBoundary({
    super.key,
    required this.store,
    required this.builder,
  });
  final TreasureAccountStore store;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AuthService.instance,
    builder: (context, _) => KeyedSubtree(
      key: ValueKey(store.scope),
      child: Builder(builder: builder),
    ),
  );
}

class TreasureAccountModal extends StatefulWidget {
  const TreasureAccountModal({
    super.key,
    required this.store,
    required this.scope,
    required this.builder,
  });
  final TreasureAccountStore store;
  final String scope;
  final WidgetBuilder builder;

  @override
  State<TreasureAccountModal> createState() => _TreasureAccountModalState();
}

class _TreasureAccountModalState extends State<TreasureAccountModal> {
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_accountChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _accountChanged();
    });
  }

  void _accountChanged() {
    if (_changed || widget.store.scope == widget.scope) return;
    setState(() => _changed = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && route.isActive) Navigator.of(context).removeRoute(route);
    });
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_accountChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_changed && widget.store.scope == widget.scope) {
      return widget.builder(context);
    }
    return Material(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(context.tr('treasure_account_changed')),
    ));
  }
}
