/// Smart Parent Matching Service with intelligent algorithm
/// Uses geographic proximity + interests + child compatibility scoring
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/logic/backend_api_client.dart';

class ParentMatchActionResult {
  final bool connected;
  final String matchState;
  
  const ParentMatchActionResult({
    required this.connected,
    required this.matchState,
  });
}

class ParentMatchingProfile {
  final String id;
  final String? userId;
  final String name;
  final int? age;
  final String city;
  final double? latitude;
  final double? longitude;
  final String? bio;
  final List<String> interests;
  final List<String> languages;
  final List<String> valuesFocus;
  final List<String> childAges;
  final String? familyForm;
  final bool phoneVerified;
  final bool identityVerified;
  final bool moderationChecked;
  final String? verificationLevel;

  ParentMatchingProfile({
    required this.id,
    this.userId,
    required this.name,
    this.age,
    required this.city,
    this.latitude,
    this.longitude,
    this.bio,
    this.interests = const [],
    this.languages = const [],
    this.valuesFocus = const [],
    this.childAges = const [],
    this.familyForm,
    this.phoneVerified = false,
    this.identityVerified = false,
    this.moderationChecked = false,
    this.verificationLevel,
  });

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    final text = value?.toString().toLowerCase().trim();
    return text == 'true' || text == '1' || text == 'yes';
  }

  factory ParentMatchingProfile.fromJson(Map<String, dynamic> json) {
    return ParentMatchingProfile(
      id: json['id'] ?? '',
      userId: json['ownerUserId'],
      name: json['name'] ?? '',
      age: json['age'],
      city: json['city'] ?? '',
      latitude: json['latitude'] != null ? double.parse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.parse(json['longitude'].toString()) : null,
      bio: json['bio'],
      interests: List<String>.from(json['interests'] ?? []),
      languages: List<String>.from(json['languages'] ?? []),
      valuesFocus: List<String>.from(json['valuesFocus'] ?? []),
      childAges: List<String>.from(json['childAges'] ?? []),
      familyForm: json['familyForm'],
      phoneVerified: _toBool(json['phoneVerified'] ?? json['isPhoneVerified']),
      identityVerified: _toBool(json['identityVerified'] ?? json['isIdentityVerified']),
      moderationChecked: _toBool(json['moderationChecked'] ?? json['isModerationChecked']),
      verificationLevel: json['verificationLevel']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
    'age': age,
    'city': city,
    'latitude': latitude,
    'longitude': longitude,
    'bio': bio,
    'interests': interests,
    'languages': languages,
    'valuesFocus': valuesFocus,
    'childAges': childAges,
    'familyForm': familyForm,
    'phoneVerified': phoneVerified,
    'identityVerified': identityVerified,
    'moderationChecked': moderationChecked,
    'verificationLevel': verificationLevel,
  };
}

class MatchResult {
  final ParentMatchingProfile profile;
  final int score;
  final Map<String, dynamic> breakdown;

  MatchResult({
    required this.profile,
    required this.score,
    required this.breakdown,
  });

  factory MatchResult.fromJson(Map<String, dynamic> json) {
    return MatchResult(
      profile: ParentMatchingProfile.fromJson(json['profile'] ?? {}),
      score: json['score'] ?? 0,
      breakdown: json['breakdown'] ?? {},
    );
  }
}

class ParentMatchingDiscoveryResult {
  final List<MatchResult> matches;
  final String scope;
  final bool globalDigitalMode;
  final bool showInviteBanner;
  final List<Map<String, String>> globalRooms;

  const ParentMatchingDiscoveryResult({
    required this.matches,
    required this.scope,
    required this.globalDigitalMode,
    required this.showInviteBanner,
    this.globalRooms = const [],
  });
}

class ParentMatchingBackendService {
  final String? _apiUrl = APIConfig.getBackendBaseUrl();
  final http.Client _httpClient;
  String? lastSyncError;
  
  // Backward compatibility: accept old apiClient parameter
  final dynamic apiClient;

  ParentMatchingBackendService({
    http.Client? httpClient,
    this.apiClient,
  }) : _httpClient = httpClient ?? http.Client();

  BackendApiClient? get _typedApiClient =>
      apiClient is BackendApiClient ? apiClient as BackendApiClient : null;

