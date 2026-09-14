import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:parentpeak/l10n/supported_languages.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  static String activeCode = AppLanguages.defaultCode;

  String _currentLanguage = AppLanguages.defaultCode;
  bool _initialized = false;

  String get currentLanguage => _currentLanguage;
  bool get initialized => _initialized;

  LanguageService() {
    // Lade synchron wenn möglich, sonst asynchron
    _initPrefs();
  }

  void _initPrefs() {
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getString('selected_language');
      if (AppLanguages.isSupported(saved ?? '')) {
        _currentLanguage = saved!;
        debugPrint('✅ Sprache async geladen: $_currentLanguage');
      } else {
        _currentLanguage = AppLanguages.defaultCode;
        debugPrint('⚠️ Keine gespeicherte Sprache, verwende: de');
      }
      activeCode = _currentLanguage;
      _initialized = true;
      notifyListeners();
    }).catchError((e) {
      debugPrint('❌ Fehler beim Laden SharedPreferences: $e');
      _currentLanguage = AppLanguages.defaultCode;
      activeCode = _currentLanguage;
      _initialized = true;
      notifyListeners();
    });
  }

  Future<void> setLanguage(String languageCode) async {
    final normalizedCode = AppLanguages.normalizeCode(languageCode);
    if (!_initialized) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_language', normalizedCode);
      _currentLanguage = normalizedCode;
      activeCode = normalizedCode;
      debugPrint('✅ Sprache SYNCHRON gespeichert und gesetzt: $normalizedCode');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Fehler beim Speichern der Sprache: $e');
    }
  }
}
