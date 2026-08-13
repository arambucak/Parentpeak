import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parentpeak/ui/backup_qr_scan_screen.dart';
import 'package:parentpeak/main.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/account_data_cleanup_service.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/models/trusted_device.dart';
import 'package:parentpeak/ui/legal_info_screen.dart';
import 'package:parentpeak/ui/privacy_settings_screen.dart';
import 'package:parentpeak/widgets/ala_rengin_flag_painter.dart';

class FamilyProfileScreen extends StatefulWidget {
  final List<TrustedDevice> devices;
  final Future<bool> Function(String deviceUuid, String deviceName) onRevoke;

  const FamilyProfileScreen(
      {super.key, required this.devices, required this.onRevoke});

  @override
  State<FamilyProfileScreen> createState() => _FamilyProfileScreenState();
}

class _FamilyProfileScreenState extends State<FamilyProfileScreen> {
  static const String _prefsFamilyMembersKey = 'family_profile.members.v1';
  static const String _prefsSelectedInterestsKey =
      'family_profile.selected_interests.v1';
  static const String _prefsNotificationsKey =
      'family_profile.notifications_enabled.v1';
  static const String _prefsNotifyEmergenciesKey =
      'family_profile.notify_emergencies.v1';
  static const String _prefsNotifyRemindersKey =
      'family_profile.notify_reminders.v1';
  static const String _prefsNotifyUpdatesKey =
      'family_profile.notify_updates.v1';
  static const String _prefsPrivacyModeKey =
      'family_profile.privacy_mode_enabled.v1';
  static const String _prefsActiveRoleKey = 'family_profile.active_role.v1';
  static const String _prefsActiveMemberNameKey =
      'family_profile.active_member_name.v1';
  static const String _prefsLastBackupAtKey =
      'family_profile.backup_last_saved_at.v1';
  static const String _prefsSignedBackupEnabledKey =
      'family_profile.backup_signed_enabled.v1';
  static const String _backupSignatureKey =
      'parentpeak.family.backup.signature.v1';
  static const int _backupVersion = 3;
  static const int _qrChunkMaxChars = 350;
  static const List<String> _memberRoles = [
    'Elternteil',
    'Kind',
    'Bezugsperson',
  ];
  static const List<String> _avatarOptions = [
    '👩',
    '👨',
    '🧒',
    '👶',
    '🧑',
    '👵',
    '👴',
    '🧑‍🏫',
  ];

  late bool _isDarkMode;
  bool _notificationsEnabled = true;
  bool _notifyEmergencies = true;
  bool _notifyReminders = true;
  bool _notifyUpdates = false;
  bool _privacyModeEnabled = true;
  bool _signedBackupEnabled = false;
  DateTime? _lastBackupAt;
  String _activeRole = 'Elternteil';
  String _activeMemberName = 'Emma';
  String _currentLanguage = 'de';
  final List<_FamilyMember> _familyMembers = [
    _FamilyMember(name: 'Mom', role: 'Elternteil', avatar: '👩'),
    _FamilyMember(name: 'Dad', role: 'Elternteil', avatar: '👨'),
    _FamilyMember(name: 'Emma', role: 'Kind', avatar: '🧒'),
    _FamilyMember(name: 'Liam', role: 'Kind', avatar: '👶'),
  ];
  final List<String> _interests = [
    '#Family',
    '#Sport',
    '#Education',
    '#Leisure',
    '#Health'
  ];
  late final Set<String> _selectedInterests;
  late final List<Map<String, String>> _languages;

  @override
  void initState() {
    super.initState();
    _isDarkMode = themeService.isDarkMode;
    _selectedInterests = _interests.toSet();
    // Nutze den globalen languageService
    _currentLanguage = languageService.currentLanguage;
    languageService.addListener(_onLanguageChanged);
    themeService.addListener(_onThemeChanged);
    _loadProfilePreferences();

    _languages = [
      {
        'code': 'de',
        'name': 'Deutsch',
        'flag': '🇩🇪',
        'nativeName': 'Deutsch'
      },
      {
        'code': 'en',
        'name': 'English',
        'flag': '🇬🇧',
        'nativeName': 'English'
      },
      {
        'code': 'fr',
        'name': 'Français',
        'flag': '🇫🇷',
        'nativeName': 'Français'
      },
      {
        'code': 'es',
        'name': 'Español',
        'flag': '🇪🇸',
        'nativeName': 'Español'
      },
      {
        'code': 'it',
        'name': 'Italiano',
        'flag': '🇮🇹',
        'nativeName': 'Italiano'
      },
      {
        'code': 'nl',
        'name': 'Nederlands',
        'flag': '🇳🇱',
        'nativeName': 'Nederlands'
      },
      {
        'code': 'pt',
        'name': 'Português',
        'flag': '🇵🇹',
        'nativeName': 'Português'
      },
      {
        'code': 'ar',
        'name': 'العربية',
        'flag': '🇸🇦',
        'nativeName': 'العربية'
      },
      {'code': 'fa', 'name': 'فارسی', 'flag': '🇮🇷', 'nativeName': 'فارسی'},
      {'code': 'ku', 'name': 'Kurdî', 'flag': '🔶', 'nativeName': 'Kurdî'},
      {'code': 'ckb', 'name': 'کوردی', 'flag': '🔶', 'nativeName': 'کوردی'},
      {'code': 'zh', 'name': '中文', 'flag': '🇨🇳', 'nativeName': '中文'},
      {'code': 'ja', 'name': '日本語', 'flag': '🇯🇵', 'nativeName': '日本語'},
      {'code': 'ko', 'name': '한국어', 'flag': '🇰🇷', 'nativeName': '한국어'},
      {'code': 'tr', 'name': 'Türkçe', 'flag': '🇹🇷', 'nativeName': 'Türkçe'},
      {
        'code': 'ru',
        'name': 'Русский',
        'flag': '🇷🇺',
        'nativeName': 'Русский'
      },
    ];
  }

