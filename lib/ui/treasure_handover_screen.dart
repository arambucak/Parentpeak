import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:parentpeak/logic/treasure_listing_service.dart';
import 'package:parentpeak/l10n/app_localizations.dart';
import 'package:parentpeak/models/treasure_listing.dart';
import 'package:parentpeak/models_and_widgets/animation_helpers.dart';
import 'package:parentpeak/ui/treasure_upload_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TreasureHandoverMode { coffeeChat, flyingSwap }

class TreasureHandoverScreen extends StatefulWidget {
  const TreasureHandoverScreen({super.key});

  @override
  State<TreasureHandoverScreen> createState() => _TreasureHandoverScreenState();
}

class _TreasureHandoverScreenState extends State<TreasureHandoverScreen> {
  static const String _blockedListingsKey = 'treasure_blocked_listing_ids.v1';
  static const String _reportedListingsKey = 'treasure_reported_listing_ids.v1';

  TreasureHandoverMode _selectedMode = TreasureHandoverMode.coffeeChat;
  String? _selectedSlot;
  String? _selectedDropPoint;
  final TreasureListingService _listingService = TreasureListingService.instance;
  List<TreasureListing> _listings = const [];
  String _categoryFilter = 'all';
  String _conditionFilter = 'all';
  int? _maxDistanceMeters;
  TreasureListing? _selectedListing;
  final ScrollController _scrollController = ScrollController();
  bool _loadingListings = true;
  String? _syncError;
  Set<String> _blockedListingIds = <String>{};
  Set<String> _reportedListingIds = <String>{};
  String _discoveryScope = '10km';
  bool _showDiscoveryInviteBanner = false;
  bool _globalDigitalMode = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeScreen());
  }

  Future<void> _initializeScreen() async {
    await _restoreSafetyState();
    await _loadListings();
    if (!mounted) return;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final compactScreen = viewportWidth < 390;
    final contentMaxWidth = viewportWidth >= 1200
        ? 980.0
        : viewportWidth >= 900
            ? 860.0
            : double.infinity;
    final horizontalPadding = viewportWidth >= 900 ? 24.0 : 16.0;
    final reserveLabel = _selectedMode == TreasureHandoverMode.coffeeChat
        ? l10n.t(
            'treasureReserveCoffeeMode',
            fallback: compactScreen ? 'Treffen' : 'Treffen sichern',
          )
        : l10n.t(
            'treasureReserveFlyingSwap',
            fallback: compactScreen ? 'Tausch' : 'Stillen Tausch sichern',
          );
    final hasAnyListings = _listings.isNotEmpty;
    final coffeeSlots = [
      l10n.t('treasureSlotSunday', fallback: 'Sonntag, 10:00 - 11:30 Uhr'),
      l10n.t('treasureSlotMonday', fallback: 'Montag, 17:30 - 18:15 Uhr'),
      l10n.t('treasureSlotTuesday', fallback: 'Dienstag, 08:15 - 08:45 Uhr'),
    ];
    final dropPoints = [
      l10n.t('treasureDropRetterBox', fallback: 'Retter-Box vor der Haustür'),
      l10n.t('treasureDropKitaLocker', fallback: 'Kita-Garderobe (Fach "Moewe")'),
      l10n.t('treasureDropMailbox', fallback: 'Briefkastenbox am Eingang'),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F9FE),
        elevation: 0,
        foregroundColor: const Color(0xFF172538),
        title: Text(
          l10n.t(
            'treasureTileTitle',
            fallback: compactScreen ? 'Markt' : 'Verschenkmarkt',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: l10n.t('treasurePublishNow', fallback: 'Jetzt teilen'),
            onPressed: _openUpload,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth),
          child: RefreshIndicator(
            onRefresh: _loadListings,
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(horizontalPadding, 4, horizontalPadding, 120),
              children: [
                _buildHeaderCard(l10n),
                const SizedBox(height: 14),
                if (_showDiscoveryInviteBanner) ...[
                  _buildDiscoveryInviteBanner(l10n),
                  const SizedBox(height: 12),
                ],
                if (_loadingListings) ...[
                  _buildLoadingState(l10n),
                ] else if (!hasAnyListings) ...[
                  _buildParentFriendlyEmptyState(l10n),
                ] else ...[
                  Text(
                    l10n.t(
                      'treasureHandoverQuestion',
                      fallback: compactScreen
                          ? 'Wie möchtet ihr übergeben?'
                          : 'Wie wollt ihr übergeben?',
                    ),
                    style: TextStyle(
                      fontSize: compactScreen ? 15 : 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF152B42),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.t(
                      'treasureDateOrSwap',
                      fallback: compactScreen
                          ? 'Treffen oder kontaktlos tauschen'
                          : 'Kurz treffen oder still tauschen',
                    ),
                    style: TextStyle(
                      fontSize: compactScreen ? 12.5 : 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF607286),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ModeSegmentedSwitch(
                    selectedMode: _selectedMode,
                    coffeeLabel: l10n.t('treasureHandoverCoffeeMode', fallback: 'Kurz treffen'),
                    flyingLabel: l10n.t('treasureHandoverFlyingSwap', fallback: 'Still tauschen'),
                    onChanged: (mode) {
                      setState(() {
                        _selectedMode = mode;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildSelectedModePanel(l10n),
                  const SizedBox(height: 14),
                  if (_selectedMode == TreasureHandoverMode.coffeeChat)
                    _buildCoffeeSlotPicker(theme, l10n, coffeeSlots)
                  else
                    _buildDropPointPicker(theme, l10n, dropPoints),
                  const SizedBox(height: 14),
                  _buildGuidingTextCard(l10n),
                  const SizedBox(height: 18),
                  _buildFeedDiscoveryStrip(l10n),
                  if (_syncError != null && _syncError!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildSyncErrorCard(l10n),
                  ],
                  const SizedBox(height: 14),
                  _buildAeroFeedPreview(l10n),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _selectedListing == null
          ? null
          : SafeArea(
              minimum: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStickySelectionSummary(l10n),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          backgroundColor: const Color(0xFF1E5CD7),
                        ),
                        onPressed: _canConfirmSelection ? _confirmSelection : null,
                        icon: const Icon(Icons.check_circle_rounded),
                        label: Text(reserveLabel),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingState(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE6F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('treasureFeedTitle', fallback: 'Schätze in deiner Nähe'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF152B42),
            ),
          ),
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 6),
          const SizedBox(height: 12),
          Text(
            l10n.t(
              'treasureLoadingHint',
              fallback: 'Wir laden gerade passende Angebote aus deiner Umgebung.',
            ),
            style: const TextStyle(
              color: Color(0xFF607286),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentFriendlyEmptyState(AppLocalizations l10n) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 720),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) {
        Widget staged({required int order, required Widget child}) {
          final start = (order * 0.14).clamp(0.0, 0.7);
          final local = ((progress - start) / (1 - start)).clamp(0.0, 1.0);
          return Opacity(
            opacity: local,
            child: Transform.translate(
              offset: Offset(0, 14 * (1 - local)),
              child: child,
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFFE9F3FF), Color(0xFFF3EEFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFD6E6FA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              staged(
                order: 0,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.volunteer_activism_rounded,
                        color: Color(0xFF1E5CD7),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.t(
                          'treasureFeedEmptyTitle',
                          fallback: 'Noch keine Schätze in deiner Nähe',
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF14263A),
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              staged(
                order: 1,
                child: Text(
                  l10n.t(
                    'treasureFeedEmptyText',
                    fallback: 'Starte mit eurem ersten Teil. So sehen Familien in eurer Nähe direkt etwas Passendes.',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF385069),
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              staged(
                order: 2,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PreviewBadge(
                      icon: Icons.camera_alt_rounded,
                      label: l10n.t('treasureTakePhoto', fallback: 'Foto'),
                      background: Colors.white,
                      foreground: const Color(0xFF1E5CD7),
                    ),
                    _PreviewBadge(
                      icon: Icons.edit_note_rounded,
                      label: l10n.t('treasureOptionalNoteLabel', fallback: 'Notiz'),
                      background: Colors.white,
                      foreground: const Color(0xFF1E5CD7),
                    ),
                    _PreviewBadge(
                      icon: Icons.share_rounded,
                      label: l10n.t('treasurePublishNow', fallback: 'Jetzt teilen'),
                      background: Colors.white,
                      foreground: const Color(0xFF1E5CD7),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              staged(
                order: 3,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: const Color(0xFF1E5CD7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _openUpload,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: Text(l10n.t('treasurePublishNow', fallback: 'Jetzt teilen')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStickySelectionSummary(AppLocalizations l10n) {
    final listing = _selectedListing;
    if (listing == null) {
      return const SizedBox.shrink();
    }
    final modeLabel = _selectedMode == TreasureHandoverMode.coffeeChat
        ? l10n.t('treasureHandoverCoffeeMode', fallback: 'Kurz treffen')
        : l10n.t('treasureHandoverFlyingSwap', fallback: 'Still tauschen');
    final detail = _selectedMode == TreasureHandoverMode.coffeeChat
        ? _selectedSlot
        : _selectedDropPoint;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE6F3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bookmark_added_rounded, size: 18, color: Color(0xFF1E5CD7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              detail == null || detail.trim().isEmpty
                  ? '${listing.title} · $modeLabel'
                  : '${listing.title} · $modeLabel · $detail',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF29425C),
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TreasureListing> get _filteredListings {
    return _listings.where((listing) {
      if (_blockedListingIds.contains(listing.id)) {
        return false;
      }
      final matchesCategory = _categoryFilter == 'all' ||
        _normalizeCategoryKey(listing.category) == _categoryFilter;
      final matchesCondition =
          _conditionFilter == 'all' || listing.conditionKey == _conditionFilter;
      final matchesDistance =
          _maxDistanceMeters == null || listing.distanceMeters <= _maxDistanceMeters!;
      return matchesCategory && matchesCondition && matchesDistance;
    }).toList();
  }

  bool get _canConfirmSelection {
    if (_selectedListing == null) {
      return false;
    }
    if (_selectedMode == TreasureHandoverMode.coffeeChat) {
      return _selectedSlot != null;
    }
    return _selectedDropPoint != null;
  }

  Widget _buildHeaderCard(AppLocalizations l10n) {
    final compactScreen = MediaQuery.sizeOf(context).width < 390;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFFDEEFFF), Color(0xFFF1EBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('treasureReserveTitle', fallback: 'Übergabe planen'),
            style: TextStyle(
              fontSize: compactScreen ? 18 : 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF122033),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.t(
              'treasureDateOrSwap',
              fallback: compactScreen
                  ? 'Treffen oder kontaktlos tauschen'
                  : 'Kurz treffen oder still tauschen',
            ),
            style: TextStyle(
              fontSize: compactScreen ? 12.2 : 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334961),
            ),
            maxLines: compactScreen ? 2 : null,
            overflow: compactScreen ? TextOverflow.ellipsis : TextOverflow.visible,
          ),
        ],
      ),
    );
  }

  Widget _buildFeedDiscoveryStrip(AppLocalizations l10n) {
    final compactScreen = MediaQuery.sizeOf(context).width < 390;
    final categoryOptions = [
      ('all', l10n.t('treasureFilterAll', fallback: 'Alle')),
      ('vehicles', l10n.t('treasureCategoryVehicles', fallback: 'Fahrzeuge')),
      ('clothing', l10n.t('treasureCategoryClothing', fallback: 'Kleidung')),
      ('toys', l10n.t('treasureCategoryToys', fallback: 'Spielzeug')),
      ('books', l10n.t('treasureCategoryBooks', fallback: 'Bücher')),
      ('equipment', l10n.t('treasureCategoryEquipment', fallback: 'Ausstattung')),
    ];
    final conditionOptions = [
      ('all', l10n.t('treasureFilterAll', fallback: 'Alle')),
      ('studio', l10n.t('treasureConditionLikeNew', fallback: 'Studio-Zustand')),
      ('round2', l10n.t('treasureConditionGood', fallback: 'Runde 2')),
      ('wild', l10n.t('treasureConditionRaider', fallback: 'Wildnis-Modus')),
    ];
    final distanceOptions = [
      (null, l10n.t('treasureFilterDistanceAll', fallback: 'Jede Distanz')),
      (250, l10n.t('treasureFilterDistance250', fallback: 'Bis 250 m')),
      (500, l10n.t('treasureFilterDistance500', fallback: 'Bis 500 m')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('treasureFeedTitle', fallback: 'Schätze in deiner Nähe'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF152B42),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.t('treasureFeedSubtitle', fallback: 'Lokal, ehrlich, sofort verständlich'),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF607286),
            fontSize: compactScreen ? 12.2 : null,
          ),
          maxLines: compactScreen ? 2 : null,
          overflow: compactScreen ? TextOverflow.ellipsis : TextOverflow.visible,
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE4EAF4)),
          ),
          child: Text(
            _globalDigitalMode
                ? 'Ansicht: Globaler Digital-Modus'
                : 'Aktueller Suchradius: $_discoveryScope',
            style: const TextStyle(
              color: Color(0xFF385069),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildFilterRow<String>(
          items: categoryOptions,
          selectedValue: _categoryFilter,
          onSelected: (value) => setState(() => _categoryFilter = value),
        ),
        const SizedBox(height: 8),
        _buildFilterRow<String>(
          items: conditionOptions,
          selectedValue: _conditionFilter,
          onSelected: (value) => setState(() => _conditionFilter = value),
        ),
        const SizedBox(height: 8),
        _buildFilterRow<int?>(
          items: distanceOptions,
          selectedValue: _maxDistanceMeters,
          onSelected: (value) => setState(() => _maxDistanceMeters = value),
        ),
      ],
    );
  }

  Widget _buildAeroFeedPreview(AppLocalizations l10n) {
    if (_listings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('treasureFeedEmptyTitle', fallback: 'Noch keine Schätze in deiner Nähe'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.t('treasureFeedEmptyText', fallback: 'Starte einfach mit dem ersten Teil, das bei euch weiterziehen darf.'),
              style: const TextStyle(color: Color(0xFF607286), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    if (_filteredListings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('treasureNoResultsTitle', fallback: 'Gerade nichts Passendes dabei'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.t('treasureNoResultsText', fallback: 'Versuch es mit einer größeren Entfernung oder schau später nochmal rein.'),
              style: const TextStyle(color: Color(0xFF607286), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _filteredListings
          .take(3)
          .toList()
          .asMap()
          .entries
          .map((entry) {
            final index = entry.key;
            final listing = entry.value;
            final delay = index * 75; // Staggered delay
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: EntranceAnimation(
                delayMs: delay,
                duration: const Duration(milliseconds: 400),
                child: _buildListingCard(l10n, listing),
              ),
            );
          })
          .toList(),
    );
  }

  Widget _buildListingCard(AppLocalizations l10n, TreasureListing listing) {
    final compactScreen = MediaQuery.sizeOf(context).width < 390;
    final conditionMeta = _conditionMeta(l10n, listing.conditionKey);
    final hasImage = listing.hasImages;
    final primaryImagePath = listing.primaryImagePath;
    final isSelected = _selectedListing?.id == listing.id;
    final isJustListed = _isJustListed(listing.createdAt);
    final isFreshToday = _isFreshToday(listing.createdAt);
    final freshnessTimeLabel = _freshnessTimeLabel(l10n, listing.createdAt);
    return GestureDetector(
      onTap: () => _openListingDetail(listing),
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? const Color(0xFF1E5CD7) : Colors.transparent,
          width: 1.6,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 210,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: hasImage
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFFFDF1E8), Color(0xFFEFF4FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: hasImage ? const Color(0xFF14283F) : null,
            ),
            child: Stack(
              children: [
                if (hasImage)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: _buildTreasureImageByPath(
                        primaryImagePath!,
                        fit: BoxFit.cover,
                        errorWidget: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFFDF1E8), Color(0xFFEFF4FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                  if (listing.photoCount > 1)
                    Positioned(
                      right: 18,
                      top: 18,
                      child: _PreviewBadge(
                        icon: Icons.collections_rounded,
                        label: l10n.tFormat(
                          'treasurePhotoCount',
                          {'count': '${listing.photoCount}'},
                          fallback: '${listing.photoCount} Fotos',
                        ),
                        background: Colors.black.withValues(alpha: 0.28),
                        foreground: Colors.white,
                      ),
                    ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: hasImage
                            ? [
                                Colors.black.withValues(alpha: 0.05),
                                Colors.black.withValues(alpha: 0.46),
                              ]
                            : [Colors.transparent, Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 18,
                  left: 18,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PreviewBadge(
                        icon: conditionMeta.$5,
                        label: conditionMeta.$1,
                        background: conditionMeta.$3,
                        foreground: conditionMeta.$4,
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        _PreviewBadge(
                          icon: Icons.check_circle_rounded,
                          label: l10n.t('treasureSelectedForHandover', fallback: 'Ausgewählt'),
                          background: const Color(0xFFEAF1FF),
                          foreground: const Color(0xFF1E5CD7),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  right: 22,
                  top: 28,
                  child: Icon(
                    _categoryIcon(listing.category),
                    size: 72,
                    color: hasImage ? Colors.white.withValues(alpha: 0.2) : const Color(0x22D96C2F),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${listing.title} · ${listing.sizeAge}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: hasImage ? Colors.white : const Color(0xFF152B42),
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.tFormat(
                          'treasureDistanceMeters',
                          {'meters': '${listing.distanceMeters}'},
                          fallback: '${listing.distanceMeters} m entfernt',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasImage ? Colors.white70 : const Color(0xFF607286),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: const Color(0xFF1E5CD7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => _openListingDetail(listing),
            icon: const Icon(Icons.handshake_rounded, size: 18),
            label: Text(
              l10n.t(
                'treasureReserveAndPickup',
                fallback: compactScreen ? 'Details' : 'Details & reservieren',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PreviewBadge(
                icon: Icons.category_rounded,
                label: listing.category,
                background: const Color(0xFFF1F5FB),
                foreground: const Color(0xFF29425C),
              ),
              _PreviewBadge(
                icon: Icons.palette_outlined,
                label: listing.colorLabel,
                background: const Color(0xFFFFF1E5),
                foreground: const Color(0xFFD96C2F),
              ),
              if (_reportedListingIds.contains(listing.id))
                _PreviewBadge(
                  icon: Icons.flag_rounded,
                  label: l10n.t('treasureReportedFlag', fallback: 'Gemeldet'),
                  background: const Color(0xFFFFEDED),
                  foreground: const Color(0xFFC53A3A),
                ),
              if (listing.ratingCount > 0)
                _PreviewBadge(
                  icon: Icons.star_rounded,
                  label: '${listing.rating.toStringAsFixed(1)} (${listing.ratingCount})',
                  background: const Color(0xFFFFF7E5),
                  foreground: const Color(0xFFC47A00),
                ),
              if (listing.views > 0)
                _PreviewBadge(
                  icon: Icons.visibility_rounded,
                  label: '${listing.views}',
                  background: const Color(0xFFEAF1FF),
                  foreground: const Color(0xFF1E5CD7),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaHintChip(
                icon: Icons.lock_open_rounded,
                label: l10n.t('treasureContactlessHint', fallback: 'Kontaktlos möglich'),
              ),
              if (isJustListed)
                _MetaHintChip(
                  icon: Icons.auto_awesome_rounded,
                  label: l10n.t('treasureJustListed', fallback: 'Gerade neu'),
                  background: const Color(0xFFEAF7EF),
                  foreground: const Color(0xFF1F9C5D),
                )
              else if (isFreshToday)
                _MetaHintChip(
                  icon: Icons.schedule_rounded,
                  label: l10n.t('treasureFreshToday', fallback: 'Heute neu'),
                  background: const Color(0xFFFFF1E5),
                  foreground: const Color(0xFFD96C2F),
                ),
              if (freshnessTimeLabel != null)
                _MetaHintChip(
                  icon: Icons.access_time_rounded,
                  label: freshnessTimeLabel,
                  background: const Color(0xFFF7F9FD),
                  foreground: const Color(0xFF607286),
                ),
              if (isSelected)
                _MetaHintChip(
                  icon: Icons.check_circle_rounded,
                  label: l10n.t('treasureSelectedForHandover', fallback: 'Vorgemerkt'),
                  background: const Color(0xFFEAF1FF),
                  foreground: const Color(0xFF1E5CD7),
                ),
            ],
          ),
          if (listing.note.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              listing.note,
              style: const TextStyle(
                color: Color(0xFF607286),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    ));
  }

  Widget _buildFilterRow<T>({
    required List<(T, String)> items,
    required T selectedValue,
    required ValueChanged<T> onSelected,
  }) {
    final compactScreen = MediaQuery.sizeOf(context).width < 390;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items
            .asMap()
            .entries
            .map(
              (entry) => Padding(
                padding: EdgeInsets.only(right: entry.key == items.length - 1 ? 0 : 8),
                child: GestureDetector(
                  onTap: () => onSelected(entry.value.$1),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compactScreen ? 10 : 12,
                      vertical: compactScreen ? 7 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: selectedValue == entry.value.$1
                          ? const Color(0xFF1E5CD7)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selectedValue == entry.value.$1
                            ? const Color(0xFF1E5CD7)
                            : const Color(0xFFDCE6F3),
                      ),
                    ),
                    child: Text(
                      entry.value.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selectedValue == entry.value.$1
                            ? Colors.white
                            : const Color(0xFF29425C),
                        fontWeight: FontWeight.w700,
                        fontSize: compactScreen ? 12 : 13,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _loadListings() async {
    final discovery = await _listingService.loadListingsWithFallback();
    final listings = discovery.listings;
    final visibleListings = listings
        .where((item) => !_blockedListingIds.contains(item.id))
        .toList();
    if (!mounted) return;
    setState(() {
      _discoveryScope = discovery.scope;
      _showDiscoveryInviteBanner = discovery.showInviteBanner;
      _globalDigitalMode = discovery.globalDigitalMode;
      _listings = visibleListings;
      _syncError = _listingService.lastSyncError;
      _selectedListing = _selectedListing == null
          ? null
          : visibleListings.where((item) => item.id == _selectedListing?.id).firstOrNull;
      _loadingListings = false;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Widget _buildDiscoveryInviteBanner(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF7D8A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.campaign_outlined, color: Color(0xFF9A5A11), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _globalDigitalMode
                  ? '🎁 Kein lokal verfügbar? Stöber jetzt im globalen Schatz-Pool — oder teile deine eigenen Schätze!'
                  : '📍 Aktuelle Reichweite: $_discoveryScope | Mehr Schätze in deiner Nähe? Lade Freunde ein!',
              style: const TextStyle(
                color: Color(0xFF74420D),
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUpload() async {
    final result = await Navigator.of(context).push<TreasureListing>(
      MaterialPageRoute(builder: (_) => const TreasureUploadScreen()),
    );
    if (result == null) return;
    final listings = await _listingService.loadListings();
    if (!mounted) return;
    setState(() {
      _listings = listings
          .where((item) => !_blockedListingIds.contains(item.id))
          .toList();
      _syncError = _listingService.lastSyncError;
      _selectedListing = _listings.where((item) => item.id == result.id).firstOrNull ?? result;
    });
  }

  Future<void> _restoreSafetyState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final blocked = prefs.getStringList(_blockedListingsKey) ?? const <String>[];
      final reported = prefs.getStringList(_reportedListingsKey) ?? const <String>[];
      if (!mounted) return;
      setState(() {
        _blockedListingIds = blocked.toSet();
        _reportedListingIds = reported.toSet();
      });
    } catch (_) {
      // Ignore local persistence read errors.
    }
  }

  Future<void> _persistSafetyState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_blockedListingsKey, _blockedListingIds.toList());
      await prefs.setStringList(_reportedListingsKey, _reportedListingIds.toList());
    } catch (_) {
      // Ignore local persistence write errors.
    }
  }

  Future<void> _reportListing(TreasureListing listing) async {
    final l10n = AppLocalizations.of(context);
    final reasons = <String>[
      'Unpassender Inhalt',
      'Falsche Angaben',
      'Unfreundliches Verhalten',
      'Sonstiges',
    ];

    String selectedReason = reasons.first;
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.t('treasureReportTitle', fallback: 'Angebot melden')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    items: reasons
                        .map((reason) => DropdownMenuItem<String>(
                              value: reason,
                              child: Text(reason),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null || value.isEmpty) return;
                      setDialogState(() {
                        selectedReason = value;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: l10n.t(
                        'treasureReportNoteHint',
                        fallback: 'Optional: kurze Notiz für die Moderation',
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.t('treasureReportSubmit', fallback: 'Melden')),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) {
      noteController.dispose();
      return;
    }

    final sent = await _listingService.reportListing(
      listingId: listing.id,
      reason: selectedReason,
      note: noteController.text.trim(),
    );
    noteController.dispose();

    setState(() {
      _reportedListingIds = {..._reportedListingIds, listing.id};
      _syncError = _listingService.lastSyncError;
    });
    await _persistSafetyState();

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? l10n.t('treasureReportSuccess', fallback: 'Danke, wir prüfen diese Meldung.')
              : l10n.t(
                  'treasureReportLocalOnly',
                  fallback: 'Meldung lokal markiert. Server-Sync folgt, sobald verfügbar.',
                ),
        ),
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  Future<void> _blockListing(TreasureListing listing) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('treasureBlockTitle', fallback: 'Angebot ausblenden?')),
        content: Text(
          l10n.t(
            'treasureBlockText',
            fallback: 'Dieses Angebot wird lokal ausgeblendet und nicht mehr im Feed angezeigt.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.t('treasureBlockAction', fallback: 'Ausblenden')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _blockedListingIds = {..._blockedListingIds, listing.id};
      _listings = _listings.where((item) => item.id != listing.id).toList();
      if (_selectedListing?.id == listing.id) {
        _selectedListing = null;
      }
    });
    await _persistSafetyState();

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.t('treasureBlockSuccess', fallback: 'Angebot wurde aus deinem Feed ausgeblendet.'),
        ),
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  Widget _buildSyncErrorCard(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD8A8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.wifi_off_rounded, size: 16, color: Color(0xFFB45814)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _syncError ??
                  l10n.t(
                    'treasureSyncHintFallback',
                    fallback: 'Live-Sync ist gerade eingeschränkt. Zieh nach unten zum Aktualisieren.',
                  ),
              style: const TextStyle(
                color: Color(0xFF8A4310),
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _normalizeCategoryKey(String category) {
    final value = category.trim().toLowerCase();
    if (value.contains('fahr') || value == 'vehicles') return 'vehicles';
    if (value.contains('kleidung') || value == 'clothing') return 'clothing';
    if (value.contains('spiel') || value == 'toys') return 'toys';
    if (value.contains('buch') || value == 'books' || value == 'bücher') return 'books';
    if (value.contains('ausstatt') || value == 'equipment') return 'equipment';
    return 'toys';
  }

  Future<void> _openListingDetail(TreasureListing listing) async {
    final l10n = AppLocalizations.of(context);
    final conditionMeta = _conditionMeta(l10n, listing.conditionKey);
    final listedTimeLabel = _detailListedTimeLabel(context, l10n, listing.createdAt);
    final galleryPaths = listing.resolvedImagePaths;
    final hasImage = galleryPaths.isNotEmpty;
    final galleryController = PageController();
    final galleryIndex = ValueNotifier<int>(0);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final compactSheet = MediaQuery.sizeOf(context).width < 390;
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.55,
          maxChildSize: 0.94,
          expand: false,
          builder: (context, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF6F9FE),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD3DDEC),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 260,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: hasImage
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFFFDF1E8), Color(0xFFEFF4FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: hasImage ? const Color(0xFF14283F) : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: ValueListenableBuilder<int>(
                        valueListenable: galleryIndex,
                        builder: (context, currentIndex, _) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              if (hasImage)
                                PageView.builder(
                                  controller: galleryController,
                                  itemCount: galleryPaths.length,
                                  onPageChanged: (index) {
                                    galleryIndex.value = index;
                                  },
                                  itemBuilder: (context, index) {
                                    return GestureDetector(
                                      onTap: () => _openFullscreenGallery(
                                        galleryPaths: galleryPaths,
                                        initialIndex: index,
                                        title: listing.title,
                                      ),
                                      child: _buildTreasureImageByPath(
                                        galleryPaths[index],
                                        fit: BoxFit.cover,
                                        errorWidget: const SizedBox.shrink(),
                                      ),
                                    );
                                  },
                                )
                              else
                                Center(
                                  child: Icon(
                                    _categoryIcon(listing.category),
                                    size: 96,
                                    color: const Color(0x22D96C2F),
                                  ),
                                ),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: hasImage
                                        ? [
                                            Colors.black.withValues(alpha: 0.06),
                                            Colors.black.withValues(alpha: 0.52),
                                          ]
                                        : [Colors.transparent, Colors.transparent],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 16,
                                top: 16,
                                child: _PreviewBadge(
                                  icon: conditionMeta.$5,
                                  label: conditionMeta.$1,
                                  background: conditionMeta.$3,
                                  foreground: conditionMeta.$4,
                                ),
                              ),
                              if (listing.photoCount > 1)
                                Positioned(
                                  right: 16,
                                  top: 16,
                                  child: _PreviewBadge(
                                    icon: Icons.collections_rounded,
                                    label: '${currentIndex + 1}/${listing.photoCount}',
                                    background: Colors.black.withValues(alpha: 0.28),
                                    foreground: Colors.white,
                                  ),
                                ),
                              if (hasImage)
                                Positioned(
                                  right: 16,
                                  bottom: 16,
                                  child: GestureDetector(
                                    onTap: () => _openFullscreenGallery(
                                      galleryPaths: galleryPaths,
                                      initialIndex: currentIndex,
                                      title: listing.title,
                                    ),
                                    child: Tooltip(
                                      message: l10n.t('treasureOpenGallery', fallback: 'Galerie öffnen'),
                                      child: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.28),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: const Icon(
                                          Icons.open_in_full_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: 16,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      listing.title,
                                      style: TextStyle(
                                        color: hasImage ? Colors.white : const Color(0xFF152B42),
                                        fontSize: compactSheet ? 21 : 24,
                                        fontWeight: FontWeight.w800,
                                        height: 1.15,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.tFormat(
                                        'treasureDistanceMeters',
                                        {'meters': '${listing.distanceMeters}'},
                                        fallback: '${listing.distanceMeters} m entfernt',
                                      ),
                                      style: TextStyle(
                                        color: hasImage ? Colors.white70 : const Color(0xFF607286),
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  if (listing.photoCount > 1) ...[
                    const SizedBox(height: 12),
                    ValueListenableBuilder<int>(
                      valueListenable: galleryIndex,
                      builder: (context, currentIndex, _) {
                        final thumbSize = compactSheet ? 64.0 : 72.0;
                        return SizedBox(
                          height: thumbSize,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: galleryPaths.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final isSelected = index == currentIndex;
                              return GestureDetector(
                                onTap: () {
                                  if (isSelected) {
                                    _openFullscreenGallery(
                                      galleryPaths: galleryPaths,
                                      initialIndex: index,
                                      title: listing.title,
                                    );
                                    return;
                                  }
                                  galleryController.animateToPage(
                                    index,
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOut,
                                  );
                                },
                                child: Container(
                                  width: thumbSize,
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF1E5CD7)
                                          : const Color(0xFFDCE6F3),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: _buildTreasureImageByPath(
                                      galleryPaths[index],
                                      fit: BoxFit.cover,
                                      errorWidget: const DecoratedBox(
                                        decoration: BoxDecoration(color: Color(0xFFF4F7FC)),
                                        child: SizedBox.expand(),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    l10n.t('treasureDetailSectionAbout', fallback: 'Auf einen Blick'),
                    style: TextStyle(
                      fontSize: compactSheet ? 14 : 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF152B42),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _DetailLine(
                    icon: Icons.category_rounded,
                    text: listing.category,
                  ),
                  if (listing.locationLabel != null &&
                      listing.locationLabel!.trim().isNotEmpty)
                    _DetailLine(
                      icon: Icons.place_outlined,
                      text: l10n.tFormat(
                        'treasurePickupAreaLine',
                        {'area': listing.locationLabel!},
                        fallback: 'Abholbereich: ${listing.locationLabel!}',
                      ),
                    ),
                  _DetailLine(
                    icon: Icons.straighten_rounded,
                    text: l10n.tFormat(
                      'treasureSizeAgeLine',
                      {'sizeAge': listing.sizeAge},
                      fallback: 'Größe/Alter: ${listing.sizeAge}',
                    ),
                  ),
                  _DetailLine(
                    icon: conditionMeta.$5,
                    text: l10n.tFormat(
                      'treasureConditionLine',
                      {'condition': conditionMeta.$1},
                      fallback: 'Zustand: ${conditionMeta.$1}',
                    ),
                  ),
                  _DetailLine(
                    icon: Icons.palette_outlined,
                    text: l10n.tFormat(
                      'treasureColorLine',
                      {'color': listing.colorLabel},
                      fallback: 'Farbe: ${listing.colorLabel}',
                    ),
                  ),
                  _DetailLine(
                    icon: Icons.access_time_rounded,
                    text: l10n.tFormat(
                      'treasureListedAgoLine',
                      {'time': listedTimeLabel},
                      fallback: 'Eingestellt: $listedTimeLabel',
                    ),
                  ),
                  if (listing.ratingCount > 0)
                    _DetailLine(
                      icon: Icons.star_rounded,
                      text: l10n.tFormat(
                        'treasureRatingLine',
                        {
                          'rating': listing.rating.toStringAsFixed(1),
                          'count': '${listing.ratingCount}',
                        },
                        fallback:
                            'Bewertung: ${listing.rating.toStringAsFixed(1)} (${listing.ratingCount})',
                      ),
                    ),
                  if (listing.views > 0)
                    _DetailLine(
                      icon: Icons.visibility_outlined,
                      text: l10n.tFormat(
                        'treasureViewsLine',
                        {'count': '${listing.views}'},
                        fallback: '${listing.views} Aufrufe',
                      ),
                    ),
                  if (listing.note.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      l10n.t('treasureFamilyNoteTitle', fallback: 'Hinweis von der Familie'),
                      style: TextStyle(
                        fontSize: compactSheet ? 14 : 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF152B42),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      listing.note,
                      style: const TextStyle(
                        color: Color(0xFF607286),
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    l10n.t('treasureDetailSectionPickup', fallback: 'Abholung & Übergabe'),
                    style: TextStyle(
                      fontSize: compactSheet ? 14 : 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF152B42),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.t('treasureContactlessHint', fallback: 'Kontaktlos möglich'),
                    style: const TextStyle(
                      color: Color(0xFF607286),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_selectedListing?.id == listing.id) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF1FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        l10n.t('treasureDetailSelectedHint', fallback: 'Dieser Schatz ist aktuell für deine Übergabe vorgemerkt.'),
                        style: const TextStyle(
                          color: Color(0xFF1E5CD7),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrowActions = constraints.maxWidth < 360;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: narrowActions
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 8) / 2,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _reportListing(listing);
                              },
                              icon: Icon(
                                Icons.flag_outlined,
                                size: narrowActions ? 17 : 18,
                              ),
                              label: Text(
                                l10n.t('treasureReportAction', fallback: 'Melden'),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: narrowActions
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 8) / 2,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _blockListing(listing);
                              },
                              icon: Icon(
                                Icons.block_rounded,
                                size: narrowActions ? 17 : 18,
                              ),
                              label: Text(
                                l10n.t('treasureBlockAction', fallback: 'Ausblenden'),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: const Color(0xFF1E5CD7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedListing = listing;
                      });
                      Navigator.of(context).pop();
                      final messenger = ScaffoldMessenger.of(this.context);
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.tFormat(
                              'treasureSelectionConfirmed',
                              {'title': listing.title},
                              fallback: '${listing.title} ist jetzt für deine Übergabe vorgemerkt.',
                            ),
                          ),
                          behavior: SnackBarBehavior.fixed,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_rounded),
                    label: Text(
                      l10n.t(
                        'treasureSelectForHandover',
                        fallback:
                            compactSheet ? 'Für Übergabe' : 'Für Übergabe wählen',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    galleryController.dispose();
    galleryIndex.dispose();
  }

  bool _isJustListed(DateTime createdAt) {
    final age = DateTime.now().difference(createdAt);
    return age.inHours < 6;
  }

  bool _isFreshToday(DateTime createdAt) {
    final age = DateTime.now().difference(createdAt);
    return age.inHours < 24;
  }

  String? _freshnessTimeLabel(AppLocalizations l10n, DateTime createdAt) {
    final age = DateTime.now().difference(createdAt);
    if (age.isNegative || age.inHours >= 24) {
      return null;
    }
    if (age.inMinutes < 60) {
      final minutes = age.inMinutes.clamp(1, 59);
      return l10n.tFormat(
        'treasureMinutesAgoShort',
        {'count': '$minutes'},
        fallback: 'vor $minutes Min.',
      );
    }
    final hours = age.inHours.clamp(1, 23);
    return l10n.tFormat(
      'treasureHoursAgoShort',
      {'count': '$hours'},
      fallback: 'vor $hours Std.',
    );
  }

  String _detailListedTimeLabel(
    BuildContext context,
    AppLocalizations l10n,
    DateTime createdAt,
  ) {
    final relative = _freshnessTimeLabel(l10n, createdAt);
    if (relative != null) {
      return relative;
    }
    return MaterialLocalizations.of(context).formatShortDate(createdAt.toLocal());
  }

  Future<void> _openFullscreenGallery({
    required List<String> galleryPaths,
    required int initialIndex,
    required String title,
  }) async {
    if (galleryPaths.isEmpty) {
      return;
    }
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.94),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, __) {
        return _TreasureFullscreenGallery(
          title: title,
          galleryPaths: galleryPaths,
          initialIndex: initialIndex,
        );
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final eased = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: eased,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(eased),
            child: child,
          ),
        );
      },
    );
  }

  (String, String, Color, Color, IconData) _conditionMeta(
    AppLocalizations l10n,
    String conditionKey,
  ) {
    switch (conditionKey) {
      case 'studio':
        return (
          l10n.t('treasureConditionLikeNew', fallback: 'Wie neu'),
          l10n.t('treasureConditionLikeNewHint', fallback: 'Sehr gepflegt, fast wie neu.'),
          const Color(0xFFE8F1FF),
          const Color(0xFF2D62F0),
          Icons.diamond_rounded,
        );
      case 'wild':
        return (
          l10n.t('treasureConditionRaider', fallback: 'Mit Spuren'),
          l10n.t('treasureConditionRaiderHint', fallback: 'Mit Spuren, aber bereit fürs nächste Abenteuer.'),
          const Color(0xFFFFF1E5),
          const Color(0xFFD96C2F),
          Icons.park_rounded,
        );
      default:
        return (
          l10n.t('treasureConditionGood', fallback: 'Gut genutzt'),
          l10n.t('treasureConditionGoodHint', fallback: 'Sichtbar genutzt, voll einsatzbereit.'),
          const Color(0xFFEAF7EF),
          const Color(0xFF1F9C5D),
          Icons.autorenew_rounded,
        );
    }
  }

  IconData _categoryIcon(String category) {
    final value = category.toLowerCase();
    if (value.contains('fahr')) return Icons.pedal_bike_rounded;
    if (value.contains('kleidung')) return Icons.checkroom_rounded;
    if (value.contains('buch')) return Icons.menu_book_rounded;
    if (value.contains('ausstattung')) return Icons.stroller_rounded;
    return Icons.toys_rounded;
  }

  Widget _buildCoffeeSlotPicker(
    ThemeData theme,
    AppLocalizations l10n,
    List<String> coffeeSlots,
  ) {
    return _PickerFrame(
      title: l10n.t('treasureTimeWindowLabel', fallback: 'Verfügbare Zeiten'),
      subtitle: l10n.t('treasureCoffeeSlotHint', fallback: 'Wähle ein Zeitfenster'),
      child: Column(
        children: coffeeSlots
            .map(
              (slot) => _SelectableOptionTile(
                label: slot,
                selected: _selectedSlot == slot,
                onTap: () {
                  setState(() {
                    _selectedSlot = slot;
                  });
                },
                textStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A2A3A),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildDropPointPicker(
    ThemeData theme,
    AppLocalizations l10n,
    List<String> dropPoints,
  ) {
    return _PickerFrame(
      title: l10n.t('treasureContactlessPointLabel', fallback: 'Kontaktloser Abholpunkt'),
      subtitle: l10n.t('treasureDropPointHint', fallback: 'Wähle einen Abholpunkt'),
      child: Column(
        children: dropPoints
            .map(
              (point) => _SelectableOptionTile(
                label: point,
                selected: _selectedDropPoint == point,
                onTap: () {
                  setState(() {
                    _selectedDropPoint = point;
                  });
                },
                textStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A2A3A),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildSelectedModePanel(AppLocalizations l10n) {
    final compactScreen = MediaQuery.sizeOf(context).width < 390;
    final isCoffee = _selectedMode == TreasureHandoverMode.coffeeChat;
    final icon = isCoffee ? Icons.groups_rounded : Icons.inventory_2_rounded;
    final title = isCoffee
        ? l10n.t('treasureHandoverCoffeeMode', fallback: 'Kurz treffen')
        : l10n.t('treasureHandoverFlyingSwap', fallback: 'Still tauschen');
    final detail = isCoffee
        ? l10n.t('treasureHandoverCoffeeModeText', fallback: 'Kurz hallo, übergeben, fertig.')
        : l10n.t('treasureHandoverFlyingSwapText', fallback: 'Kontaktlos abholen, wenn es passt.');
    final background = isCoffee ? const Color(0xFFFFF3EA) : const Color(0xFFEFF9F2);
    final foreground = isCoffee ? const Color(0xFFD96C2F) : const Color(0xFF1F9C5D);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EDF8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: foreground),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: compactScreen ? 14 : 15,
                    color: const Color(0xFF14283F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: compactScreen ? 12.2 : 13,
                    color: const Color(0xFF5D6F84),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: compactScreen ? 2 : null,
                  overflow: compactScreen ? TextOverflow.ellipsis : TextOverflow.visible,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidingTextCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EDF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${l10n.t('treasureGuidelineHonest', fallback: 'Ehrlich teilen statt perfekt inszenieren.')} '
            '${l10n.t('treasureGuidelineNoPressure', fallback: 'Gebrauchsspuren sind okay.')} '
            '${l10n.t('treasureGuidelineTempo', fallback: 'Du entscheidest das Tempo: mit Treffen oder kontaktlos.')} '
            '${l10n.t('treasureGuidelineCommunity', fallback: 'So wird Teilen im Viertel leicht.')}',
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF31465F),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Rechtlicher Hinweis: Parentpeak ist im Verschenkmarkt nur Vermittler. Für Zustand, Sicherheit und Übergabe der Artikel sind ausschließlich die beteiligten Nutzer verantwortlich.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Color(0xFF5D6F84),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSelection() {
    final l10n = AppLocalizations.of(context);
    final modeLabel = _selectedMode == TreasureHandoverMode.coffeeChat
      ? l10n.t('treasureHandoverCoffeeMode', fallback: 'Kurz treffen')
      : l10n.t('treasureHandoverFlyingSwap', fallback: 'Still tauschen');
    final detail = _selectedMode == TreasureHandoverMode.coffeeChat
        ? _selectedSlot
        : _selectedDropPoint;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.tFormat(
            'treasureReservationPrepared',
            {
              'title': _selectedListing?.title ?? l10n.t('treasureReserveTitle', fallback: 'Übergabe planen'),
              'mode': modeLabel,
              'detail': detail ?? '',
            },
            fallback: '${_selectedListing?.title ?? l10n.t('treasureReserveTitle', fallback: 'Übergabe planen')}: $modeLabel - $detail',
          ),
        ),
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }
}

class _ModeSegmentedSwitch extends StatelessWidget {
  const _ModeSegmentedSwitch({
    required this.selectedMode,
    required this.coffeeLabel,
    required this.flyingLabel,
    required this.onChanged,
  });

  final TreasureHandoverMode selectedMode;
  final String coffeeLabel;
  final String flyingLabel;
  final ValueChanged<TreasureHandoverMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _ModeSegmentButton(
            label: coffeeLabel,
            icon: Icons.groups_rounded,
            selected: selectedMode == TreasureHandoverMode.coffeeChat,
            onTap: () => onChanged(TreasureHandoverMode.coffeeChat),
          ),
          const SizedBox(width: 4),
          _ModeSegmentButton(
            label: flyingLabel,
            icon: Icons.inventory_2_rounded,
            selected: selectedMode == TreasureHandoverMode.flyingSwap,
            onTap: () => onChanged(TreasureHandoverMode.flyingSwap),
          ),
        ],
      ),
    );
  }
}

class _ModeSegmentButton extends StatelessWidget {
  const _ModeSegmentButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x121E5CD7),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? const Color(0xFF1E5CD7) : const Color(0xFF607286),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? const Color(0xFF1E5CD7) : const Color(0xFF607286),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerFrame extends StatelessWidget {
  const _PickerFrame({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6EDF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF152B42),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF5D6F84),
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _SelectableOptionTile extends StatelessWidget {
  const _SelectableOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.textStyle,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF1FF) : const Color(0xFFF8FAFD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF1E5CD7) : const Color(0xFFDDE7F5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: textStyle,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? const Color(0xFF1E5CD7) : const Color(0xFF8EA0B5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 155 : 180),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 9,
          vertical: compact ? 5.5 : 6,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 13 : 14, color: foreground),
            SizedBox(width: compact ? 4 : 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 11.2 : 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaHintChip extends StatelessWidget {
  const _MetaHintChip({
    required this.icon,
    required this.label,
    this.background = const Color(0xFFF7F9FD),
    this.foreground = const Color(0xFF607286),
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 200 : 240),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 9 : 10,
          vertical: compact ? 6 : 7,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 13 : 14, color: foreground),
            SizedBox(width: compact ? 5 : 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 11.2 : 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: compact ? 17 : 18, color: const Color(0xFF607286)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: const Color(0xFF31465F),
                fontWeight: FontWeight.w600,
                height: 1.35,
                fontSize: compact ? 13.2 : 14,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TreasureFullscreenGallery extends StatefulWidget {
  const _TreasureFullscreenGallery({
    required this.title,
    required this.galleryPaths,
    required this.initialIndex,
  });

  final String title;
  final List<String> galleryPaths;
  final int initialIndex;

  @override
  State<_TreasureFullscreenGallery> createState() => _TreasureFullscreenGalleryState();
}

class _TreasureFullscreenGalleryState extends State<_TreasureFullscreenGallery> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.galleryPaths.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.galleryPaths.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: _buildTreasureImageByPath(
                        widget.galleryPaths[index],
                        fit: BoxFit.contain,
                        errorWidget: const SizedBox.shrink(),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _PreviewBadge(
                          icon: Icons.collections_rounded,
                          label: '${_currentIndex + 1}/${widget.galleryPaths.length}',
                          background: Colors.white.withValues(alpha: 0.14),
                          foreground: Colors.white,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.cancel,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            if (widget.galleryPaths.length > 1)
              Positioned(
                left: 16,
                right: 16,
                bottom: 20,
                child: SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.galleryPaths.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final isSelected = index == _currentIndex;
                      return GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          );
                        },
                        child: Container(
                          width: 72,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.28),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: _buildTreasureImageByPath(
                              widget.galleryPaths[index],
                              fit: BoxFit.cover,
                              errorWidget: const DecoratedBox(
                                decoration: BoxDecoration(color: Color(0xFF1B1F26)),
                                child: SizedBox.expand(),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Widget _buildTreasureImageByPath(
  String path, {
  required BoxFit fit,
  required Widget errorWidget,
}) {
  final trimmed = path.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return Image.network(
      trimmed,
      fit: fit,
      errorBuilder: (_, __, ___) => errorWidget,
    );
  }

  return Image.file(
    File(trimmed),
    fit: fit,
    errorBuilder: (_, __, ___) => errorWidget,
  );
}
