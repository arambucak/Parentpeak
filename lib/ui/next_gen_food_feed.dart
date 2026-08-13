import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:just_audio/just_audio.dart';
import 'package:latlong2/latlong.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/next_gen_food_feed_backend_service.dart';
import 'package:parentpeak/logic/next_gen_food_feed_service.dart';
import 'package:parentpeak/models/audio_hack.dart';
import 'package:parentpeak/models/community_snack.dart';
import 'package:parentpeak/models/ingredient_share.dart';
import 'package:parentpeak/models/kitchen_sos.dart';
import 'package:parentpeak/models/recipe.dart';
import 'package:video_player/video_player.dart';

class NextGenFoodFeedScreen extends StatefulWidget {
  const NextGenFoodFeedScreen({super.key});

  @override
  State<NextGenFoodFeedScreen> createState() => _NextGenFoodFeedScreenState();
}

class _NextGenFoodFeedScreenState extends State<NextGenFoodFeedScreen> {
  static const GeoCoordinates _myLocation = GeoCoordinates(
    latitude: 52.5200,
    longitude: 13.4050,
  );

  final NextGenFoodFeedService _service = const NextGenFoodFeedService();
  final NextGenFoodFeedBackendService _backend =
      BackendServiceFactory.createNextGenFoodFeedBackendService();

  final PageController _pageController = PageController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  late final List<Recipe> _recipes = _buildRecipes();

  List<CommunitySnack> _snacks = const [];
  List<AudioHack> _audioHacks = const [];
  List<IngredientShare> _shares = const [];

  final Set<String> _importedRecipeIds = <String>{};
  final Set<String> _likedSnackIds = <String>{};

  int _currentIndex = 0;
  int _activeAudioIndex = 0;

  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _loading = true;
  bool _audioPlaying = false;
  final bool _audioAutoplay = true;
  String? _syncInfo;
  bool _loadingMore = false;
  bool _hasMoreSnacks = true;
  int _nextSnackPage = 2;
  static const int _snackPageSize = 5;

  CommunitySnack? get _currentSnack {
    if (_snacks.isEmpty) return null;
    final safeIndex = _currentIndex.clamp(0, _snacks.length - 1);
    return _snacks[safeIndex];
  }

