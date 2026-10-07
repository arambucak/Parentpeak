import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/treasure_photo_analysis_service.dart';
import 'package:parentpeak/logic/treasure_draft_images.dart';
import 'package:parentpeak/models/treasure_category.dart';
import 'package:parentpeak/ui/widgets/account_ai_consent_dialog.dart';
import 'package:parentpeak/services/image_upload_service.dart';
import 'package:parentpeak/services/location_service.dart';
import 'package:parentpeak/logic/treasure_listing_service.dart';
import 'package:parentpeak/ui/widgets/treasure_account_boundary.dart';
import 'package:parentpeak/ui/widgets/treasure_legacy_card.dart';
import 'package:parentpeak/l10n/app_localizations.dart';
import 'package:parentpeak/models/treasure_listing.dart';
import 'package:parentpeak/ui/widgets/safe_image.dart';

class TreasureUploadScreen extends StatelessWidget {
  const TreasureUploadScreen({
    super.key,
    this.photoAnalysisService,
    this.imagePicker,
    this.listingService,
    this.imageUploadService,
    this.draftImages = const TreasureDraftImages(),
  });

  final TreasurePhotoAnalysisService? photoAnalysisService;
  final ImagePicker? imagePicker;
  final TreasureListingService? listingService;
  final ImageUploadService? imageUploadService;
  final TreasureDraftImages draftImages;

  @override
  Widget build(BuildContext context) {
    final service = listingService ?? TreasureListingService.instance;
    return TreasureAccountBoundary(
      store: service.store,
      builder: (_) => _ScopedTreasureUploadScreen(
        imagePicker: imagePicker, photoAnalysisService: photoAnalysisService,
        listingService: service,
        imageUploadService: imageUploadService, draftImages: draftImages,
      ),
    );
  }
}

class _ScopedTreasureUploadScreen extends StatefulWidget {
  const _ScopedTreasureUploadScreen({
    this.imagePicker, this.photoAnalysisService, required this.listingService,
    this.imageUploadService, required this.draftImages,
  });
  final ImagePicker? imagePicker;
  final TreasurePhotoAnalysisService? photoAnalysisService;
  final TreasureListingService listingService;
  final ImageUploadService? imageUploadService;
  final TreasureDraftImages draftImages;

  @override
  State<_ScopedTreasureUploadScreen> createState() => _TreasureUploadScreenState();
}

class _TreasureUploadScreenState extends State<_ScopedTreasureUploadScreen> {
  static const String _defaultCategoryKey = 'vehicles';
  static const double _defaultRadiusKm = 1;
  static const int _defaultConditionIndex = 1;
  late String _defaultTitle;
  late String _defaultColor;
  late String _defaultSizeAge;
  bool _defaultsInitialized = false;

