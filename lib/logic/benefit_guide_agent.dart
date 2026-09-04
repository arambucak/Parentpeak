import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:parentpeak/logic/gemini_ai_service.dart';
import 'package:parentpeak/models/benefit_guide_result.dart';
import 'package:parentpeak/models/country_finance_config.dart';
import 'package:parentpeak/services/ai_rate_limiter.dart';

/// Der "Familien-Leistungs-Wegweiser".
///
/// Orientierungs- und Vorbereitungshelfer — KEINE Rechts- oder Finanzberatung.
/// Nutzt die kuratierten [CountryFinanceConfig]-Daten als harte Faktenbasis und
/// lässt Gemini nur personalisieren/erklären. Erfindet bewusst KEINE Beträge.
class BenefitGuideAgent {
  static const _model = 'gemini-3.5-flash'; // stabil für Grounding

  /// Ermittelt passende Leistungen + Checkliste für die geschilderte Situation.
  /// [situation] wird vor dem Versand automatisch durch den PrivacySanitizer
  /// im GeminiAIService anonymisiert.
  Future<BenefitGuideResult> guide({
    required CountryFinanceConfig country,
    required String situation,
    List<int> childAgesYears = const [],
    bool isSingleParent = false,
  }) async {
    await AIRateLimiter.initialize();
    if (!AIRateLimiter.canMakeRequest()) {
      debugPrint('BenefitGuideAgent: Rate limit erreicht');
      return _fallback(country);
    }

    final prompt = _buildPrompt(
      country: country,
      situation: situation,
      childAgesYears: childAgesYears,
      isSingleParent: isSingleParent,
    );

    try {
      final response = await GeminiAIService(modelName: _model)
          .generate(prompt, useGoogleSearch: true)
          .timeout(const Duration(seconds: 35));
      await AIRateLimiter.recordRequest();
      final result = _parse(response.text, country, response.groundingUrls);
      if (result.isEmpty) return _fallback(country);
      return result;
    } catch (e) {
      debugPrint('BenefitGuideAgent.guide: $e');
      return _fallback(country);
    }
  }

  // ─── Prompt ─────────────────────────────────────────────────────────────

  String _buildPrompt({
    required CountryFinanceConfig country,
    required String situation,
    required List<int> childAgesYears,
    required bool isSingleParent,
  }) {
    // Kuratierte Leistungen als Faktenbasis serialisieren.
    final facts = country.benefits
        .map((b) => {
              'id': b.id,
              'name': b.name,
              'description': b.description,
              if (b.amount != null) 'amount': b.amount,
              if (b.eligibility != null) 'eligibility': b.eligibility,
              if (b.url != null) 'url': b.url,
              'status': b.status.name,
            })
        .toList();

    final ages = childAgesYears.isEmpty
        ? 'nicht angegeben'
        : childAgesYears.map((a) => '$a J.').join(', ');

    return '''
Du bist ein einfühlsamer Familien-Leistungs-WEGWEISER für das Land: ${country.name} (${country.currency}).
Du gibst ORIENTIERUNG, KEINE Rechts- oder Finanzberatung.

KURATIERTE LEISTUNGEN (das ist deine WAHRHEIT — bevorzuge diese Fakten):
${jsonEncode(facts)}

SITUATION DER FAMILIE (in eigenen Worten):
"$situation"
Kinder-Alter: $ages
Alleinerziehend: ${isSingleParent ? 'ja' : 'nein/unbekannt'}

STRENGE REGELN:
- Nenne NUR Leistungen, die zum Land und zur Situation passen. Bevorzuge die kuratierten Leistungen (nutze deren "id" im Feld "benefitId", wenn du eine davon meinst).
- ERFINDE KEINE BETRÄGE. Nenne KEINE konkrete Anspruchshöhe. Wenn nach Höhe gefragt wäre, schreibe sinngemäß: "die genaue Höhe berechnet die zuständige Stelle".
- Formuliere warm, klar, ohne Behörden-Deutsch. Keine Garantie ("dir steht X zu") — sondern "könnte für euch in Frage kommen".
- Bei Unsicherheit ehrlich sein: auf die zuständige Stelle verweisen.
- Nutze offizielle URLs NUR aus den kuratierten Daten oder verlässlichen offiziellen Quellen.
- Antworte auf Deutsch.

Antworte NUR mit gültigem JSON (kein Markdown, kein Text davor/danach):
{
  "matched": [
    {"benefitId": "kindergeld", "name": "Kindergeld", "why": "Kurz warum es zur Situation passt.", "authority": "Zuständige Stelle", "url": "https://..."}
  ],
  "checklist": ["Benötigtes Dokument 1", "Aufgabe 2"],
  "nextSteps": ["Konkreter nächster Schritt 1", "Schritt 2"]
}
''';
  }