  @override
  void initState() {
    super.initState();
    _audioPlayer.currentIndexStream.listen((index) {
      if (!mounted || index == null) return;
      setState(() {
        _activeAudioIndex = index;
      });
    });
    _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _audioPlaying = state.playing;
      });
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_snacks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Food Feed Next Gen')),
        body: const Center(
          child: Text('Noch keine Snacks verfügbar.'),
        ),
      );
    }

    final snack = _currentSnack!;
    final currentRecipe = _service.recipeFromSnack(
      snack: snack,
      recipes: _recipes,
    );
    final hacks = _service.orderedAudioHacksForRecipe(
      recipeId: currentRecipe.id,
      allAudioHacks: _audioHacks,
    );
    final shares = _service.findIngredientSharesForWeeklyPlan(
      weeklyPlan: [currentRecipe],
      allShares: _shares,
      center: _myLocation,
      radiusMeters: 2000,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF080D17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080D17),
        foregroundColor: Colors.white,
        title: const Text('Food Feed Next Gen'),
        actions: [
          IconButton(
            onPressed: _openCreateContentSheet,
            tooltip: 'Neuen Snack posten',
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _snacks.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                _activeAudioIndex = 0;
              });
              _initVideoForIndex(index);
              _queueRecipeAudioHacksIfNeeded(autoplay: _audioAutoplay);
              _loadMoreSnacksIfNeeded(index);
            },
            itemBuilder: (context, index) {
              final pageSnack = _snacks[index];
              final isActive = index == _currentIndex;
              return _buildSnackPage(pageSnack, isActive: isActive);
            },
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 18,
            child: _buildBottomOverlay(
              recipe: currentRecipe,
              hacks: hacks,
              shares: shares,
            ),
          ),
          Positioned(
            top: 14,
            right: 12,
            child: _buildSideActions(currentRecipe, hacks),
          ),
          if (_syncInfo != null && _syncInfo!.trim().isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: _buildSyncBanner(_syncInfo!),
            ),
          if (_loadingMore)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 2,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }

  Future<void> _bootstrap() async {
    final firstPage = await _backend.loadCommunitySnacksPage(
      page: 1,
      pageSize: _snackPageSize,
    );
    final audio = await _backend.loadAudioHacks();
    final shares = await _backend.loadIngredientShares();

    if (!mounted) return;

    setState(() {
      _snacks = firstPage.items;
      _audioHacks = audio;
      _shares = shares;
      _syncInfo = _backend.lastSyncError;
      _loading = false;
      _hasMoreSnacks = firstPage.hasMore;
      _nextSnackPage = firstPage.nextPage;
    });

    if (_snacks.isNotEmpty) {
      await _initVideoForIndex(0);
      await _queueRecipeAudioHacksIfNeeded(autoplay: true);
    }
  }

  Future<void> _loadMoreSnacksIfNeeded(int index) async {
    if (!_hasMoreSnacks || _loadingMore) return;
    if (index < _snacks.length - 2) return;

    setState(() {
      _loadingMore = true;
    });

    final page = await _backend.loadCommunitySnacksPage(
      page: _nextSnackPage,
      pageSize: _snackPageSize,
    );

    if (!mounted) return;

    setState(() {
      final knownIds = _snacks.map((item) => item.id).toSet();
      final appended = page.items.where((item) => !knownIds.contains(item.id)).toList();
      _snacks = [..._snacks, ...appended];
      _hasMoreSnacks = page.hasMore;
      _nextSnackPage = page.nextPage;
      _loadingMore = false;
      _syncInfo = _backend.lastSyncError ?? _syncInfo;
    });
  }

  Widget _buildSnackPage(CommunitySnack snack, {required bool isActive}) {
    final reach = _service.estimateCommunityReachScore(snack);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A1227), Color(0xFF1A2A49)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: _buildVideoLayer(isActive),
          ),
          Positioned(
            left: 14,
            top: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xAA101828),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Reach Score $reach',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            bottom: 230,
            right: 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snack.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Von ${snack.authorId} · ${snack.viewsCount} Views',
                  style: const TextStyle(
                    color: Color(0xFFD6E2FF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoLayer(bool isActive) {
    if (!isActive || _videoController == null || !_videoReady) {
      return Container(
        color: const Color(0xFF0F172A),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -40) {
          _openRecipeSheet();
        }
      },
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _videoController!.value.size.width,
          height: _videoController!.value.size.height,
          child: VideoPlayer(_videoController!),
        ),
      ),
    );
  }

  Widget _buildSideActions(Recipe recipe, List<AudioHack> hacks) {
    final snack = _currentSnack!;
    final liked = _likedSnackIds.contains(snack.id);

    return Column(
      children: [
        _actionCircle(
          icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: '${snack.likesCount + (liked ? 1 : 0)}',
          onTap: () async {
            setState(() {
              if (liked) {
                _likedSnackIds.remove(snack.id);
              } else {
                _likedSnackIds.add(snack.id);
              }
            });

            final updatedSnack = snack.copyWith(
              likesCount: snack.likesCount + (liked ? 0 : 1),
            );
            CommunitySnack savedSnack;
            try {
              savedSnack = await _backend.publishCommunitySnack(updatedSnack);
            } catch (_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_backend.lastSyncError ?? 'Like konnte nicht gespeichert werden.'),
                ),
              );
              return;
            }
            if (!mounted) return;
            setState(() {
              _snacks = [
                for (final item in _snacks)
                  if (item.id == savedSnack.id) savedSnack else item,
              ];
              _syncInfo = _backend.lastSyncError;
            });
          },
        ),
        const SizedBox(height: 10),
        _actionCircle(
          icon: Icons.graphic_eq_rounded,
          label: hacks.isEmpty ? '0' : '${hacks.first.upvotes}',
          onTap: _openCookMode,
        ),
        const SizedBox(height: 10),
        _actionCircle(
          icon: Icons.playlist_add_check_circle_rounded,
          label: _importedRecipeIds.contains(recipe.id) ? 'imported' : 'plan',
          onTap: () {
            setState(() {
              _importedRecipeIds.add(recipe.id);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${recipe.title} in Wochenplan importiert.')),
            );
          },
        ),
      ],
    );
  }

  Widget _actionCircle({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        Material(
          color: const Color(0xAA111827),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomOverlay({
    required Recipe recipe,
    required List<AudioHack> hacks,
    required List<IngredientShare> shares,
  }) {
    final hack = hacks.isEmpty ? null : hacks[_activeAudioIndex % hacks.length];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xCC0B1220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x3382A6E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  recipe.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2D62F0),
                  foregroundColor: Colors.white,
                ),
                onPressed: _openRecipeSheet,
                icon: const Icon(Icons.swipe_left_rounded, size: 16),
                label: const Text('Swipe->Rezept'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hack != null) _buildAudioHackCard(hack, hacks.length),
          if (shares.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildIngredientRescueMap(shares),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioHackCard(AudioHack hack, int totalHacks) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF111C33),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mic_rounded, color: Color(0xFF9CC3FF), size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Audio-Hack von ${hack.userId}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${hack.durationSeconds}s',
                style: const TextStyle(color: Color(0xFF9CC3FF)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hack.transcript ?? 'Kein Transkript vorhanden.',
            style: const TextStyle(color: Color(0xFFE7EEFF), height: 1.3),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFBFD4FF),
                ),
                onPressed: totalHacks <= 1
                    ? null
                    : () async {
                        setState(() {
                          _activeAudioIndex = (_activeAudioIndex + 1) % totalHacks;
                        });
                        await _queueRecipeAudioHacksIfNeeded(autoplay: true);
                      },
                icon: const Icon(Icons.skip_next_rounded, size: 16),
                label: const Text('Naechster Hack'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  if (_audioPlaying) {
                    await _audioPlayer.pause();
                  } else {
                    await _queueRecipeAudioHacksIfNeeded(autoplay: true);
                  }
                },
                icon: Icon(_audioPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                label: Text(_audioPlaying ? 'Pause' : 'Play'),
              ),
              Chip(
                label: Text('${hack.upvotes} Upvotes'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientRescueMap(List<IngredientShare> shares) {
    final center = LatLng(_myLocation.latitude, _myLocation.longitude);

    return Container(
      height: 170,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x3357D694)),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 14,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'trusted_circle_demo',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: center,
                width: 34,
                height: 34,
                child: const Icon(Icons.home_rounded, color: Color(0xFF2D62F0), size: 24),
              ),
              ...shares.take(8).map(
                (share) => Marker(
                  point: LatLng(share.location.latitude, share.location.longitude),
                  width: 38,
                  height: 38,
                  child: Tooltip(
                    message: '${share.ingredientName} von ${share.userId}',
                    child: const Icon(Icons.location_on_rounded, color: Color(0xFF00B56A), size: 30),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyncBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xD9111C33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x3382A6E8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateContentSheet() async {
    final titleController = TextEditingController();
    final videoUrlController = TextEditingController();
    final audioTranscriptController = TextEditingController();
    final audioUrlController = TextEditingController();
    final shareIngredientController = TextEditingController();

    String selectedRecipeId = _recipes.first.id;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Neuen Community-Inhalt posten',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Snack Titel',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRecipeId,
                        items: _recipes
                            .map((recipe) => DropdownMenuItem(
                                  value: recipe.id,
                                  child: Text(recipe.title),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setModalState(() {
                            selectedRecipeId = value;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Verknuepftes Rezept',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: videoUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Video URL',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: audioUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Audio URL (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: audioTranscriptController,
                        decoration: const InputDecoration(
                          labelText: 'Audio Hack Text (optional)',
                          border: OutlineInputBorder(),
                        ),
                        minLines: 2,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: shareIngredientController,
                        decoration: const InputDecoration(
                          labelText: 'Zutat teilen (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            final title = titleController.text.trim();
                            final videoUrl = videoUrlController.text.trim();
                            if (title.isEmpty || videoUrl.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Titel und Video URL sind erforderlich.')),
                              );
                              return;
                            }

                            final now = DateTime.now().millisecondsSinceEpoch;
                            final snack = CommunitySnack(
                              id: 'snack-$now',
                              title: title,
                              videoUrl: videoUrl,
                              linkedRecipeId: selectedRecipeId,
                              authorId: 'mama_fatih',
                              viewsCount: 0,
                              likesCount: 0,
                              locationCoordinates: _myLocation,
                            );

                            CommunitySnack savedSnack;
                            try {
                              savedSnack = await _backend.publishCommunitySnack(snack);
                            } catch (_) {
                              if (!mounted || !context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _backend.lastSyncError ??
                                        'Snack konnte nicht veröffentlicht werden.',
                                  ),
                                ),
                              );
                              return;
                            }

                            AudioHack? savedHack;
                            final audioUrl = audioUrlController.text.trim();
                            if (audioUrl.isNotEmpty) {
                              final hack = AudioHack(
                                id: 'hack-$now',
                                recipeId: selectedRecipeId,
                                userId: 'mama_fatih',
                                audioUrl: audioUrl,
                                durationSeconds: 10,
                                upvotes: 0,
                                transcript: audioTranscriptController.text.trim().isEmpty
                                    ? null
                                    : audioTranscriptController.text.trim(),
                              );
                              try {
                                savedHack = await _backend.publishAudioHack(hack);
                              } catch (_) {
                                if (!mounted || !context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _backend.lastSyncError ??
                                          'Audio-Hack konnte nicht veröffentlicht werden.',
                                    ),
                                  ),
                                );
                                return;
                              }
                            }

                            IngredientShare? savedShare;
                            final ingredient = shareIngredientController.text.trim();
                            if (ingredient.isNotEmpty) {
                              final share = IngredientShare(
                                id: 'share-$now',
                                userId: 'mama_fatih',
                                ingredientName: ingredient,
                                status: IngredientShareStatus.available,
                                geoHash: 'u33dc9',
                                location: _myLocation,
                              );
                              try {
                                savedShare = await _backend.publishIngredientShare(share);
                              } catch (_) {
                                if (!mounted || !context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _backend.lastSyncError ??
                                          'Zutat konnte nicht veröffentlicht werden.',
                                    ),
                                  ),
                                );
                                return;
                              }
                            }

                            if (!mounted || !context.mounted) return;

                            setState(() {
                              _snacks = [savedSnack, ..._snacks];
                              if (savedHack != null) {
                                _audioHacks = [savedHack, ..._audioHacks];
                              }
                              if (savedShare != null) {
                                _shares = [savedShare, ..._shares];
                              }
                              _syncInfo = _backend.lastSyncError ?? 'Inhalt erfolgreich gepostet.';
                              _currentIndex = 0;
                              _activeAudioIndex = 0;
                            });

                            Navigator.of(context).pop();
                            _pageController.jumpToPage(0);
                            await _initVideoForIndex(0);
                            await _queueRecipeAudioHacksIfNeeded(autoplay: true);
                          },
                          icon: const Icon(Icons.cloud_upload_rounded),
                          label: const Text('Jetzt posten'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    videoUrlController.dispose();
    audioTranscriptController.dispose();
    audioUrlController.dispose();
    shareIngredientController.dispose();
  }

  void _openCookMode() {
    final snack = _currentSnack;
    if (snack == null) return;

    final recipe = _service.recipeFromSnack(snack: snack, recipes: _recipes);
    final hacks = _service.orderedAudioHacksForRecipe(
      recipeId: recipe.id,
      allAudioHacks: _audioHacks,
    );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.84,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                const Text(
                  'Koch-Modus',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  recipe.title,
                  style: const TextStyle(color: Color(0xFFD8E3FF), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                ...recipe.ingredients.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF9CC3FF)),
                    title: Text(item.name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(item.amount, style: const TextStyle(color: Color(0xFFBFD4FF))),
                  ),
                ),
                const SizedBox(height: 10),
                if (hacks.isNotEmpty)
                  _buildAudioHackCard(hacks[_activeAudioIndex % hacks.length], hacks.length),
              ],
            );
          },
        );
      },
    );
  }

  void _openRecipeSheet() {
    final snack = _currentSnack;
    if (snack == null) return;

    final recipe = _service.recipeFromSnack(snack: snack, recipes: _recipes);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                ),
                const SizedBox(height: 8),
                ...recipe.ingredients.map(
                  (ingredient) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('- ${ingredient.name}: ${ingredient.amount}'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      setState(() {
                        _importedRecipeIds.add(recipe.id);
                      });
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('${recipe.title} in Wochenplan importiert.')),
                      );
                    },
                    icon: const Icon(Icons.playlist_add_check_circle_rounded),
                    label: const Text('In Wochenplan importieren'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _initVideoForIndex(int index) async {
    if (_snacks.isEmpty) return;

    _videoReady = false;
    await _videoController?.dispose();
    final controller = VideoPlayerController.networkUrl(Uri.parse(_snacks[index].videoUrl));
    _videoController = controller;

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (!mounted) return;
      setState(() {
        _videoReady = true;
      });
    } catch (e) {
      debugPrint('NextGenFoodFeed._initVideoForIndex(): failed: $e');
      if (!mounted) return;
      setState(() {
        _videoReady = false;
      });
    }
  }

  Future<void> _queueRecipeAudioHacksIfNeeded({required bool autoplay}) async {
    final snack = _currentSnack;
    if (snack == null) return;

    final recipe = _service.recipeFromSnack(snack: snack, recipes: _recipes);
    final hacks = _service.orderedAudioHacksForRecipe(
      recipeId: recipe.id,
      allAudioHacks: _audioHacks,
    );

    final playable = hacks
        .where((hack) => hack.audioUrl.trim().isNotEmpty)
        .map((hack) => AudioSource.uri(Uri.parse(hack.audioUrl)))
        .toList();

    if (playable.isEmpty) {
      if (!mounted) return;
      setState(() {
        _audioPlaying = false;
      });
      return;
    }

    try {
      await _audioPlayer.setAudioSource(
        ConcatenatingAudioSource(children: playable),
        initialIndex: _activeAudioIndex % playable.length,
      );
      if (autoplay) {
        await _audioPlayer.play();
      }
      if (!mounted) return;
      setState(() {
        _audioPlaying = autoplay;
      });
    } catch (e) {
      debugPrint('NextGenFoodFeed._queueRecipeAudioHacksIfNeeded(): failed: $e');
      if (!mounted) return;
      setState(() {
        _audioPlaying = false;
        _syncInfo = 'Audio-Hacks konnten nicht gestartet werden.';
      });
    }
  }

  List<Recipe> _buildRecipes() {
    return const [
      Recipe(
        id: 'recipe-brokkoli-pasta',
        title: 'Brokkoli-Creme-Pasta',
        ingredients: [
          RecipeIngredient(name: 'Pasta', amount: '300 g'),
          RecipeIngredient(name: 'Brokkoli', amount: '200 g'),
          RecipeIngredient(name: 'Frischkaese', amount: '150 g'),
        ],
        durationMinutes: 20,
        isPickEaterFriendly: true,
        isOnePot: false,
        hideVegetables: true,
      ),
      Recipe(
        id: 'recipe-3-zutaten-snack',
        title: '3-Zutaten-Nachmittags-Snack',
        ingredients: [
          RecipeIngredient(name: 'Banane', amount: '2 Stueck'),
          RecipeIngredient(name: 'Haferflocken', amount: '100 g'),
          RecipeIngredient(name: 'Erdnussmus', amount: '2 EL'),
        ],
        durationMinutes: 10,
        isPickEaterFriendly: true,
        isOnePot: true,
        hideVegetables: false,
      ),
      Recipe(
        id: 'recipe-linsen-lasagne',
        title: 'Linsen-Lasagne für alle',
        ingredients: [
          RecipeIngredient(name: 'Lasagneblaetter', amount: '250 g'),
          RecipeIngredient(name: 'Rote Linsen', amount: '150 g'),
          RecipeIngredient(name: 'Tomatensosse', amount: '500 ml'),
        ],
        durationMinutes: 35,
        isPickEaterFriendly: true,
        isOnePot: false,
        hideVegetables: true,
      ),
    ];
  }

}
