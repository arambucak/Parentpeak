import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/chat_account_store.dart';
import 'package:parentpeak/logic/chat_thread_store.dart';

const Color _kBrand = Color(0xFF8B5CF6);

/// Ergebnis der Übersicht: entweder "neues Gespräch starten" oder ein
/// bestehendes Gespräch öffnen.
class ChatThreadsResult {
  const ChatThreadsResult.startNew()
      : startNew = true,
        openThread = null;
  const ChatThreadsResult.open(this.openThread) : startNew = false;

  final bool startNew;
  final ChatThread? openThread;
}

/// Übersicht aller Gespräche der KI-Elternberatung: Liste mit Titel, Datum und
/// Vorschau, plus "Neues Gespräch". Öffnen, Umbenennen und Löschen möglich.
class ChatThreadsScreen extends StatefulWidget {
  const ChatThreadsScreen({
    super.key,
    required this.threadStore,
    required this.accountStore,
    this.activeThreadId,
  });

  final ChatThreadStore threadStore;
  final ChatAccountStore accountStore;
  final String? activeThreadId;

  @override
  State<ChatThreadsScreen> createState() => _ChatThreadsScreenState();
}

class _ChatThreadsScreenState extends State<ChatThreadsScreen> {
  List<ChatThread> _threads = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final threads =
          await widget.threadStore.loadThreads(widget.accountStore.ticket);
      if (!mounted) return;
      setState(() {
        _threads = threads;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _threads = [];
        _loading = false;
      });
    }
  }

  Future<void> _delete(ChatThread thread) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('chat_thread_delete_title')),
        content: Text(ctx.tr('chat_thread_delete_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.threadStore
          .deleteThread(widget.accountStore.ticket, thread.id);
    } catch (_) {}
    await _load();
  }

  Future<void> _rename(ChatThread thread) async {
    final controller = TextEditingController(text: thread.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('chat_thread_rename_title')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: InputDecoration(hintText: ctx.tr('chat_thread_rename_hint')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(ctx.tr('save_btn')),
          ),
        ],
      ),
    );
    if (newTitle == null || newTitle.isEmpty) return;
    try {
      await widget.threadStore.upsertThread(
        widget.accountStore.ticket,
        thread.copyWith(title: newTitle, updatedAt: DateTime.now()),
      );
    } catch (_) {}
    await _load();
  }

  String _dateLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return context.tr('date_today');
    if (diff == 1) return context.tr('date_yesterday');
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('chat_threads_title')),
        foregroundColor: _kBrand,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(
                          context, const ChatThreadsResult.startNew()),
                      icon: const Icon(Icons.add_comment_outlined),
                      label: Text(context.tr('chat_new_conversation')),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kBrand,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _threads.isEmpty
                      ? _buildEmpty(theme)
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _threads.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) =>
                              _buildThreadCard(theme, _threads[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💬', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              context.tr('chat_threads_empty'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThreadCard(ThemeData theme, ChatThread thread) {
    final isActive = thread.id == widget.activeThreadId;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            Navigator.pop(context, ChatThreadsResult.open(thread)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? _kBrand.withValues(alpha: 0.5)
                  : theme.dividerColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      thread.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    if (thread.preview.isNotEmpty)
                      Text(
                        thread.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      _dateLabel(thread.updatedAt),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    color: theme.colorScheme.outline),
                onSelected: (v) {
                  if (v == 'rename') _rename(thread);
                  if (v == 'delete') _delete(thread);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Row(children: [
                      const Icon(Icons.edit_outlined, size: 20),
                      const SizedBox(width: 10),
                      Text(context.tr('rename')),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      const Icon(Icons.delete_outline_rounded, size: 20),
                      const SizedBox(width: 10),
                      Text(context.tr('delete')),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
