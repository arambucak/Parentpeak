import 'package:flutter/material.dart';
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
            ? 'Kein Admin-Zugriff. Bitte mit einem Admin-Konto anmelden.'
            : 'Konnte Meldungen nicht laden. Bitte später erneut versuchen.';
      });
    }
  }

  List<ReportDetail> _reportsFor(String userId) =>
      _data.reports.where((r) => r.reportedUserId == userId).toList();

  Future<void> _confirmSuspend(ReportGroup g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Account sperren?'),
        content: Text(
            'Der Account wird aus dem Netzwerk und der Discovery ausgeblendet. '
            'Die Sperre ist umkehrbar – es werden keine Daten gelöscht.\n\n'
            'User-ID: ${g.reportedUserId}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Sperren')),
        ],
      ),
    );
    if (ok != true) return;
    final success = await _service.suspendUser(g.reportedUserId,
        reason: 'Moderation: ${g.lastReason}');
    _afterAction(
        success, success ? 'Account gesperrt.' : 'Sperren fehlgeschlagen.');
  }

  Future<void> _unsuspend(ReportGroup g) async {
    final success = await _service.unsuspendUser(g.reportedUserId);
    _afterAction(
        success, success ? 'Sperre aufgehoben.' : 'Aktion fehlgeschlagen.');
  }

  Future<void> _ignore(ReportGroup g) async {
    final success = await _service.resolveReportsForUser(g.reportedUserId);
    _afterAction(success,
        success ? 'Meldungen als geprüft markiert.' : 'Aktion fehlgeschlagen.');
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
      messenger.showSnackBar(const SnackBar(
        content:
            Text('Vorschau fehlgeschlagen. Bitte später erneut versuchen.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (count == 0) {
      setState(() => _cleaning = false);
      messenger.showSnackBar(const SnackBar(
        content: Text('Alles sauber – keine kaputten Einträge gefunden. 🎉'),
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
        title: const Text('Datenbank aufräumen?'),
        content: Text('Es wurden $count kaputte Verbindungs-Einträge gefunden '
            '(fehlerhafte oder verwaiste Codes). Diese werden entfernt.\n\n'
            'Echte Nutzer, Namen und Chats bleiben unberührt.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('$count entfernen')),
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
          ? '$deleted Einträge bereinigt. Datenbank ist sauber. ✅'
          : 'Aufräumen fehlgeschlagen. Bitte später erneut versuchen.'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: deleted >= 0 ? const Color(0xFF16A34A) : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderation'),
        actions: [
          IconButton(
            tooltip: 'Datenbank aufräumen',
            icon: const Icon(Icons.cleaning_services_rounded),
            onPressed: _cleaning ? null : _startCleanup,
          ),
          PopupMenuButton<String>(
            initialValue: _status,
            onSelected: (v) {
              setState(() => _status = v);
              _load();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pending', child: Text('Offen')),
              PopupMenuItem(value: 'resolved', child: Text('Erledigt')),
              PopupMenuItem(value: 'all', child: Text('Alle')),
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
            child: Text('Keine offenen Meldungen',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('Alles ruhig. Deine Community ist sicher.',
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
            child: Text('${g.reportCount}× gemeldet',
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
              child: const Text('gesperrt',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          const Spacer(),
          if (g.lastReportedAt != null)
            Text(_formatDate(g.lastReportedAt!),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline)),
        ]),
        const SizedBox(height: 10),
        Text('User: ${g.reportedUserId}',
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Letzter Grund: ${_reasonLabel(g.lastReason)}',
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
              label: const Text('Ignorieren'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: g.suspended
                ? OutlinedButton.icon(
                    onPressed: () => _unsuspend(g),
                    icon: const Icon(Icons.lock_open_rounded, size: 16),
                    label: const Text('Entsperren'),
                  )
                : FilledButton.icon(
                    onPressed: () => _confirmSuspend(g),
                    icon: const Icon(Icons.block_rounded, size: 16),
                    label: const Text('Sperren'),
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
        return 'Beleidigung / Hassrede';
      case 'spam':
        return 'Spam / Werbung';
      case 'inappropriate':
        return 'Unangemessene Inhalte';
      case 'fraud':
        return 'Betrug / Fake';
      default:
        return key.isEmpty ? 'Sonstiges' : key;
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
