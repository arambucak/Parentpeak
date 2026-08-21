import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';
import 'package:flutter/material.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/family_circle_service.dart';
import 'package:parentpeak/models/family_contact.dart';

String _t(String key) =>
    AppStringsManager.getString(languageService.currentLanguage, key);


class FamilyCircleScreen extends StatefulWidget {
  const FamilyCircleScreen({super.key});

  @override
  State<FamilyCircleScreen> createState() => _FamilyCircleScreenState();
}

class _FamilyCircleScreenState extends State<FamilyCircleScreen> {
  final _service = FamilyCircleService.instance;


  List<FamilyContact> _contacts = [];
  List<FamilyConnectionRequest> _requests = [];
  bool _isLoading = true;
  String? _errorMessage;

  String? get _currentUserId => AuthService.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _contacts = [];
        _requests = [];
        _errorMessage =
            'Bitte melde dich an, um deinen Familienkreis zu sehen.';
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    final contacts = await _service.getConnectedContacts(userId: currentUserId);
    final requests = await _service.getIncomingRequests(userId: currentUserId);
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _requests = requests;
      _errorMessage = null;
      _isLoading = false;
    });
  }

  Future<void> _respond(FamilyConnectionRequest request, bool accept) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.trim().isEmpty) return;
    try {
      await _service.respondToRequest(
        requestId: request.id,
        accept: accept,
        actingUserId: currentUserId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Anfrage konnte nicht synchronisiert werden: $e')),
      );
      return;
    }
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            accept ? 'Kontaktanfrage angenommen' : 'Kontaktanfrage abgelehnt'),
      ),
    );
  }

  Future<void> _sendNewRequest() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.trim().isEmpty) return;
    final controller = TextEditingController();
    final targetUserId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('circle_invite_contact')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'User-ID des Kontakts',
            hintText: 'z. B. user_abc123',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(_t('circle_send_request')),
          ),
        ],
      ),
    );

    if (targetUserId == null || targetUserId.isEmpty) return;
    if (targetUserId == currentUserId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Du kannst keine Anfrage an dich selbst senden.')),
      );
      return;
    }

    try {
      await _service.sendRequest(
        fromUserId: currentUserId,
        toUserId: targetUserId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Anfrage konnte nicht gesendet werden: $e')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Anfrage an $targetUserId gesendet')),
    );
    await _load();
  }

  Future<void> _deleteContact(FamilyContact contact) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.trim().isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('circle_remove_contact')),
        content: Text(
            'Möchtest du ${contact.displayName} aus deinem Kreis entfernen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_t('circle_remove')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteConnectionWithUser(
        currentUserId: currentUserId,
        otherUserId: contact.userId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kontakt konnte nicht entfernt werden: $e')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${contact.displayName} entfernt')),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('circle_title')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sendNewRequest,
        icon: const Icon(Icons.person_add_rounded),
        label: Text(_t('circle_invite')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dein vertrauensvoller Kreis',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Teile private Events gezielt mit deinen Kontakten und bearbeite Anfragen in einem ruhigen Flow.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _InfoPill(
                                    icon: Icons.people_alt_rounded,
                                    label: 'Kontakte',
                                    value: _contacts.length.toString(),
                                    color: const Color(0xFF2563EB),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _InfoPill(
                                    icon: Icons.mark_email_unread_rounded,
                                    label: 'Offene Anfragen',
                                    value: _requests.length.toString(),
                                    color: const Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SectionHeader(
                        title: 'Kontaktanfragen',
                        subtitle: _requests.isEmpty
                            ? 'Keine offenen Anfragen'
                            : '${_requests.length} offen',
                      ),
                      const SizedBox(height: 10),
                      if (_requests.isEmpty)
                        const _EmptyStateTile(
                          icon: Icons.inbox_rounded,
                          text: 'Aktuell keine offenen Anfragen.',
                        )
                      else
                        ..._requests.map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _RequestRow(
                              request: r,
                              onAccept: () => _respond(r, true),
                              onDecline: () => _respond(r, false),
                            ),
                          ),
                        ),
                      const SizedBox(height: 18),
                      _SectionHeader(
                        title: 'Deine Kontakte',
                        subtitle: _contacts.isEmpty
                            ? 'Noch keine Kontakte verbunden'
                            : '${_contacts.length} verbunden',
                      ),
                      const SizedBox(height: 10),
                      if (_contacts.isEmpty)
                        const _EmptyStateTile(
                          icon: Icons.people_outline_rounded,
                          text: 'Noch keine Kontakte verbunden.',
                        )
                      else
                        ..._contacts.map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ContactRow(
                              contact: c,
                              onDelete: () => _deleteContact(c),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final FamilyConnectionRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 16,
                child: Icon(Icons.person_add_alt_1_rounded, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  request.fromDisplayName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  child: Text(_t('circle_decline')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onAccept,
                  child: Text(_t('circle_accept')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, required this.onDelete});

  final FamilyContact contact;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            child: Icon(Icons.people_alt_rounded, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.displayName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${contact.city} • ${contact.childrenSummary}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Kontakt entfernen',
            onPressed: onDelete,
            icon: const Icon(Icons.person_remove_rounded),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateTile extends StatelessWidget {
  const _EmptyStateTile({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