  Future<Map<String, dynamic>?> requestVerificationOtp({
    required String userId,
    required String phoneNumber,
  }) async {
    lastSyncError = null;
    if (_apiUrl == null) {
      lastSyncError = 'Backend-URL nicht konfiguriert';
      return null;
    }

    final payload = {
      'userId': userId,
      'phoneNumber': phoneNumber,
    };

    try {
      const endpoint = '/parent-matching/verification/request-otp';
      final client = _typedApiClient;
      if (client != null) {
        final decoded = await client.postJsonAny(endpoint, payload);
        return decoded is Map<String, dynamic> ? decoded : null;
      }

      final fallbackToken = APIConfig.getBackendApiToken();
      final response = await _httpClient.post(
        Uri.parse('$_apiUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          if (fallbackToken != null && fallbackToken.trim().isNotEmpty)
            'Authorization': 'Bearer ${fallbackToken.trim()}',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        lastSyncError = 'OTP-Anfrage fehlgeschlagen: ${response.statusCode}';
        return null;
      }

      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      lastSyncError = 'OTP-Anfrage fehlgeschlagen: $e';
      return null;
    }
  }

  Future<bool> confirmVerificationOtp({
    required String userId,
    required String code,
  }) async {
    lastSyncError = null;
    if (_apiUrl == null) {
      lastSyncError = 'Backend-URL nicht konfiguriert';
      return false;
    }

    final payload = {
      'userId': userId,
      'code': code,
    };

    try {
      const endpoint = '/parent-matching/verification/confirm-otp';
      final client = _typedApiClient;
      if (client != null) {
        final decoded = await client.postJsonAny(endpoint, payload);
        if (decoded is Map<String, dynamic>) {
          return decoded['verified'] == true || decoded['ok'] == true;
        }
        return false;
      }

      final fallbackToken = APIConfig.getBackendApiToken();
      final response = await _httpClient.post(
        Uri.parse('$_apiUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          if (fallbackToken != null && fallbackToken.trim().isNotEmpty)
            'Authorization': 'Bearer ${fallbackToken.trim()}',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        lastSyncError = 'OTP-Bestaetigung fehlgeschlagen: ${response.statusCode}';
        return false;
      }

      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> &&
          (decoded['verified'] == true || decoded['ok'] == true);
    } catch (e) {
      lastSyncError = 'OTP-Bestaetigung fehlgeschlagen: $e';
      return false;
    }
  }

  /// Backward compatibility: Create or update user's matching profile
  /// with interests and child compatibility info
  Future<ParentMatchingProfile?> createProfile({
    required String userId,
    required String name,
    int? age,
    required String city,
    double? latitude,
    double? longitude,
    List<String>? interests,
    List<String>? languages,
    List<String>? valuesFocus,
    List<String>? childAges,
    String? familyForm,
    String? bio,
  }) async {
    lastSyncError = null;

    if (_apiUrl == null) {
      lastSyncError = 'Backend-URL nicht konfiguriert';
      return null;
    }

    final payload = {
      'userId': userId,
      'name': name,
      'age': age,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'bio': bio,
      'interests': interests ?? [],
      'languages': languages ?? [],
      'valuesFocus': valuesFocus ?? [],
      'childAges': childAges ?? [],
      'familyForm': familyForm,
    };

    try {
      final myProfilePath = APIConfig.getBackendParentMatchingMyProfilePath();
      final client = _typedApiClient;
      if (client != null) {
        final decoded = await client.postJsonAny(myProfilePath, payload);
        final data = decoded is Map<String, dynamic>
            ? (decoded['item'] is Map<String, dynamic>
                ? decoded['item'] as Map<String, dynamic>
                : decoded)
            : <String, dynamic>{};
        if (data.isEmpty) {
          lastSyncError = 'Profil-Speicherung fehlgeschlagen: leere Server-Antwort';
          return null;
        }
        return ParentMatchingProfile.fromJson(data);
      }

      final fallbackToken = APIConfig.getBackendApiToken();
      final response = await _httpClient.post(
        Uri.parse('$_apiUrl$myProfilePath'),
        headers: {
          'Content-Type': 'application/json',
          if (fallbackToken != null && fallbackToken.trim().isNotEmpty)
            'Authorization': 'Bearer ${fallbackToken.trim()}',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        lastSyncError = 'Profil-Speicherung fehlgeschlagen: ${response.statusCode}';
        return null;
      }

      final decoded = jsonDecode(response.body);
      final data = decoded is Map<String, dynamic>
          ? (decoded['item'] is Map<String, dynamic>
              ? decoded['item'] as Map<String, dynamic>
              : decoded)
          : <String, dynamic>{};
      if (data.isEmpty) {
        lastSyncError = 'Profil-Speicherung fehlgeschlagen: leere Server-Antwort';
        return null;
      }
      return ParentMatchingProfile.fromJson(data);
    } catch (e) {
      lastSyncError = 'Fehler beim Erstellen des Profils: $e';
      return null;
    }
  }

  /// Backward compatibility: Fetch my profile
  Future<Map<String, dynamic>?> fetchMyProfile({required String userId}) async {
    lastSyncError = null;
    try {
      if (_apiUrl == null) {
        lastSyncError = 'Backend-URL nicht konfiguriert';
        return null;
      }

      final myProfilePath = APIConfig.getBackendParentMatchingMyProfilePath();
      final requestPath = '$myProfilePath?userId=$userId';
      final client = _typedApiClient;
      if (client != null) {
        final decoded = await client.getJson(requestPath);
        if (decoded is! Map<String, dynamic>) {
          return null;
        }
        final item = decoded['item'];
        if (item is Map<String, dynamic>) {
          return item;
        }
        return decoded;
      }

      final fallbackToken = APIConfig.getBackendApiToken();
      final response = await _httpClient.get(
        Uri.parse('$_apiUrl$requestPath'),
        headers: {
          'Content-Type': 'application/json',
          if (fallbackToken != null && fallbackToken.trim().isNotEmpty)
            'Authorization': 'Bearer ${fallbackToken.trim()}',
        },
      );

      if (response.statusCode == 404) {
        return null;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        lastSyncError = 'Profil konnte nicht geladen werden: ${response.statusCode}';
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final item = decoded['item'];
      if (item is Map<String, dynamic>) {
        return item;
      }
      return decoded;
    } catch (e) {
      final text = e.toString();
      if (text.contains('404')) {
        return null;
      }
      lastSyncError = 'Profil konnte nicht geladen werden: $e';
      return null;
    }
  }

  /// Backward compatibility: Upsert (update or insert) user profile
  Future<Map<String, dynamic>?> upsertMyProfile({
    required String userId,
    required Map<String, dynamic> profile,
  }) async {
    lastSyncError = null;
    try {
      final result = await createProfile(
        userId: userId,
        name: profile['name'] ?? 'Elternteil',
        age: profile['age'],
        city: profile['city'] ?? 'Berlin',
        latitude: profile['latitude'],
        longitude: profile['longitude'],
        interests: List<String>.from(profile['interests'] ?? []),
        languages: List<String>.from(profile['languages'] ?? []),
        valuesFocus: List<String>.from(profile['valuesFocus'] ?? []),
        childAges: List<String>.from(profile['childAges'] ?? []),
        familyForm: profile['familyForm'],
        bio: profile['bio'],
      );
      return result?.toJson();
    } catch (e) {
      lastSyncError = 'Profil konnte nicht aktualisiert werden: $e';
      return null;
    }
  }

  /// Backward compatibility: Fetch all profiles
  Future<List<Map<String, dynamic>>> fetchProfiles({String? userId}) async {
    lastSyncError = null;
    try {
      // Return empty for backward compatibility
      // The new API uses findMatches() instead
      return [];
    } catch (e) {
      lastSyncError = 'Profile konnten nicht geladen werden: $e';
      return [];
    }
  }

  /// Backward compatibility: Fetch connected profile IDs
  Future<Set<String>> fetchConnectedProfileIds({required String userId}) async {
    lastSyncError = null;
    try {
      return <String>{};
    } catch (e) {
      lastSyncError = 'Verbindungen konnten nicht geladen werden: $e';
      return <String>{};
    }
  }

  /// Backward compatibility: Fetch messages
  Future<List<Map<String, dynamic>>> fetchMessages({
    required String profileId,
    required String userId,
  }) async {
    lastSyncError = null;
    try {
      return [];
    } catch (e) {
      lastSyncError = 'Nachrichten konnten nicht geladen werden: $e';
      return [];
    }
  }

  /// Backward compatibility: Send message
  Future<Map<String, dynamic>?> sendMessage({
    required String profileId,
    required String userId,
    required String userName,
    required String content,
  }) async {
    lastSyncError = null;
    try {
      return null;
    } catch (e) {
      lastSyncError = 'Nachricht konnte nicht gesendet werden: $e';
      return null;
    }
  }

  /// Backward compatibility: Stream messages
  Stream<Map<String, dynamic>> streamMessages({
    required String profileId,
    required String userId,
  }) async* {
    // Not implemented in new API
    yield {};
  }

  /// Backward compatibility: Send action with old signature
  Future<ParentMatchActionResult> sendAction({
    required String profileId,
    required String action,
    String? userId,
  }) async {
    lastSyncError = null;
    try {
      final result = await recordAction(
        userId: userId ?? 'anonymous',
        matchedProfileId: profileId,
        action: action,
      );
      return ParentMatchActionResult(
        connected: result,
        matchState: result ? 'matched' : (action == 'like' ? 'pending' : 'none'),
      );
    } catch (e) {
      lastSyncError = 'Aktion konnte nicht gespeichert werden: $e';
      return const ParentMatchActionResult(
        connected: false,
        matchState: 'error',
      );
    }
  }

  Future<ParentMatchingDiscoveryResult> findMatchesWithFallback({
    required String userId,
    int limit = 10,
    List<String> childAges = const [],
  }) async {
    lastSyncError = null;
    const fallbackRadii = <double>[10, 50, 100, 1200];
    const fallbackScopes = <String>['10km', '50km', '100km', 'country'];

    for (var i = 0; i < fallbackRadii.length; i++) {
      final matches = await findMatches(
        userId: userId,
        limit: limit,
        maxDistanceKm: fallbackRadii[i],
      );
      if (matches.isNotEmpty) {
        return ParentMatchingDiscoveryResult(
          matches: matches,
          scope: fallbackScopes[i],
          globalDigitalMode: false,
          showInviteBanner: i > 0,
        );
      }
    }

    final ageTag = childAges.isNotEmpty ? childAges.first : '6-9';
    return ParentMatchingDiscoveryResult(
      matches: const [],
      scope: 'global',
      globalDigitalMode: true,
      showInviteBanner: true,
      globalRooms: [
        {
          'id': 'global-room-age-$ageTag',
          'title': 'Globaler Elternchat: Alter $ageTag',
          'subtitle': 'Online Austausch zu Alltag, Schlaf und Routinen',
        },
        {
          'id': 'global-room-bedtime',
          'title': 'Globaler Elternchat: Schlaf & Abendroutinen',
          'subtitle': 'Kurzform Tipps und Erfahrungen in Echtzeit',
        },
        {
          'id': 'global-room-school',
          'title': 'Globaler Elternchat: Kita, Schule & Lernen',
          'subtitle': 'Themenbasierter Austausch fuer Eltern weltweit',
        },
      ],
    );
  }

  // ===== NEW SMART MATCHING METHODS =====

  /// Find matching parent profiles using smart algorithm
  /// Considers: geographic proximity (haversine), interests (jaccard), child age compatibility
  /// Returns sorted list by match score (0-100)
  Future<List<MatchResult>> findMatches({
    required String userId,
    int limit = 10,
    double maxDistanceKm = 25,
  }) async {
    lastSyncError = null;
    
    if (_apiUrl == null) {
      lastSyncError = 'Backend-URL nicht konfiguriert';
      return [];
    }
    
    try {
      final response = await _httpClient.get(
        Uri.parse(
          '$_apiUrl/api/parent-matching/find?userId=$userId&limit=$limit&maxDistanceKm=$maxDistanceKm',
        ),
      );

      if (response.statusCode == 404) {
        return [];
      }

      if (response.statusCode != 200) {
        lastSyncError = 'Matching fehlgeschlagen: ${response.statusCode}';
        return [];
      }

      final data = jsonDecode(response.body);
      final matches = List<MatchResult>.from(
        (data['matches'] as List? ?? []).map((m) => MatchResult.fromJson(m as Map<String, dynamic>)),
      );

      return matches;
    } catch (e) {
      lastSyncError = 'Fehler beim Finden von Matches: $e';
      return [];
    }
  }

  /// Record user action (like, contact, pass, favorite) for analytics
  /// This helps refine future matches based on user interactions
  Future<bool> recordAction({
    required String userId,
    required String matchedProfileId,
    required String action, // 'like', 'contact', 'pass', 'favorite'
    String? familyId,
  }) async {
    lastSyncError = null;
    
    if (_apiUrl == null) {
      lastSyncError = 'Backend-URL nicht konfiguriert';
      return false;
    }
    
    try {
      final response = await _httpClient.post(
        Uri.parse('$_apiUrl/api/parent-matching/record-action'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'matchedProfileId': matchedProfileId,
          'action': action,
          'familyId': familyId,
        }),
      );

      if (response.statusCode != 201) {
        lastSyncError = 'Aktion konnte nicht gespeichert werden: ${response.statusCode}';
        return false;
      }

      return true;
    } catch (e) {
      lastSyncError = 'Fehler beim Speichern der Aktion: $e';
      return false;
    }
  }
}
