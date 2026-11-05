import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/app_localizations.dart';

class RevokeConfirmationDialog extends StatefulWidget {
  final String deviceName;

  const RevokeConfirmationDialog({super.key, required this.deviceName});

  @override
  State<RevokeConfirmationDialog> createState() => _RevokeConfirmationDialogState();
}

class _RevokeConfirmationDialogState extends State<RevokeConfirmationDialog> {
  final _controller = TextEditingController();
  bool _isConfirmed = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _checkInput(String input) {
    setState(() {
      _isConfirmed = input.trim() == widget.deviceName;
      _errorText = _isConfirmed ? null : 'Der eingegebene Name stimmt nicht überein.';
    });
  }

  void _onSubmitted(String _) {
    if (_isConfirmed) _confirm();
  }

  void _confirm() {
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final errorText = _errorText;
    return AlertDialog(
      title: Text(AppLocalizations.of(context).removeDeviceDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppLocalizations.of(context).removeDeviceDialogMessage(widget.deviceName)),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: _checkInput,
            onSubmitted: _onSubmitted,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).deviceNameLabel,
              helperText: AppLocalizations.of(context).deviceNameHelper,
              errorText: errorText,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(AppLocalizations.of(context).cancel)),
        ElevatedButton(
          key: const Key('confirm-revoke'),
          onPressed: _isConfirmed ? _confirm : null,
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          child: Text(AppLocalizations.of(context).removeDevice),
        ),
      ],
    );
  }
}
