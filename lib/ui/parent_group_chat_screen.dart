import 'dart:async';

import 'package:flutter/material.dart';
import 'package:parentpeak/logic/friendship_service.dart';
import 'package:parentpeak/logic/parent_group_chat_service.dart';

class ParentGroupChatScreen extends StatefulWidget {
  const ParentGroupChatScreen({super.key});

  @override
  State<ParentGroupChatScreen> createState() => _ParentGroupChatScreenState();
}

class _ParentGroupChatScreenState extends State<ParentGroupChatScreen> {
  final _service = ParentGroupChatService();
  List<ParentChatGroup> _groups = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final groups = await _service.loadGroups();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _loading = false;
    });
  }

  Future<void> _createGroup() async {
    final friends = FriendshipService.instance.friends;
    if (friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verbinde dich zuerst mit Freunden.')),
      );
      return;
    }
    final nameController = TextEditingController();
    final selected = <String>{};
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Neue Elterngruppe',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      )),
              const SizedBox(height: 6),
              Text('Ein privater Raum nur für dich und bestätigte Freunde.',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                maxLength: 80,
                onChanged: (_) => setSheetState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Gruppenname',
                  hintText: 'z. B. Kita-Sonnenschein',
                  prefixIcon: Icon(Icons.auto_awesome_rounded),
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView(
                  shrinkWrap: true,
                  children: friends
                      .map((friend) => CheckboxListTile(
                            value: selected.contains(friend.uid),
                            onChanged: (value) => setSheetState(() {
                              if (value == true) {
                                selected.add(friend.uid);
                              } else {
                                selected.remove(friend.uid);
                              }
                            }),
                            secondary: CircleAvatar(
                              backgroundImage: friend.avatarUrl != null
                                  ? NetworkImage(friend.avatarUrl!)
                                  : null,
                              child: friend.avatarUrl == null
                                  ? Text(friend.name.isNotEmpty
                                      ? friend.name[0].toUpperCase()
                                      : '?')
                                  : null,
                            ),
                            title: Text(friend.name),
                            subtitle: const Text('Bestätigter Freund'),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      selected.isEmpty || nameController.text.trim().isEmpty
                          ? null
                          : () => Navigator.pop(sheetContext, true),
                  icon: const Icon(Icons.add_comment_rounded),
                  label: Text('Gruppe starten (${selected.length})'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != true || !mounted) return;
    final group = await _service.createGroup(
      name: nameController.text,
      memberIds: selected.toList(),
    );
    if (!mounted) return;
    if (group == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gruppe konnte nicht erstellt werden.')),
      );
      return;
    }
    await _loadGroups();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Gruppen'),
        actions: [
          IconButton(
            onPressed: _createGroup,
            tooltip: 'Neue Gruppe',
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadGroups,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _groups.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 60),
                      Icon(Icons.forum_rounded,
                          size: 64, color: theme.colorScheme.primary),
                      const SizedBox(height: 18),
                      Text('Euer kleiner Elternraum',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      const Text(
                        'Erstelle eine private Gruppe für Kita, Nachbarschaft oder Spielplatz.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: _createGroup,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Erste Gruppe erstellen'),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _groups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final group = _groups[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        tileColor: theme.colorScheme.surfaceContainerLow,
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(Icons.forum_rounded,
                              color: theme.colorScheme.primary),
                        ),
                        title: Text(group.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${group.memberCount} Mitglieder'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ParentGroupConversationScreen(
                              group: group,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class ParentGroupConversationScreen extends StatefulWidget {
  const ParentGroupConversationScreen({super.key, required this.group});

  final ParentChatGroup group;

  @override
  State<ParentGroupConversationScreen> createState() =>
      _ParentGroupConversationScreenState();
}

class _ParentGroupConversationScreenState
    extends State<ParentGroupConversationScreen> {
  final _service = ParentGroupChatService();
  final _controller = TextEditingController();
  Timer? _poller;
  List<ParentGroupMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _poller =
        Timer.periodic(const Duration(seconds: 6), (_) => _loadMessages());
  }

  @override
  void dispose() {
    _poller?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final messages = await _service.loadMessages(widget.group.id);
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _loading = false;
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final sent = await _service.sendMessage(
      groupId: widget.group.id,
      content: text,
    );
    if (!mounted) return;
    if (sent != null) {
      _controller.clear();
      await _loadMessages();
    }
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.group.name),
          Text('${widget.group.memberCount} Mitglieder',
              style: theme.textTheme.labelSmall),
        ]),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text('Noch keine Nachricht. Sagt Hallo!'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(message.authorName,
                                      style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 3),
                                  Text(message.content),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Nachricht an eure Gruppe',
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
