import 'package:flutter/material.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/shopping_backend_service.dart';
import 'package:parentpeak/widgets/language_change_mixin.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen>
    with LanguageChangeMixin<ShoppingScreen> {
  final ShoppingBackendService _shoppingService =
      BackendServiceFactory.createShoppingService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _syncError;

  final TextEditingController _controller = TextEditingController();

  String _t(String key) {
    return AppStringsManager.getString(languageService.currentLanguage, key);
  }

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await _shoppingService.fetchItems();
    if (!mounted) return;

    setState(() {
      _items = items;
      _loading = false;
      _syncError = _shoppingService.lastSyncError;
    });
  }

  Future<void> _toggleItemChecked(
      Map<String, dynamic> item, bool checked) async {
    final previous = item['checked'] as bool;
    setState(() => item['checked'] = checked);
    final id = item['id']?.toString();
    if (id != null && id.isNotEmpty) {
      try {
        await _shoppingService.updateChecked(id, checked);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          item['checked'] = previous;
          _syncError = _shoppingService.lastSyncError;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  _syncError ?? 'Status konnte nicht gespeichert werden.')),
        );
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _syncError = _shoppingService.lastSyncError;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    if (_controller.text.trim().isEmpty) return;
    final name = _controller.text.trim();
    try {
      final created = await _shoppingService.addItem(
        name: name,
        category: _t('category_general'),
      );
      if (!mounted) return;

      _controller.clear();
      setState(() {
        _items.insert(0, created);
        _syncError = _shoppingService.lastSyncError;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _syncError = _shoppingService.lastSyncError;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(_syncError ?? 'Eintrag konnte nicht gespeichert werden.')),
      );
    }
  }

  Future<void> _deleteItem(int index) async {
    final item = _items[index];
    final id = item['id']?.toString();
    setState(() => _items.removeAt(index));
    if (id != null && id.isNotEmpty) {
      try {
        await _shoppingService.deleteItem(id);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _items.insert(index, item);
          _syncError = _shoppingService.lastSyncError;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(_syncError ?? 'Eintrag konnte nicht gelöscht werden.')),
        );
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _syncError = _shoppingService.lastSyncError;
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text('${item['name']} ${_t('deleted')}'),
        action: SnackBarAction(
          label: _t('undo'),
          onPressed: () {
            if (!mounted) return;
            setState(() => _items.insert(index, item));
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unchecked =
        _items.where((item) => !(item['checked'] as bool)).toList();
    final checked = _items.where((item) => item['checked'] as bool).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('shopping')),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _loadItems,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Synchronisieren',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_syncError != null && APIConfig.isBackendConfigured())
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color:
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                  leading: Icon(
                    Icons.cloud_off_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text('Server-Sync fehlgeschlagen'),
                  subtitle: Text(_syncError!),
                  trailing: TextButton(
                    onPressed: _loadItems,
                    child: const Text('Erneut versuchen'),
                  ),
                )
                ),
              ),
            ),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),

          // Input Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: _t('add_item_hint'),
                        border: InputBorder.none,
                        prefixIcon: Icon(
                          Icons.shopping_cart_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      onSubmitted: (_) => _addItem(),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text(''),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(12),
                      shape: const CircleBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // To-Buy Section
          if (unchecked.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.playlist_add_check,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_t('to_buy')} (${unchecked.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ...unchecked.asMap().entries.map((e) => _buildItem(
                  e.value,
                  theme,
                  e.key,
                )),
            const SizedBox(height: 16),
          ],

          // Checked Section
          if (checked.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.done_all,
                    color: Colors.green[400],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_t('in_cart')} (${checked.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            ...checked.asMap().entries.map((e) => _buildItem(
                  e.value,
                  theme,
                  unchecked.length + e.key,
                )),
          ],

          if (_items.isEmpty) ...[
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _t('no_items'),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItem(
    Map<String, dynamic> item,
    ThemeData theme,
    int index,
  ) {
    final isChecked = item['checked'] as bool;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: isChecked ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isChecked
              ? BorderSide(color: Colors.grey[300]!, width: 1)
              : BorderSide.none,
        ),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Checkbox(
            value: isChecked,
            onChanged: (val) => _toggleItemChecked(item, val ?? false),
            shape: const RoundedRectangleBorder(),
          ),
          title: Text(
            item['name'] as String,
            style: theme.textTheme.bodyLarge?.copyWith(
              decoration: isChecked ? TextDecoration.lineThrough : null,
              color: isChecked ? Colors.grey : null,
            ),
          ),
          subtitle: Text(
            item['category'] as String,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.grey),
            onPressed: () => _deleteItem(index),
          ),
        )
        ),
      ),
    );
  }
}
