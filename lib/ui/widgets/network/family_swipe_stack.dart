import 'package:flutter/material.dart';
import 'package:parentpeak/ui/widgets/network/info_chip.dart';
import 'package:parentpeak/ui/widgets/network/network_actions.dart';

/// Vorbereitete, bereits lokalisierte Darstellungsdaten einer Familie für die
/// große Wisch-Karte. Die l10n-/Breakdown-Logik bleibt im Screen; dieses
/// Widget bleibt rein darstellend und wiederverwendbar.
class FamilySwipeCardData {
  const FamilySwipeCardData({
    required this.id,
    required this.name,
    this.city = '',
    this.kids = '',
    this.bio = '',
    this.meta = '',
    this.tags = const [],
    this.reasons = const [],
  });

  /// Stabile ID (Owner-ID) — steuert Farbe und Identität der Karte.
  final String id;
  final String name;
  final String city;

  /// Bereits formatierte Kinder-Zeile (z. B. "🧒 3-5 • 6-9"), leer = aus.
  final String kids;
  final String bio;

  /// Bereits zusammengesetzte Meta-Zeile (Entfernung • Sprachen …).
  final String meta;
  final List<String> tags;

  /// Lokalisierte Match-Gründe (z. B. "Gleiche Stadt").
  final List<String> reasons;
}

/// Bumble-artiger Wisch-Stack für die Familien-Community.
///
/// Zeigt die oberste Familie als große Karte mit warmem Verlauf-Avatar-Bereich.
/// Nach rechts wischen = Interessiert ([onLike]), nach links = Nicht jetzt
/// ([onPass]). Zwei gleichwertige Buttons unter dem Stack bieten dieselbe
/// Aktion ohne Wischen (wichtig auf Web/Desktop).
///
/// Zeigt bewusst **keine Fotos** (Kinderschutz): nur Initiale + Farbverlauf.
/// Web-kompatibel (kein `dart:io`, `GestureDetector` mit
/// `HitTestBehavior.opaque`).
class FamilySwipeStack extends StatefulWidget {
  const FamilySwipeStack({
    super.key,
    required this.cards,
    required this.onLike,
    required this.onPass,
    required this.likeLabel,
    required this.passLabel,
    this.safetyMenuBuilder,
    this.cardHeight = 460,
  });

  /// Karten von oben (erste) nach unten. Nur die ersten beiden werden gemalt.
  final List<FamilySwipeCardData> cards;

  /// Rechts-Wisch / „Interessiert"-Button.
  final ValueChanged<FamilySwipeCardData> onLike;

  /// Links-Wisch / „Nicht jetzt"-Button.
  final ValueChanged<FamilySwipeCardData> onPass;

  final String likeLabel;
  final String passLabel;

  /// Optionales Overlay oben rechts (z. B. Melden/Blockieren-Menü).
  final Widget Function(FamilySwipeCardData card)? safetyMenuBuilder;

  final double cardHeight;

  @override
  State<FamilySwipeStack> createState() => _FamilySwipeStackState();
}

