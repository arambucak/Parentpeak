import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/chat_account_store.dart';

class ChatAccountModal extends StatefulWidget {
  const ChatAccountModal({
    super.key,
    required this.store,
    required this.ticket,
    required this.builder,
    this.clearPrivateInputs,
  });
  final ChatAccountStore store;
  final ChatAccountTicket ticket;
  final WidgetBuilder builder;
  final VoidCallback? clearPrivateInputs;

  @override
  State<ChatAccountModal> createState() => _ChatAccountModalState();
}

class _ChatAccountModalState extends State<ChatAccountModal> {
  bool _changed = false;
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_check);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _check();
  }

  void _check() {
    try {
      widget.store.require(widget.ticket);
    } on ChatAccountChanged {
      if (_changed) return;
      widget.clearPrivateInputs?.call();
      setState(() => _changed = true);
      final route = ModalRoute.of(context);
      final navigator = Navigator.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route != null && route.isActive && navigator.mounted) {
          navigator.removeRoute(route);
        }
      });
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _changed
      ? SafeArea(child: Text(context.tr('family_hub_account_changed')))
      : widget.builder(context);
}
