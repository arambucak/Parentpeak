import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/logic/chat_context_policy.dart';
import 'package:parentpeak/models/family_profile_model.dart';

/// Baut einen kompakten, datensparsamen Familienkontext für die
/// KI-Elternberatung, damit der Coach die Familie "kennt" statt bei jeder
/// Frage bei null zu starten.
///
/// Bewusste Datenschutz-Grenzen:
///   • KEINE Klarnamen von Kindern oder Eltern — nur Alter (volle Jahre),
///     Erziehungswerte der Eltern und optional wiederkehrende Gesprächsthemen.
///   • Rein aus lokalen, kontogetrennten Quellen (FamilyMatchProfile +
///     Chat-Themenzähler). Keine Serverdaten, kein zusätzlicher Memory-Consent.
///   • Der erzeugte String wird ohnehin durch den PrivacySanitizer geschickt,
///     bevor er die KI erreicht.
///
/// Reine Funktion ohne Seiteneffekte → eigenständig unit-testbar.
class FamilyContextBuilder {
  const FamilyContextBuilder();

  /// Erzeugt den Familienkontext-Block für den Coaching-Prompt.
  /// Gibt einen leeren String zurück, wenn keine verwertbaren Daten vorliegen
  /// (dann wird im Prompt ein neutraler Platzhalter verwendet).
  ///
  /// [profile]      lok/kontogetrennt geladenes Familienprofil (oder null)
  /// [languageCode] Sprache für die Werte-Labels
  /// [topTopics]    optionale, bereits sortierte häufigste Gesprächsthemen
  /// [now]          Testbarkeit der Altersberechnung
  String build({
    required FamilyMatchProfile? profile,
    required String languageCode,
    List<String> topTopics = const [],
    DateTime? now,
  }) {
    final parts = <String>[];

    if (profile != null && profile.children.isNotEmpty) {
      final ages = <int>[];
      for (final child in profile.children) {
        final age = ChatContextPolicy.completedAge(child, now: now);
        if (age != null) ages.add(age);
      }
      ages.sort();
      if (ages.length == 1) {
        parts.add(_t(languageCode, 'chat_family_one_child', {'age': '${ages.first}'}));
      } else if (ages.length > 1) {
        parts.add(_t(languageCode, 'chat_family_children', {
          'count': '${ages.length}',
          'ages': ages.join(', '),
        }));
      }
    }

    final values = _readableValues(profile, languageCode);
    if (values.isNotEmpty) {
      parts.add(_t(languageCode, 'chat_family_values', {'values': values.join(', ')}));
    }

    final topics = topTopics.where((t) => t.trim().isNotEmpty).take(3).toList();
    if (topics.isNotEmpty) {
      parts.add(_t(languageCode, 'chat_family_topics', {'topics': topics.join(', ')}));
    }

    return parts.join(' ');
  }

  /// Übersetzt die gespeicherten Werte-Codes (z. B. 'gfk') in lesbare, vom
  /// Emoji befreite Labels. Begrenzt auf die wichtigsten, um den Prompt
  /// schlank zu halten.
  List<String> _readableValues(FamilyMatchProfile? profile, String languageCode) {
    if (profile == null) return const [];
    final out = <String>[];
    for (final code in profile.values.take(4)) {
      final label = MatchOptions.valueLabels[code];
      if (label == null) continue;
      // Führendes Emoji + Leerzeichen entfernen, nur den Text behalten.
      final cleaned = label.replaceFirst(RegExp(r'^\s*\S+\s+'), '').trim();
      if (cleaned.isNotEmpty) out.add(cleaned);
    }
    final custom = profile.valuesCustom?.trim();
    if (custom != null && custom.isNotEmpty && out.length < 5) {
      out.add(custom);
    }
    return out;
  }

  String _t(String lang, String key, Map<String, String> values) {
    return AppStringsManager.getString(lang, key).replaceAllMapped(
      RegExp(r'\{(\w+)\}'),
      (m) => values[m.group(1)] ?? m.group(0)!,
    );
  }
}
