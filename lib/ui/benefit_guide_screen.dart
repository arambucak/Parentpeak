import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:parentpeak/config/benefit_application_de.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:parentpeak/logic/benefit_guide_agent.dart';
import 'package:parentpeak/models/benefit_guide_result.dart';
import 'package:parentpeak/services/ai_rate_limiter.dart';
import 'package:parentpeak/models/country_finance_config.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/ui/antragshelfer_screen.dart';

/// Familien-Leistungs-Wegweiser.
///
/// Eltern schildern ihre Situation (frei + optionale Chips). Der KI-Agent
/// nennt passende Leistungen, eine persönliche Checkliste und nächste Schritte
/// — als ORIENTIERUNG, nicht als Rechtsberatung. Checkliste bleibt lokal.
class BenefitGuideScreen extends StatefulWidget {
  final CountryFinanceConfig country;
  final bool isSingleParent;

  const BenefitGuideScreen({
    super.key,
    required this.country,
    this.isSingleParent = false,
  });

  @override
  State<BenefitGuideScreen> createState() => _BenefitGuideScreenState();
}

class _BenefitGuideScreenState extends State<BenefitGuideScreen> {
  static const _accent = Color(0xFF8B5CF6);

  final _agent = BenefitGuideAgent();
  final _situationCtrl = TextEditingController();

  // Schnell-Impuls-Chips, die den Freitext ergänzen.
  static const _chips = [
    'Elternzeit',
    'Gehalt sinkt',
    'Alleinerziehend',
    'Umzug',
    'Zweites Kind kommt',
    'Wenig Einkommen',
  ];
  final Set<String> _selectedChips = {};

