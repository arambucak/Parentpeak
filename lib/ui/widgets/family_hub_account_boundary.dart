import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/family_hub_store.dart';

/// Recreates consumers so locally copied dossiers/recipes cannot survive logout.
class FamilyHubAccountBoundary extends StatefulWidget {
  const FamilyHubAccountBoundary({super.key, required this.builder});
  final WidgetBuilder builder;

  @override
  State<FamilyHubAccountBoundary> createState() => _FamilyHubAccountBoundaryState();
}

class _FamilyHubAccountBoundaryState extends State<FamilyHubAccountBoundary> {
  String _scope = FamilyHubStore.instance.scope;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_accountChanged);
  }

  void _accountChanged() {
    final scope = FamilyHubStore.instance.scope;
    if (scope == _scope) return;
    setState(() {
      _scope = scope;
      _revision++;
    });
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_accountChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(
        key: ValueKey(_revision),
        child: Builder(builder: widget.builder),
      );
}

/// Modal routes outlive their opener. Hide their previous account's fields too.
class FamilyHubAccountModal extends StatelessWidget {
  const FamilyHubAccountModal({
    super.key,
    required this.expectedScope,
    required this.builder,
  });
  final String expectedScope;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: AuthService.instance,
        builder: (context, _) => FamilyHubStore.instance.scope == expectedScope
            ? builder(context)
            : Material(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(context.tr('family_hub_account_changed')),
                ),
              ),
      );
}
