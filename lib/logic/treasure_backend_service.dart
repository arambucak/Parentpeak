import 'package:image_picker/image_picker.dart';
import 'package:parentpeak/services/image_upload_service.dart';

import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/backend_api_client.dart';
import 'package:parentpeak/models/treasure_listing.dart';

class TreasureBackendService {
  TreasureBackendService({BackendApiClient? apiClient})
      : _apiClient = apiClient ?? BackendServiceFactory.createApiClient();

  final BackendApiClient? _apiClient;
  String? lastSyncError;

  bool get isEnabled => _apiClient != null;

  String get _treasuresPath => '/api/treasures';

  Future<List<TreasureListing>> fetchTreasures({
    String status = 'available',
    String visibility = 'nearby',
    String? category,
    String? condition,
    int limit = 50,
    int offset = 0,
    double? latitude,
    double? longitude,
    double radiusKm = 25,
  }) async {
    if (_apiClient == null) return [];

    try {
      final query = <String, String>{
        'status': status,
        'visibility': visibility,
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
        if (condition != null && condition.trim().isNotEmpty)
          'condition': condition.trim(),
        'maxResults': limit.toString(),
        'offset': offset.toString(),
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
        'radiusKm': radiusKm.toString(),
      };

      final payload =
          await _apiClient!.getJson(_appendQuery(_treasuresPath, query));
      final data =
          payload is Map<String, dynamic> ? payload['treasures'] : payload;
      if (data is! List) {
        return [];
      }

      return data
          .map((item) => _mapTreasureToListing(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      lastSyncError = 'Verschenkmarkt konnte nicht geladen werden: $e';
      return [];
    }
  }

  Future<TreasureListing?> createTreasure({
    required TreasureListing listing,
    required String userId,
    required String location,
    required double latitude,
    required double longitude,
  }) async {
    if (_apiClient == null) return null;

    try {
      String? uploadedImageUrl;
      final primaryImagePath = listing.primaryImagePath;
      if (primaryImagePath != null && primaryImagePath.isNotEmpty) {
        // Bereits hochgeladene URL? Direkt verwenden (keine Re-Upload).
        if (primaryImagePath.startsWith('http://') ||
            primaryImagePath.startsWith('https://')) {
          uploadedImageUrl = primaryImagePath;
        } else {
          final imageFile = XFile(primaryImagePath);
          uploadedImageUrl =
              await ImageUploadService.instance.uploadImage(imageFile);
        }
      }

      final payload = await _apiClient!.postJsonAny(_treasuresPath, {
        'userId': userId,
        'title': listing.title,
        'description': listing.note,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'category': _mapCategoryForBackend(listing.category),
        'condition': _mapConditionForBackend(listing.conditionKey),
        'isFree': true,
        'visibility': 'nearby',
        'shareRadiusKm': (listing.distanceMeters / 1000).clamp(1, 100),
        if (uploadedImageUrl != null && uploadedImageUrl.isNotEmpty)
          'photoUrl': uploadedImageUrl,
      });

      final data = payload is Map<String, dynamic>
          ? payload['treasure'] ?? payload
          : payload;
      if (data is! Map) {
        return null;
      }

      return _mapTreasureToListing(
        Map<String, dynamic>.from(data),
        fallbackListing: listing,
      );
    } catch (e) {
      lastSyncError = 'Treasure konnte nicht erstellt werden: $e';
      return null;
    }
  }

  Future<bool> reportTreasure({
    required String treasureId,
    required String reporterUserId,
    required String reason,
    String? note,
  }) async {
    if (_apiClient == null) return false;

    try {
      await _apiClient!.postJsonAny(
        '$_treasuresPath/$treasureId/report',
        {
          'reporterUserId': reporterUserId,
          'reason': reason,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
      );
      return true;
    } catch (e) {
      lastSyncError = 'Meldung konnte nicht an den Server gesendet werden: $e';
      return false;
    }
  }

  TreasureListing _mapTreasureToListing(
    Map<String, dynamic> treasure, {
    TreasureListing? fallbackListing,
  }) {
    final rawRadiusKm =
        double.tryParse(treasure['shareRadiusKm']?.toString() ?? '');
    final rawCondition = treasure['condition']?.toString() ?? '';
    final categoryRaw = treasure['category']?.toString() ?? '';
    final createdAt =
        DateTime.tryParse(treasure['createdAt']?.toString() ?? '');
    final imageUrl = treasure['photoUrl']?.toString();
    final latitude = double.tryParse(treasure['latitude']?.toString() ?? '');
    final longitude = double.tryParse(treasure['longitude']?.toString() ?? '');
    final rating = double.tryParse(treasure['rating']?.toString() ?? '') ?? 0;
    final ratingCount =
        int.tryParse(treasure['ratingCount']?.toString() ?? '') ?? 0;
    final views = int.tryParse(treasure['views']?.toString() ?? '') ?? 0;

    return TreasureListing(
      id: treasure['id']?.toString() ?? fallbackListing?.id ?? '',
      title: treasure['title']?.toString() ?? fallbackListing?.title ?? '',
      category: _mapCategoryForUi(categoryRaw),
      sizeAge: fallbackListing?.sizeAge ?? 'Flexible Größe',
      conditionKey: _mapConditionForUi(rawCondition),
      distanceMeters: ((rawRadiusKm ??
                  (fallbackListing?.distanceMeters.toDouble() ?? 10000) /
                      1000) *
              1000)
          .round(),
      colorLabel: fallbackListing?.colorLabel ?? 'Neutral',
      note: treasure['description']?.toString() ?? fallbackListing?.note ?? '',
      locationLabel:
          treasure['location']?.toString() ?? fallbackListing?.locationLabel,
      latitude: latitude ?? fallbackListing?.latitude,
      longitude: longitude ?? fallbackListing?.longitude,
      rating: rating,
      ratingCount: ratingCount,
      views: views,
      imagePath: imageUrl ?? fallbackListing?.imagePath,
      imagePaths: [
        if (imageUrl != null && imageUrl.isNotEmpty) imageUrl,
        ...?fallbackListing?.imagePaths,
      ],
      createdAt: createdAt ?? fallbackListing?.createdAt ?? DateTime.now(),
    );
  }

  String _appendQuery(String path, Map<String, String> query) {
    if (query.isEmpty) return path;
    final uri = Uri(path: path, queryParameters: query);
    return uri.toString();
  }

  String _mapCategoryForBackend(String uiCategory) {
    final value = uiCategory.trim().toLowerCase();
    if (value.contains('fahr')) return 'vehicles';
    if (value.contains('kleidung')) return 'clothing';
    if (value.contains('spiel')) return 'toys';
    if (value.contains('buch')) return 'books';
    if (value.contains('ausstatt')) return 'equipment';
    return 'other';
  }

  String _mapCategoryForUi(String backendCategory) {
    final value = backendCategory.trim().toLowerCase();
    switch (value) {
      case 'vehicles':
        return 'Fahrzeuge';
      case 'clothing':
        return 'Kleidung';
      case 'books':
        return 'Bücher';
      case 'equipment':
        return 'Ausstattung';
      case 'toys':
      default:
        return 'Spielzeug';
    }
  }

  String _mapConditionForBackend(String uiCondition) {
    switch (uiCondition) {
      case 'studio':
        return 'like_new';
      case 'wild':
        return 'used';
      default:
        return 'good';
    }
  }

  String _mapConditionForUi(String backendCondition) {
    switch (backendCondition.trim().toLowerCase()) {
      case 'like_new':
      case 'new':
        return 'studio';
      case 'used':
      case 'fair':
        return 'wild';
      default:
        return 'round2';
    }
  }
}
