import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/moments_service.dart';
import 'package:parentpeak/models/moment.dart';
import 'package:parentpeak/ui/widgets/network/family_avatar.dart';

/// Bottom-Sheet mit den Kommentaren eines Moments: laden, anzeigen, schreiben,
/// löschen (eigene Kommentare oder – als Moment-Autor – fremde auf dem eigenen
/// Moment). Meldet die geänderte Kommentarzahl über [onCountChanged] zurück.
class MomentCommentsSheet extends StatefulWidget {
  const MomentCommentsSheet({
    super.key,
    required this.moment,
    required this.onCountChanged,
    this.service,
  });

  final Moment moment;
  final ValueChanged<int> onCountChanged;
  final MomentsService? service;

  static Future<void> show(
    BuildContext context, {
    required Moment moment,
    required ValueChanged<int> onCountChanged,
    MomentsService? service,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MomentCommentsSheet(
        moment: moment,
        onCountChanged: onCountChanged,
        service: service,
      ),
    );
  }

  @override
  State<MomentCommentsSheet> createState() => _MomentCommentsSheetState();
}

class _MomentCommentsSheetState extends State<MomentCommentsSheet> {
  late final _service = widget.service ?? MomentsService.instance;
  final _inputCtrl = TextEditingController();

  bool _loading = true;
  bool _sending = false;
  List<MomentComment> _comments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await _service.loadComments(widget.moment.id);
    if (!mounted) return;
    setState(() {
      _comments = list;
      _loading = false;
    });
    widget.onCountChanged(list.length);
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final c = await _service.addComment(widget.moment.id, text);
      if (!mounted) return;
      if (c != null) {
        _inputCtrl.clear();
        setState(() {
          _comments = [..._comments, c];
          _sending = false;
        });
        widget.onCountChanged(_comments.length);
      } else {
        setState(() => _sending = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(
        content: Text(context.tr('moments_comment_failed')),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _delete(MomentComment c) async {
    final ok = await _service.deleteComment(widget.moment.id, c.id);
    if (!mounted || !ok) return;
    setState(() => _comments = _comments.where((x) => x.id != c.id).toList());
    widget.onCountChanged(_comments.length);
  }

  bool _canDelete(MomentComment c) => c.isMine || widget.moment.isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              context.tr('moments_comments_title'),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Flexible(child: _body(theme)),
            const Divider(height: 20),
            _input(theme),
          ],
        ),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Text(
          context.tr('moments_comments_empty'),
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: _comments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _commentTile(theme, _comments[i]),
    );
  }

  Widget _commentTile(ThemeData theme, MomentComment c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FamilyAvatar(name: c.authorName, size: FamilyAvatarSize.s),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.authorName,
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(c.text, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        if (_canDelete(c))
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _delete(c),
            child: Icon(Icons.delete_outline_rounded,
                size: 18, color: theme.colorScheme.outline),
          ),
      ],
    );
  }

  Widget _input(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _inputCtrl,
            minLines: 1,
            maxLines: 4,
            maxLength: 1000,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(
              hintText: context.tr('moments_comment_hint'),
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _sending ? null : _send,
          icon: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded, size: 18),
        ),
      ],
    );
  }
}