  // ─── Parsing ────────────────────────────────────────────────────────────

  BenefitGuideResult _parse(
      String raw, CountryFinanceConfig country, List<String> groundingUrls) {
    try {
      final jsonStr = _extractJsonObject(raw);
      if (jsonStr == null) return const BenefitGuideResult();
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      final matched = (map['matched'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(GuideBenefit.fromJson)
          .where((b) => b.name.isNotEmpty)
          .map((b) => _enrichFromCurated(b, country))
          .toList();

      List<String> strings(dynamic v) => (v as List? ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final sources = groundingUrls
          .where((u) => u.startsWith('https://'))
          .toSet()
          .take(6)
          .toList();

      return BenefitGuideResult(
        matched: matched,
        checklist: strings(map['checklist']),
        nextSteps: strings(map['nextSteps']),
        sources: sources,
      );
    } catch (e) {
      debugPrint('BenefitGuideAgent._parse: $e');
      return const BenefitGuideResult();
    }
  }

  /// Ergänzt eine KI-Leistung mit kuratierten Fakten (offizielle URL/Name),
  /// falls die benefitId zu einer bekannten Leistung passt. So bleibt der Link
  /// verlässlich, auch wenn die KI etwas anderes vorschlägt.
  GuideBenefit _enrichFromCurated(
      GuideBenefit b, CountryFinanceConfig country) {
    if (b.benefitId.isEmpty) return b;
    SocialBenefit? curated;
    for (final c in country.benefits) {
      if (c.id == b.benefitId) {
        curated = c;
        break;
      }
    }
    if (curated == null) return b;
    return GuideBenefit(
      benefitId: b.benefitId,
      name: b.name.isNotEmpty ? b.name : curated.name,
      why: b.why,
      authority: b.authority,
      // Offizielle kuratierte URL hat Vorrang (verlässlich, kein Halluzinat).
      url: curated.url ?? b.url,
    );
  }

  String? _extractJsonObject(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    text = text.replaceAll(RegExp(r'^```(?:json)?\s*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'\s*```$', multiLine: true), '');
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    return text.substring(start, end + 1);
  }

  // ─── Fallback (rein kuratiert, ohne KI) ───────────────────────────────────

  /// Wenn die KI nicht verfügbar ist: zeige die kuratierten Leistungen des
  /// Landes als Orientierung — ehrlich, ohne erfundene Beträge.
  BenefitGuideResult _fallback(CountryFinanceConfig country) {
    final matched = country.benefits
        .map((b) => GuideBenefit(
              benefitId: b.id,
              name: b.name,
              why: b.description,
              url: b.url ?? '',
            ))
        .toList();
    return BenefitGuideResult(
      matched: matched,
      checklist: const [],
      nextSteps: const [
        'Prüfe die verlinkten offiziellen Stellen für die Details.',
        'Halte Ausweis, Nachweise zu Einkommen und Geburtsurkunde bereit.',
      ],
      sources: const [],
    );
  }
}

/// Rein lokaler Speicher für die abgehakten Checklisten-Punkte (pro Land).
/// Kein Backend — bleibt auf dem Gerät.
class BenefitChecklistStore {
  static String _key(String countryCode) =>
      'benefitguide.checklist.$countryCode.v1';

  static Future<Set<String>> loadChecked(String countryCode) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key(countryCode)) ?? const []).toSet();
  }

  static Future<void> saveChecked(
      String countryCode, Set<String> checkedItems) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key(countryCode), checkedItems.toList());
  }
}
