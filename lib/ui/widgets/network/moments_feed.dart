import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/moments_service.dart';
import 'package:parentpeak/models/moment.dart';
import 'package:parentpeak/ui/widgets/network/family_avatar.dart';

/// Der „Momente"-Feed der Familien-Community (M-C1: ansehen).
///
/// Lädt die sichtbaren Momente (eigene + öffentliche + von verbundenen
/// Familien) und zeigt sie als Karten: Autor, Zeit, Text, Bild-Galerie und
/// Herz-/Kommentar-Zähler. Interaktion (Herz/Kommentar), Erstellen und Melden
/// kommen in den Folgepaketen und docken über die bereitgestellten Callbacks
/// bzw. den [MomentsService] an.
class MomentsFeed extends StatefulWidget {
  const MomentsFeed({super.key, this.onCreate});

  /// Optionaler Hook für „Moment teilen" (wird in M-C2 verdrahtet).
  final VoidCallback? onCreate;

  @override
  State<MomentsFeed> createState() => MomentsFeedState();
}

class MomentsFeedState extends State<MomentsFeed> {
  final _service = MomentsService.instance;
  bool _loading = true;
  List<Moment> _moments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final moments = await _service.loadFeed();
    if (!mounted) return;
    setState(() {
      _moments = moments;
      _loading = false;
    });
  }

  /// Von außen aufrufbar (z. B. nach dem Erstellen eines Moments).
  Future<void> reload() => _load();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_moments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 90),
            const Center(child: Text('✨', style: TextStyle(fontSize: 44))),
            const SizedBox(height: 16),
            Center(
              child: Text(
                context.tr('moments_empty_title'),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Text(
                context.tr('moments_empty_body'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _moments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, i) => _MomentCard(moment: _moments[i]),
      ),
    );
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({required this.moment});

  final Moment moment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Kopf: Avatar, Name, Zeit ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
            child: Row(
              children: [
                FamilyAvatar(name: moment.authorName, size: FamilyAvatarSize.m),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        moment.authorName,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (moment.createdAt != null)
                        Text(
                          _relativeTime(context, moment.createdAt!),
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: scheme.outline),
                        ),
                    ],
                  ),
                ),
                _visibilityChip(context, moment.visibility),
              ],
            ),
          ),
          // ── Text ──────────────────────────────────────────────────────────
          if (moment.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                moment.text,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
            ),
          // ── Bild-Galerie ──────────────────────────────────────────────────
          if (moment.imageUrls.isNotEmpty) _gallery(context, moment.imageUrls),
          // ── Fuß: Herz- und Kommentar-Zähler (read-only in M-C1) ───────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              children: [
                Icon(
                  moment.heartedByMe
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 18,
                  color: moment.heartedByMe ? scheme.primary : scheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  '${moment.heartCount}',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 16),
                Icon(Icons.mode_comment_outlined,
                    size: 17, color: scheme.outline),
                const SizedBox(width: 4),
                Text(
                  '${moment.commentCount}',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gallery(BuildContext context, List<String> urls) {
    if (urls.length == 1) {
      return _image(context, urls.first, aspectRatio: 4 / 3);
    }
    // Mehrere Bilder: horizontale Galerie.
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _image(context, urls[i], width: 150),
        ),
      ),
    );
  }

  Widget _image(
    BuildContext context, String url, {
    double? aspectRatio,
    double? width,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final img = Image.network(
      url,
      fit: BoxFit.cover,
      width: width,
      loadingBuilder: (c, child, progress) => progress == null
          ? child
          : Container(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
      errorBuilder: (c, _, __) => Container(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        alignment: Alignment.center,
        child: Icon(Icons.broken_image_outlined, color: scheme.outline),
      ),
    );
    if (aspectRatio != null) {
      return AspectRatio(aspectRatio: aspectRatio, child: img);
    }
    return img;
  }

  Widget _visibilityChip(BuildContext context, String visibility) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, labelKey) = switch (visibility) {
      'public' => (Icons.public_rounded, 'moments_visibility_public'),
      'private' => (Icons.lock_outline_rounded, 'moments_visibility_private'),
      _ => (Icons.group_outlined, 'moments_visibility_friends'),
    };
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: context.tr(labelKey),
        child: Icon(icon, size: 16, color: scheme.outline),
      ),
    );
  }

  String _relativeTime(BuildContext context, DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return context.tr('moments_time_now');
    if (diff.inMinutes < 60) {
      return context.tr('moments_time_minutes')
          .replaceAll('{count}', '${diff.inMinutes}');
    }
    if (diff.inHours < 24) {
      return context.tr('moments_time_hours')
          .replaceAll('{count}', '${diff.inHours}');
    }
    if (diff.inDays < 7) {
      return context.tr('moments_time_days')
          .replaceAll('{count}', '${diff.inDays}');
    }
    return '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year}';
  }
}
