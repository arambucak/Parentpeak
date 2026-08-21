import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/config/monetization_config.dart';
import 'package:parentpeak/models/benefit_application_data.dart';
import 'package:parentpeak/services/premium_service.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';

/// Antragshelfer — geführter 3-Schritt-Flow für Sozialleistungs-Anträge.
///
/// Schritt 1: Unterlagen-Checkliste (Free)
/// Schritt 2: Schritt-für-Schritt Anleitung (Premium)
/// Schritt 3: KI-Textvorlage + Erinnerung (Premium)
class AntragshelferScreen extends StatefulWidget {
  final BenefitApplicationData benefit;

  const AntragshelferScreen({super.key, required this.benefit});

  @override
  State<AntragshelferScreen> createState() => _AntragshelferScreenState();
}

class _AntragshelferScreenState extends State<AntragshelferScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  String _t(String key) =>
      AppStringsManager.getString(languageService.currentLanguage, key);
  final Set<int> _checkedDocs = {};
  bool _aiLoading = false;
  String? _aiText;
  String? _aiError;

  BenefitApplicationData get _b => widget.benefit;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadCheckedDocs();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadCheckedDocs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('antragshelfer.${_b.benefitId}.docs');
    if (saved != null) {
      setState(() {
        _checkedDocs.addAll(saved.map(int.parse));
      });
    }
  }

  Future<void> _saveCheckedDocs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'antragshelfer.${_b.benefitId}.docs',
      _checkedDocs.map((i) => i.toString()).toList(),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool get _isPremium => PremiumService.instance.isPremium;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_b.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _b.benefitName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(
                icon: Icon(Icons.checklist_rounded, size: 18),
                text: 'Unterlagen'),
            Tab(icon: Icon(Icons.route_rounded, size: 18), text: 'Anleitung'),
            Tab(
                icon: Icon(Icons.auto_awesome_rounded, size: 18),
                text: 'KI-Hilfe'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildDocumentsTab(theme),
          _buildStepsTab(theme),
          _buildAiTab(theme),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: UNTERLAGEN-CHECKLISTE (Free)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDocumentsTab(ThemeData theme) {
    final allChecked = _checkedDocs.length == _b.documents.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Text(
              allChecked ? '✅' : '📋',
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 8),
            Text(
              allChecked ? 'Alles bereit!' : 'Das brauchst du',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              allChecked
                  ? 'Du hast alle Unterlagen zusammen. Weiter zu Schritt 2!'
                  : '${_checkedDocs.length} von ${_b.documents.length} Unterlagen bereit',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: const Color(0xFF166534)),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _b.documents.isEmpty
                ? 0
                : _checkedDocs.length / _b.documents.length,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: const AlwaysStoppedAnimation(Color(0xFF16A34A)),
          ),
        ),
        const SizedBox(height: 20),

        // Document list
        ...List.generate(_b.documents.length, (i) {
          final doc = _b.documents[i];
          final checked = _checkedDocs.contains(i);
          return _documentTile(theme, doc, i, checked);
        }),

        // Pro-Tipp
        if (_b.proTip != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFF97316).withValues(alpha: 0.2)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('💡', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _b.proTip!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF9A3412),
                    height: 1.4,
                  ),
                ),
              ),
            ]),
          ),
        ],

        // Next step button
        if (allChecked) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _tabs.animateTo(1),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(_t('antrag_next_guide')),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _documentTile(
      ThemeData theme, RequiredDocument doc, int index, bool checked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: checked
            ? const Color(0xFF16A34A).withValues(alpha: 0.05)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: checked
              ? const Color(0xFF16A34A).withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: CheckboxListTile(
        value: checked,
        onChanged: (val) {
          setState(() {
            if (val == true) {
              _checkedDocs.add(index);
            } else {
              _checkedDocs.remove(index);
            }
          });
          _saveCheckedDocs();
          HapticFeedback.lightImpact();
        },
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: const Color(0xFF16A34A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          doc.name,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            decoration: checked ? TextDecoration.lineThrough : null,
            color: checked ? theme.colorScheme.outline : null,
          ),
        ),
        subtitle: doc.whereToGet != null
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded,
                      size: 12, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      doc.whereToGet!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ]),
              )
            : null,
        secondary: doc.isOptional
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_t('antrag_optional'),
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF59E0B))),
              )
            : null,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: ANLEITUNG (Premium)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStepsTab(ThemeData theme) {
    if (!_isPremium && MonetizationConfig.enabled) {
      return _buildPremiumLock(theme, 'Schritt-für-Schritt Anleitung');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Info-Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            const Text('🏛️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Zuständig: ${_b.responsibleAuthority}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('⏱️ Bearbeitungszeit: ${_b.processingTime}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                  if (_b.renewalNote != null) ...[
                    const SizedBox(height: 2),
                    Text('🔄 ${_b.renewalNote}',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: const Color(0xFFF97316))),
                  ],
                ])),
          ]),
        ),
        const SizedBox(height: 24),

        // Steps
        ...List.generate(_b.steps.length, (i) {
          final step = _b.steps[i];
          return _stepCard(theme, step, i == _b.steps.length - 1);
        }),

        // Online-Antrag Button
        if (_b.onlineApplicationUrl != null) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openUrl(_b.onlineApplicationUrl!),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(_t('antrag_open_online')),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _stepCard(ThemeData theme, ApplicationStep step, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline
        Column(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${step.stepNumber}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14),
              ),
            ),
          ),
          if (!isLast)
            Container(
              width: 2,
              height: 60,
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
            ),
        ]),
        const SizedBox(width: 14),
        // Content
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(step.title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(step.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.4, color: theme.colorScheme.onSurfaceVariant)),
              if (step.url != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _openUrl(step.url!),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.open_in_new_rounded,
                        size: 13, color: Color(0xFF8B5CF6)),
                    const SizedBox(width: 4),
                    Text(_t('antrag_open_link'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF8B5CF6),
                          fontWeight: FontWeight.w700,
                        )),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 3: KI-HILFE (Premium)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildAiTab(ThemeData theme) {
    if (!_isPremium && MonetizationConfig.enabled) {
      return _buildPremiumLock(theme, 'KI-Textvorlagen');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFDF4FF), Color(0xFFFCE7F3)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: const Color(0xFFEC4899).withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            const Text('✨', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(_t('antrag_ai_template'),
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Die KI erstellt dir einen Begleitbrief oder eine Begründung — fertig zum Kopieren.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: const Color(0xFF831843)),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // Generate button
        if (_aiText == null && !_aiLoading)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _generateAiText,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text('Textvorlage für ${_b.benefitName} erstellen'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEC4899),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

        // Loading
        if (_aiLoading) ...[
          const SizedBox(height: 20),
          const Center(
              child: CircularProgressIndicator(color: Color(0xFFEC4899))),
          const SizedBox(height: 12),
          Center(
            child: Text(_t('antrag_ai_writing'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ),
        ],

        // Error
        if (_aiError != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_aiError!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error)),
          ),
        ],

        // Result
        if (_aiText != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.description_rounded,
                    size: 16, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 6),
                Text('Vorlage',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Kopieren',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _aiText!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('📋 In die Zwischenablage kopiert!'),
                          duration: Duration(seconds: 2)),
                    );
                  },
                ),
              ]),
              const Divider(height: 16),
              SelectableText(
                _aiText!,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _generateAiText,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(_t('antrag_regenerate')),
              ),
            ),
          ]),
        ],

        // Disclaimer
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('⚠️', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Dies ist eine Vorlage, keine Rechtsberatung. Passe den Text an deine persönliche Situation an.',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: const Color(0xFF92400E), height: 1.3),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ─── KI Text Generation ───────────────────────────────────────────────────

  Future<void> _generateAiText() async {
    if (_b.aiTemplatePrompt == null) return;

    setState(() {
      _aiLoading = true;
      _aiError = null;
      _aiText = null;
    });

    try {
      final apiKey = APIConfig.getGeminiApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('Kein API-Key konfiguriert');
      }

      final model = GenerativeModel(
        model: APIConfig.getGeminiModelName(),
        apiKey: apiKey,
      );

      final prompt = '''
Du bist ein freundlicher Sozialberater-Assistent. Erstelle eine Textvorlage für Eltern.

Aufgabe: ${_b.aiTemplatePrompt}

Regeln:
- Sachlich, freundlich, nicht unterwürfig
- Maximal 150 Wörter
- Platzhalter in [ECKIGEN KLAMMERN] für persönliche Daten
- Keine Rechtsberatung, nur Formulierungshilfe
- Format: Direkt als Brief-Text (kein "Betreff:", kein Header)
''';

      final response = await model.generateContent(
          [Content.text(prompt)]).timeout(const Duration(seconds: 20));

      final text = response.text;
      if (text == null || text.trim().isEmpty) {
        throw Exception('Keine Antwort erhalten');
      }

      if (mounted) {
        setState(() {
          _aiText = text.trim();
          _aiLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiError =
              'Textvorlage konnte nicht erstellt werden. Bitte versuche es erneut.';
          _aiLoading = false;
        });
      }
    }
  }

  // ─── Premium Lock ─────────────────────────────────────────────────────────

  Widget _buildPremiumLock(ThemeData theme, String featureName) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                size: 36, color: Color(0xFF8B5CF6)),
          ),
          const SizedBox(height: 20),
          Text(featureName,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            'Mit Premium bekommst du die volle Anleitung, KI-Textvorlagen und Erinnerungen.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline, height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              // TODO: Open Premium sheet
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Premium kommt bald! Während der Beta ist alles kostenlos.')),
              );
            },
            icon: const Icon(Icons.star_rounded, size: 18),
            label: Text(_t('antrag_unlock_premium')),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ]),
      ),
    );
  }
}
