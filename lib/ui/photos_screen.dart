import 'package:flutter/material.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/photo_backend_service.dart';
import 'package:parentpeak/widgets/language_change_mixin.dart';

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key});

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen>
    with LanguageChangeMixin<PhotosScreen> {
  final PhotoBackendService _service =
      BackendServiceFactory.createPhotoService();
  final List<Map<String, dynamic>> _photos = [];
  bool _isLoading = true;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    setState(() => _isLoading = true);
    final albums = await _service.fetchAlbums();
    if (!mounted) return;
    setState(() {
      _photos
        ..clear()
        ..addAll(albums);
      _syncError = _service.lastSyncError;
      _isLoading = false;
    });
  }

  Future<void> _createAlbum() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Neues Album'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Titel',
              hintText: 'z. B. Sommerfest',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, controller.text.trim());
              },
              child: const Text('Anlegen'),
            ),
          ],
        );
      },
    );

    if (title == null || title.isEmpty) return;
    try {
      final created = await _service.addAlbum(title: title);
      if (!mounted) return;

      setState(() {
        _photos.insert(0, created);
        _syncError = _service.lastSyncError;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _syncError = _service.lastSyncError;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_syncError ?? 'Album konnte nicht angelegt werden.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fotos'),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: _loadAlbums,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Synchronisieren',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.03),
                    theme.brightness == Brightness.dark
                        ? Colors.grey[900]!
                        : Colors.white
                  ],
                ),
              ),
              child: Column(
                children: [
                  if (_syncError != null && APIConfig.isBackendConfigured())
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Material(
                        color: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.45),
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
                            onPressed: _loadAlbums,
                            child: const Text('Erneut versuchen'),
                          ),
                        )
                        ),
                      ),
                    ),
                  Expanded(
                    child: _photos.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.photo_library_outlined,
                                    size: 64,
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.3)),
                                const SizedBox(height: 16),
                                Text(
                                  'Noch keine Fotos',
                                  style: theme.textTheme.bodyLarge
                                      ?.copyWith(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: _photos.length + 1,
                            itemBuilder: (_, i) {
                              if (i == 0) {
                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                        color: theme.colorScheme.primary,
                                        width: 2),
                                  ),
                                  child: InkWell(
                                    onTap: _createAlbum,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate_outlined,
                                          size: 48,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Fotos\nhinzufügen',
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              final photo = _photos[i - 1];
                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                      color: Colors.grey[200]!, width: 1),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('${photo['title']} öffnen')),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                    top: Radius.circular(16)),
                                          ),
                                          child: Center(
                                            child: Icon(
                                              Icons.photo,
                                              size: 48,
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              photo['title'] as String,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.image,
                                                    size: 12,
                                                    color: Colors.grey[600]),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${photo['count']} Fotos',
                                                  style: theme
                                                      .textTheme.bodySmall
                                                      ?.copyWith(
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
