import 'package:flutter/material.dart';
import 'package:parentpeak/logic/ai_memory_service.dart';
import 'package:parentpeak/models/ai_memory.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';

class AiMemorySettingsScreen extends StatefulWidget {
  const AiMemorySettingsScreen({
    super.key,
    this.service,
  });

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

  String _t(String key) =>
      AppStringsManager.getString(languageService.currentLanguage, key);

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AiMemoryService();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await _service.getSettings();
      final children = await _service.getChildren();
      if (!mounted) return;
      setState(() {
        _enabled = settings.enabled;
        _children = children;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _t('ai_memory_load_failed');
      });
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    setState(() => _enabled = value);
    try {
      await _service.setEnabled(value);
    } catch (error) {
      if (!mounted) return;
      setState(() => _enabled = !value);
      _showMessage(_t('ai_memory_request_failed'));
    }
  }

  Future<void> _editChild([AiChildProfile? child]) async {
    final nameController = TextEditingController(text: child?.name ?? '');
    final genderController = TextEditingController(text: child?.gender ?? '');
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t(child == null ? 'ai_memory_add_title' : 'ai_memory_edit_title')),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(labelText: _t('ai_memory_name')),
              validator: (value) => value == null || value.trim().isEmpty
                  ? _t('ai_memory_name')
                  : null,
            ),
            TextField(
              controller: genderController,
              decoration: InputDecoration(labelText: _t('ai_memory_gender_optional')),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('ai_memory_cancel')),
          ),
          FilledButton(
            onPressed: () async {
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
                if (context.mounted) Navigator.pop(context, true);
              } catch (error) {
                if (context.mounted) Navigator.pop(context, false);
                _showMessage(_t('ai_memory_request_failed'));
              }
            },
            child: Text(_t('ai_memory_save')),
          ),
        ],
      ),
    );
    nameController.dispose();
    genderController.dispose();
    if (saved == true) _load();
  }

  Future<void> _deleteChild(AiChildProfile child) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('ai_memory_delete_child_title')),
        content: Text('${_t('ai_memory_delete_child_message')}\n\n${child.name}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t('ai_memory_cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(_t('ai_memory_delete'))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteChild(child.id);
      await _load();
    } catch (error) {
      _showMessage(_t('ai_memory_request_failed'));
    }
  }

  Future<void> _showChildDetails(AiChildProfile child) async {
    final items = await _service.getMemory(child.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(child.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_t('ai_memory_confirmed_description')),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Padding(
                padding: EdgeInsets.all(20),
                child: Text(_t('ai_memory_no_items')),
              )
            else
              ...items.map((item) => ListTile(
                    title: Text(item.key),
                    subtitle: Text(item.value),
                    leading: const Icon(Icons.verified_user_outlined),
                    trailing: IconButton(
                      tooltip: _t('ai_memory_delete'),
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await _service.deleteMemory(child.id, item.id);
                        if (context.mounted) Navigator.pop(context);
                        _showChildDetails(child);
                      },
                    ),
                  )),
          ]),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_t('ai_memory_title'))),
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
                        title: Text(_t('ai_memory_load_failed')),
                        subtitle: Text(_error!),
                        trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
                      ),
                    ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_t('ai_memory_enable')),
                    subtitle: Text(_t('ai_memory_enable_subtitle')),
                    value: _enabled,
                    onChanged: _toggleEnabled,
                  ),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(_t('ai_memory_transparency')),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_t('ai_memory_children'), style: Theme.of(context).textTheme.titleLarge),
                      IconButton(
                        tooltip: _t('ai_memory_add_child'),
                        onPressed: () => _editChild(),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  if (_children.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(_t('ai_memory_no_children')),
                    )
                  else
                    ..._children.map((child) => Card(
                          child: ListTile(
                            title: Text(child.name),
                            subtitle: Text(child.memoryItems.isEmpty
                                ? _t('ai_memory_none_confirmed')
                                : _t('ai_memory_confirmed_count').replaceFirst('{count}', '${child.memoryItems.length}')),
                            onTap: () => _showChildDetails(child),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') _editChild(child);
                                if (value == 'delete') _deleteChild(child);
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                    value: 'edit',
                                    child: Text(_t('ai_memory_edit'))),
                                PopupMenuItem(
                                    value: 'delete',
                                    child: Text(_t('ai_memory_delete'))),
                              ],
                            ),
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}