  @override
  void dispose() {
    themeService.removeListener(_onThemeChanged);
    languageService.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        _isDarkMode = themeService.isDarkMode;
      });
    }
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {
        _currentLanguage = languageService.currentLanguage;
      });
    }
  }

  String _t(String key) => AppStringsManager.getString(_currentLanguage, key);

  _FamilyMember? get _activeMember {
    for (final member in _familyMembers) {
      if (member.name == _activeMemberName) {
        return member;
      }
    }
    return _familyMembers.isEmpty ? null : _familyMembers.first;
  }

  bool get _canManageMembers => _activeRole == 'Elternteil';

  bool get _canManageSensitiveSettings => _activeRole == 'Elternteil';

  bool _canEditMember(_FamilyMember target) {
    if (_activeRole == 'Elternteil') {
      return true;
    }

    final active = _activeMember;
    if (_activeRole == 'Kind') {
      return active != null && identical(active, target);
    }

    if (_activeRole == 'Bezugsperson') {
      return target.role == 'Kind';
    }

    return false;
  }

  void _showPermissionDeniedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diese Aktion ist in dieser Rolle nicht erlaubt.'),
      ),
    );
  }

  Future<void> _persistAllProfileSettings() async {
    await Future.wait([
      _persistFamilyMembers(),
      _persistSelectedInterests(),
      _persistNotificationsSetting(),
      _persistPrivacyModeSetting(),
      _persistActiveRole(),
      _persistActiveMemberName(),
      _persistSignedBackupSetting(),
    ]);
  }

  String _backupJson() {
    final backup = <String, dynamic>{
      'version': _backupVersion,
      'schema': 'family_profile_backup_v3',
      'exportedAt': DateTime.now().toIso8601String(),
      'familyMembers': _familyMembers.map((m) => m.toMap()).toList(),
      'selectedInterests': _selectedInterests.toList(),
      'notifications': {
        'enabled': _notificationsEnabled,
        'emergencies': _notifyEmergencies,
        'reminders': _notifyReminders,
        'updates': _notifyUpdates,
      },
      'privacyModeEnabled': _privacyModeEnabled,
      'activeRole': _activeRole,
      'activeMemberName': _activeMemberName,
      'signed': _signedBackupEnabled,
    };
    backup['checksum'] = _computeChecksum(backup);
    if (_signedBackupEnabled) {
      backup['signature'] = _computeSignature(backup);
    }
    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  String _computeChecksum(Map<String, dynamic> backup) {
    final copy = Map<String, dynamic>.from(backup)..remove('checksum');
    final bytes = utf8.encode(jsonEncode(copy));
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String _computeSignature(Map<String, dynamic> backup) {
    final copy = Map<String, dynamic>.from(backup)
      ..remove('signature')
      ..remove('checksum');
    final payload = utf8.encode(jsonEncode(copy));
    final mac = Hmac(sha256, utf8.encode(_backupSignatureKey));
    return mac.convert(payload).toString();
  }

  List<String> _buildQrPayloadChunks(String rawBackupJson) {
    if (rawBackupJson.length <= _qrChunkMaxChars) {
      return [rawBackupJson];
    }

    final chunkId = DateTime.now().millisecondsSinceEpoch.toString();
    final chunks = <String>[];
    final total = (rawBackupJson.length / _qrChunkMaxChars).ceil();
    for (var i = 0; i < total; i++) {
      final start = i * _qrChunkMaxChars;
      final end = (start + _qrChunkMaxChars < rawBackupJson.length)
          ? start + _qrChunkMaxChars
          : rawBackupJson.length;
      final payload = rawBackupJson.substring(start, end);
      final envelope = <String, dynamic>{
        '_ppChunk': true,
        'chunkId': chunkId,
        'index': i + 1,
        'total': total,
        'payload': payload,
      };
      chunks.add(jsonEncode(envelope));
    }
    return chunks;
  }

  Map<String, dynamic> _normalizeImportedBackup(Map<String, dynamic> raw) {
    final version = (raw['version'] as num?)?.toInt() ?? 1;
    if (version > _backupVersion) {
      throw const FormatException('Backup-Version wird nicht unterstuetzt');
    }

    if (version == 1) {
      return {
        ...raw,
        'version': 1,
        'schema': 'family_profile_backup_v1',
        'exportedAt': raw['exportedAt'] ?? DateTime.now().toIso8601String(),
      };
    }

    if (version == 2) {
      return {
        ...raw,
        'version': 2,
        'schema': 'family_profile_backup_v2',
        'exportedAt': raw['exportedAt'] ?? DateTime.now().toIso8601String(),
        'signed': false,
      };
    }

    if (version == 3 && !raw.containsKey('signed')) {
      return {
        ...raw,
        'signed': false,
      };
    }

    return raw;
  }

  void _validateChecksumIfRequired(Map<String, dynamic> backup) {
    final version = (backup['version'] as num?)?.toInt() ?? 1;
    if (version < 3) {
      return;
    }
    final checksum = backup['checksum'];
    if (checksum is! String || checksum.trim().isEmpty) {
      throw const FormatException('Checksum fehlt');
    }
    final computed = _computeChecksum(backup);
    if (computed != checksum) {
      throw const FormatException('Checksum ungueltig');
    }
  }

  void _validateSignatureIfRequired(Map<String, dynamic> backup) {
    final signed = backup['signed'] as bool? ?? false;
    if (!signed) {
      return;
    }
    final signature = backup['signature'];
    if (signature is! String || signature.trim().isEmpty) {
      throw const FormatException('Signatur fehlt');
    }
    final computed = _computeSignature(backup);
    if (computed != signature) {
      throw const FormatException('Signatur ungueltig');
    }
  }

  Future<void> _exportProfileBackup() async {
    final json = _backupJson();
    await Clipboard.setData(ClipboardData(text: json));
    final now = DateTime.now();
    setState(() {
      _lastBackupAt = now;
    });
    await _persistLastBackupAt(now);
    if (!mounted) {
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup exportiert'),
        content: const Text(
          'Das Familienprofil-Backup wurde als JSON in die Zwischenablage kopiert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBackupQrDialog() async {
    final payload = _backupJson();
    final chunks = _buildQrPayloadChunks(payload);
    var activeIndex = 0;
    var autoPlay = false;
    var autoPlaySeconds = 2;
    Timer? autoTimer;

    void syncAutoPlay(void Function(void Function()) setDialogState) {
      autoTimer?.cancel();
      if (!autoPlay || chunks.length <= 1) {
        return;
      }
      autoTimer = Timer.periodic(Duration(seconds: autoPlaySeconds), (_) {
        setDialogState(() {
          activeIndex = (activeIndex + 1) % chunks.length;
        });
      });
    }

    if (!mounted) {
      return;
    }
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Backup als QR'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(
                  data: chunks[activeIndex],
                  size: 240,
                  version: QrVersions.auto,
                  errorStateBuilder: (context, error) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'QR-Code konnte nicht erzeugt werden. Nutze stattdessen den JSON-Export in die Zwischenablage.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  chunks.length > 1
                      ? 'Teil ${activeIndex + 1} von ${chunks.length}'
                      : 'Einzelner QR-Code',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Scanne alle Teile der Reihe nach auf dem zweiten Geraet.',
                  textAlign: TextAlign.center,
                ),
                if (chunks.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_outline, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Dieses Backup ist für einen einzelnen QR-Code zu gross und wurde in ${chunks.length} Teile aufgeteilt.',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (chunks.length > 1)
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto-Weiter'),
                    subtitle: Text(
                      'Wechselt alle $autoPlaySeconds Sek. den QR-Teil',
                    ),
                    value: autoPlay,
                    onChanged: (value) {
                      setDialogState(() {
                        autoPlay = value;
                      });
                      syncAutoPlay(setDialogState);
                    },
                  ),
                if (chunks.length > 1)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [1, 2, 3].map((seconds) {
                      final selected = autoPlaySeconds == seconds;
                      return ChoiceChip(
                        label: Text('${seconds}s'),
                        selected: selected,
                        onSelected: (_) {
                          setDialogState(() {
                            autoPlaySeconds = seconds;
                          });
                          syncAutoPlay(setDialogState);
                        },
                      );
                    }).toList(),
                  ),
                if (chunks.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: activeIndex > 0
                              ? () {
                                  setDialogState(() {
                                    activeIndex -= 1;
                                  });
                                  syncAutoPlay(setDialogState);
                                }
                              : null,
                          child: const Text('Zurück'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: activeIndex < chunks.length - 1
                              ? () {
                                  setDialogState(() {
                                    activeIndex += 1;
                                  });
                                  syncAutoPlay(setDialogState);
                                }
                              : null,
                          child: const Text('Weiter'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                autoTimer?.cancel();
                Navigator.pop(context);
              },
              child: const Text('Schliessen'),
            ),
          ],
        ),
      ),
    );
    autoTimer?.cancel();
  }

  Future<void> _importProfileBackup() async {
    if (!_canManageMembers) {
      _showPermissionDeniedMessage();
      return;
    }

    final controller = TextEditingController();
    String? errorText;

    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Backup importieren'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  minLines: 8,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    labelText: 'Backup JSON',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (errorText != null) {
                      setDialogState(() {
                        errorText = null;
                      });
                    }
                  },
                ),
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      errorText!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          final value = data?.text?.trim() ?? '';
                          if (value.isEmpty) {
                            setDialogState(() {
                              errorText = 'Zwischenablage ist leer.';
                            });
                            return;
                          }
                          setDialogState(() {
                            controller.text = value;
                            errorText = null;
                          });
                        },
                        icon: const Icon(Icons.content_paste),
                        label: const Text('Zwischenablage'),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final scanned = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BackupQrScanScreen(),
                            ),
                          );
                          if (scanned == null || scanned.isEmpty) {
                            return;
                          }
                          setDialogState(() {
                            controller.text = scanned;
                            errorText = null;
                          });
                        },
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('QR scannen'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_t('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) {
                  setDialogState(() {
                    errorText = 'Bitte Backup-JSON einfuegen.';
                  });
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Importieren'),
            ),
          ],
        ),
      ),
    );

    if (shouldImport != true) {
      controller.dispose();
      return;
    }

    final raw = controller.text.trim();
    controller.dispose();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid root object');
      }
      final normalized = _normalizeImportedBackup(decoded);
      _validateChecksumIfRequired(normalized);
      _validateSignatureIfRequired(normalized);

      final membersRaw = normalized['familyMembers'];
      if (membersRaw is! List) {
        throw const FormatException('familyMembers fehlt');
      }

      final parsedMembers = <_FamilyMember>[];
      for (final item in membersRaw) {
        if (item is Map<String, dynamic>) {
          parsedMembers.add(_FamilyMember.fromMap(item));
        }
      }
      if (parsedMembers.isEmpty) {
        throw const FormatException('Keine gueltigen Mitglieder');
      }

      final interestsRaw = normalized['selectedInterests'];
      final selectedInterests = <String>{};
      if (interestsRaw is List) {
        for (final item in interestsRaw) {
          if (item is String && _interests.contains(item)) {
            selectedInterests.add(item);
          }
        }
      }

      final notificationsRaw = normalized['notifications'];
      bool enabled = _notificationsEnabled;
      bool emergencies = _notifyEmergencies;
      bool reminders = _notifyReminders;
      bool updates = _notifyUpdates;
      if (notificationsRaw is Map<String, dynamic>) {
        enabled = notificationsRaw['enabled'] as bool? ?? enabled;
        emergencies = notificationsRaw['emergencies'] as bool? ?? emergencies;
        reminders = notificationsRaw['reminders'] as bool? ?? reminders;
        updates = notificationsRaw['updates'] as bool? ?? updates;
      }

      final importedRole = normalized['activeRole'] as String?;
      final importedMemberName = normalized['activeMemberName'] as String?;
      final importedExportedAt = normalized['exportedAt'] as String?;
      final importedVersion = (normalized['version'] as num?)?.toInt() ?? 1;
      final importedSigned = normalized['signed'] as bool? ?? false;

      setState(() {
        _familyMembers
          ..clear()
          ..addAll(parsedMembers);

        _selectedInterests
          ..clear()
          ..addAll(selectedInterests);

        _notificationsEnabled = enabled;
        _notifyEmergencies = emergencies;
        _notifyReminders = reminders;
        _notifyUpdates = updates;
        _privacyModeEnabled = normalized['privacyModeEnabled'] as bool? ?? true;

        if (importedRole != null && _memberRoles.contains(importedRole)) {
          _activeRole = importedRole;
        }

        final fallbackName = _familyMembers.first.name;
        final hasImportedMember = importedMemberName != null &&
            _familyMembers.any((m) => m.name == importedMemberName);
        _activeMemberName =
            hasImportedMember ? importedMemberName : fallbackName;
      });

      await _persistAllProfileSettings();
      final importedDate = importedExportedAt != null
          ? DateTime.tryParse(importedExportedAt)?.toLocal()
          : null;
      final now = importedDate ?? DateTime.now();
      setState(() {
        _lastBackupAt = now;
      });
      await _persistLastBackupAt(now);

      if (!mounted) {
        return;
      }
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Backup wiederhergestellt'),
          content: Text(
            'Version: v$importedVersion\nMitglieder: ${parsedMembers.length}\nInteressen: ${selectedInterests.length}\nAktive Rolle: ${_activeRole.isEmpty ? '-' : _activeRole}\nSigniert: ${importedSigned ? 'Ja' : 'Nein'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import fehlgeschlagen: ${error.message}')),
      );
    } catch (e) {
      debugPrint('FamilyProfileScreen._importBackupData(): failed: $e');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import fehlgeschlagen. JSON ungueltig.')),
      );
    }
  }

  Future<void> _loadProfilePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final storedMembers =
        prefs.getStringList(_prefsFamilyMembersKey) ?? const <String>[];
    final storedSelectedInterests =
        prefs.getStringList(_prefsSelectedInterestsKey) ?? const <String>[];

    if (!mounted) {
      return;
    }

    setState(() {
      if (storedMembers.isNotEmpty) {
        final parsedMembers = <_FamilyMember>[];
        for (final raw in storedMembers) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map<String, dynamic>) {
              parsedMembers.add(_FamilyMember.fromMap(decoded));
            }
          } catch (e) {
            debugPrint(
                'FamilyProfileScreen._loadProfilePreferences(): skipping broken member entry: $e');
            // Ignore broken legacy entries and keep defaults.
          }
        }

        if (parsedMembers.isNotEmpty) {
          _familyMembers
            ..clear()
            ..addAll(parsedMembers);
        }
      }

      _notificationsEnabled = prefs.getBool(_prefsNotificationsKey) ?? true;
      _notifyEmergencies =
          prefs.getBool(_prefsNotifyEmergenciesKey) ?? _notificationsEnabled;
      _notifyReminders =
          prefs.getBool(_prefsNotifyRemindersKey) ?? _notificationsEnabled;
      _notifyUpdates = prefs.getBool(_prefsNotifyUpdatesKey) ?? false;
      _privacyModeEnabled = prefs.getBool(_prefsPrivacyModeKey) ?? true;
      _activeRole = prefs.getString(_prefsActiveRoleKey) ?? 'Elternteil';
      _activeMemberName = prefs.getString(_prefsActiveMemberNameKey) ?? 'Emma';
      _signedBackupEnabled =
          prefs.getBool(_prefsSignedBackupEnabledKey) ?? false;
      final backupMillis = prefs.getInt(_prefsLastBackupAtKey);
      _lastBackupAt = backupMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(backupMillis);

      if (!_notificationsEnabled) {
        _notifyEmergencies = false;
        _notifyReminders = false;
        _notifyUpdates = false;
      }

      if (storedMembers.isNotEmpty) {
        _familyMembers.removeWhere((member) => member.name.trim().isEmpty);
      }

      if (_activeMember == null && _familyMembers.isNotEmpty) {
        _activeMemberName = _familyMembers.first.name;
      }

      if (storedSelectedInterests.isNotEmpty) {
        _selectedInterests
          ..clear()
          ..addAll(storedSelectedInterests.where(_interests.contains));
      }
    });
  }

  Future<void> _persistFamilyMembers() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _familyMembers
        .map((member) => jsonEncode(member.toMap()))
        .toList(growable: false);
    await prefs.setStringList(_prefsFamilyMembersKey, payload);
  }

  Future<void> _persistSelectedInterests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsSelectedInterestsKey,
      _selectedInterests.toList(),
    );
  }

  Future<void> _persistNotificationsSetting() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool(_prefsNotificationsKey, _notificationsEnabled),
      prefs.setBool(_prefsNotifyEmergenciesKey, _notifyEmergencies),
      prefs.setBool(_prefsNotifyRemindersKey, _notifyReminders),
      prefs.setBool(_prefsNotifyUpdatesKey, _notifyUpdates),
    ]);
  }

  Future<void> _persistPrivacyModeSetting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsPrivacyModeKey, _privacyModeEnabled);
  }

  Future<void> _persistActiveRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsActiveRoleKey, _activeRole);
  }

  Future<void> _persistActiveMemberName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsActiveMemberNameKey, _activeMemberName);
  }

  Future<void> _persistLastBackupAt(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsLastBackupAtKey, timestamp.millisecondsSinceEpoch);
  }

  Future<void> _persistSignedBackupSetting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsSignedBackupEnabledKey, _signedBackupEnabled);
  }

  Future<void> _addFamilyMember() async {
    if (!_canManageMembers) {
      _showPermissionDeniedMessage();
      return;
    }

    final controller = TextEditingController();
    String selectedRole = 'Kind';
    String selectedAvatar = '🧒';
    String? nameErrorText;
    String? duplicateErrorText;
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Familienmitglied hinzufuegen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(30)],
                onChanged: (_) {
                  if (nameErrorText != null || duplicateErrorText != null) {
                    setDialogState(() {
                      nameErrorText = null;
                      duplicateErrorText = null;
                    });
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'z.B. Mila',
                ),
              ),
              if (nameErrorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    nameErrorText!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              if (duplicateErrorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    duplicateErrorText!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                items: const [
                  DropdownMenuItem(
                      value: 'Elternteil', child: Text('Elternteil')),
                  DropdownMenuItem(value: 'Kind', child: Text('Kind')),
                  DropdownMenuItem(
                      value: 'Bezugsperson', child: Text('Bezugsperson')),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setDialogState(() {
                    selectedRole = value;
                  });
                },
                decoration: const InputDecoration(labelText: 'Rolle'),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Avatar',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _avatarOptions.map((emoji) {
                  final isSelected = emoji == selectedAvatar;
                  return ChoiceChip(
                    label: Text(emoji, style: const TextStyle(fontSize: 18)),
                    selected: isSelected,
                    onSelected: (_) {
                      setDialogState(() {
                        selectedAvatar = emoji;
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_t('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();
                final isDuplicate = _familyMembers.any((member) =>
                    member.name.toLowerCase() == value.toLowerCase());
                if (value.isEmpty) {
                  setDialogState(() {
                    nameErrorText = 'Bitte einen Namen eingeben.';
                    duplicateErrorText = null;
                  });
                  return;
                }
                if (isDuplicate) {
                  setDialogState(() {
                    nameErrorText = null;
                    duplicateErrorText = 'Dieser Name existiert bereits.';
                  });
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Hinzufuegen'),
            ),
          ],
        ),
      ),
    );

    final memberName = controller.text.trim();
    controller.dispose();

    final isDuplicate = _familyMembers
        .any((member) => member.name.toLowerCase() == memberName.toLowerCase());
    if (added != true || memberName.isEmpty || isDuplicate) {
      return;
    }

    setState(() {
      _familyMembers.add(
        _FamilyMember(
          name: memberName,
          role: selectedRole,
          avatar: selectedAvatar,
        ),
      );
    });
    await _persistFamilyMembers();
  }

  Future<void> _editFamilyMember(_FamilyMember member) async {
    if (!_canEditMember(member)) {
      _showPermissionDeniedMessage();
      return;
    }

    final controller = TextEditingController(text: member.name);
    String selectedRole = member.role;
    String selectedAvatar = member.avatar;
    final canEditRole = _activeRole == 'Elternteil';
    String? nameErrorText;
    String? duplicateErrorText;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Mitglied bearbeiten'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(30)],
                onChanged: (_) {
                  if (nameErrorText != null || duplicateErrorText != null) {
                    setDialogState(() {
                      nameErrorText = null;
                      duplicateErrorText = null;
                    });
                  }
                },
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              if (nameErrorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    nameErrorText!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              if (duplicateErrorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    duplicateErrorText!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                items: const [
                  DropdownMenuItem(
                      value: 'Elternteil', child: Text('Elternteil')),
                  DropdownMenuItem(value: 'Kind', child: Text('Kind')),
                  DropdownMenuItem(
                      value: 'Bezugsperson', child: Text('Bezugsperson')),
                ],
                onChanged: canEditRole
                    ? (value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() {
                          selectedRole = value;
                        });
                      }
                    : null,
                decoration: const InputDecoration(labelText: 'Rolle'),
              ),
              if (!canEditRole)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Rollen können nur durch Elternprofile geaendert werden.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Avatar',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _avatarOptions.map((emoji) {
                  final isSelected = emoji == selectedAvatar;
                  return ChoiceChip(
                    label: Text(emoji, style: const TextStyle(fontSize: 18)),
                    selected: isSelected,
                    onSelected: (_) {
                      setDialogState(() {
                        selectedAvatar = emoji;
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            if (_canManageMembers)
              TextButton(
                onPressed: () {
                  Navigator.pop(context, false);
                  _removeFamilyMember(member);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Entfernen'),
              ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_t('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();
                final duplicate = _familyMembers.any((other) {
                  if (identical(other, member)) {
                    return false;
                  }
                  return other.name.toLowerCase() == value.toLowerCase();
                });
                if (value.isEmpty) {
                  setDialogState(() {
                    nameErrorText = 'Bitte einen Namen eingeben.';
                    duplicateErrorText = null;
                  });
                  return;
                }
                if (duplicate) {
                  setDialogState(() {
                    nameErrorText = null;
                    duplicateErrorText = 'Dieser Name existiert bereits.';
                  });
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );

    final newName = controller.text.trim();
    controller.dispose();
    if (saved != true || newName.isEmpty) {
      return;
    }

    final duplicate = _familyMembers.any((other) {
      if (identical(other, member)) {
        return false;
      }
      return other.name.toLowerCase() == newName.toLowerCase();
    });
    if (duplicate) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name ist bereits vorhanden.')),
      );
      return;
    }

    setState(() {
      final previousName = member.name;
      member.name = newName;
      member.role = selectedRole;
      member.avatar = selectedAvatar;
      if (_activeMemberName == previousName) {
        _activeMemberName = newName;
      }
    });
    await _persistFamilyMembers();
    await _persistActiveMemberName();
  }

  Future<void> _removeFamilyMember(_FamilyMember member) async {
    if (!_canManageMembers) {
      _showPermissionDeniedMessage();
      return;
    }

    if (_familyMembers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mindestens ein Mitglied muss bleiben.')),
      );
      return;
    }

    final shouldRemove = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Mitglied entfernen?'),
            content:
                Text('${member.name} wird aus dem Familienprofil entfernt.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_t('cancel')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Entfernen'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldRemove) {
      return;
    }

    setState(() {
      _familyMembers.remove(member);
      if (_activeMemberName == member.name && _familyMembers.isNotEmpty) {
        _activeMemberName = _familyMembers.first.name;
      }
    });
    await _persistFamilyMembers();
    await _persistActiveMemberName();
  }

  Future<void> _openPrivacySettings() async {
    if (!_canManageSensitiveSettings) {
      _showPermissionDeniedMessage();
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrivacySettingsScreen(
          isPrivacyModeEnabled: _privacyModeEnabled,
          onPrivacyModeChanged: (value) async {
            setState(() {
              _privacyModeEnabled = value;
            });
            await _persistPrivacyModeSetting();
          },
        ),
      ),
    );
  }

  void _showEngagementInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(_t('engagement')),
        content: const Text(
          'Deine Aktivitaet wird im Profil gesammelt, damit ihr als Familie Fortschritte und Beteiligung besser sehen koennt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLegalInfo() {
    if (!_canManageSensitiveSettings) {
      _showPermissionDeniedMessage();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LegalInfoScreen(),
      ),
    );
  }

  Future<void> _toggleAllNotifications(bool value) async {
    if (!_canManageSensitiveSettings) {
      _showPermissionDeniedMessage();
      return;
    }

    setState(() {
      _notificationsEnabled = value;
      _notifyEmergencies = value;
      _notifyReminders = value;
      _notifyUpdates = value;
    });
    await _persistNotificationsSetting();
  }

  Future<void> _updateGranularNotifications({
    bool? emergencies,
    bool? reminders,
    bool? updates,
  }) async {
    if (!_canManageSensitiveSettings) {
      _showPermissionDeniedMessage();
      return;
    }

    setState(() {
      if (emergencies != null) {
        _notifyEmergencies = emergencies;
      }
      if (reminders != null) {
        _notifyReminders = reminders;
      }
      if (updates != null) {
        _notifyUpdates = updates;
      }
      _notificationsEnabled =
          _notifyEmergencies || _notifyReminders || _notifyUpdates;
    });
    await _persistNotificationsSetting();
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _t('language'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            Divider(height: 1, color: Colors.grey[300]),
            Expanded(
              child: ListView.builder(
                itemCount: _languages.length,
                itemBuilder: (context, index) {
                  final lang = _languages[index];
                  final code = lang['code']!;
                  final isSelected = code == _currentLanguage;

                  // Special handling for Kurdish languages to show Ala rengin flag
                  Widget flagWidget;
                  if (code == 'ku' || code == 'ckb') {
                    flagWidget = const AlaRenginFlag(width: 32, height: 20);
                  } else {
                    flagWidget = Text(lang['flag'] ?? '🌐',
                        style: const TextStyle(fontSize: 28));
                  }

                  return ListTile(
                    leading: flagWidget,
                    title: Text(
                      lang['nativeName'] ?? '',
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(lang['name'] ?? ''),
                    trailing: isSelected
                        ? Icon(Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                    selected: isSelected,
                    selectedTileColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    onTap: () async {
                      // Nutze den globalen languageService und warte auf das Ergebnis
                      await languageService.setLanguage(code);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Kontoaktionen – modernes Design ─────────────────────────────────────────

  Widget _buildAccountActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Abmelden ─────────────────────────────────────────────────────────
        _LogoutButton(onTap: _logout),
        const SizedBox(height: 12),
        // ── Konto löschen (bewusst kleiner + dezenter) ────────────────────────
        _DeleteAccountButton(onTap: _showDeleteAccountConfirmation),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Abmelden?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'Ihr werdet von diesem Gerät abgemeldet. Eure Familiendaten bleiben gespeichert.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abmelden'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService.instance.logout();
    if (!mounted) return;
    // Komplette Widget-Tree ersetzen — AuthGate erkennt currentUser == null
    // und zeigt automatisch LoginScreen an.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DemoApp()),
      (route) => false,
    );
  }

  void _showDeleteAccountConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text(
          'Konto wirklich löschen?',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Diese Aktion ist endgültig und kann nicht rückgängig gemacht werden.',
            ),
            SizedBox(height: 10),
            Text(
              'Folgendes wird gelöscht:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text('• Alle Familienmitglieder & Profile'),
            Text('• Notfallkontakte & Geräte'),
            Text('• Backups & Einstellungen'),
            Text('• Euer gesamter Parentpeak-Bereich'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final firebaseUser = FirebaseAuth.instance.currentUser;
              final accountUserId = firebaseUser?.uid;

              // First remove server-side user data if backend is configured.
              if (accountUserId != null && accountUserId.isNotEmpty) {
                final cleanupService = AccountDataCleanupService();
                final cleanupOk = await cleanupService.deleteAccountData(
                  userId: accountUserId,
                );
                if (!cleanupOk) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          cleanupService.lastError ??
                              'Server-Daten konnten nicht geloescht werden.',
                        ),
                      ),
                    );
                  }
                  return;
                }
              }

              // Delete account from Firebase Auth.
              try {
                if (firebaseUser != null) {
                  await firebaseUser.delete();
                }
              } catch (e) {
                debugPrint('Error deleting Firebase account: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Fehler beim Löschen des Kontos: $e')),
                  );
                }
                return;
              }
              // Alle lokalen Daten löschen
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              await AuthService.instance.logout();
              if (!mounted) return;
              // Komplette Widget-Tree ersetzen
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const DemoApp()),
                (route) => false,
              );
            },
            child: const Text('Endgültig löschen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primaryColor = Color(0xFFBDB2FF);
    const accentColor = Color(0xFFFFC6FF);

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('family_profile_title')),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(primaryColor, accentColor),
            const SizedBox(height: 24),
            _buildSafetySnapshot(primaryColor, accentColor),
            const SizedBox(height: 24),
            _buildFamilyAvatars(primaryColor),
            const SizedBox(height: 24),
            _buildSubscriptionCard(primaryColor, accentColor),
            const SizedBox(height: 24),
            _buildInterests(theme),
            const SizedBox(height: 24),
            _buildSettings(primaryColor, theme),
            const SizedBox(height: 24),
            _buildAccountSection(theme),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color primary, Color accent) {
    final childrenCount =
        _familyMembers.where((member) => member.role == 'Kind').length;
    final adultCount = _familyMembers.length - childrenCount;

    return Stack(
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 252),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primary.withValues(alpha: 0.8),
                accent.withValues(alpha: 0.6)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.family_restroom,
                      size: 64, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    _t('family_profile_title'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      'Euer geschuetzter Raum für Rollen, Familienprofile, Datenschutz und vertrauensvolle Organisation.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, height: 1.35),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildHeaderStat(
                          'Mitglieder', _familyMembers.length.toString()),
                      _buildHeaderStat('Kinder', childrenCount.toString()),
                      _buildHeaderStat('Erwachsene', adultCount.toString()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetySnapshot(Color primary, Color accent) {
    final trustDevicesCount = widget.devices.length;
    final privacyLabel = _privacyModeEnabled ? 'Aktiv' : 'Offen';
    final updatesLabel = _notificationsEnabled ? 'An' : 'Aus';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: primary.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.shield_rounded, color: primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schutzstatus',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Euer Profil auf einen Blick',
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildSnapshotPill(
                  Icons.lock_rounded,
                  'Privatsphaere',
                  privacyLabel,
                  _privacyModeEnabled
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFFEDD5),
                  _privacyModeEnabled
                      ? const Color(0xFF166534)
                      : const Color(0xFF9A3412),
                ),
                const SizedBox(width: 8),
                _buildSnapshotPill(
                  Icons.devices_rounded,
                  'Geraete',
                  '$trustDevicesCount aktiv',
                  const Color(0xFFDBEAFE),
                  const Color(0xFF1D4ED8),
                ),
                const SizedBox(width: 8),
                _buildSnapshotPill(
                  Icons.notifications_rounded,
                  'Hinweise',
                  updatesLabel,
                  const Color(0xFFF3E8FF),
                  const Color(0xFF7E22CE),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnapshotPill(
    IconData icon,
    String label,
    String value,
    Color bg,
    Color fgColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: fgColor),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: fgColor,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  String _memberStatusLabel(_FamilyMember member) {
    if (_activeMemberName == member.name) {
      return 'Aktives Profil';
    }
    if (member.role == 'Kind') {
      return _privacyModeEnabled ? 'Kind · geschuetzt' : 'Kind · sichtbar';
    }
    if (member.role == 'Bezugsperson') {
      return 'Vertrauensprofil';
    }
    return 'Elternprofil';
  }

  Color _memberStatusColor(_FamilyMember member) {
    if (_activeMemberName == member.name) {
      return const Color(0xFFDCFCE7);
    }
    if (member.role == 'Kind') {
      return _privacyModeEnabled
          ? const Color(0xFFDBEAFE)
          : const Color(0xFFFFEDD5);
    }
    if (member.role == 'Bezugsperson') {
      return const Color(0xFFF3E8FF);
    }
    return const Color(0xFFE2E8F0);
  }

  Color _memberStatusTextColor(_FamilyMember member) {
    if (_activeMemberName == member.name) {
      return const Color(0xFF166534);
    }
    if (member.role == 'Kind') {
      return _privacyModeEnabled
          ? const Color(0xFF1D4ED8)
          : const Color(0xFF9A3412);
    }
    if (member.role == 'Bezugsperson') {
      return const Color(0xFF7E22CE);
    }
    return const Color(0xFF334155);
  }

  Widget _buildSectionHeader(
    ThemeData theme,
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(
    Color primary,
    String title,
    String subtitle,
    List<Widget> children,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primary.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    String? status,
    Color statusColor = const Color(0xFFE2E8F0),
    Color? statusTextColor,
    Color? tileTint,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      tileColor: tileTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: leading,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(subtitle),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (status != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusTextColor ?? const Color(0xFF334155),
                ),
              ),
            ),
          const Icon(Icons.arrow_forward_ios, size: 16),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildFamilyAvatars(Color primary) {
    final activeMember = _familyMembers.firstWhere(
      (m) => m.name == _activeMemberName,
      orElse: () => _familyMembers.first,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('family_members'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tippen zum Wechseln · Lang halten zum Bearbeiten',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black45,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(activeMember.avatar,
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      activeMember.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: primary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _familyMembers.length + 1,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
            ),
            itemBuilder: (context, index) {
              if (index == _familyMembers.length) {
                return InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: _canManageMembers
                      ? _addFamilyMember
                      : _showPermissionDeniedMessage,
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      color: primary.withValues(alpha: 0.08),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_rounded,
                            color: primary, size: 36),
                        const SizedBox(height: 10),
                        Text(
                          'Mitglied hinzufuegen',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _canManageMembers
                              ? 'Neues Profil anlegen'
                              : 'Nur für Elternteil',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final member = _familyMembers[index];
              final isActive = _activeMemberName == member.name;
              return InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () async {
                  setState(() {
                    _activeMemberName = member.name;
                    _activeRole = member.role;
                  });
                  await _persistActiveMemberName();
                  await _persistActiveRole();
                },
                onLongPress: () => _editFamilyMember(member),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: isActive
                        ? primary.withValues(alpha: 0.12)
                        : Colors.white,
                    border: Border.all(
                      color: isActive
                          ? primary.withValues(alpha: 0.32)
                          : Colors.black12,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: primary.withValues(alpha: 0.18),
                              child: Text(
                                member.avatar,
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                            const Spacer(),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _memberStatusColor(member),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _memberStatusLabel(member),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _memberStatusTextColor(member),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          member.name,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          member.role,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.black54,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        if (isActive)
                          Row(
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  size: 12, color: primary),
                              const SizedBox(width: 4),
                              Text(
                                'Aktiv',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            'Tippen zum Wechseln',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Colors.black38,
                                ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(Color primary, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                primary.withValues(alpha: 0.12),
                accent.withValues(alpha: 0.10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: primary.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.card_membership,
                      color: Color(0xFFBDB2FF)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('premium_subscription'),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        _t('subscription_active'),
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_t('subscription_manage'))),
                    );
                  },
                  child: Text(_t('subscription_manage')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInterests(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('interests'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _interests.map((interest) {
              return FilterChip(
                label: Text(interest),
                selected: _selectedInterests.contains(interest),
                onSelected: (selected) async {
                  setState(() {
                    if (selected) {
                      _selectedInterests.add(interest);
                    } else {
                      _selectedInterests.remove(interest);
                    }
                  });
                  await _persistSelectedInterests();
                },
                backgroundColor: const Color(0xFFBDB2FF).withValues(alpha: 0.2),
                labelStyle: const TextStyle(
                  color: Color(0xFFBDB2FF),
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSettings(Color primary, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            theme,
            _t('settings'),
            'Steuert Sichtbarkeit, Benachrichtigungen und Sicherheitszugriffe passend für euren Familienalltag.',
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            primary,
            'Profil & Sichtbarkeit',
            'Sprache, Darstellung, Hinweise und Datenschutz für euren Familienraum.',
            [
              _buildActionTile(
                leading: Builder(
                  builder: (context) {
                    final currentLang = _languages
                        .firstWhere((l) => l['code'] == _currentLanguage);
                    final code = currentLang['code']!;
                    if (code == 'ku' || code == 'ckb') {
                      return const AlaRenginFlag(width: 24, height: 15);
                    }
                    final flagValue = currentLang['flag']!;
                    return Text(flagValue,
                        style: const TextStyle(fontSize: 20));
                  },
                ),
                title: _t('language'),
                subtitle: 'Aktive Sprache im Familienbereich wechseln',
                status: _languages.firstWhere(
                        (l) => l['code'] == _currentLanguage)['nativeName'] ??
                    '',
                onTap: _showLanguageSelector,
              ),
              Divider(height: 1, color: primary.withValues(alpha: 0.1)),
              SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                secondary:
                    const Icon(Icons.dark_mode, color: Color(0xFFBDB2FF)),
                title: Text(_t('dark_mode')),
                value: _isDarkMode,
                onChanged: (value) async {
                  setState(() => _isDarkMode = value);
                  await themeService.setDarkMode(value);
                  DemoApp.setThemeMode(
                      value ? ThemeMode.dark : ThemeMode.light);
                },
              ),
              Divider(height: 1, color: primary.withValues(alpha: 0.1)),
              SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                secondary:
                    const Icon(Icons.notifications, color: Color(0xFFBDB2FF)),
                title: Text(_t('notifications')),
                value: _notificationsEnabled,
                onChanged: _toggleAllNotifications,
              ),
              if (_notificationsEnabled) ...[
                Divider(height: 1, color: primary.withValues(alpha: 0.08)),
                SwitchListTile(
                  contentPadding: const EdgeInsets.only(
                    left: 52,
                    right: 20,
                    top: 6,
                    bottom: 6,
                  ),
                  title: const Text('Notfaelle'),
                  subtitle: const Text('Sofortige Benachrichtigungen'),
                  value: _notifyEmergencies,
                  onChanged: (value) =>
                      _updateGranularNotifications(emergencies: value),
                ),
                Divider(height: 1, color: primary.withValues(alpha: 0.08)),
                SwitchListTile(
                  contentPadding: const EdgeInsets.only(
                    left: 52,
                    right: 20,
                    top: 6,
                    bottom: 6,
                  ),
                  title: const Text('Erinnerungen'),
                  subtitle: const Text('Termine und Aufgaben'),
                  value: _notifyReminders,
                  onChanged: (value) =>
                      _updateGranularNotifications(reminders: value),
                ),
                Divider(height: 1, color: primary.withValues(alpha: 0.08)),
                SwitchListTile(
                  contentPadding: const EdgeInsets.only(
                    left: 52,
                    right: 20,
                    top: 6,
                    bottom: 6,
                  ),
                  title: const Text('Produkt-Updates'),
                  subtitle: const Text('Neue Funktionen und Hinweise'),
                  value: _notifyUpdates,
                  onChanged: (value) =>
                      _updateGranularNotifications(updates: value),
                ),
              ],
              Divider(height: 1, color: primary.withValues(alpha: 0.1)),
              _buildActionTile(
                leading:
                    const Icon(Icons.privacy_tip, color: Color(0xFFBDB2FF)),
                title: _t('privacy'),
                subtitle: _privacyModeEnabled
                    ? 'Schuetzt sensible Familieninfos im Alltag'
                    : 'Mehr Infos sind im Familienkreis sichtbar',
                status: _privacyModeEnabled ? 'Geschuetzt' : 'Offener',
                statusColor: _privacyModeEnabled
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFFEDD5),
                statusTextColor: _privacyModeEnabled
                    ? const Color(0xFF166534)
                    : const Color(0xFF9A3412),
                onTap: _openPrivacySettings,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(ThemeData theme) {
    const primaryColor = Color(0xFFBDB2FF);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            theme,
            _t('account'),
            'Sichert euer Profil, prueft rechtliche Leitplanken und haltet euren Parentpeak-Bereich langfristig stabil.',
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            primaryColor,
            'Vertrauen & Orientierung',
            'Was eure Familie ueber Verantwortung, Leitplanken und Zusammenarbeit wissen sollte.',
            [
              _buildActionTile(
                leading: const Icon(Icons.star, color: Color(0xFFBDB2FF)),
                title: _t('engagement'),
                subtitle: _t('engagement_subtitle'),
                status: 'Einblick',
                statusColor: const Color(0xFFFAE8FF),
                statusTextColor: const Color(0xFF86198F),
                onTap: _showEngagementInfo,
              ),
              Divider(height: 1, color: primaryColor.withValues(alpha: 0.1)),
              _buildActionTile(
                leading:
                    const Icon(Icons.description, color: Color(0xFFBDB2FF)),
                title: _t('legal'),
                subtitle:
                    'Leitplanken für faire und sichere Nutzung im Familienalltag',
                status: 'Wichtig',
                statusColor: const Color(0xFFDBEAFE),
                statusTextColor: const Color(0xFF1D4ED8),
                onTap: _showLegalInfo,
              ),
            ],
          ),
          _buildSectionCard(
            primaryColor,
            'Sicherheit & Wiederherstellung',
            'Backups, Signaturen und Wiederherstellung für euren geschuetzten Familienraum.',
            [
              _buildActionTile(
                leading: const Icon(Icons.copy_all, color: Color(0xFFBDB2FF)),
                title: 'Backup exportieren',
                subtitle: _lastBackupAt == null
                    ? 'Noch kein Backup erstellt'
                    : 'Letztes Backup: ${_lastBackupAt!.day.toString().padLeft(2, '0')}.${_lastBackupAt!.month.toString().padLeft(2, '0')}.${_lastBackupAt!.year}',
                status: 'v$_backupVersion',
                onTap: _exportProfileBackup,
              ),
              Divider(height: 1, color: primaryColor.withValues(alpha: 0.1)),
              SwitchListTile.adaptive(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                secondary:
                    const Icon(Icons.verified_user, color: Color(0xFFBDB2FF)),
                title: const Text('Signierte Backups'),
                subtitle: const Text(
                    'Fügt eine HMAC-Signatur zur Integritätsprüfung hinzu'),
                value: _signedBackupEnabled,
                onChanged: _canManageMembers
                    ? (value) async {
                        setState(() {
                          _signedBackupEnabled = value;
                        });
                        await _persistSignedBackupSetting();
                      }
                    : null,
              ),
              Divider(height: 1, color: primaryColor.withValues(alpha: 0.1)),
              _buildActionTile(
                leading: const Icon(Icons.qr_code_2, color: Color(0xFFBDB2FF)),
                title: 'Backup als QR anzeigen',
                subtitle:
                    'Direkter Transfer auf ein zweites Geraet ohne Teilen-Dialog',
                status: 'QR',
                statusColor: const Color(0xFFE0F2FE),
                statusTextColor: const Color(0xFF0369A1),
                onTap: _showBackupQrDialog,
              ),
              Divider(height: 1, color: primaryColor.withValues(alpha: 0.1)),
              _buildActionTile(
                leading:
                    const Icon(Icons.upload_file, color: Color(0xFFBDB2FF)),
                title: 'Backup importieren',
                subtitle:
                    'Gespeichertes Profil aus JSON oder QR wiederherstellen',
                status: _signedBackupEnabled ? 'Signatur an' : 'Standard',
                statusColor: _signedBackupEnabled
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFF1F5F9),
                statusTextColor: _signedBackupEnabled
                    ? const Color(0xFF166534)
                    : const Color(0xFF334155),
                onTap: _canManageMembers
                    ? _importProfileBackup
                    : _showPermissionDeniedMessage,
              ),
            ],
          ),
          _buildAccountActionsSection(),
        ],
      ),
    );
  }
}

// ─── Abmelden Button ──────────────────────────────────────────────────────────

class _LogoutButton extends StatefulWidget {
  const _LogoutButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF7ED), Color(0xFFFFF3E0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFFFED7AA),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEA580C).withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFEA580C),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Abmelden',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7C2D12),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sitzung auf diesem Gerät beenden',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF9A3412).withValues(alpha: 0.75),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: Color(0xFFEA580C),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Konto löschen Button (bewusst kleiner + dezenter) ───────────────────────

class _DeleteAccountButton extends StatefulWidget {
  const _DeleteAccountButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_DeleteAccountButton> createState() => _DeleteAccountButtonState();
}

class _DeleteAccountButtonState extends State<_DeleteAccountButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedOpacity(
        opacity: _pressed ? 0.7 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFFFFF5F5),
            border: Border.all(
              color: const Color(0xFFFFCDD2),
              width: 1.2,
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFE53935),
                size: 16,
              ),
              SizedBox(width: 7),
              Text(
                'Konto löschen',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE53935),
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilyMember {
  _FamilyMember({
    required this.name,
    required this.role,
    required this.avatar,
  });

  String name;
  String role;
  String avatar;

  Map<String, dynamic> toMap() => {
        'name': name,
        'role': role,
        'avatar': avatar,
      };

  factory _FamilyMember.fromMap(Map<String, dynamic> map) {
    return _FamilyMember(
      name: (map['name'] as String?)?.trim().isNotEmpty == true
          ? map['name'] as String
          : 'Mitglied',
      role: (map['role'] as String?)?.trim().isNotEmpty == true
          ? map['role'] as String
          : 'Kind',
      avatar: (map['avatar'] as String?)?.trim().isNotEmpty == true
          ? map['avatar'] as String
          : '🧑',
    );
  }
}
