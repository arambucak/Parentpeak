import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/moments_service.dart';
import 'package:parentpeak/models/moment.dart';

/// Formular zum Erstellen eines Moments: Text, mehrere Bilder, Sichtbarkeit.
///
/// Zeigt einen sanften Kinderschutz-Hinweis beim Hinzufügen von Bildern
/// (Produktentscheidung: keine erkennbaren Kinderfotos). Bilder werden beim
/// Teilen einzeln über den sanitisierten `/uploads/image`-Endpoint hochgeladen.
class MomentComposeScreen extends StatefulWidget {
  const MomentComposeScreen({super.key, this.imagePicker, this.service});

  final ImagePicker? imagePicker;
  final MomentsService? service;

  @override
  State<MomentComposeScreen> createState() => _MomentComposeScreenState();
}

/// Ein lokal ausgewähltes Bild (Bytes für web-sichere Vorschau + Upload).
class _PickedImage {
  _PickedImage(this.file, this.bytes);
  final XFile file;
  final Uint8List bytes;
}

class _MomentComposeScreenState extends State<MomentComposeScreen> {
  late final _picker = widget.imagePicker ?? ImagePicker();
  late final _service = widget.service ?? MomentsService.instance;
  final _textCtrl = TextEditingController();

  final List<_PickedImage> _images = [];
  String _visibility = 'friends';
  bool _sharing = false;

  static const int _maxImages = 10;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  bool get _canShare =>
      !_sharing && (_textCtrl.text.trim().isNotEmpty || _images.isNotEmpty);

  Future<void> _addImages() async {
    if (_images.length >= _maxImages) return;
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 82, maxWidth: 1800);
      if (picked.isEmpty) return;
      final remaining = _maxImages - _images.length;
      for (final x in picked.take(remaining)) {
        final bytes = await x.readAsBytes();
        _images.add(_PickedImage(x, bytes));
      }
      if (mounted) setState(() {});
    } catch (_) {
      // Auswahl abgebrochen/fehlgeschlagen — still ignorieren.
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  Future<void> _share() async {
    if (!_canShare) return;
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Bilder einzeln hochladen, URLs sammeln.
      final urls = <String>[];
      for (final img in _images) {
        final url = await _service.uploadImage(img.file);
        if (url != null) urls.add(url);
      }
      if (_images.isNotEmpty && urls.isEmpty) {
        // Alle Uploads fehlgeschlagen — nicht als leeren Text-Moment posten.
        throw Exception('upload_failed');
      }
      final moment = await _service.createMoment(
        text: _textCtrl.text,
        imageUrls: urls,
        visibility: _visibility,
      );
      if (!mounted) return;
      if (moment != null) {
        Navigator.of(context).pop<Moment>(moment);
      } else {
        throw Exception('create_failed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _sharing = false);
      messenger.showSnackBar(SnackBar(
        content: Text(context.tr('moments_share_failed')),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('moments_compose_title')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _canShare ? _share : null,
              child: _sharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr('moments_share_action')),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // ── Text ──────────────────────────────────────────────────────────
          TextField(
            controller: _textCtrl,
            minLines: 3,
            maxLines: 8,
            maxLength: 2000,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: context.tr('moments_compose_hint'),
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // ── Kinderschutz-Hinweis ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 18, color: scheme.tertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr('moments_child_safety_hint'),
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── Bilder ────────────────────────────────────────────────────────
          _imageStrip(theme),
          const SizedBox(height: 20),
          // ── Sichtbarkeit ──────────────────────────────────────────────────
          Text(
            context.tr('moments_visibility_label'),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _visibilityOption('public', Icons.public_rounded,
              'moments_visibility_public', 'moments_visibility_public_desc'),
          _visibilityOption('friends', Icons.group_outlined,
              'moments_visibility_friends', 'moments_visibility_friends_desc'),
          _visibilityOption('private', Icons.lock_outline_rounded,
              'moments_visibility_private', 'moments_visibility_private_desc'),
        ],
      ),
    );
  }

  Widget _imageStrip(ThemeData theme) {
    final scheme = theme.colorScheme;
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          if (i == _images.length) {
            // „Bild hinzufügen"-Kachel.
            final full = _images.length >= _maxImages;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: full ? null : _addImages,
              child: Container(
                width: 96,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      color: full ? scheme.outline : scheme.primary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      full
                          ? context.tr('moments_images_full')
                          : context.tr('moments_add_image'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _images[i].bytes,
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _removeImage(i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _visibilityOption(
      String value, IconData icon, String labelKey, String descKey) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = _visibility == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _visibility = value),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 20, color: selected ? scheme.primary : scheme.outline),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(labelKey),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      context.tr(descKey),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded,
                    size: 20, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
