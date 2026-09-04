import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';
import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/parent_matching_backend_service.dart';
import 'package:parentpeak/ui/match_conversation_screen.dart';

class ParentMatchingScreen extends StatefulWidget {
  const ParentMatchingScreen({
    super.key,
    this.openNewConnectionsOnOpen = false,
  });

  final bool openNewConnectionsOnOpen;

  @override
  State<ParentMatchingScreen> createState() => _ParentMatchingScreenState();
}

class _ParentMatchingScreenState extends State<ParentMatchingScreen> {
  static const String _storageKey = 'parent_matching.v1';
  static const Set<String> _defaultMyInterests = {
    'Bildung',
    'Spielplatz',
    'Familienzeit',
    'Outdoor',
    'Gesundheit'
  };
  static const Set<String> _defaultMyLanguages = {'Deutsch', 'Englisch'};
  static const Set<String> _defaultMyValues = {
    'Gewaltfrei',
    'Respekt',
    'Inklusion',
    'Empathie'
  };
  static const Map<String, (double, double)> _cityCenters = {
    'Berlin': (52.520008, 13.404954),
    'Koeln': (50.937531, 6.960279),
    'Hamburg': (53.551086, 9.993682),
    'Muenchen': (48.137154, 11.576124),
    'Frankfurt': (50.110924, 8.682127),
  };

  final ParentMatchingBackendService _service =
      BackendServiceFactory.createParentMatchingService();
  final List<_ParentProfile> _allProfiles = [];
  final List<_ParentProfile> _likedProfiles = [];
  final List<_ParentProfile> _matchedProfiles = [];
  final Set<String> _blockedProfileIds = {};
  final Set<String> _reportedProfileIds = {};

  final Set<String> _interestFilter = {};
  final Set<String> _languageFilter = {};
  final Set<String> _valuesFilter = {};
  final Set<String> _familyFormFilter = {};
  final Set<String> _childAgeFilter = {};
  final Set<String> _myInterests = {..._defaultMyInterests};
  final Set<String> _myLanguages = {..._defaultMyLanguages};
  final Set<String> _myValues = {..._defaultMyValues};
  final Set<String> _seenMatchedProfileIds = {};
  final Set<String> _newlyConfirmedProfileIds = {};

  double _maxDistanceKm = 20;
  String _homeCity = 'Berlin';
  int _newConfirmedSinceLastVisit = 0;

  int _currentIndex = 0;
  bool _isRestoring = true;
  bool _requiresProfileSetup = false;
  bool _isSavingProfile = false;
  bool _saveSuccessFlash = false;
  bool _setupEntranceVisible = false;
  bool _showWelcomeMatchHighlight = false;
  String? _welcomeMatchProfileId;
  final TextEditingController _profileNameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _otpCodeController = TextEditingController();
  final FocusNode _profileNameFocusNode = FocusNode();
  final FocusNode _cityFocusNode = FocusNode();
  final FocusNode _ageFocusNode = FocusNode();
  final FocusNode _familyFormFocusNode = FocusNode();
  int _profileAge = 33;
  String _profileFamilyForm = 'Kernfamilie';
  bool _phoneVerifiedLocal = false;
  bool _isVerifyingPhone = false;
  bool _otpRequested = false;
  String? _otpDevHint;
  bool _showDiscoveryInviteBanner = false;
  bool _globalDigitalMode = false;
  String _discoveryScope = '10km';
  List<Map<String, String>> _globalRooms = const [];

  String? get _currentUserId {
    final value = AuthService.instance.currentUser?.uid.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  String get _effectiveUserId => _currentUserId ?? 'local-parent-user';

  String _t(String key) =>
      AppStringsManager.getString(languageService.currentLanguage, key);

  @override
  void initState() {
    super.initState();
    _profileNameFocusNode.addListener(_onSetupFieldFocusChanged);
    _cityFocusNode.addListener(_onSetupFieldFocusChanged);
    _ageFocusNode.addListener(_onSetupFieldFocusChanged);
    _familyFormFocusNode.addListener(_onSetupFieldFocusChanged);
    _bootstrap();
  }

  void _onSetupFieldFocusChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _profileNameFocusNode.removeListener(_onSetupFieldFocusChanged);
    _cityFocusNode.removeListener(_onSetupFieldFocusChanged);
    _ageFocusNode.removeListener(_onSetupFieldFocusChanged);
    _familyFormFocusNode.removeListener(_onSetupFieldFocusChanged);
    _profileNameFocusNode.dispose();
    _cityFocusNode.dispose();
    _ageFocusNode.dispose();
    _familyFormFocusNode.dispose();
    _phoneNumberController.dispose();
    _otpCodeController.dispose();
    _profileNameController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedInputShell({
    required bool focused,
    required Widget child,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: focused
            ? const [
                BoxShadow(
                  color: Color(0x1F1E5CD7),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  Widget _buildAnimatedFieldLabel({
    required String label,
    required bool focused,
  }) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      style: TextStyle(
        color: focused ? const Color(0xFF1E5CD7) : const Color(0xFF62758C),
        fontSize: focused ? 12.5 : 12,
        fontWeight: FontWeight.w700,
      ),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(left: focused ? 2 : 0, bottom: 6),
        child: Text(label),
      ),
    );
  }

  Future<void> _bootstrap() async {
    final profileReady = await _ensureMyProfileExists();
    if (!profileReady) return;

    await _loadProfiles();
    await _restoreState();
    await _refreshConnectionsFromBackend(
      announce: !widget.openNewConnectionsOnOpen,
    );

    if (widget.openNewConnectionsOnOpen && _newConfirmedSinceLastVisit > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openNewConnectionsSheet();
      });
    }
  }

