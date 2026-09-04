import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/admin_moderation_service.dart';

/// Schlankes Moderations-Dashboard fuer Admins.
/// Sichtbarkeit wird vom Aufrufer (Admin-UID) gesteuert; die echte
/// Absicherung passiert serverseitig (ADMIN_USER_IDS auf Render).
class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen> {
  final _service = AdminModerationService();
  bool _loading = true;
  String? _error;
  AdminReportsResult _data = const AdminReportsResult(groups: [], reports: []);
  String _status = 'pending';
  bool _cleaning = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.fetchReports(status: _status);
      if (!mounted) return;
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().contains('403')
          ? context.tr('admin_no_access')
          : context.tr('admin_load_failed');
      });
    }
  }

  List<ReportDetail> _reportsFor(String userId) =>
      _data.reports.where((r) => r.reportedUserId == userId).toList();

  Future<void> _confirmSuspend(ReportGroup g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('admin_suspend_title')),
        content: Text(context.tr('admin_suspend_message',
          values: {'userId': g.reportedUserId})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              child: Text(context.tr('admin_suspend_action'))),
        ],
      ),
    );
    if (ok != true) return;
    final success = await _service.suspendUser(g.reportedUserId,
        reason: 'Moderation: ${g.lastReason}');
    _afterAction(success,
      context.tr(success ? 'admin_suspended' : 'admin_suspend_failed'));
  }

  Future<void> _unsuspend(ReportGroup g) async {
    final success = await _service.unsuspendUser(g.reportedUserId);
    _afterAction(success,
      context.tr(success ? 'admin_unsuspended' : 'admin_action_failed'));
  }

  Future<void> _ignore(ReportGroup g) async {
    final success = await _service.resolveReportsForUser(g.reportedUserId);
    _afterAction(success,
      context.tr(success ? 'admin_reports_resolved' : 'admin_action_failed'));
  }

  void _afterAction(bool success, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: success ? const Color(0xFF16A34A) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
    if (success) _load();
  }

  /// Datenbank aufräumen: erst Vorschau (brokenCount), dann Bestätigung, dann
  /// löschen. Nur kaputte Freundschafts-Kanten; echte Daten bleiben.
  Future<void> _startCleanup() async {
    setState(() => _cleaning = true);
    final messenger = ScaffoldMessenger.of(context);
    final count = await _service.cleanupPreview();
    if (!mounted) return;

    if (count < 0) {
      setState(() => _cleaning = false);
      messenger.showSnackBar(SnackBar(
        content: Text(context.tr('admin_cleanup_preview_failed')),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (count == 0) {
      setState(() => _cleaning = false);
      messenger.showSnackBar(SnackBar(
        content: Text(context.tr('admin_cleanup_empty')),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF16A34A),
      ));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.cleaning_services_rounded, size: 32),
        title: Text(context.tr('admin_cleanup_title')),
        content: Text(context.tr('admin_cleanup_message',
          values: {'count': count})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
                child: Text(context.tr('admin_remove_count',
                  values: {'count': count}))),
        ],
      ),
    );
    if (confirm != true) {
      if (mounted) setState(() => _cleaning = false);
      return;
    }

    final deleted = await _service.runCleanup();
    if (!mounted) return;
    setState(() => _cleaning = false);
    messenger.showSnackBar(SnackBar(
        content: Text(deleted >= 0
          ? context.tr('admin_cleanup_success', values: {'count': deleted})
          : context.tr('admin_cleanup_failed')),
      behavior: SnackBarBehavior.floating,
      backgroundColor: deleted >= 0 ? const Color(0xFF16A34A) : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('admin_title')),
        actions: [
          IconButton(
            tooltip: context.tr('admin_cleanup_tooltip'),
            icon: const Icon(Icons.cleaning_services_rounded),
            onPressed: _cleaning ? null : _startCleanup,
          ),
          PopupMenuButton<String>(
            initialValue: _status,
            onSelected: (v) {
              setState(() => _status = v);
              _load();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'pending',
                child: Text(context.tr('admin_filter_open'))),
              PopupMenuItem(
                value: 'resolved',
                child: Text(context.tr('admin_filter_done'))),
              PopupMenuItem(
                value: 'all', child: Text(context.tr('admin_filter_all'))),
            ],
            icon: const Icon(Icons.filter_list_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.lock_outline_rounded,
              size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_error!,
                textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          ),
        ],
      );
    }
    if (_data.groups.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          const Center(child: Text('🎉', style: TextStyle(fontSize: 44))),
          const SizedBox(height: 16),
          Center(
            child: Text(context.tr('admin_no_reports'),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(context.tr('admin_community_safe'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _data.groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _groupCard(theme, _data.groups[i]),
    );
  }

  Widget _groupCard(ThemeData theme, ReportGroup g) {
    final details = _reportsFor(g.reportedUserId);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text(context.tr('admin_reported_count',
              values: {'count': g.reportCount}),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.error)),
          ),
          const SizedBox(width: 8),
          if (g.suspended)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(context.tr('admin_locked'),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          const Spacer(),
          if (g.lastReportedAt != null)
            Text(_formatDate(g.lastReportedAt!),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline)),
        ]),
        const SizedBox(height: 10),
        Text(context.tr('admin_user_id', values: {'userId': g.reportedUserId}),
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(context.tr('admin_last_reason',
          values: {'reason': _reasonLabel(g.lastReason)}),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        if (details.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...details.take(3).map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                    '• ${_reasonLabel(d.reason)}'
                    '${d.content.isNotEmpty ? ' – "${d.content}"' : ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              )),
        ],
        const Divider(height: 24),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _ignore(g),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: Text(context.tr('admin_ignore')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: g.suspended
                ? OutlinedButton.icon(
                    onPressed: () => _unsuspend(g),
                    icon: const Icon(Icons.lock_open_rounded, size: 16),
                    label: Text(context.tr('admin_unlock')),
                  )
                : FilledButton.icon(
                    onPressed: () => _confirmSuspend(g),
                    icon: const Icon(Icons.block_rounded, size: 16),
                    label: Text(context.tr('admin_suspend_action')),
                    style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error),
                  ),
          ),
        ]),
      ]),
    );
  }

  String _reasonLabel(String key) {
    switch (key) {
      case 'insult':
        return context.tr('admin_reason_insult');
      case 'spam':
        return context.tr('admin_reason_spam');
      case 'inappropriate':
        return context.tr('admin_reason_inappropriate');
      case 'fraud':
        return context.tr('admin_reason_fraud');
      default:
        return key.isEmpty ? context.tr('admin_reason_other') : key;
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
