import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/chat_account_store.dart';
import 'package:parentpeak/logic/chat_thread_store.dart';

const Color _kBrand = Color(0xFF8B5CF6);
const Color _kBrand2 = Color(0xFF7C3AED);
const Color _kBg = Color(0xFFF6F3FF);

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

/// Übersicht aller Gespräche der KI-Elternberatung — warm, modern und
/// elternfreundlich: zeitliche Gruppierung (Heute / Diese Woche / Früher),
/// ein passendes Themen-Emoji je Gespräch, weiche Karten. Öffnen, Umbenennen
/// und Löschen möglich.
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
          decoration:
              InputDecoration(hintText: ctx.tr('chat_thread_rename_hint')),
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

  /// Wählt ein passendes Emoji anhand von Titel/Vorschau des Gesprächs, damit
  /// die Liste auf einen Blick erfassbar ist.
  String _emojiFor(ChatThread t) {
    final s = '${t.title} ${t.preview}'.toLowerCase();
    bool has(List<String> words) => words.any(s.contains);
    if (has(['schlaf', 'einschlaf', 'zubett', 'bett', 'nacht', 'müde'])) {
      return '🌙';
    }
    if (has(['streit', 'geschwister', 'schlag', 'haut', 'wut', 'aggress'])) {
      return '🤝';
    }
    if (has(['schule', 'hausaufgab', 'lernen', 'kita', 'lehrer'])) return '🎒';
    if (has(['handy', 'bildschirm', 'medien', 'tablet', 'tv', 'youtube'])) {
      return '📱';
    }
    if (has(['essen', 'ernähr', 'picky', 'gemüse', 'kochen'])) return '🍽️';
    if (has(['angst', 'traurig', 'gefühl', 'weint', 'trauer'])) return '💛';
    if (has(['limit', 'erschöpft', 'überfordert', 'kraft', 'stress'])) {
      return '🫂';
    }
    return '💬';
  }

  /// Gruppiert Threads zeitlich. Reihenfolge der Gruppen bleibt stabil.
  Map<String, List<ChatThread>> _grouped() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groups = <String, List<ChatThread>>{};
    for (final t in _threads) {
      final that =
          DateTime(t.updatedAt.year, t.updatedAt.month, t.updatedAt.day);
      final diff = today.difference(that).inDays;
      final key = diff <= 0
          ? context.tr('date_today')
          : diff == 1
              ? context.tr('date_yesterday')
              : diff <= 7
                  ? context.tr('date_this_week')
                  : context.tr('date_earlier');
      (groups[key] ??= []).add(t);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(context.tr('chat_threads_title'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        foregroundColor: const Color(0xFF1F2937),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_kBg, Color(0xFFFCFBFF)],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildNewButton(context),
                  Expanded(
                    child: _threads.isEmpty
                        ? _buildEmpty(theme)
                        : _buildGroupedList(theme),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildNewButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Material(
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () =>
              Navigator.pop(context, const ChatThreadsResult.startNew()),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kBrand, _kBrand2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _kBrand.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_comment_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  context.tr('chat_new_conversation'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedList(ThemeData theme) {
    final groups = _grouped();
    final children = <Widget>[];
    groups.forEach((label, threads) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ));
      for (final t in threads) {
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: _buildThreadCard(theme, t),
        ));
      }
    });
    return ListView(
        padding: const EdgeInsets.only(bottom: 24), children: children);
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: _kBrand.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('💬', style: TextStyle(fontSize: 34)),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('chat_threads_empty'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
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
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.pop(context, ChatThreadsResult.open(thread)),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive
                  ? _kBrand.withValues(alpha: 0.55)
                  : const Color(0xFFECE8F7),
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _kBrand.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Text(_emojiFor(thread),
                    style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        if (isActive)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kBrand.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              context.tr('chat_thread_active'),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _kBrand,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (thread.preview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        thread.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    color: theme.colorScheme.outline, size: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
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
                      const Icon(Icons.delete_outline_rounded,
                          size: 20, color: Color(0xFFDC2626)),
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