  int _conditionIndex = 1;
  List<XFile> _selectedImages = const [];
  bool _isAnalyzingImage = false;
  bool _imageAnalysisFailed = false;
  String _selectedCategoryKey = _defaultCategoryKey;
  double _shareRadiusKm = _defaultRadiusKm;
  bool _draftHydrated = false;
  bool _publishing = false;
  bool _publishOutcomeUnknown = false;
  TreasureListing? _publishedListing;
  bool _publishedLocalFailed = false;
  int _draftRevision = 0;
  Timer? _draftDebounce;
  late final ImagePicker _imagePicker = widget.imagePicker ?? ImagePicker();
  late final TreasurePhotoAnalysisService _photoAnalysis =
      widget.photoAnalysisService ?? TreasurePhotoAnalysisService();
  int _analysisRequest = 0;
  late final TreasureListingService _listingService =
      widget.listingService.forScope(widget.listingService.store.scope);
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _sizeAgeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_onAnalysisAccountChanged);
    _titleController.addListener(_onDraftChanged);
    _colorController.addListener(_onDraftChanged);
    _noteController.addListener(_onDraftChanged);
    _sizeAgeController.addListener(_onDraftChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_defaultsInitialized) return;
    final l10n = AppLocalizations.of(context);
    _defaultTitle = l10n.t('treasureDefaultTitle');
    _defaultColor = l10n.t('treasureDefaultColor');
    _defaultSizeAge = l10n.t('treasureDefaultSizeAge');
    _titleController.text = _defaultTitle;
    _colorController.text = _defaultColor;
    _sizeAgeController.text = _defaultSizeAge;
    _defaultsInitialized = true;
    unawaited(_restoreDraft());
  }

  @override
  void dispose() {
    _listingService.dispose();
    AuthService.instance.removeListener(_onAnalysisAccountChanged);
    _analysisRequest++;
    _draftDebounce?.cancel();
    _titleController.removeListener(_onDraftChanged);
    _colorController.removeListener(_onDraftChanged);
    _noteController.removeListener(_onDraftChanged);
    _sizeAgeController.removeListener(_onDraftChanged);
    _selectedImages = const [];
    _titleController.clear();
    _colorController.clear();
    _noteController.clear();
    _sizeAgeController.clear();
    _titleController.dispose();
    _colorController.dispose();
    _noteController.dispose();
    _sizeAgeController.dispose();
    super.dispose();
  }

  void _invalidateAnalysis() {
    _analysisRequest++;
    _isAnalyzingImage = false;
    _imageAnalysisFailed = false;
  }

  void _onAnalysisAccountChanged() {
    if (mounted) setState(_invalidateAnalysis);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final contentMaxWidth = viewportWidth >= 1200
        ? 920.0
        : viewportWidth >= 900
        ? 820.0
        : double.infinity;
    final horizontalPadding = viewportWidth >= 900 ? 24.0 : 16.0;
    final hasSelectedImages = _selectedImages.isNotEmpty;
    final conditions = [
      (
        l10n.t('treasureConditionLikeNew', fallback: 'Studio-Zustand'),
        l10n.t(
          'treasureConditionLikeNewHint',
          fallback: 'Sehr gepflegt, fast wie neu.',
        ),
        const Color(0xFFE8F1FF),
        const Color(0xFF2D62F0),
        Icons.diamond_rounded,
      ),
      (
        l10n.t('treasureConditionGood', fallback: 'Runde 2'),
        l10n.t(
          'treasureConditionGoodHint',
          fallback: 'Sichtbar genutzt, voll einsatzbereit.',
        ),
        const Color(0xFFEAF7EF),
        const Color(0xFF1F9C5D),
        Icons.autorenew_rounded,
      ),
      (
        l10n.t('treasureConditionRaider', fallback: 'Wildnis-Modus'),
        l10n.t(
          'treasureConditionRaiderHint',
          fallback: 'Mit Spuren, aber bereit fürs nächste Abenteuer.',
        ),
        const Color(0xFFFFF1E5),
        const Color(0xFFD96C2F),
        Icons.park_rounded,
      ),
    ];
    final categoryOptions = [
      ('vehicles', l10n.t('treasureCategoryVehicles', fallback: 'Fahrzeuge')),
      ('clothing', l10n.t('treasureCategoryClothing', fallback: 'Kleidung')),
      ('toys', l10n.t('treasureCategoryToys', fallback: 'Spielzeug')),
      ('books', l10n.t('treasureCategoryBooks', fallback: 'Bücher')),
      (
        'equipment',
        l10n.t('treasureCategoryEquipment', fallback: 'Ausstattung'),
      ),
      ('other', l10n.t('treasureCategoryOther')),
    ];

    final currentCondition = conditions[_conditionIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F9FE),
        elevation: 0,
        foregroundColor: const Color(0xFF172538),
        title: Text(
          l10n.t('treasureUploadTitle', fallback: 'Schatz teilen'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              8,
              horizontalPadding,
              24,
            ),
            children: [
              _buildCameraStage(l10n),
              TreasureLegacyCard(store: _listingService.store, onClaimed: _restoreDraft),
              if (_selectedImages.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildSelectedPhotosStrip(l10n),
              ],
              const SizedBox(height: 14),
              _buildAiSuggestions(l10n),
              const SizedBox(height: 14),
              _buildBasicsCard(l10n, categoryOptions),
              const SizedBox(height: 14),
              _buildConditionCarousel(l10n, conditions),
              const SizedBox(height: 14),
              _buildSizeAgeCard(l10n),
              const SizedBox(height: 14),
              _buildDistanceCard(l10n),
              const SizedBox(height: 14),
              _buildLocationCard(l10n),
              const SizedBox(height: 14),
              _buildNoteCard(l10n),
              const SizedBox(height: 16),
              _buildPreviewCard(l10n, currentCondition),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: const Color(0xFF1E5CD7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _publishing || _publishOutcomeUnknown || _publishedListing != null ? null : () => _runPublish(() async {
                  final owner = _listingService.scope;
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  if (_listingService.store.userId == null || !_listingService.isBackendEnabled) {
                    messenger.showSnackBar(SnackBar(content: Text(l10n.t('treasure_publish_unavailable'))));
                    return;
                  }
                  if (!hasSelectedImages) {
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.t(
                            'treasurePhotoMissing',
                            fallback:
                                'Fueg zuerst ein Foto hinzu, damit Familien sofort sehen, worum es geht.',
                          ),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  final loc = LocationService.instance;
                  if (!loc.hasLocation) {
                    final located = await loc.requestGPSLocation();
                    if (!mounted) return;
                    _listingService.store.requireScope(owner);
                    if (!located || !loc.hasLocation) {
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(content: Text(l10n.t('location_denied'))),
                      );
                      return;
                    }
                  }
                  // Bilder JETZT hochladen (XFiles sind hier frisch/gültig)
                  final uploadedUrls = await (widget.imageUploadService ?? ImageUploadService.instance)
                      .uploadImages(List.of(_selectedImages), requireCurrent: () {
                        if (!mounted) throw StateError('Upload screen closed');
                        _listingService.store.requireScope(owner);
                      });
                  if (!mounted) return;
                  _listingService.store.requireScope(owner);
                  if (uploadedUrls.isEmpty) {
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.t(
                            'treasureImageUploadFailed',
                            fallback:
                                'Bild-Upload fehlgeschlagen. Bitte versuch es erneut.',
                          ),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  final locationLabel = loc.city ?? l10n.t('location');
                  final locationCoords = (loc.latitude!, loc.longitude!);
                  final title = _titleController.text.trim().isEmpty
                      ? l10n.t(
                          'treasureTitlePlaceholder',
                          fallback: 'Rotes Laufrad',
                        )
                      : _titleController.text.trim();
                  final color = _colorController.text.trim().isEmpty
                      ? l10n.t('treasureNeutralColor')
                      : _colorController.text.trim();
                  final note = _noteController.text.trim();
                  final listing = TreasureListing(
                    id: 'treasure-${DateTime.now().millisecondsSinceEpoch}',
                    title: title,
                    category: _selectedCategoryKey,
                    sizeAge: _sizeAgeController.text.trim().isEmpty
                        ? l10n.t(
                            'treasureSizeAgePlaceholder',
                            fallback: '2 bis 3 Jahre',
                          )
                        : _sizeAgeController.text.trim(),
                    conditionKey: _conditionKeyForIndex(_conditionIndex),
                    distanceMeters: null,
                    shareRadiusKm: _shareRadiusKm,
                    colorLabel: color,
                    note: note,
                    locationLabel: locationLabel,
                    latitude: locationCoords.$1,
                    longitude: locationCoords.$2,
                    imagePath: uploadedUrls.first,
                    imagePaths: uploadedUrls,
                    createdAt: DateTime.now(),
                  );
                  _publishOutcomeUnknown = true;
                  final createdListing = await _listingService
                      .createListing(
                        listing,
                        userId: _listingService.store.userId,
                      );
                  if (createdListing == null) {
                    if (!mounted) return;
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.t(
                            'treasure_publish_uncertain',
                            fallback:
                                'Das Veröffentlichen hat gerade nicht geklappt. Dein Entwurf bleibt erhalten.',
                          ),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  _publishOutcomeUnknown = false;
                  _publishedListing = createdListing;
                  _draftDebounce?.cancel();
                  await _listingService.clearDraft();
                  if (!mounted) return;
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.t(
                          'treasureUploadSuccess',
                          fallback: 'Dein Schatz ist jetzt sichtbar.',
                        ),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  navigator.pop(createdListing);
                }),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  l10n.t('treasurePublishNow', fallback: 'Jetzt teilen'),
                ),
              ),
              const SizedBox(height: 10),
              Text(l10n.t('treasure_photos_public_info')),
              if (_publishedLocalFailed)
                Text(l10n.t('treasure_published_local_failed')),
              if (_publishOutcomeUnknown)
                Text(l10n.t('treasure_publish_uncertain')),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _publishing || _publishedListing != null ? null : () {
                  unawaited(_persistDraft(showFeedback: true));
                },
                icon: const Icon(Icons.bookmark_border_rounded),
                label: Text(
                  l10n.t('treasureSaveDraft', fallback: 'Entwurf speichern'),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _publishing ? null : _confirmDiscardDraft,
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(l10n.t('treasureDiscard', fallback: 'Verwerfen')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraStage(AppLocalizations l10n) {
    final primaryImage = _primarySelectedImage;
    final hasSelectedImages = primaryImage != null;
    return Container(
      height: 280,
      decoration: BoxDecoration(
        gradient: !hasSelectedImages
            ? const LinearGradient(
                colors: [Color(0xFF11203A), Color(0xFF223A65)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: !hasSelectedImages ? null : const Color(0xFF11203A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          if (primaryImage != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SafeXFileImage(file: primaryImage, fit: BoxFit.cover),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: !hasSelectedImages
                      ? [Colors.transparent, Colors.transparent]
                      : [
                          Colors.black.withValues(alpha: 0.12),
                          Colors.black.withValues(alpha: 0.48),
                        ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t(
                      'treasureUploadSubtitle',
                      fallback: 'Ein Foto reicht für den Start',
                    ),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.t(
                      'treasurePhotoSectionHint',
                      fallback:
                          'Zeig den Gegenstand einfach so, wie er gerade ist.',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      _ActionGlassChip(
                        icon: hasSelectedImages
                            ? Icons.add_a_photo_rounded
                            : Icons.photo_camera_back_rounded,
                        label: hasSelectedImages
                            ? l10n.t(
                                'treasureAddMorePhotos',
                                fallback: 'Mehr Fotos',
                              )
                            : l10n.t(
                                'treasureTakePhoto',
                                fallback: 'Foto machen',
                              ),
                        onTap: _pickCameraImage,
                      ),
                      const SizedBox(width: 8),
                      _ActionGlassChip(
                        icon: hasSelectedImages
                            ? Icons.collections_rounded
                            : Icons.photo_library_outlined,
                        label: hasSelectedImages
                            ? l10n.tFormat(
                                'treasurePhotoCount',
                                {'count': '${_selectedImages.length}'},
                                fallback: '${_selectedImages.length} Fotos',
                              )
                            : l10n.t(
                                'treasureChooseFromLibrary',
                                fallback: 'Aus Mediathek',
                              ),
                        onTap: _pickGalleryImages,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!hasSelectedImages)
            Center(
              child: Container(
                width: 210,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 1.4,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.toys_rounded,
                    size: 42,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          if (hasSelectedImages)
            Positioned(
              right: 16,
              top: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.tFormat(
                    'treasurePhotoCount',
                    {'count': '${_selectedImages.length}'},
                    fallback: '${_selectedImages.length} Fotos',
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAiSuggestions(AppLocalizations l10n) {
    final categoryLabel = _categoryLabelForKey(l10n, _selectedCategoryKey);
    final colorLabel = _colorController.text.trim().isEmpty
        ? l10n.t('treasureColorLabel', fallback: 'Farbe')
        : _colorController.text.trim();
    final sizeAgeLabel = _sizeAgeController.text.trim().isEmpty
        ? l10n.t('treasureSizeAgePlaceholder', fallback: '2-4 Jahre')
        : _sizeAgeController.text.trim();
    return _SectionFrame(
      title: l10n.t('treasureAiTitle', fallback: 'Schnell erkannt'),
      subtitle: l10n.t(
        'treasureAiHelper',
        fallback: 'Wir schlagen dir Kategorie und Farbe direkt vor.',
      ),
      child: _isAnalyzingImage
          ? Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(l10n.t('treasurePhotoAnalyzing'))),
              ],
            )
          : _imageAnalysisFailed
          ? Row(
              children: [
                Expanded(child: Text(l10n.t('treasure_photo_analysis_failed'))),
                TextButton.icon(
                  onPressed: _primarySelectedImage == null
                      ? null
                      : () => _analyzeImageWithAI(_primarySelectedImage!),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.t('try_again')),
                ),
              ],
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TagChip(label: categoryLabel),
                _TagChip(label: colorLabel),
                _TagChip(label: sizeAgeLabel),
                _TagChip(
                  label: _selectedImages.isEmpty
                      ? l10n.t('treasureAiAccept', fallback: 'Übernehmen')
                      : l10n.tFormat(
                          'treasurePhotoCount',
                          {'count': '${_selectedImages.length}'},
                          fallback: '${_selectedImages.length} Fotos',
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSelectedPhotosStrip(AppLocalizations l10n) {
    return _SectionFrame(
      title: l10n.t('treasurePhotoReady', fallback: 'Foto bereit'),
      subtitle: l10n.t(
        'treasurePhotoGalleryHint',
        fallback: 'Wähle ein Coverbild oder entferne Extras.',
      ),
      child: SizedBox(
        height: 98,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            final image = _selectedImages[index];
            final isCover = index == 0;
            return Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _promoteSelectedImage(index),
                  child: Container(
                    width: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isCover
                            ? const Color(0xFF1E5CD7)
                            : const Color(0xFFDCE6F3),
                        width: isCover ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: SafeXFileImage(file: image, fit: BoxFit.cover),
                    ),
                  ),
                ),
                if (isCover)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E5CD7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l10n.t('treasureCoverPhotoLabel', fallback: 'Cover'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _removeSelectedImageAt(index),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemCount: _selectedImages.length,
        ),
      ),
    );
  }

  Widget _buildBasicsCard(
    AppLocalizations l10n,
    List<(String, String)> categoryOptions,
  ) {
    return _SectionFrame(
      title: l10n.t(
        'treasureUploadHeadline',
        fallback: 'Teile, was bei euch nicht mehr gebraucht wird',
      ),
      subtitle: l10n.t(
        'treasureUploadSubline',
        fallback: 'Ein Foto, kurzer Check, fertig',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: l10n.t('treasureTitleLabel', fallback: 'Titel'),
              hintText: l10n.t(
                'treasureTitlePlaceholder',
                fallback: 'z. B. Rotes Laufrad',
              ),
              filled: true,
              fillColor: const Color(0xFFF4F7FC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.t('treasureCategoryLabel', fallback: 'Kategorie'),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF152B42),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categoryOptions
                .map(
                  (item) => ChoiceChip(
                    label: Text(item.$2),
                    selected: _selectedCategoryKey == item.$1,
                    onSelected: (_) {
                      setState(() {
                        _selectedCategoryKey = item.$1;
                      });
                      _onDraftChanged();
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _colorController,
            decoration: InputDecoration(
              labelText: l10n.t('treasureColorLabel', fallback: 'Farbe'),
              hintText: l10n.t(
                'treasureColorPlaceholder',
                fallback: 'z. B. Rot, Salbei, Naturholz',
              ),
              filled: true,
              fillColor: const Color(0xFFF4F7FC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionCarousel(
    AppLocalizations l10n,
    List<(String, String, Color, Color, IconData)> conditions,
  ) {
    return _SectionFrame(
      title: l10n.t('treasureConditionLabel', fallback: 'Zustand'),
      subtitle: l10n.t(
        'treasureConditionHelper',
        fallback: 'Ehrlich ist perfekt.',
      ),
      child: Column(
        children: List.generate(conditions.length, (index) {
          final item = conditions[index];
          final selected = index == _conditionIndex;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == conditions.length - 1 ? 0 : 10,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  setState(() => _conditionIndex = index);
                  _onDraftChanged();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: selected
                          ? [item.$3, item.$3.withValues(alpha: 0.92)]
                          : [const Color(0xFFF8FBFF), Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? item.$4 : const Color(0xFFD9E5F3),
                      width: selected ? 1.8 : 1.1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: item.$4.withValues(alpha: 0.14),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : const [
                            BoxShadow(
                              color: Color(0x080C2A4D),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: selected
                              ? item.$4.withValues(alpha: 0.14)
                              : item.$4.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.$5, color: item.$4, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.$1,
                                    style: TextStyle(
                                      color: item.$4,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                                if (selected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: item.$4.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      l10n.t(
                                        'treasureSelectedForHandover',
                                        fallback: 'Ausgewählt',
                                      ),
                                      style: TextStyle(
                                        color: item.$4,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.$2,
                              style: const TextStyle(
                                color: Color(0xFF40556F),
                                fontSize: 13.5,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected ? item.$4 : const Color(0xFF98A9BC),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNoteCard(AppLocalizations l10n) {
    final notePreview = _noteController.text.trim();
    return _SectionFrame(
      title: l10n.t('treasureOptionalNoteLabel', fallback: 'Kurze Notiz'),
      subtitle: l10n.t(
        'treasureOptionalNoteHelper',
        fallback: 'Ein ehrlicher Satz hilft anderen Familien sofort weiter.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _noteController,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF4F7FC),
              hintText: l10n.t(
                'treasureOptionalNotePlaceholder',
                fallback: 'z. B. Größe 92, fällt eher kleiner aus.',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7FC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        notePreview.isNotEmpty
                            ? Icons.check_circle_rounded
                            : Icons.edit_note_rounded,
                        size: 18,
                        color: notePreview.isNotEmpty
                            ? const Color(0xFF1F9C5D)
                            : const Color(0xFF6A7D91),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          notePreview.isNotEmpty
                              ? l10n.t(
                                  'treasureNoteEditable',
                                  fallback: 'Notiz übernommen.',
                                )
                              : l10n.t(
                                  'treasureNoteSuggestionHint',
                                  fallback:
                                      'Wir wandeln deine Notiz in einen startklaren Text um.',
                                ),
                          style: TextStyle(
                            color: notePreview.isNotEmpty
                                ? const Color(0xFF23364B)
                                : const Color(0xFF6A7D91),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E5CD7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  final suggestedNote = _noteSuggestion(l10n);
                  _noteController.text = suggestedNote;
                  _noteController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _noteController.text.length),
                  );
                  setState(() {});
                  _onDraftChanged();
                },
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: Text(
                  l10n.t('treasureInsertNoteSuggestion'),
                ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(l10n.t('treasureNoteSuggestionHint')),
        ],
      ),
    );
  }

  Widget _buildSizeAgeCard(AppLocalizations l10n) {
    return _SectionFrame(
      title: l10n.t('treasureSizeAgeLabel', fallback: 'Größe oder Alter'),
      subtitle: l10n.t(
        'treasureSizeAgePlaceholder',
        fallback: 'z. B. Größe 92 oder 2 bis 3 Jahre',
      ),
      child: TextField(
        controller: _sizeAgeController,
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF4F7FC),
          hintText: l10n.t(
            'treasureSizeAgePlaceholder',
            fallback: 'z. B. Größe 92 oder 2 bis 3 Jahre',
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  String _conditionKeyForIndex(int index) {
    switch (index) {
      case 0:
        return 'studio';
      case 2:
        return 'wild';
      default:
        return 'round2';
    }
  }

  Widget _buildDistanceCard(AppLocalizations l10n) {
    return _SectionFrame(
      title: l10n.t('treasureShareRadiusLabel'),
      subtitle: l10n.t(
        'treasureShareRadiusHelper',
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Slider(
                  min: 1,
                  max: 25,
                  divisions: 24,
                  value: _shareRadiusKm,
                  onChanged: (value) {
                    setState(() {
                      _shareRadiusKm = value;
                    });
                    _onDraftChanged();
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.tFormat(
                    'treasureShareRadiusKm',
                    {'radius': '${_shareRadiusKm.round()}'},
                  ),
                  style: const TextStyle(
                    color: Color(0xFF1E5CD7),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(AppLocalizations l10n) {
    final location = LocationService.instance;
    final locationLabel = location.city;

    return _SectionFrame(
      title: l10n.t('treasurePickupLocationTitle', fallback: 'Abholbereich'),
      subtitle: l10n.t(
        'treasurePickupLocationHint',
        fallback: 'Dein Standort bestimmt, welche Familien dein Angebot sehen.',
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.location_on_outlined),
        title: Text(locationLabel ?? l10n.t('location_denied')),
        trailing: OutlinedButton(
          onPressed: () async {
            final located = await location.requestGPSLocation();
            if (!mounted) return;
            setState(() {});
            if (!located) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.t('location_denied'))),
              );
            }
          },
          child: Text(l10n.t('use_my_location')),
        ),
      ),
    );
  }

  String _categoryLabelForKey(AppLocalizations l10n, String key) {
    switch (key) {
      case 'clothing':
        return l10n.t('treasureCategoryClothing', fallback: 'Kleidung');
      case 'toys':
        return l10n.t('treasureCategoryToys', fallback: 'Spielzeug');
      case 'books':
        return l10n.t('treasureCategoryBooks', fallback: 'Bücher');
      case 'equipment':
        return l10n.t('treasureCategoryEquipment', fallback: 'Ausstattung');
      case 'other':
        return l10n.t('treasureCategoryOther');
      default:
        return l10n.t('treasureCategoryVehicles', fallback: 'Fahrzeuge');
    }
  }

  String _noteSuggestion(AppLocalizations l10n) {
    final sizeAge = _sizeAgeController.text.trim().isEmpty
        ? l10n.t('treasureSizeAgePlaceholder', fallback: '2-4 Jahre')
        : _sizeAgeController.text.trim();
    final title = _titleController.text.trim().isEmpty
        ? l10n.t('treasureTitlePlaceholder', fallback: 'Rotes Laufrad')
        : _titleController.text.trim();
    return l10n.tFormat('treasureNoteSuggestion', {'title': title, 'sizeAge': sizeAge});
  }

  Future<void> _pickCameraImage() async {
    setState(_invalidateAnalysis);
    final request = _analysisRequest;
    final scope = _photoAnalysis.consent.scope;
    final pickedImage = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (!mounted ||
        pickedImage == null ||
        request != _analysisRequest ||
        _photoAnalysis.consent.scope != scope) {
      return;
    }
    setState(() {
      _selectedImages = [
        pickedImage,
        ..._selectedImages.where((image) => image.path != pickedImage.path),
      ];
    });
    _onDraftChanged();
    // KI-Analyse: Objekt erkennen und Beschreibung generieren
    await _analyzeImageWithAI(pickedImage);
  }

  Future<void> _analyzeImageWithAI(XFile image) async {
    final request = ++_analysisRequest;
    final scope = _photoAnalysis.consent.scope;
    bool current() =>
        mounted &&
        request == _analysisRequest &&
        _photoAnalysis.consent.scope == scope &&
        _primarySelectedImage?.path == image.path;
    void requireCurrent() {
      if (!current()) {
        throw StateError('Treasure photo analysis is no longer current');
      }
    }

    final originalCategory = _selectedCategoryKey;
    final originalCondition = _conditionIndex;
    try {
      setState(() {
        _isAnalyzingImage = false;
        _imageAnalysisFailed = false;
      });
      final accepted = await ensureAccountAiConsent(
        context,
        consent: _photoAnalysis.consent,
        titleKey: 'treasure_photo_consent_title',
        bodyKey: 'treasure_photo_consent_body',
        acceptKey: 'treasure_photo_consent_accept',
        failedKey: 'treasure_photo_consent_failed',
      );
      if (!accepted || !mounted || !current()) return;
      setState(() => _isAnalyzingImage = true);
      final parsed = await _photoAnalysis.analyze(
        image,
        expectedScope: scope,
        languageCode: Localizations.localeOf(context).languageCode,
        requireCurrentRequest: requireCurrent,
      );
      if (!current()) return;
      final title = parsed.title;
      final description = parsed.description;
      final category = parsed.category;
      final color = parsed.color;
      final sizeAge = parsed.sizeAge;
      final condition = parsed.condition;

      setState(() {
        // Titel nur überschreiben wenn noch Default
        if (title.isNotEmpty &&
            (_titleController.text.trim() == _defaultTitle ||
                _titleController.text.trim().isEmpty)) {
          _titleController.text = title;
        }
        // Beschreibung nur wenn noch leer
        if (description.isNotEmpty && _noteController.text.trim().isEmpty) {
          _noteController.text = description;
        }
        // Kategorie setzen wenn gültig
        if (_selectedCategoryKey == originalCategory) {
          _selectedCategoryKey = category;
        }
        // Farbe nur wenn noch Default
        if (color.isNotEmpty &&
            (_colorController.text.trim() == _defaultColor ||
                _colorController.text.trim().isEmpty)) {
          _colorController.text = color;
        }
        // Größe/Alter nur wenn noch Default
        if (sizeAge.isNotEmpty &&
            (_sizeAgeController.text.trim() == _defaultSizeAge ||
                _sizeAgeController.text.trim().isEmpty)) {
          _sizeAgeController.text = sizeAge;
        }
        // Zustand
        if (_conditionIndex != originalCondition) return;
        if (condition == 'new') {
          _conditionIndex = 0;
        } else if (condition == 'good') {
          _conditionIndex = 1;
        } else if (condition == 'used') {
          _conditionIndex = 2;
        }
      });
    } catch (e) {
      debugPrint('Image analysis failed: $e');
      if (current()) setState(() => _imageAnalysisFailed = true);
    } finally {
      if (current()) setState(() => _isAnalyzingImage = false);
    }
  }

  Future<void> _pickGalleryImages() async {
    final request = _analysisRequest;
    final scope = _listingService.store.scope;
    final pickedImages = await _imagePicker.pickMultiImage(
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (!mounted ||
        pickedImages.isEmpty ||
        request != _analysisRequest ||
        scope != _listingService.store.scope) {
      return;
    }
    final mergedImages = [..._selectedImages];
    for (final image in pickedImages) {
      if (mergedImages.every((item) => item.path != image.path)) {
        mergedImages.add(image);
      }
    }
    setState(() {
      _invalidateAnalysis();
      _selectedImages = mergedImages;
    });
    _onDraftChanged();
  }

  void _promoteSelectedImage(int index) {
    if (index <= 0 || index >= _selectedImages.length) {
      return;
    }
    setState(() {
      _invalidateAnalysis();
      final selected = _selectedImages[index];
      final reordered = [..._selectedImages]..removeAt(index);
      _selectedImages = [selected, ...reordered];
    });
    _onDraftChanged();
  }

  void _removeSelectedImageAt(int index) {
    if (index < 0 || index >= _selectedImages.length) {
      return;
    }
    setState(() {
      _invalidateAnalysis();
      final updated = [..._selectedImages]..removeAt(index);
      _selectedImages = updated;
    });
    _onDraftChanged();
  }

  void _onDraftChanged() {
    _draftRevision++;
    if (!_draftHydrated || _publishing || _publishedListing != null) {
      return;
    }
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_persistDraft());
    });
  }

  Future<void> _restoreDraft() async {
    Map<String, dynamic>? loaded;
    try {
      loaded = await _listingService.loadDraft();
    } catch (error) {
      debugPrint('Treasure draft load: $error');
      if (mounted) _showPersistenceMessage('treasure_storage_failed');
      return;
    }
    final draft = loaded;
    if (!mounted) {
      return;
    }
    var restoredDraft = false;
    var missingImages = false;
    var restoredImages = <XFile>[];
    if (draft != null && draft.isNotEmpty) {
      final rawImagePaths = draft['imagePaths'];
      final imagePaths = rawImagePaths is List
          ? rawImagePaths
                .map((item) => item.toString())
                .where((path) => path.isNotEmpty)
                .toList()
          : <String>[];
      final fallbackImagePath = draft['imagePath']?.toString();
      if (imagePaths.isEmpty &&
          fallbackImagePath != null &&
          fallbackImagePath.isNotEmpty) {
        imagePaths.add(fallbackImagePath);
      }
      final durable = widget.draftImages.decode(draft);
      if (durable != null) {
        restoredImages = durable;
      } else {
        for (final path in imagePaths) {
          try {
            final image = XFile(path);
            if (kIsWeb || widget.draftImages.web) {
              if ((await image.readAsBytes()).isEmpty) throw StateError('Empty legacy photo');
            } else if (!File(path).existsSync()) {
              throw StateError('Legacy draft photo missing');
            }
            restoredImages.add(image);
          } catch (error) {
            debugPrint('Treasure draft photo unavailable: $error');
            missingImages = true;
          }
        }
      }
      if (!mounted) return;
      _runWithoutDraftAutosave(() {
        setState(() {
          _titleController.text = draft['title']?.toString() ?? _defaultTitle;
          _colorController.text =
              draft['colorLabel']?.toString() ?? _defaultColor;
          _noteController.text = draft['note']?.toString() ?? '';
          _sizeAgeController.text =
              draft['sizeAge']?.toString() ?? _defaultSizeAge;
          _selectedCategoryKey = draft['categoryKey'] == null
              ? _defaultCategoryKey
              : TreasureCategory.normalize(draft['categoryKey'].toString());
          _shareRadiusKm =
              double.tryParse(draft['shareRadiusKm']?.toString() ?? '') ??
              _defaultRadiusKm;
          _conditionIndex =
              int.tryParse(draft['conditionIndex']?.toString() ?? '') ??
              _defaultConditionIndex;
          _selectedImages = restoredImages;
        });
      });
      restoredDraft = true;
    }
    _draftHydrated = true;
    if (restoredDraft) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        final l10n = AppLocalizations.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.t(
                missingImages ? 'treasure_draft_images_missing' : 'treasureDraftRestored',
                fallback: 'Dein letzter Entwurf ist wieder da.',
              ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }
  }

  Future<void> _persistDraft({bool showFeedback = false}) async {
    if (_publishing || _publishedListing != null) return;
    if (!_draftHydrated) {
      if (showFeedback) _showPersistenceMessage('treasure_storage_failed');
      return;
    }
    final revision = _draftRevision;
    final payload = _buildDraftPayload();
    final images = List<XFile>.of(_selectedImages);
    final meaningful = _hasMeaningfulDraft();
    final saved = await _attempt(() async {
      if (meaningful) {
        final storedImages = await widget.draftImages.encode(images);
        if (!mounted || revision != _draftRevision || _publishing || _publishedListing != null) return false;
        await _listingService.saveDraft({...payload, ...storedImages});
      } else {
        await _listingService.clearDraft();
      }
      return true;
    });
    if (saved != true) return;
    if (!mounted || !showFeedback) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.t(
            'treasureDraftSaved',
            fallback: 'Entwurf gespeichert. Du kannst später weitermachen.',
          ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Map<String, dynamic> _buildDraftPayload() {
    return {
      'title': _titleController.text.trim(),
      'colorLabel': _colorController.text.trim(),
      'note': _noteController.text.trim(),
      'sizeAge': _sizeAgeController.text.trim(),
      'categoryKey': _selectedCategoryKey,
      'shareRadiusKm': _shareRadiusKm,
      'conditionIndex': _conditionIndex,
    };
  }

  bool _hasMeaningfulDraft() {
    return _selectedImages.isNotEmpty ||
        _titleController.text.trim() != _defaultTitle ||
        _colorController.text.trim() != _defaultColor ||
        _noteController.text.trim().isNotEmpty ||
        _sizeAgeController.text.trim() != _defaultSizeAge ||
        _selectedCategoryKey != _defaultCategoryKey ||
        _shareRadiusKm != _defaultRadiusKm ||
        _conditionIndex != _defaultConditionIndex;
  }

  XFile? get _primarySelectedImage =>
      _selectedImages.isEmpty ? null : _selectedImages.first;

  void _runWithoutDraftAutosave(VoidCallback action) {
    final wasHydrated = _draftHydrated;
    _draftHydrated = false;
    action();
    _draftHydrated = wasHydrated;
  }

  Future<void> _confirmDiscardDraft() async {
    final l10n = AppLocalizations.of(context);
    final scope = _listingService.scope;
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => TreasureAccountModal(
        store: _listingService.store, scope: scope,
        builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            l10n.t('treasureDiscardDraftTitle', fallback: 'Entwurf verwerfen?'),
          ),
          content: Text(
            l10n.t(
              'treasureDiscardDraftText',
              fallback:
                  'Dein aktueller Formularstand und der lokal gespeicherte Entwurf werden entfernt.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('treasureDiscard', fallback: 'Verwerfen')),
            ),
          ],
        );
        },
      ),
    );
    if (shouldDiscard != true || !mounted) {
      return;
    }
    await _discardDraft();
  }

  Future<void> _discardDraft() async {
    _draftDebounce?.cancel();
    final cleared = await _attempt(() async {
      await _listingService.clearDraft();
      return true;
    });
    if (!mounted || cleared != true) return;
    _draftHydrated = true;
    _draftRevision++;
    _invalidateAnalysis();
    _runWithoutDraftAutosave(() {
      setState(() {
        _titleController.text = _defaultTitle;
        _colorController.text = _defaultColor;
        _noteController.clear();
        _sizeAgeController.text = _defaultSizeAge;
        _selectedCategoryKey = _defaultCategoryKey;
        _shareRadiusKm = _defaultRadiusKm;
        _conditionIndex = _defaultConditionIndex;
        _selectedImages = const [];
      });
    });
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.t('treasureDraftDiscarded', fallback: 'Entwurf verworfen.'),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<T?> _attempt<T>(Future<T> Function() operation) async {
    if (!mounted) return null;
    try {
      return await operation();
    } catch (error) {
      debugPrint('Treasure upload storage: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).t('treasure_storage_failed'))),
        );
      }
      return null;
    }
  }

  void _showPersistenceMessage(String key) {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t(key))));
      }

      Future<void> _runPublish(Future<void> Function() operation) async {
        if (_publishing || _publishOutcomeUnknown || _publishedListing != null) return;
        setState(() => _publishing = true);
        _draftRevision++;
        _draftDebounce?.cancel();
        try {
          await operation();
        } on ImageBatchUploadException catch (error) {
          if (mounted) {
            _showPersistenceMessage(error.remainingUploads > 0
                ? 'treasure_upload_cleanup_failed' : 'treasure_upload_batch_failed');
          }
        } on TreasureRemoteCommitException catch (error) {
          debugPrint('Treasure publish local follow-up failed: ${error.cause}');
          if (mounted) {
            _publishOutcomeUnknown = false;
            _publishedListing = error.listing;
            _publishedLocalFailed = true;
            _showPersistenceMessage('treasure_published_local_failed');
          }
        } catch (error) {
          debugPrint('Treasure publish: $error');
          if (mounted) {
            _publishedLocalFailed = _publishedListing != null;
            _showPersistenceMessage(_publishedListing != null
                ? 'treasure_published_local_failed' : 'treasure_publish_uncertain');
          }
        } finally {
          if (mounted) setState(() => _publishing = false);
        }
      }

  Widget _buildPreviewCard(
    AppLocalizations l10n,
    (String, String, Color, Color, IconData) currentCondition,
  ) {
    final primaryImage = _primarySelectedImage;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Text(
            l10n.t('treasurePreviewTitle', fallback: 'Aero-Feed Vorschau'),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF152B42),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: primaryImage == null
                  ? const LinearGradient(
                      colors: [Color(0xFFFFF0E8), Color(0xFFEFF5FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: primaryImage == null ? null : const Color(0xFF14283F),
            ),
            child: Stack(
              children: [
                if (primaryImage != null)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SafeXFileImage(
                        file: primaryImage,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: primaryImage == null
                            ? [Colors.transparent, Colors.transparent]
                            : [
                                Colors.black.withValues(alpha: 0.08),
                                Colors.black.withValues(alpha: 0.56),
                              ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                if (primaryImage == null)
                  const Positioned(
                    right: 14,
                    top: 14,
                    child: Icon(
                      Icons.toys_rounded,
                      size: 72,
                      color: Color(0x22D96C2F),
                    ),
                  ),
                Positioned(
                  left: 14,
                  top: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: currentCondition.$3,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          currentCondition.$5,
                          size: 14,
                          color: currentCondition.$4,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          currentCondition.$1,
                          style: TextStyle(
                            color: currentCondition.$4,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_selectedImages.length > 1)
                  Positioned(
                    right: 14,
                    top: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l10n.tFormat(
                          'treasurePhotoCount',
                          {'count': '${_selectedImages.length}'},
                          fallback: '${_selectedImages.length} Fotos',
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                const Positioned(
                  left: 14,
                  bottom: 46,
                  child: SizedBox.shrink(),
                ),
                Positioned(
                  left: 14,
                  bottom: 46,
                  child: Text(
                    '${_titleController.text.trim().isEmpty ? l10n.t('treasureTitlePlaceholder', fallback: 'Rotes Laufrad') : _titleController.text.trim()} · ${_sizeAgeController.text.trim().isEmpty ? l10n.t('treasureSizeAgePlaceholder', fallback: '2-4 Jahre') : _sizeAgeController.text.trim()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  bottom: 18,
                  child: Text(
                    l10n.tFormat(
                      'treasureShareRadiusKm',
                      {'radius': '${_shareRadiusKm.round()}'},
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_noteController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FD),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t(
                      'treasurePreviewNoteLabel',
                      fallback: 'Familien-Hinweis',
                    ),
                    style: const TextStyle(
                      color: Color(0xFF152B42),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _noteController.text.trim(),
                    style: const TextStyle(
                      color: Color(0xFF40556F),
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_selectedImages.length > 1) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SafeXFileImage(
                    file: _selectedImages[index],
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: _selectedImages.length,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionFrame extends StatelessWidget {
  const _SectionFrame({
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF152B42),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: Color(0xFF607286),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5FB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF29425C),
        ),
      ),
    );
  }
}

class _ActionGlassChip extends StatelessWidget {
  const _ActionGlassChip({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: onTap == null ? 0.2 : 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