class _FamilySwipeStackState extends State<FamilySwipeStack>
    with SingleTickerProviderStateMixin {
  // Aktueller Drag-Versatz der obersten Karte.
  Offset _drag = Offset.zero;

  // Läuft, während eine Karte nach einer Entscheidung wegfliegt.
  bool _flinging = false;

  // Schwelle (px), ab der ein Loslassen als Entscheidung zählt.
  static const double _threshold = 110;

  void _onPanUpdate(DragUpdateDetails d) {
    if (_flinging) return;
    setState(() => _drag += d.delta);
  }

  void _onPanEnd(DragEndDetails d, FamilySwipeCardData top) {
    if (_flinging) return;
    if (_drag.dx > _threshold) {
      _decide(top, like: true);
    } else if (_drag.dx < -_threshold) {
      _decide(top, like: false);
    } else {
      setState(() => _drag = Offset.zero); // zurückfedern
    }
  }

  void _decide(FamilySwipeCardData top, {required bool like}) {
    // Karte sichtbar hinauswerfen, dann Aktion melden. Der Parent entfernt die
    // Karte aus der Liste; dadurch rückt die nächste automatisch nach.
    setState(() {
      _flinging = true;
      _drag = Offset(like ? 600 : -600, _drag.dy);
    });
    Future.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      final cb = like ? widget.onLike : widget.onPass;
      setState(() {
        _flinging = false;
        _drag = Offset.zero;
      });
      cb(top);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards;
    if (cards.isEmpty) return const SizedBox.shrink();

    final top = cards.first;
    final behind = cards.length > 1 ? cards[1] : null;
    final angle = (_drag.dx / 1000).clamp(-0.3, 0.3);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.cardHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Karte dahinter (leicht verkleinert), gibt Stapel-Gefühl.
              if (behind != null)
                Transform.scale(
                  scale: 0.94,
                  child: Opacity(
                    opacity: 0.6,
                    child: _card(context, behind, overlay: false),
                  ),
                ),
              // Oberste, wischbare Karte.
              AnimatedSlide(
                offset: _flinging ? Offset(_drag.dx.sign, 0) : Offset.zero,
                duration: _flinging
                    ? const Duration(milliseconds: 200)
                    : Duration.zero,
                child: Transform.translate(
                  offset: _flinging ? Offset.zero : _drag,
                  child: Transform.rotate(
                    angle: _flinging ? 0 : angle,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: (d) => _onPanEnd(d, top),
                      child: _card(context, top, overlay: true),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SecondaryAction(
                label: widget.passLabel,
                icon: Icons.close_rounded,
                onPressed: _flinging ? null : () => _decide(top, like: false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryAction(
                label: widget.likeLabel,
                icon: Icons.favorite_rounded,
                onPressed: _flinging ? null : () => _decide(top, like: true),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Eine einzelne große Karte: warmer Verlauf-Avatar oben, Infos unten.
  Widget _card(
    BuildContext context,
    FamilySwipeCardData card, {
    required bool overlay,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = _tint(scheme, card.id.isNotEmpty ? card.id : card.name);
    // Wisch-Richtungs-Hinweis (grün = interessiert, grau = nicht jetzt).
    final dir = overlay && !_flinging ? _drag.dx : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Warmer Avatar-Bereich (Verlauf + großes Initial) ──────────────
          Stack(
            children: [
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tint,
                      Color.alphaBlend(
                          Colors.black.withValues(alpha: 0.12), tint)
                    ],
                  ),
                ),
                child: Center(
                  child: Text(
                    _initial(card.name),
                    style: TextStyle(
                      fontSize: 84,
                      fontWeight: FontWeight.w800,
                      color: _onTint(tint),
                    ),
                  ),
                ),
              ),
              if (overlay && widget.safetyMenuBuilder != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                    child: widget.safetyMenuBuilder!(card),
                  ),
                ),
              // Richtungs-Badge beim Wischen.
              if (dir.abs() > 20)
                Positioned(
                  top: 16,
                  left: dir > 0 ? 16 : null,
                  right: dir < 0 ? 16 : null,
                  child: _swipeBadge(theme, like: dir > 0),
                ),
            ],
          ),
          // ── Infos ─────────────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (card.city.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.place_outlined,
                            size: 15, color: scheme.outline),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            card.city,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (card.kids.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      card.kids,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (card.bio.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      card.bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                  if (card.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children:
                          card.tags.map((t) => InfoChip(label: t)).toList(),
                    ),
                  ],
                  const Spacer(),
                  if (card.reasons.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: card.reasons
                          .map(
                            (label) => Text(
                              label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  if (card.meta.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      card.meta,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _swipeBadge(ThemeData theme, {required bool like}) {
    final color = like ? const Color(0xFF16A34A) : theme.colorScheme.outline;
    return Transform.rotate(
      angle: like ? -0.25 : 0.25,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 3),
          borderRadius: BorderRadius.circular(10),
          color: theme.colorScheme.surface.withValues(alpha: 0.8),
        ),
        child: Icon(
          like ? Icons.favorite_rounded : Icons.close_rounded,
          color: color,
          size: 22,
        ),
      ),
    );
  }

  String _initial(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t.characters.first.toUpperCase();
  }

  /// Stabil aus der Karten-ID abgeleitete Tönung aus dem Theme-ColorScheme —
  /// gleiche Familie, gleiche Farbe (wie FamilyAvatar, nur für den Verlauf).
  Color _tint(ColorScheme scheme, String seed) {
    final palette = <Color>[
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.primaryContainer,
      scheme.secondaryContainer,
      scheme.tertiaryContainer,
    ];
    if (seed.isEmpty) return palette.first;
    final idx = seed.codeUnitAt(0) % palette.length;
    return palette[idx];
  }

  Color _onTint(Color bg) =>
      ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
          ? Colors.white
          : Colors.black.withValues(alpha: 0.75);
}
