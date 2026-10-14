import 'package:parentpeak/models/eltern_wissen_faq.dart';
import 'package:parentpeak/l10n/eltern_wissen_localizations_fr.dart';
import 'package:parentpeak/l10n/eltern_wissen_localizations_es.dart';
import 'package:parentpeak/l10n/eltern_wissen_localizations_it.dart';
import 'package:parentpeak/l10n/eltern_wissen_localizations_ar.dart';
import 'package:parentpeak/l10n/eltern_wissen_localizations_tr.dart';

/// Localized copy for one parent-knowledge FAQ entry.
///
/// Only the user-facing prose is translated; [ElternWissenEntry.tags],
/// `category`, `id` and the age bounds stay as in the German source so the
/// fuzzy search keeps working with German search terms (as the UI notice
/// explains).
class ElternWissenText {
  const ElternWissenText({
    required this.question,
    required this.akut,
    required this.beduerfnis,
    required this.gfkSatz,
    required this.aktion,
    required this.ermutigung,
  });

  final String question;
  final String akut;
  final String beduerfnis;
  final String gfkSatz;
  final List<String> aktion;
  final String ermutigung;
}

const Map<String, Map<String, ElternWissenText>> _translations = {
  'fr': elternWissenFr,
  'es': elternWissenEs,
  'it': elternWissenIt,
  'ar': elternWissenAr,
  'tr': elternWissenTr,
};

/// Returns a copy of [entry] with its prose translated into [language].
///
/// Falls back to the original German entry when the language or the specific
/// id has no translation. Preserves tags, category, id and age bounds.
ElternWissenEntry localizeElternWissenEntry(
  ElternWissenEntry entry,
  String language,
) {
  final text = _translations[language]?[entry.id];
  if (text == null) return entry;
  // Keep the action-step count stable; if a translation is malformed fall
  // back to the German steps rather than showing an empty list.
  final aktion = text.aktion.length == entry.aktion.length
      ? text.aktion
      : entry.aktion;
  return ElternWissenEntry(
    id: entry.id,
    question: text.question,
    akut: text.akut,
    beduerfnis: text.beduerfnis,
    gfkSatz: text.gfkSatz,
    aktion: aktion,
    ermutigung: text.ermutigung,
    minAge: entry.minAge,
    maxAge: entry.maxAge,
    tags: entry.tags,
    category: entry.category,
  );
}