  bool _loading = false;
  BenefitGuideResult? _result;
  Set<String> _checked = {};
  List<int> _childAges = const [];

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  @override
  void dispose() {
    _situationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContext() async {
    try {
      final profile = await FamilyMatchProfile.load();
      final ages = (profile?.children ?? [])
          .map((c) => (c.ageMonths / 12).round())
          .toList();
      if (mounted) setState(() => _childAges = ages);
    } catch (_) {}
    final checked =
        await BenefitChecklistStore.loadChecked(widget.country.code);
    if (mounted) setState(() => _checked = checked);
  }

  Future<void> _ask() async {
    final base = _situationCtrl.text.trim();
    final chips = _selectedChips.join(', ');
    final situation = [base, chips].where((s) => s.isNotEmpty).join('. ');
    if (situation.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('benefit_input_required')),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final result = await _agent.guide(
        country: widget.country,
        situation: situation,
        childAgesYears: _childAges,
        isSingleParent:
            widget.isSingleParent || _selectedChips.contains('Alleinerziehend'),
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } on AiRateLimitException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('benefit_request_failed')),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _toggleChecklistItem(String item) async {
    setState(() {
      if (_checked.contains(item)) {
        _checked.remove(item);
      } else {
        _checked.add(item);
      }
    });
    await BenefitChecklistStore.saveChecked(widget.country.code, _checked);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openAntragshelfer(String benefitId) {
    final data = BenefitApplicationDE.getById(benefitId);
    if (data == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AntragshelferScreen(benefit: data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.country.flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Flexible(child: Text(context.tr('benefit_guide_title'))),
        ]),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _disclaimer(theme),
            const SizedBox(height: 16),
            _inputSection(theme),
            if (_loading) ...[
              const SizedBox(height: 30),
              const Center(child: CircularProgressIndicator(color: _accent)),
              const SizedBox(height: 12),
              Center(
                child: Text(context.tr('benefit_loading'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ),
            ],
            if (_result != null && !_loading) ...[
              const SizedBox(height: 24),
              _resultSection(theme, _result!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _disclaimer(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ℹ️', style: TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.tr('benefit_disclaimer'),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: const Color(0xFF92400E), height: 1.4),
          ),
        ),
      ]),
    );
  }

  Widget _inputSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('benefit_situation_title'),
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          context.tr('benefit_situation_description'),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _situationCtrl,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: context.tr('benefit_situation_hint'),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _chips.map((c) {
            final active = _selectedChips.contains(c);
            return FilterChip(
              label: Text(c),
              selected: active,
              showCheckmark: false,
              onSelected: (_) => setState(() {
                if (active) {
                  _selectedChips.remove(c);
                } else {
                  _selectedChips.add(c);
                }
              }),
              selectedColor: _accent.withValues(alpha: 0.15),
              labelStyle: TextStyle(
                color: active ? _accent : theme.colorScheme.onSurface,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
              side: BorderSide(
                  color: active ? _accent : theme.colorScheme.outlineVariant),
              backgroundColor: theme.colorScheme.surface,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _loading ? null : _ask,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(context.tr('benefit_ask_action')),
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _resultSection(ThemeData theme, BenefitGuideResult r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.matched.isNotEmpty) ...[
          Text(context.tr('benefit_matches_title'),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...r.matched.map((b) => _benefitCard(theme, b)),
          const SizedBox(height: 20),
        ],
        if (r.checklist.isNotEmpty) ...[
          Row(children: [
            Text(context.tr('benefit_checklist_title'),
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Icon(Icons.lock_rounded,
                size: 13, color: theme.colorScheme.outline),
            const SizedBox(width: 3),
            Text(context.tr('benefit_local_only'),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ]),
          const SizedBox(height: 8),
          ...r.checklist.map((item) => _checklistTile(theme, item)),
          const SizedBox(height: 20),
        ],
        if (r.nextSteps.isNotEmpty) ...[
          Text(context.tr('benefit_next_steps'),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...List.generate(r.nextSteps.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${i + 1}. ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700, color: _accent)),
                Expanded(
                    child: Text(r.nextSteps[i],
                        style:
                            theme.textTheme.bodyMedium?.copyWith(height: 1.4))),
              ]),
            );
          }),
          const SizedBox(height: 20),
        ],
        if (r.sources.isNotEmpty) ...[
          Text(context.tr('benefit_sources'),
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ...r.sources.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: GestureDetector(
                  onTap: () => _openUrl(s),
                  child: Text('🔗 $s',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          theme.textTheme.labelSmall?.copyWith(color: _accent)),
                ),
              )),
          const SizedBox(height: 20),
        ],
        _disclaimer(theme),
      ],
    );
  }

  Widget _benefitCard(ThemeData theme, GuideBenefit b) {
    final hasAntragshelfer = widget.country.code == 'de' &&
        b.benefitId.isNotEmpty &&
        BenefitApplicationDE.getById(b.benefitId) != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(b.name,
            style: theme.textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        if (b.why.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(b.why, style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
        ],
        if (b.authority.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.account_balance_rounded,
                size: 13, color: theme.colorScheme.outline),
            const SizedBox(width: 4),
            Expanded(
              child: Text(b.authority,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ),
          ]),
        ],
        if (b.url.isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _openUrl(b.url);
            },
            child: Text(context.tr('benefit_check_link'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w700, color: _accent)),
          ),
        ],
        if (hasAntragshelfer) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openAntragshelfer(b.benefitId),
              icon: const Icon(Icons.assignment_turned_in_rounded, size: 16),
              label: Text(context.tr('benefit_start_application')),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF16A34A),
                side: const BorderSide(color: Color(0xFF16A34A)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _checklistTile(ThemeData theme, String item) {
    final checked = _checked.contains(item);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _toggleChecklistItem(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(children: [
          Icon(
            checked
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color:
                checked ? const Color(0xFF16A34A) : theme.colorScheme.outline,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(item,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.3,
                  decoration: checked ? TextDecoration.lineThrough : null,
                  color: checked ? theme.colorScheme.outline : null,
                )),
          ),
        ]),
      ),
    );
  }
}