  Future<bool> _ensureMyProfileExists() async {
    final profile = await _service.fetchMyProfile(userId: _effectiveUserId);
    if (profile != null) {
      if (_setupEntranceVisible) {
        _setupEntranceVisible = false;
      }
      _phoneVerifiedLocal = profile['phoneVerified'] == true ||
          profile['isPhoneVerified'] == true;
      if (_profileNameController.text.trim().isEmpty) {
        _profileNameController.text = (profile['name'] ?? '').toString();
      }
      return true;
    }

    if (!mounted) return false;
    _profileNameController.text =
        AuthService.instance.currentUser?.displayName.trim().isNotEmpty == true
            ? AuthService.instance.currentUser!.displayName.trim()
            : AuthService.instance.currentUser?.friendlyName ??
                'Familien-Kontakt';
    setState(() {
      _requiresProfileSetup = true;
      _isRestoring = false;
      _setupEntranceVisible = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_requiresProfileSetup) return;
      setState(() => _setupEntranceVisible = true);
    });
    return false;
  }

  Future<void> _loadProfiles() async {
    try {
      final discovery = await _service.findMatchesWithFallback(
        userId: _effectiveUserId,
        childAges: _childAgeFilter.toList(),
      );

      final matchResults = discovery.matches;

      // Convert MatchResult objects to internal _ParentProfile format
      final profiles = matchResults.map((result) {
        final profile = result.profile;
        // Convert breakdown map values to doubles
        final breakdownAsDoubles = result.breakdown.map(
          (key, value) =>
              MapEntry(key, (value is num) ? value.toDouble() : 0.0),
        );
        final age = profile.age;
        final familyForm = profile.familyForm;
        return _ParentProfile(
          id: profile.id,
          name: profile.name,
          age: age ?? 30,
          city: profile.city,
          bio: 'Matching-Score: ${result.score.toStringAsFixed(0)}%',
          interests: profile.interests,
          languages: profile.languages,
          valuesFocus: profile.valuesFocus,
          familyForm: familyForm ?? 'Familie',
          childAges: profile.childAges,
          latitude: profile.latitude,
          longitude: profile.longitude,
          verificationLevel: _mapVerificationLevel(profile),
          score: result.score.toDouble(),
          breakdown: breakdownAsDoubles,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _showDiscoveryInviteBanner = discovery.showInviteBanner;
        _globalDigitalMode = discovery.globalDigitalMode;
        _discoveryScope = discovery.scope;
        _globalRooms = discovery.globalRooms;
        _allProfiles
          ..clear()
          ..addAll(profiles);
      });
    } catch (e) {
      // Fallback for errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_t('matching_load_failed')}: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      if (!mounted) return;
      setState(() => _isRestoring = false);
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        if (!mounted) return;
        setState(() => _isRestoring = false);
        return;
      }

      final likedIds =
          (decoded['likedIds'] as List?)?.map((e) => e.toString()).toSet() ??
              <String>{};
      final matchedIds =
          (decoded['matchedIds'] as List?)?.map((e) => e.toString()).toSet() ??
              <String>{};
      final blockedIds =
          (decoded['blockedIds'] as List?)?.map((e) => e.toString()).toSet() ??
              <String>{};
      final reportedIds =
          (decoded['reportedIds'] as List?)?.map((e) => e.toString()).toSet() ??
              <String>{};

      if (!mounted) return;
      setState(() {
        _likedProfiles
          ..clear()
          ..addAll(_allProfiles.where((p) => likedIds.contains(p.id)));
        _matchedProfiles
          ..clear()
          ..addAll(_allProfiles.where((p) => matchedIds.contains(p.id)));
        _seenMatchedProfileIds
          ..clear()
          ..addAll((decoded['seenMatchedProfileIds'] as List?)
                  ?.map((e) => e.toString())
                  .toSet() ??
              matchedIds);
        _blockedProfileIds
          ..clear()
          ..addAll(blockedIds);
        _reportedProfileIds
          ..clear()
          ..addAll(reportedIds);

        _interestFilter
          ..clear()
          ..addAll((decoded['interestFilter'] as List?)
                  ?.map((e) => e.toString())
                  .toSet() ??
              <String>{});
        _languageFilter
          ..clear()
          ..addAll((decoded['languageFilter'] as List?)
                  ?.map((e) => e.toString())
                  .toSet() ??
              <String>{});
        _valuesFilter
          ..clear()
          ..addAll((decoded['valuesFilter'] as List?)
                  ?.map((e) => e.toString())
                  .toSet() ??
              <String>{});
        _familyFormFilter
          ..clear()
          ..addAll((decoded['familyFormFilter'] as List?)
                  ?.map((e) => e.toString())
                  .toSet() ??
              <String>{});
        _childAgeFilter
          ..clear()
          ..addAll((decoded['childAgeFilter'] as List?)
                  ?.map((e) => e.toString())
                  .toSet() ??
              <String>{});

        _myInterests
          ..clear()
          ..addAll((decoded['myInterests'] as List?)
                  ?.map((e) => e.toString())
                  .toSet() ??
              _defaultMyInterests);
        _myLanguages
          ..clear()
          ..addAll((decoded['myLanguages'] as List?)
                  ?.map((e) => e.toString())
                  .toSet() ??
              _defaultMyLanguages);
        _myValues
          ..clear()
          ..addAll((decoded['myValues'] as List?)
                  ?.map((e) => e.toString())
                  .toSet() ??
              _defaultMyValues);
        _homeCity = (decoded['homeCity'] ?? _homeCity).toString();
        _maxDistanceKm =
            (decoded['maxDistanceKm'] as num?)?.toDouble().clamp(3, 100) ?? 20;

        _currentIndex = (decoded['currentIndex'] as num?)?.toInt() ?? 0;
        _isRestoring = false;
      });
    } catch (e) {
      debugPrint('ParentMatchingScreen._restoreState(): failed: $e');
      if (!mounted) return;
      setState(() => _isRestoring = false);
    }
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'likedIds': _likedProfiles.map((p) => p.id).toList(),
      'matchedIds': _matchedProfiles.map((p) => p.id).toList(),
      'blockedIds': _blockedProfileIds.toList(),
      'reportedIds': _reportedProfileIds.toList(),
      'interestFilter': _interestFilter.toList(),
      'languageFilter': _languageFilter.toList(),
      'valuesFilter': _valuesFilter.toList(),
      'familyFormFilter': _familyFormFilter.toList(),
      'childAgeFilter': _childAgeFilter.toList(),
      'myInterests': _myInterests.toList(),
      'myLanguages': _myLanguages.toList(),
      'myValues': _myValues.toList(),
      'homeCity': _homeCity,
      'maxDistanceKm': _maxDistanceKm,
      'seenMatchedProfileIds': _seenMatchedProfileIds.toList(),
      'currentIndex': _currentIndex,
    };
    await prefs.setString(_storageKey, jsonEncode(payload));
  }

  Future<void> _refreshConnectionsFromBackend({bool announce = true}) async {
    try {
      // Fetch latest matches using smart algorithm
      final matchResults = await _service.findMatches(userId: _effectiveUserId);

      // Get connected profile IDs from backend
      final connectedIds =
          await _service.fetchConnectedProfileIds(userId: _effectiveUserId);
      final newlyConfirmedIds = connectedIds.difference(_seenMatchedProfileIds);

      if (!mounted) return;

      // Update both all profiles and matched profiles
      final profiles = matchResults.map((result) {
        final profile = result.profile;
        // Convert breakdown map values to doubles
        final breakdownAsDoubles = result.breakdown.map(
          (key, value) =>
              MapEntry(key, (value is num) ? value.toDouble() : 0.0),
        );
        final age = profile.age;
        final familyForm = profile.familyForm;
        return _ParentProfile(
          id: profile.id,
          name: profile.name,
          age: age ?? 30,
          city: profile.city,
          bio: 'Matching-Score: ${result.score.toStringAsFixed(0)}%',
          interests: profile.interests,
          languages: profile.languages,
          valuesFocus: profile.valuesFocus,
          familyForm: familyForm ?? 'Familie',
          childAges: profile.childAges,
          latitude: profile.latitude,
          longitude: profile.longitude,
          verificationLevel: _mapVerificationLevel(profile),
          score: result.score.toDouble(),
          breakdown: breakdownAsDoubles,
        );
      }).toList();

      setState(() {
        _allProfiles
          ..clear()
          ..addAll(profiles);

        _matchedProfiles
          ..clear()
          ..addAll(_allProfiles.where((p) => connectedIds.contains(p.id)));
        _newlyConfirmedProfileIds
          ..clear()
          ..addAll(newlyConfirmedIds);
        _newConfirmedSinceLastVisit = _newlyConfirmedProfileIds.length;
      });

      if (announce && newlyConfirmedIds.isNotEmpty) {
        final count = newlyConfirmedIds.length;
        final text = count == 1
            ? 'Neue bestätigte Verbindung verfügbar.'
            : '$count neue bestätigte Verbindungen verfügbar.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      _persistState();
    } catch (e) {
      // Fallback - try the old method
      final connectedIds =
          await _service.fetchConnectedProfileIds(userId: _effectiveUserId);
      final newlyConfirmedIds = connectedIds.difference(_seenMatchedProfileIds);

      if (!mounted) return;
      setState(() {
        _matchedProfiles
          ..clear()
          ..addAll(_allProfiles.where((p) => connectedIds.contains(p.id)));
        _newlyConfirmedProfileIds
          ..clear()
          ..addAll(newlyConfirmedIds);
        _newConfirmedSinceLastVisit = _newlyConfirmedProfileIds.length;
      });

      if (announce && newlyConfirmedIds.isNotEmpty) {
        final count = newlyConfirmedIds.length;
        final text = count == 1
            ? 'Neue bestätigte Verbindung verfügbar.'
            : '$count neue bestätigte Verbindungen verfügbar.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      _persistState();
    }
  }

  Future<void> _acknowledgeNewConnections() async {
    setState(() {
      _seenMatchedProfileIds.addAll(_matchedProfiles.map((p) => p.id));
      _newlyConfirmedProfileIds.clear();
      _newConfirmedSinceLastVisit = 0;
    });
    await _persistState();
  }

  void _openNewConnectionsSheet() {
    final names = _matchedProfiles
        .where((profile) => _newlyConfirmedProfileIds.contains(profile.id))
        .map((profile) => profile.name)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Neue bestätigte Verbindungen',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (names.isEmpty)
                  Text(_t('matching_no_new_connections'))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: names
                        .map(
                          (name) => Chip(
                            avatar:
                                const Icon(Icons.handshake_rounded, size: 16),
                            label: Text(name),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await _acknowledgeNewConnections();
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
                    child: Text(AppStringsManager.getString(
                        languageService.currentLanguage, 'all_seen')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_ParentProfile> get _filteredProfiles {
    final list = _allProfiles.where((profile) {
      if (_blockedProfileIds.contains(profile.id)) {
        return false;
      }
      if (_reportedProfileIds.contains(profile.id)) {
        return false;
      }
      if (_interestFilter.isNotEmpty &&
          profile.interests.toSet().intersection(_interestFilter).isEmpty) {
        return false;
      }
      if (_languageFilter.isNotEmpty &&
          profile.languages.toSet().intersection(_languageFilter).isEmpty) {
        return false;
      }
      if (_valuesFilter.isNotEmpty &&
          profile.valuesFocus.toSet().intersection(_valuesFilter).isEmpty) {
        return false;
      }
      if (_familyFormFilter.isNotEmpty &&
          !_familyFormFilter.contains(profile.familyForm)) {
        return false;
      }
      if (_childAgeFilter.isNotEmpty &&
          profile.childAges.toSet().intersection(_childAgeFilter).isEmpty) {
        return false;
      }
      final distanceKm = _distanceKm(profile);
      if (distanceKm != null && distanceKm > _maxDistanceKm) {
        return false;
      }
      return true;
    }).toList();

    list.sort((a, b) => _compatibility(b).compareTo(_compatibility(a)));
    return list;
  }

  _ParentProfile? get _currentProfile {
    final list = _filteredProfiles;
    if (list.isEmpty || _currentIndex >= list.length) return null;
    return list[_currentIndex];
  }

  List<_ParentProfile> get _pendingProfiles {
    final matchedIds = _matchedProfiles.map((p) => p.id).toSet();
    return _likedProfiles.where((p) => !matchedIds.contains(p.id)).toList();
  }

  void _moveNext() {
    final list = _filteredProfiles;
    if (list.isEmpty) return;
    setState(() {
      if (_currentIndex < list.length - 1) {
        _currentIndex += 1;
      } else {
        _currentIndex = 0;
      }
    });
    _persistState();
  }

  int _compatibility(_ParentProfile profile) {
    final interestsMatch =
        profile.interests.toSet().intersection(_myInterests).length;
    final languagesMatch =
        profile.languages.toSet().intersection(_myLanguages).length;
    final valuesMatch =
        profile.valuesFocus.toSet().intersection(_myValues).length;
    final distanceKm = _distanceKm(profile);

    var distanceBoost = 0;
    if (distanceKm != null) {
      if (distanceKm <= 5) {
        distanceBoost = 18;
      } else if (distanceKm <= 10) {
        distanceBoost = 12;
      } else if (distanceKm <= 20) {
        distanceBoost = 8;
      } else if (distanceKm <= _maxDistanceKm) {
        distanceBoost = 4;
      }
    }

    final base = (interestsMatch * 15) +
        (languagesMatch * 13) +
        (valuesMatch * 11) +
        distanceBoost;
    return min(98, max(45, base));
  }

  (double, double)? get _homeLatLng => _cityCenters[_homeCity];

  double? _distanceKm(_ParentProfile profile) {
    if (profile.latitude == null || profile.longitude == null) {
      return null;
    }
    final home = _homeLatLng;
    if (home == null) return null;
    return _haversineKm(
        home.$1, home.$2, profile.latitude!, profile.longitude!);
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = pow(sin(dLat / 2), 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * pow(sin(dLon / 2), 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRadians(double degree) => degree * pi / 180;

  int _categoryScore(List<String> profileValues, Set<String> myValues) {
    if (profileValues.isEmpty) return 0;
    final overlap = profileValues.toSet().intersection(myValues).length;
    return min(100, ((overlap / profileValues.length) * 100).round());
  }

  _MatchQuality _matchQuality(_ParentProfile profile) {
    return _MatchQuality(
      interests: _categoryScore(profile.interests, _myInterests),
      languages: _categoryScore(profile.languages, _myLanguages),
      values: _categoryScore(profile.valuesFocus, _myValues),
    );
  }

  List<String> _whyMatch(_ParentProfile profile) {
    final reasons = <String>[];
    final sharedInterests =
        profile.interests.toSet().intersection(_myInterests).toList();
    final sharedLanguages =
        profile.languages.toSet().intersection(_myLanguages).toList();
    final sharedValues =
        profile.valuesFocus.toSet().intersection(_myValues).toList();

    if (sharedInterests.isNotEmpty) {
      reasons
          .add('Gemeinsame Interessen: ${sharedInterests.take(2).join(', ')}');
    }
    if (sharedLanguages.isNotEmpty) {
      reasons.add('Sprache passt: ${sharedLanguages.take(2).join(', ')}');
    }
    if (sharedValues.isNotEmpty) {
      reasons.add('Ähnliche Werte: ${sharedValues.take(2).join(', ')}');
    }
    final distance = _distanceKm(profile);
    if (distance != null) {
      reasons.add('Wohnortnähe: ${distance.toStringAsFixed(1)} km entfernt');
    }
    if (reasons.isEmpty) {
      reasons.add('Passende Familienphase und Offenheit für Austausch');
    }
    return reasons;
  }

  Future<void> _likeCurrent() async {
    final profile = _currentProfile;
    if (profile == null) return;

    if (profile.verificationLevel == _VerificationLevel.basic) {
      final proceed = await _confirmBasicVerification(profile);
      if (!proceed) {
        return;
      }
    }

    if (!_likedProfiles.any((p) => p.id == profile.id)) {
      _likedProfiles.add(profile);
    }

    final score = _compatibility(profile);

    _moveNext();
    _persistState();
    final result = await _service.sendAction(
      profileId: profile.id,
      action: 'like',
      userId: _effectiveUserId,
    );
    await _refreshConnectionsFromBackend(announce: false);
    if (!mounted) return;

    if (result.connected || result.matchState == 'matched') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_t('matching_confirmed')
              .replaceAll('{name}', profile.name)
              .replaceAll('{score}', '$score')),
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (result.matchState == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Anfrage an ${profile.name} gesendet. Wir melden uns, sobald es gegenseitig ist.'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('matching_request_sent')),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  _VerificationLevel _mapVerificationLevel(ParentMatchingProfile profile) {
    final raw = (profile.verificationLevel ?? '').trim().toLowerCase();
    if (raw == 'recommended' || raw == 'trusted') {
      return _VerificationLevel.recommended;
    }
    if (raw == 'checked' || raw == 'verified') {
      return _VerificationLevel.checked;
    }
    if (profile.identityVerified ||
        profile.phoneVerified ||
        profile.moderationChecked) {
      return _VerificationLevel.checked;
    }
    return _VerificationLevel.basic;
  }

  Future<bool> _confirmBasicVerification(_ParentProfile profile) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('matching_safety_check')),
        content: Text(
          'Das Profil ${profile.name} ist aktuell nur auf Basisniveau verifiziert. '
          'Teile keine privaten Kontaktdaten oder genaue Kinder-Standorte im ersten Kontakt. '
          'Möchtest du trotzdem eine Anfrage senden?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppStringsManager.getString(
                languageService.currentLanguage, 'send_anyway')),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _reportCurrent() {
    final profile = _currentProfile;
    if (profile == null) return;

    setState(() {
      _reportedProfileIds.add(profile.id);
      _likedProfiles.removeWhere((p) => p.id == profile.id);
      _matchedProfiles.removeWhere((p) => p.id == profile.id);
      _currentIndex = 0;
    });
    _persistState();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Profil ${profile.name} wurde gemeldet und ausgeblendet.'),
        duration: const Duration(seconds: 2),
      ),
    );

    _service.sendAction(
      profileId: profile.id,
      action: 'report',
      userId: _effectiveUserId,
    );
  }

  void _blockCurrent() {
    final profile = _currentProfile;
    if (profile == null) return;

    setState(() {
      _blockedProfileIds.add(profile.id);
      _likedProfiles.removeWhere((p) => p.id == profile.id);
      _matchedProfiles.removeWhere((p) => p.id == profile.id);
      _currentIndex = 0;
    });
    _persistState();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${profile.name} wurde blockiert.'),
        duration: const Duration(seconds: 2),
      ),
    );

    _service.sendAction(
      profileId: profile.id,
      action: 'block',
      userId: _effectiveUserId,
    );
  }

  Future<void> _saveMyProfile() async {
    final name = _profileNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('matching_enter_name'))),
      );
      return;
    }

    setState(() => _isSavingProfile = true);

    // Get city coordinates
    final cityCenter = _cityCenters[_homeCity] ?? _cityCenters['Berlin']!;

    final saved = await _service.createProfile(
      userId: _effectiveUserId,
      name: name,
      age: _profileAge,
      city: _homeCity,
      latitude: cityCenter.$1,
      longitude: cityCenter.$2,
      interests: _myInterests.toList(),
      languages: _myLanguages.toList(),
      valuesFocus: _myValues.toList(),
      childAges: _childAgeFilter.isNotEmpty
          ? _childAgeFilter.toList()
          : const ['3-5', '6-9'],
      familyForm: _profileFamilyForm,
    );
    if (!mounted) return;

    if (saved == null) {
      setState(() => _isSavingProfile = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _service.lastSyncError ??
                'Matching-Profil konnte nicht gespeichert werden.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSavingProfile = false;
      _saveSuccessFlash = true;
    });
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    setState(() => _setupEntranceVisible = false);
    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;

    setState(() {
      _saveSuccessFlash = false;
      _requiresProfileSetup = false;
      _isRestoring = true;
    });
    await _bootstrap();
    if (!mounted) return;
    _showWelcomeMatchHighlightOnce();
    _showProfileSavedToast();
  }

  Future<void> _requestPhoneOtp() async {
    final phone = _phoneNumberController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('matching_enter_phone'))),
      );
      return;
    }

    setState(() => _isVerifyingPhone = true);
    final response = await _service.requestVerificationOtp(
      userId: _effectiveUserId,
      phoneNumber: phone,
    );
    if (!mounted) return;

    setState(() {
      _isVerifyingPhone = false;
      _otpRequested = response != null;
      _otpDevHint = response?['devCode']?.toString();
    });

    if (response == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _service.lastSyncError ?? 'OTP konnte nicht angefordert werden.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('matching_otp_sent'))),
    );
  }

  Future<void> _confirmPhoneOtp() async {
    final code = _otpCodeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('matching_enter_otp'))),
      );
      return;
    }

    setState(() => _isVerifyingPhone = true);
    final ok = await _service.confirmVerificationOtp(
      userId: _effectiveUserId,
      code: code,
    );
    if (!mounted) return;
    setState(() => _isVerifyingPhone = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _service.lastSyncError ?? 'OTP-Bestaetigung fehlgeschlagen.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _phoneVerifiedLocal = true;
      _otpRequested = false;
      _otpDevHint = null;
    });

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('matching_phone_verified'))),
    );
  }

  Future<void> _openPhoneVerificationSheet() async {
    _otpCodeController.clear();
    setState(() {
      _otpRequested = false;
      _otpDevHint = null;
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 10,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Telefon verifizieren',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Zum Schutz im Eltern-Matching wird ein OTP per SMS bestaetigt.',
                style: TextStyle(
                  color: Color(0xFF5A6E86),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneNumberController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefonnummer',
                  hintText: '+49 ...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isVerifyingPhone ? null : _requestPhoneOtp,
                  child:
                      Text(_isVerifyingPhone ? 'Senden...' : 'OTP anfordern'),
                ),
              ),
              if (_otpRequested) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _otpCodeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'OTP-Code',
                    hintText: '6-stellig',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_otpDevHint != null && _otpDevHint!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Dev-Code: $_otpDevHint',
                    style: const TextStyle(
                      color: Color(0xFF1E5CD7),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: _isVerifyingPhone ? null : _confirmPhoneOtp,
                    child: Text(
                      _isVerifyingPhone ? 'Pruefen...' : 'OTP bestaetigen',
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showProfileSavedToast() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        duration: const Duration(seconds: 2),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFF0B9A74), Color(0xFF0E7F77)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x260A7E63),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Profil gespeichert. Deine Matches sind jetzt bereit.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWelcomeMatchHighlightOnce() {
    final profile = _currentProfile;
    if (profile == null) return;

    setState(() {
      _welcomeMatchProfileId = profile.id;
      _showWelcomeMatchHighlight = true;
    });

    Future<void>.delayed(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      if (_welcomeMatchProfileId != profile.id) return;
      setState(() => _showWelcomeMatchHighlight = false);
    });
  }

  Widget _buildProfileSetupRequired() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FD),
      appBar: AppBar(
        title: const Text(
          'Eltern-Matching einrichten',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: const Color(0xFFF4F7FD),
        elevation: 0,
        foregroundColor: const Color(0xFF172538),
      ),
      body: AnimatedOpacity(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOut,
        opacity: _setupEntranceVisible ? 1 : 0,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 460),
          curve: Curves.easeOutCubic,
          offset: _setupEntranceVisible ? Offset.zero : const Offset(0, 0.02),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 760),
                curve: Curves.easeOutCubic,
                builder: (context, progress, _) {
                  Widget staged({required int index, required Widget child}) {
                    final start = (index * 0.12).clamp(0.0, 0.72);
                    final local =
                        ((progress - start) / (1 - start)).clamp(0.0, 1.0);
                    return Opacity(
                      opacity: local,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - local)),
                        child: child,
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    children: [
                      staged(
                        index: 0,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE9F3FF), Color(0xFFF4EEFF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: const Color(0xFFD6E4F9)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.groups_rounded,
                                      color: Color(0xFF1E5CD7),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Mit einem kurzen Profil finden euch Familien schneller und passender.',
                                      style: TextStyle(
                                        color: Color(0xFF2D4560),
                                        fontSize: 14,
                                        height: 1.35,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _SetupStepChip(
                                      icon: Icons.person_rounded,
                                      label: 'Profil'),
                                  _SetupStepChip(
                                      icon: Icons.location_city_rounded,
                                      label: 'Ort'),
                                  _SetupStepChip(
                                      icon: Icons.family_restroom_rounded,
                                      label: 'Familie'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      staged(
                        index: 1,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFDDE6F3)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x12000000),
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildAnimatedInputShell(
                                focused: _profileNameFocusNode.hasFocus,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildAnimatedFieldLabel(
                                      label: 'Name',
                                      focused: _profileNameFocusNode.hasFocus,
                                    ),
                                    TextField(
                                      controller: _profileNameController,
                                      focusNode: _profileNameFocusNode,
                                      textInputAction: TextInputAction.next,
                                      onSubmitted: (_) =>
                                          _cityFocusNode.requestFocus(),
                                      decoration: InputDecoration(
                                        hintText: 'Name',
                                        filled: true,
                                        fillColor: const Color(0xFFF4F7FC),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF1E5CD7),
                                            width: 1.4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildAnimatedInputShell(
                                      focused: _cityFocusNode.hasFocus,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildAnimatedFieldLabel(
                                            label: 'Stadt',
                                            focused: _cityFocusNode.hasFocus,
                                          ),
                                          DropdownButtonFormField<String>(
                                            focusNode: _cityFocusNode,
                                            initialValue: _homeCity,
                                            decoration: InputDecoration(
                                              hintText: 'Stadt',
                                              filled: true,
                                              fillColor:
                                                  const Color(0xFFF4F7FC),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                borderSide: BorderSide.none,
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFF1E5CD7),
                                                  width: 1.4,
                                                ),
                                              ),
                                            ),
                                            items: _cityCenters.keys
                                                .map((city) =>
                                                    DropdownMenuItem<String>(
                                                      value: city,
                                                      child: Text(city),
                                                    ))
                                                .toList(),
                                            onChanged: (value) {
                                              if (value == null) return;
                                              setState(() => _homeCity = value);
                                              _ageFocusNode.requestFocus();
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildAnimatedInputShell(
                                      focused: _ageFocusNode.hasFocus,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildAnimatedFieldLabel(
                                            label: 'Alter',
                                            focused: _ageFocusNode.hasFocus,
                                          ),
                                          DropdownButtonFormField<int>(
                                            focusNode: _ageFocusNode,
                                            initialValue: _profileAge,
                                            decoration: InputDecoration(
                                              hintText: 'Alter',
                                              filled: true,
                                              fillColor:
                                                  const Color(0xFFF4F7FC),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                borderSide: BorderSide.none,
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFF1E5CD7),
                                                  width: 1.4,
                                                ),
                                              ),
                                            ),
                                            items:
                                                List.generate(54, (i) => i + 18)
                                                    .map((age) =>
                                                        DropdownMenuItem<int>(
                                                          value: age,
                                                          child: Text('$age'),
                                                        ))
                                                    .toList(),
                                            onChanged: (value) {
                                              if (value == null) return;
                                              setState(
                                                  () => _profileAge = value);
                                              _familyFormFocusNode
                                                  .requestFocus();
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildAnimatedInputShell(
                                focused: _familyFormFocusNode.hasFocus,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildAnimatedFieldLabel(
                                      label: 'Familienform',
                                      focused: _familyFormFocusNode.hasFocus,
                                    ),
                                    DropdownButtonFormField<String>(
                                      focusNode: _familyFormFocusNode,
                                      initialValue: _profileFamilyForm,
                                      decoration: InputDecoration(
                                        hintText: 'Familienform',
                                        filled: true,
                                        fillColor: const Color(0xFFF4F7FC),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF1E5CD7),
                                            width: 1.4,
                                          ),
                                        ),
                                      ),
                                      items: const [
                                        'Alleinerziehend',
                                        'Patchwork',
                                        'Kernfamilie',
                                        'Mehrgeneration',
                                      ]
                                          .map((form) =>
                                              DropdownMenuItem<String>(
                                                value: form,
                                                child: Text(form),
                                              ))
                                          .toList(),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setState(
                                            () => _profileFamilyForm = value);
                                        _familyFormFocusNode.unfocus();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F8FF),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFFCFE0F8)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _phoneVerifiedLocal
                                          ? Icons.verified_rounded
                                          : Icons.shield_outlined,
                                      color: _phoneVerifiedLocal
                                          ? const Color(0xFF0B9A74)
                                          : const Color(0xFF1E5CD7),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _phoneVerifiedLocal
                                            ? 'Telefon verifiziert'
                                            : 'Verifiziere dein Telefon für mehr Sicherheit',
                                        style: const TextStyle(
                                          color: Color(0xFF24405E),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _phoneVerifiedLocal
                                          ? null
                                          : _openPhoneVerificationSheet,
                                      child: Text(
                                        _phoneVerifiedLocal
                                            ? 'OK'
                                            : 'Verifizieren',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              AnimatedScale(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutBack,
                                scale: _saveSuccessFlash ? 1.03 : 1,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOut,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: _saveSuccessFlash
                                        ? const [
                                            BoxShadow(
                                              color: Color(0x3319A884),
                                              blurRadius: 16,
                                              offset: Offset(0, 6),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(50),
                                      backgroundColor: _saveSuccessFlash
                                          ? const Color(0xFF0B9A74)
                                          : const Color(0xFF0E7F77),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: _isSavingProfile
                                        ? null
                                        : _saveMyProfile,
                                    icon: _isSavingProfile
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : Icon(
                                            _saveSuccessFlash
                                                ? Icons.verified_rounded
                                                : Icons.check_rounded,
                                          ),
                                    label: Text(
                                      _isSavingProfile
                                          ? 'Speichern...'
                                          : _saveSuccessFlash
                                              ? 'Gespeichert'
                                              : 'Profil speichern',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      staged(
                        index: 2,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Datenschutz: Nur relevante Profilangaben werden für passende Matches genutzt.',
                            style: TextStyle(
                              color: Color(0xFF62758C),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openSafetyInfo() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              Text(
                'Sicherheit im Eltern-Matching',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.flag_outlined),
                title: Text(_t('matching_report_profiles')),
                subtitle: Text(
                    'Unpassende Inhalte können jederzeit gemeldet werden.'),
              ),
              ListTile(
                leading: Icon(Icons.block_rounded),
                title: Text(_t('matching_block_profiles')),
                subtitle:
                    Text(_t('matching_blocked_info')),
              ),
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(_t('matching_current_status')),
                subtitle: Text(
                    '${_matchedProfiles.length} Verbindungen, ${_blockedProfileIds.length} blockierte Profile, ${_reportedProfileIds.length} gemeldete Profile'),
              ),
              if (_reportedProfileIds.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(_t('matching_safety_queue')),
                  subtitle: Text(
                      '${_reportedProfileIds.length} Profile in Prüfung (lokal markiert)'),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openMatchChat(_ParentProfile profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchConversationScreen(
          profileId: profile.id,
          profileName: profile.name,
        ),
      ),
    );
  }

  void _skipCurrent() {
    _moveNext();
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildFilterGroup({
              required String title,
              required List<String> options,
              required Set<String> selected,
            }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options.map((option) {
                      final isSelected = selected.contains(option);
                      return FilterChip(
                        label: Text(option),
                        selected: isSelected,
                        onSelected: (value) {
                          setModalState(() {
                            if (value) {
                              selected.add(option);
                            } else {
                              selected.remove(option);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                              AppStringsManager.getString(
                                  languageService.currentLanguage,
                                  'matching_filter'),
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 18)),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                _interestFilter.clear();
                                _languageFilter.clear();
                                _valuesFilter.clear();
                                _familyFormFilter.clear();
                                _childAgeFilter.clear();
                              });
                            },
                            child: Text(_t('matching_reset')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      buildFilterGroup(
                        title: 'Interessen',
                        options: const [
                          'Bildung',
                          'Outdoor',
                          'Sport',
                          'Familienzeit',
                          'Kreativ',
                          'Gesundheit',
                          'Spielplatz'
                        ],
                        selected: _interestFilter,
                      ),
                      const SizedBox(height: 14),
                      buildFilterGroup(
                        title: 'Sprache',
                        options: const [
                          'Deutsch',
                          'Englisch',
                          'Türkisch',
                          'Arabisch',
                          'Kurdisch',
                          'Französisch'
                        ],
                        selected: _languageFilter,
                      ),
                      const SizedBox(height: 14),
                      buildFilterGroup(
                        title: 'Weltanschauung und Werte',
                        options: const [
                          'Gewaltfrei',
                          'Respekt',
                          'Inklusion',
                          'Empathie',
                          'Tradition',
                          'Offenheit'
                        ],
                        selected: _valuesFilter,
                      ),
                      const SizedBox(height: 14),
                      buildFilterGroup(
                        title: 'Familienform',
                        options: const [
                          'Alleinerziehend',
                          'Patchwork',
                          'Kernfamilie',
                          'Mehrgeneration'
                        ],
                        selected: _familyFormFilter,
                      ),
                      const SizedBox(height: 14),
                      buildFilterGroup(
                        title: 'Kinderalter',
                        options: const ['0-2', '3-5', '6-9', '10-13', '14+'],
                        selected: _childAgeFilter,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _currentIndex = 0;
                            });
                            _persistState();
                            Navigator.pop(context);
                          },
                          child: Text(AppStringsManager.getString(
                              languageService.currentLanguage, 'apply_filter')),
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
  }

  void _openPreferenceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildGroup({
              required String title,
              required List<String> options,
              required Set<String> selected,
            }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options.map((option) {
                      final isSelected = selected.contains(option);
                      return FilterChip(
                        label: Text(option),
                        selected: isSelected,
                        onSelected: (value) {
                          setModalState(() {
                            if (value) {
                              selected.add(option);
                            } else {
                              selected.remove(option);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                              AppStringsManager.getString(
                                  languageService.currentLanguage,
                                  'matching_profile'),
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 18)),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                _myInterests
                                  ..clear()
                                  ..addAll(_defaultMyInterests);
                                _myLanguages
                                  ..clear()
                                  ..addAll(_defaultMyLanguages);
                                _myValues
                                  ..clear()
                                  ..addAll(_defaultMyValues);
                                _homeCity = 'Berlin';
                                _maxDistanceKm = 20;
                              });
                            },
                            child: Text(_t('matching_reset')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _homeCity,
                        decoration: const InputDecoration(
                          labelText: 'Standort (Mittelpunkt)',
                          border: OutlineInputBorder(),
                        ),
                        items: _cityCenters.keys
                            .map((city) => DropdownMenuItem<String>(
                                  value: city,
                                  child: Text(city),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setModalState(() => _homeCity = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      Text('Radius: ${_maxDistanceKm.toStringAsFixed(0)} km'),
                      Slider(
                        value: _maxDistanceKm,
                        min: 3,
                        max: 100,
                        divisions: 97,
                        label: '${_maxDistanceKm.toStringAsFixed(0)} km',
                        onChanged: (value) {
                          setModalState(() => _maxDistanceKm = value);
                        },
                      ),
                      const SizedBox(height: 8),
                      buildGroup(
                        title: 'Meine Interessen',
                        options: const [
                          'Bildung',
                          'Outdoor',
                          'Sport',
                          'Familienzeit',
                          'Kreativ',
                          'Gesundheit',
                          'Spielplatz'
                        ],
                        selected: _myInterests,
                      ),
                      const SizedBox(height: 14),
                      buildGroup(
                        title: 'Meine Sprachen',
                        options: const [
                          'Deutsch',
                          'Englisch',
                          'Türkisch',
                          'Arabisch',
                          'Kurdisch',
                          'Französisch'
                        ],
                        selected: _myLanguages,
                      ),
                      const SizedBox(height: 14),
                      buildGroup(
                        title: 'Meine Werte',
                        options: const [
                          'Gewaltfrei',
                          'Respekt',
                          'Inklusion',
                          'Empathie',
                          'Tradition',
                          'Offenheit'
                        ],
                        selected: _myValues,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _currentIndex = 0;
                            });
                            _persistState();
                            Navigator.pop(context);
                          },
                          child: const Text('Speichern'),
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = _currentProfile;
    final compactToolbar = MediaQuery.of(context).size.width < 390;
    final compactScreen = MediaQuery.of(context).size.width < 390;
    final infoBannerText = compactScreen
        ? 'Freundschaft & Playdates · Radius ${_maxDistanceKm.toStringAsFixed(0)} km ab $_homeCity'
        : 'Nur für Freundschaft, Playdates und Eltern-Austausch · Radius ${_maxDistanceKm.toStringAsFixed(0)} km ab $_homeCity';
    final pendingSectionTitle =
        compactScreen ? 'Offene Anfragen' : 'Ausstehende Anfragen';

    if (_requiresProfileSetup) {
      return _buildProfileSetupRequired();
    }

    if (_isRestoring) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          compactToolbar ? 'Eltern-Match' : 'Eltern-Matching',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Neue Verbindungen',
            onPressed: _openNewConnectionsSheet,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded),
                if (_newConfirmedSinceLastVisit > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _newConfirmedSinceLastVisit > 9
                            ? '9+'
                            : _newConfirmedSinceLastVisit.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (compactToolbar)
            PopupMenuButton<String>(
              tooltip: 'Mehr Optionen',
              onSelected: (value) {
                if (value == 'profile') {
                  _openPreferenceSheet();
                } else if (value == 'safety') {
                  _openSafetyInfo();
                } else if (value == 'filter') {
                  _openFilterSheet();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'profile',
                  child: Text(AppStringsManager.getString(
                      languageService.currentLanguage, 'my_profile')),
                ),
                PopupMenuItem<String>(
                  value: 'safety',
                  child: Text(AppStringsManager.getString(
                      languageService.currentLanguage, 'security')),
                ),
                PopupMenuItem<String>(
                  value: 'filter',
                  child: Text(AppStringsManager.getString(
                      languageService.currentLanguage, 'filter_search')),
                ),
              ],
              icon: const Icon(Icons.more_horiz_rounded),
            )
          else ...[
            IconButton(
              tooltip: 'Mein Profil',
              onPressed: _openPreferenceSheet,
              icon: const Icon(Icons.tune_rounded),
            ),
            IconButton(
              tooltip: 'Sicherheit',
              onPressed: _openSafetyInfo,
              icon: const Icon(Icons.shield_outlined),
            ),
            IconButton(
              tooltip: 'Suche filtern',
              onPressed: _openFilterSheet,
              icon: const Icon(Icons.filter_list_rounded),
            ),
          ],
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 390;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatPill(
                          icon: Icons.group_add_rounded,
                          label: compact ? 'Inter.' : 'Interesse',
                          value: _likedProfiles.length,
                          color: const Color(0xFF0EA5A4),
                          compact: compact,
                        ),
                        _StatPill(
                          icon: Icons.hourglass_top_rounded,
                          label: compact ? 'Anfr.' : 'Ausstehend',
                          value: _pendingProfiles.length,
                          color: const Color(0xFFF59E0B),
                          compact: compact,
                        ),
                        _StatPill(
                          icon: Icons.handshake_rounded,
                          label: compact ? 'Verb.' : 'Verbindungen',
                          value: _matchedProfiles.length,
                          color: const Color(0xFF2563EB),
                          compact: compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_filteredProfiles.isEmpty ? 0 : (_currentIndex + 1)}/${_filteredProfiles.length}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer
                    .withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.12),
                ),
              ),
              child: Text(
                infoBannerText,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                maxLines: compactScreen ? 2 : null,
                overflow: compactScreen
                    ? TextOverflow.ellipsis
                    : TextOverflow.visible,
              ),
            ),
            if (_showDiscoveryInviteBanner) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF7D8A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.campaign_outlined,
                        color: Color(0xFF9A5A11), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _discoveryScope == 'global'
                            ? '🌍 Noch niemand lokal aktiv? Triff Eltern online & bilde dein Netzwerk auf.'
                            : 'Erweiterte Suche: Suche in $_discoveryScope statt lokal. Lade Freunde in deine Nähe ein!',
                        style: const TextStyle(
                          color: Color(0xFF74420D),
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: profile == null
                  ? (_globalDigitalMode
                      ? _GlobalParentRoomsState(
                          rooms: _globalRooms,
                          onOpenRoom: (room) {
                            _openMatchChat(
                              _ParentProfile(
                                id: room['id'] ?? 'global-room',
                                name: room['title'] ?? 'Globaler Elternchat',
                                age: 30,
                                city: 'Online',
                                bio: room['subtitle'] ??
                                    'Themenbasierter Online-Austausch',
                                interests: const ['Online', 'Austausch'],
                                languages: const ['Deutsch'],
                                valuesFocus: const ['Respekt'],
                                childAges: const ['0-3', '3-5', '6-9'],
                                familyForm: 'Community',
                                verificationLevel: _VerificationLevel.checked,
                              ),
                            );
                          },
                        )
                      : _EmptyMatchState(onReset: () {
                          setState(() {
                            _currentIndex = 0;
                            _interestFilter.clear();
                            _languageFilter.clear();
                            _valuesFilter.clear();
                            _familyFormFilter.clear();
                            _childAgeFilter.clear();
                          });
                          _persistState();
                        }))
                  : TweenAnimationBuilder<double>(
                      key: ValueKey<String>(
                          'profile-${profile.id}-${_showWelcomeMatchHighlight && _welcomeMatchProfileId == profile.id}'),
                      tween: Tween<double>(
                        begin: _showWelcomeMatchHighlight &&
                                _welcomeMatchProfileId == profile.id
                            ? 0.97
                            : 1,
                        end: 1,
                      ),
                      duration: Duration(
                        milliseconds: _showWelcomeMatchHighlight &&
                                _welcomeMatchProfileId == profile.id
                            ? 320
                            : 1,
                      ),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) {
                        final highlighted = _showWelcomeMatchHighlight &&
                            _welcomeMatchProfileId == profile.id;
                        final opacity = highlighted
                            ? (0.78 + ((scale - 0.97) / 0.03) * 0.22)
                            : 1.0;
                        return Opacity(
                          opacity: opacity.clamp(0.0, 1.0),
                          child: Transform.scale(scale: scale, child: child),
                        );
                      },
                      child: _ProfileCard(
                        profile: profile,
                        compatibility: _compatibility(profile),
                        distanceKm: _distanceKm(profile),
                        quality: _matchQuality(profile),
                        reasons: _whyMatch(profile),
                        showWelcomeHighlight: _showWelcomeMatchHighlight &&
                            _welcomeMatchProfileId == profile.id,
                        onReport: _reportCurrent,
                        onBlock: _blockCurrent,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compactActions = constraints.maxWidth < 360;
                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: profile == null ? null : _skipCurrent,
                        icon: Icon(
                          Icons.close_rounded,
                          size: compactActions ? 17 : 19,
                        ),
                        label: Text(
                          'Weiter',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style:
                              TextStyle(fontSize: compactActions ? 15 : null),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: profile == null ? null : _likeCurrent,
                        icon: Icon(
                          Icons.handshake_rounded,
                          size: compactActions ? 17 : 19,
                        ),
                        label: Text(
                          compactActions ? 'Verb.' : 'Verbinden',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style:
                              TextStyle(fontSize: compactActions ? 15 : null),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            if (_pendingProfiles.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pendingSectionTitle,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _pendingProfiles
                          .map((p) => Chip(
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                avatar: const Icon(
                                  Icons.hourglass_top_rounded,
                                  size: 16,
                                ),
                                label: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 170),
                                  child: Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            if (_matchedProfiles.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _matchedProfiles
                      .map((p) => Chip(
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            avatar: CircleAvatar(
                              child: Text(_safeInitial(p.name)),
                            ),
                            label: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 170),
                              child: Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            onDeleted: () => _openMatchChat(p),
                            deleteIcon:
                                const Icon(Icons.chat_bubble_outline_rounded),
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 10,
        vertical: compact ? 7 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 15, color: color),
          const SizedBox(width: 5),
          Text('$label: $value',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: compact ? 11.8 : 12.5,
                height: 1,
              )),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.compatibility,
    required this.distanceKm,
    required this.quality,
    required this.reasons,
    required this.showWelcomeHighlight,
    required this.onReport,
    required this.onBlock,
  });

  final _ParentProfile profile;
  final int compatibility;
  final double? distanceKm;
  final _MatchQuality quality;
  final List<String> reasons;
  final bool showWelcomeHighlight;
  final VoidCallback onReport;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: showWelcomeHighlight
            ? const [
                BoxShadow(
                  color: Color(0x2A1E5CD7),
                  blurRadius: 22,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        child: Text(_safeInitial(profile.name),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text('${profile.name}, ${profile.age}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700)),
                                ),
                                _VerificationBadge(
                                    level: profile.verificationLevel),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                                distanceKm == null
                                    ? profile.city
                                    : '${profile.city} · ${distanceKm!.toStringAsFixed(1)} km',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('$compatibility%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ),
                      PopupMenuButton<String>(
                        color: Colors.white,
                        iconColor: Colors.white,
                        onSelected: (value) {
                          if (value == 'report') onReport();
                          if (value == 'block') onBlock();
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: 'report',
                            child: Text(AppStringsManager.getString(
                                languageService.currentLanguage,
                                'report_profile')),
                          ),
                          PopupMenuItem<String>(
                            value: 'block',
                            child: Text(AppStringsManager.getString(
                                languageService.currentLanguage,
                                'block_profile')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(profile.bio,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(height: 1.35)),
                      const SizedBox(height: 14),
                      _TagSection(
                          title: 'Interessen', values: profile.interests),
                      const SizedBox(height: 10),
                      _TagSection(title: 'Sprachen', values: profile.languages),
                      const SizedBox(height: 10),
                      _TagSection(title: 'Werte', values: profile.valuesFocus),
                      const SizedBox(height: 10),
                      _TagSection(
                          title: 'Kinderalter', values: profile.childAges),
                      const SizedBox(height: 10),
                      _MatchQualityRow(quality: quality),
                      const SizedBox(height: 10),
                      _TagSection(title: 'Warum ihr passt', values: reasons),
                      const SizedBox(height: 10),
                      Text('Familienform: ${profile.familyForm}',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: IgnorePointer(
              ignoring: true,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                opacity: showWelcomeHighlight ? 1 : 0,
                child: _WelcomeMatchBadge(showShine: showWelcomeHighlight),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeMatchBadge extends StatelessWidget {
  const _WelcomeMatchBadge({required this.showShine});

  final bool showShine;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD6E4F9)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 14,
            color: Color(0xFF1E5CD7),
          ),
          SizedBox(width: 6),
          Text(
            'Neu für euch',
            style: TextStyle(
              color: Color(0xFF224161),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    if (!showShine) {
      return badge;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -1.2, end: 1.8),
      duration: const Duration(milliseconds: 980),
      curve: Curves.easeOutCubic,
      child: badge,
      builder: (context, position, child) {
        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment(position - 1, 0),
              end: Alignment(position, 0),
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.62),
                Colors.white.withValues(alpha: 0),
              ],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(rect);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
    );
  }
}

class _TagSection extends StatelessWidget {
  const _TagSection({required this.title, required this.values});

  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Color(0xFF2A3D54),
            )),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values
              .map((v) => Chip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: const Color(0xFFF5F8FC),
                    side: const BorderSide(color: Color(0xFFE0E8F2)),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2B4158),
                    ),
                    label: Text(v),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _MatchQuality {
  const _MatchQuality({
    required this.interests,
    required this.languages,
    required this.values,
  });

  final int interests;
  final int languages;
  final int values;
}

class _MatchQualityRow extends StatelessWidget {
  const _MatchQualityRow({required this.quality});

  final _MatchQuality quality;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Match-Qualität',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _QualityPill(label: 'Interessen', score: quality.interests),
            _QualityPill(label: 'Sprache', score: quality.languages),
            _QualityPill(label: 'Werte', score: quality.values),
          ],
        ),
      ],
    );
  }
}

class _QualityPill extends StatelessWidget {
  const _QualityPill({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (score >= 80) {
      color = const Color(0xFF16A34A);
    } else if (score >= 55) {
      color = const Color(0xFF0EA5E9);
    } else {
      color = const Color(0xFFF59E0B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        '$label $score%',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyMatchState extends StatelessWidget {
  const _EmptyMatchState({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 390;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 56),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              'Keine Profile für die aktuellen Filter.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 16 : null,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onReset,
            child: Text(
              compact ? 'Filter zurück' : 'Filter zurücksetzen',
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalParentRoomsState extends StatelessWidget {
  const _GlobalParentRoomsState({
    required this.rooms,
    required this.onOpenRoom,
  });

  final List<Map<String, String>> rooms;
  final ValueChanged<Map<String, String>> onOpenRoom;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return const _EmptyMatchState(onReset: _noop);
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      itemCount: rooms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final room = rooms[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDCE6F3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.public_rounded, color: Color(0xFF1E5CD7)),
                  SizedBox(width: 8),
                  Text(
                    'Globaler Digital-Modus',
                    style: TextStyle(
                      color: Color(0xFF1E5CD7),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                room['title'] ?? 'Globaler Elternchat',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                room['subtitle'] ?? 'Online Austausch für Eltern',
                style: const TextStyle(
                    color: Color(0xFF607286), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: () => onOpenRoom(room),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: Text(AppStringsManager.getString(
                      languageService.currentLanguage, 'open_room')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

void _noop() {}

class _SetupStepChip extends StatelessWidget {
  const _SetupStepChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD8E6F8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF1E5CD7)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF224161),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentProfile {
  const _ParentProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.city,
    required this.bio,
    required this.interests,
    required this.languages,
    required this.valuesFocus,
    required this.childAges,
    required this.familyForm,
    this.latitude,
    this.longitude,
    this.verificationLevel = _VerificationLevel.basic,
    this.score,
    this.breakdown,
  });

  final String id;
  final String name;
  final int age;
  final String city;
  final String bio;
  final List<String> interests;
  final List<String> languages;
  final List<String> valuesFocus;
  final List<String> childAges;
  final String familyForm;
  final double? latitude;
  final double? longitude;
  final _VerificationLevel verificationLevel;
  final double? score;
  final Map<String, double>? breakdown;
}

String _safeInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  return trimmed.substring(0, 1).toUpperCase();
}

enum _VerificationLevel { basic, checked, recommended }

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.level});

  final _VerificationLevel level;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (level) {
      _VerificationLevel.basic => ('Basis', Colors.white70),
      _VerificationLevel.checked => ('Geprüft', const Color(0xFF93C5FD)),
      _VerificationLevel.recommended => ('Empfohlen', const Color(0xFFFDE68A)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, color: color, size: 15),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 11)),
        ],
      ),
    );
  }
}
