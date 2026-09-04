import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLanguage {
  final String code;
  final String name;
  final String nativeName;
  final String flag;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
  });

  Locale get locale => Locale(code);
}

class AppLanguages {
  static const defaultCode = 'de';

  static const supported = <AppLanguage>[
    AppLanguage(
      code: 'de',
      name: 'Deutsch',
      nativeName: 'Deutsch',
      flag: '\u{1F1E9}\u{1F1EA}',
    ),
    AppLanguage(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      flag: '\u{1F1EC}\u{1F1E7}',
    ),
    AppLanguage(
      code: 'ar',
      name: 'Arabisch',
      nativeName: '\u{0627}\u{0644}\u{0639}\u{0631}\u{0628}\u{064A}\u{0629}',
      flag: '\u{1F1F8}\u{1F1E6}',
    ),
    AppLanguage(
      code: 'fa',
      name: 'Persisch',
      nativeName: '\u{0641}\u{0627}\u{0631}\u{0633}\u{06CC}',
      flag: '\u{1F1EE}\u{1F1F7}',
    ),
    AppLanguage(
      code: 'ku',
      name: 'Kurmanc\u{00EE}',
      nativeName: 'Kurd\u{00EE}',
      flag: 'ala_rengin',
    ),
    AppLanguage(
      code: 'ckb',
      name: 'Sorani',
      nativeName: '\u{06A9}\u{0648}\u{0631}\u{062F}\u{06CC}',
      flag: 'ala_rengin',
    ),
    AppLanguage(
      code: 'fr',
      name: 'Franz\u{00F6}sisch',
      nativeName: 'Fran\u{00E7}ais',
      flag: '\u{1F1EB}\u{1F1F7}',
    ),
    AppLanguage(
      code: 'es',
      name: 'Spanisch',
      nativeName: 'Espa\u{00F1}ol',
      flag: '\u{1F1EA}\u{1F1F8}',
    ),
    AppLanguage(
      code: 'it',
      name: 'Italienisch',
      nativeName: 'Italiano',
      flag: '\u{1F1EE}\u{1F1F9}',
    ),
    AppLanguage(
      code: 'pt',
      name: 'Portugiesisch',
      nativeName: 'Portugu\u{00EA}s',
      flag: '\u{1F1F5}\u{1F1F9}',
    ),
    AppLanguage(
      code: 'nl',
      name: 'Niederl\u{00E4}ndisch',
      nativeName: 'Nederlands',
      flag: '\u{1F1F3}\u{1F1F1}',
    ),
    AppLanguage(
      code: 'pl',
      name: 'Polnisch',
      nativeName: 'Polski',
      flag: '\u{1F1F5}\u{1F1F1}',
    ),
    AppLanguage(
      code: 'tr',
      name: 'T\u{00FC}rkisch',
      nativeName: 'T\u{00FC}rk\u{00E7}e',
      flag: '\u{1F1F9}\u{1F1F7}',
    ),
    AppLanguage(
      code: 'ja',
      name: 'Japanisch',
      nativeName: '\u{65E5}\u{672C}\u{8A9E}',
      flag: '\u{1F1EF}\u{1F1F5}',
    ),
    AppLanguage(
      code: 'zh',
      name: 'Chinesisch',
      nativeName: '\u{4E2D}\u{6587}',
      flag: '\u{1F1E8}\u{1F1F3}',
    ),
    AppLanguage(
      code: 'hi',
      name: 'Hindi',
      nativeName: '\u{0939}\u{093F}\u{0928}\u{094D}\u{0926}\u{0940}',
      flag: '\u{1F1EE}\u{1F1F3}',
    ),
  ];

  static const rtlCodes = {'ar', 'fa', 'ckb'};

  static const materialLocalizationsDelegate =
      _AppMaterialLocalizationsDelegate();
  static const widgetsLocalizationsDelegate =
      _AppWidgetsLocalizationsDelegate();
  static const cupertinoLocalizationsDelegate =
      _AppCupertinoLocalizationsDelegate();

  static final supportedLocales =
      supported.map((language) => language.locale).toList(growable: false);

  static bool isSupported(String code) =>
      supported.any((language) => language.code == code);

  static bool isRtl(String code) => rtlCodes.contains(code);

  static String normalizeCode(String? code) =>
      code != null && isSupported(code) ? code : defaultCode;

  static Locale localeFor(String? code) => Locale(normalizeCode(code));

  static Locale platformLocaleFor(Locale locale) =>
      switch (locale.languageCode) {
        'ckb' => const Locale('ar'),
        'ku' => const Locale('en'),
        _ => locale,
      };
}

class _AppMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _AppMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLanguages.isSupported(locale.languageCode);

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate
          .load(AppLanguages.platformLocaleFor(locale));

  @override
  bool shouldReload(_AppMaterialLocalizationsDelegate old) => false;
}

class _AppWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const _AppWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLanguages.isSupported(locale.languageCode);

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      GlobalWidgetsLocalizations.delegate
          .load(AppLanguages.platformLocaleFor(locale));

  @override
  bool shouldReload(_AppWidgetsLocalizationsDelegate old) => false;
}

class _AppCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _AppCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLanguages.isSupported(locale.languageCode);

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate
          .load(AppLanguages.platformLocaleFor(locale));

  @override
  bool shouldReload(_AppCupertinoLocalizationsDelegate old) => false;
}
