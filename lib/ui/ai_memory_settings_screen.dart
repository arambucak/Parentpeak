import 'package:flutter/material.dart';
import 'package:parentpeak/logic/ai_memory_service.dart';
import 'package:parentpeak/logic/chat_account_store.dart';
import 'package:parentpeak/ui/widgets/chat_account_modal.dart';
import 'package:parentpeak/models/ai_memory.dart';

class AiMemorySettingsScreen extends StatefulWidget {
  const AiMemorySettingsScreen({super.key, this.service});

  final AiMemoryService? service;

  @override
  State<AiMemorySettingsScreen> createState() => _AiMemorySettingsScreenState();
}

class _AiMemorySettingsScreenState extends State<AiMemorySettingsScreen> {
  late final AiMemoryService _service;
  bool _loading = true;
  bool _enabled = false;
  List<AiChildProfile> _children = const [];
  String? _error;
  late final ChatAccountStore _store;
  late ChatAccountTicket _ticket;
  final List<TextEditingController> _privateControllers = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AiMemoryService();
    _store = _service.accountStore;
    _ticket = _store.ticket;
    _store.addListener(_accountChanged);
    _load();
  }

  bool _current(ChatAccountTicket ticket) {
    if (!mounted) return false;
    try {
      _store.require(ticket);
      return true;
    } on ChatAccountChanged {
      return false;
    }
  }

  void _accountChanged() {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
    for (final controller in _privateControllers) {
      controller.clear();
    }
    setState(() {
      _ticket = _store.ticket;
      _children = const [];
      _enabled = false;
      _error = null;
      _loading = true;
      _saving = false;
    });
    _load();
  }

  @override
  void dispose() {
    _store.removeListener(_accountChanged);
    for (final controller in _privateControllers) {
      controller.clear();
    }
    _children = const [];
    super.dispose();
  }

  Future<void> _load() async {
    final ticket = _ticket;
    try {
      final settings = await _service.getSettings();
      if (!_current(ticket)) return;
      final children = await _service.getChildren();
      if (!_current(ticket)) return;
      setState(() {
        _enabled = settings.enabled;
        _children = children;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!_current(ticket)) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    final ticket = _ticket;
    setState(() => _saving = true);
    try {
      final settings = await _service.setEnabled(value);
      if (_current(ticket)) setState(() => _enabled = settings.enabled);
    } catch (error) {
      if (!_current(ticket)) return;
      _showMessage('$error');
    } finally {
      if (_current(ticket)) setState(() => _saving = false);
    }
  }

  Future<void> _editChild([AiChildProfile? child]) async {
    final ticket = _ticket;
    final nameController = TextEditingController(text: child?.name ?? '');
    final genderController = TextEditingController(text: child?.gender ?? '');
    _privateControllers.addAll([nameController, genderController]);
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ChatAccountModal(
        store: _store,
        ticket: ticket,
        clearPrivateInputs: () {
          nameController.clear();
          genderController.clear();
        },
        builder: (context) => AlertDialog(
          title: Text(
            child == null ? 'Kind hinzufügen' : 'Kinderprofil bearbeiten',
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Bitte einen Namen eingeben.'
                      : null,
                ),
                TextField(
                  controller: genderController,
                  decoration: const InputDecoration(
                    labelText: 'Geschlecht (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () async {
                if (!_current(ticket)) return;
                if (!formKey.currentState!.validate()) return;
                try {
                  if (child == null) {
                    await _service.createChild(
                      name: nameController.text,
                      gender: genderController.text,
                    );
                  } else {
                    await _service.updateChild(
                      child.id,
                      name: nameController.text,
                      gender: genderController.text,
                    );
                  }
                  if (_current(ticket) && context.mounted) {
                    Navigator.pop(context, true);
                  }
                } catch (error) {
                  if (_current(ticket)) {
                    if (context.mounted) Navigator.pop(context, false);
                    _showMessage('$error');
                  }
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
    _privateControllers.remove(nameController);
    _privateControllers.remove(genderController);
    nameController.dispose();
    genderController.dispose();
    if (saved == true && _current(ticket)) _load();
  }

  Future<void> _deleteChild(AiChildProfile child) async {
    final ticket = _ticket;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ChatAccountModal(
        store: _store,
        ticket: ticket,
        builder: (context) => AlertDialog(
          title: const Text('Kinderprofil löschen?'),
          content: Text(
            'Alle gespeicherten KI-Informationen zu ${child.name} werden gelöscht.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Löschen'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !_current(ticket)) return;
    try {
      await _service.deleteChild(child.id);
      if (!_current(ticket)) return;
      await _load();
    } catch (error) {
      if (_current(ticket)) _showMessage('$error');
    }
  }

  Future<void> _showChildDetails(AiChildProfile child) async {
    final ticket = _ticket;
    try {
      final items = await _service.getMemory(child.id);
      if (!mounted || !_current(ticket)) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => ChatAccountModal(
          store: _store,
          ticket: ticket,
          builder: (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    child.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bestätigte Informationen, die die KI verwenden darf.',
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Noch keine gespeicherten Informationen.'),
                    )
                  else
                    ...items.map(
                      (item) => ListTile(
                        title: Text(item.key),
                        subtitle: Text(item.value),
                        leading: const Icon(Icons.verified_user_outlined),
                        trailing: IconButton(
                          tooltip: 'Löschen',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            if (!_current(ticket)) return;
                            try {
                              await _service.deleteMemory(child.id, item.id);
                              if (!_current(ticket)) return;
                              if (context.mounted) Navigator.pop(context);
                              _showChildDetails(child);
                            } catch (error) {
                              if (_current(ticket)) _showMessage('$error');
                            }
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (error) {
      if (_current(ticket)) _showMessage('$error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;
    return Scaffold(
      appBar: AppBar(title: const Text('KI-Gedächtnis & Kinder')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.error_outline),
                        title: const Text(
                          'Daten konnten nicht geladen werden.',
                        ),
                        subtitle: Text(_error!),
                        trailing: IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _load,
                        ),
                      ),
                    ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('KI-Gedächtnis aktivieren'),
                    subtitle: const Text(
                      'Bestätigte Familieninformationen können die Beratung persönlicher machen.',
                    ),
                    value: _enabled,
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (_current(ticket)) _toggleEnabled(value);
                          },
                  ),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'Diese Daten werden ausschließlich genutzt, um die KI-Beratung für deine Familie persönlicher zu machen.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kinderprofile',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        tooltip: 'Kind hinzufügen',
                        onPressed: () => _editChild(),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  if (_children.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('Noch kein Kinderprofil angelegt.'),
                    )
                  else
                    ..._children.map(
                      (child) => Card(
                        child: ListTile(
                          title: Text(child.name),
                          subtitle: Text(
                            child.memoryItems.isEmpty
                                ? 'Keine bestätigten Informationen'
                                : '${child.memoryItems.length} bestätigte Informationen',
                          ),
                          onTap: () {
                            if (_current(ticket)) _showChildDetails(child);
                          },
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (!_current(ticket)) return;
                              if (value == 'edit') _editChild(child);
                              if (value == 'delete') _deleteChild(child);
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Bearbeiten'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Löschen'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
