import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:parentpeak/logic/family_finance_store.dart';
import 'package:parentpeak/logic/finance_number.dart';
import 'package:parentpeak/logic/finance_milestone_timeline.dart';
import 'package:parentpeak/ui/widgets/family_hub_account_boundary.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:parentpeak/config/country_finance_data.dart';
import 'package:parentpeak/config/benefit_application_de.dart';
import 'package:parentpeak/models/country_finance_config.dart';
import 'package:parentpeak/models/family_profile_model.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/ui/antragshelfer_screen.dart';
import 'package:parentpeak/ui/benefit_guide_screen.dart';
import 'package:parentpeak/main.dart';

/// Familien-Geld — Ruhiger Finanz-Helfer für Eltern.
///
/// 3 Tabs:
/// 1. Schnellcheck — Monatliche Fixkosten-Übersicht
/// 2. Leistungen — Was steht euch zu? (Laender-spezifisch)
/// 3. Meilensteine — Was kommt auf euch zu? (Kind-Alter-basiert)
class FamilienGeldScreen extends StatelessWidget {
  const FamilienGeldScreen({super.key, this.store, this.now});
  final FamilyFinanceStore? store;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) => FamilyHubAccountBoundary(
    builder: (_) => _ScopedFamilienGeldScreen(store: store, now: now),
  );
}

class _ScopedFamilienGeldScreen extends StatefulWidget {
  const _ScopedFamilienGeldScreen({this.store, this.now});
  final FamilyFinanceStore? store;
  final DateTime Function()? now;

  @override
  State<_ScopedFamilienGeldScreen> createState() => _FamilienGeldScreenState();
}

class _FamilienGeldScreenState extends State<_ScopedFamilienGeldScreen>
    with SingleTickerProviderStateMixin {
  DateTime get _now => widget.now?.call() ?? DateTime.now();
  late final TabController _tabs;
  CountryFinanceConfig _country = CountryFinanceData.germany;
  bool _countrySelected = false;
  Map<String, double> _monthlyAmounts = {};
  List<ChildEntry> _children = [];

  // Feature 1: Steuer-Spar
  bool _showTaxDetail = false;

  // Feature 2: Eligibility Quick-Check
  bool _eligibilityDone = false;
  bool _isEmployee = true;
  bool _isSingleParent = false;
  int _incomeLevel = 1; // 0=unter 2.000€, 1=2.000–4.000€, 2=ueber 4.000€
  bool _draftEmployee = true;
  bool _draftSingleParent = false;
  int _draftIncome = 1;

  // Feature 3: Spar-Ziel
  double _monthlySavingsGoal = 0;
  double _totalSaved = 0;

  // Feature 4: Monat ist eng
  bool _showKnappSection = false;

  // Persistente TextField-Controller (verhindert Reset beim setState)
  final Map<String, TextEditingController> _controllers = {};
  late final _store = widget.store ?? FamilyFinanceStore.instance;
  late final String _scope = _store.scope;
  bool _loaded = false;
  bool _loadError = false;
  bool _hasLegacy = false;
  bool _claiming = false;
  int _pendingWrites = 0;
  bool _switchingCountry = false;
  final Map<String, String> _fieldErrors = {};
  final Map<String, int> _fieldRevisions = {};

  TextEditingController _controllerFor(String id, double amount) {
    if (!_controllers.containsKey(id)) {
      _controllers[id] = TextEditingController(
        text: amount > 0 ? _inputAmount(amount) : '',
      );
    }
    return _controllers[id]!;
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadSavedData();
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    try {
      final data = await _store.read(expectedScope: _scope);
      final profile = await FamilyMatchProfile.load(throwOnError: true);
      final hasLegacy = await _store.hasUnassignedLegacy(expectedScope: _scope);
      _store.requireScope(_scope);
      if (!mounted) return;
      final code = data[FamilyFinanceStore.countryKey] as String?;
      final amounts =
          data[FamilyFinanceStore.amountsKey] as Map<String, dynamic>?;
      setState(() {
        _country = code == null
            ? CountryFinanceData.germany
            : CountryFinanceData.getByCode(code);
        _countrySelected = code != null;
        _monthlyAmounts =
            amounts?.map(
              (key, value) => MapEntry(key, (value as num).toDouble()),
            ) ??
            {};
        _children = profile?.children ?? [];
        _eligibilityDone =
            data[FamilyFinanceStore.eligibilityKey] as bool? ?? false;
        _isEmployee = data[FamilyFinanceStore.employeeKey] as bool? ?? true;
        _isSingleParent =
            data[FamilyFinanceStore.singleParentKey] as bool? ?? false;
        _incomeLevel = data[FamilyFinanceStore.incomeKey] as int? ?? 1;
        _draftEmployee = _isEmployee;
        _draftSingleParent = _isSingleParent;
        _draftIncome = _incomeLevel;
        _monthlySavingsGoal =
            (data[FamilyFinanceStore.savingsGoalKey] as num?)?.toDouble() ?? 0;
        _totalSaved =
            (data[FamilyFinanceStore.savedKey] as num?)?.toDouble() ?? 0;
        _hasLegacy = hasLegacy;
        _loaded = true;
        _loadError = false;
      });
    } catch (error) {
      debugPrint('FamilienGeld load: $error');
      if (mounted) {
        setState(() {
          _loadError = true;
          _loaded = true;
        });
      }
    }
  }

  Future<bool> _write(Map<String, dynamic> values, VoidCallback commit,
      {bool mergeAmounts = false}) async {
    setState(() => _pendingWrites++);
    try {
      await _store.write(values, expectedScope: _scope, mergeAmounts: mergeAmounts);
      _store.requireScope(_scope);
      if (!mounted) return false;
      setState(commit);
      return true;
    } catch (error) {
      debugPrint('FamilienGeld write: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('family_hub_save_error'))),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _pendingWrites--);
    }
  }

  Future<void> _selectCountry(String code) async {
    if (_pendingWrites > 0 || _switchingCountry) return;
    setState(() => _switchingCountry = true);
    try {
      final saved = await _write({FamilyFinanceStore.countryKey: code}, () {});
      if (!saved || !mounted) return;
      await _loadSavedData();
      if (!mounted) return;
      _fieldErrors.clear();
      _fieldRevisions.clear();
      for (final entry in _controllers.entries) {
        final amount = entry.key == 'savings_total'
            ? _totalSaved
            : entry.key == 'savings_goal'
            ? _monthlySavingsGoal
            : _monthlyAmounts[entry.key] ?? 0;
        entry.value.text = amount == 0 ? '' : _inputAmount(amount);
      }
    } finally {
      if (mounted) setState(() => _switchingCountry = false);
    }
  }

  static String _inputAmount(double value) => value == value.truncateToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  Future<void> _saveEligibility(bool done) async {
    final employee = _draftEmployee;
    final singleParent = _draftSingleParent;
    final income = _draftIncome;
    await _write(
      {
        FamilyFinanceStore.eligibilityKey: done,
        FamilyFinanceStore.employeeKey: employee,
        FamilyFinanceStore.singleParentKey: singleParent,
        FamilyFinanceStore.incomeKey: income,
      },
      () {
        _eligibilityDone = done;
        _isEmployee = employee;
        _isSingleParent = singleParent;
        _incomeLevel = income;
      },
    );
  }

  Future<void> _saveNumber(String id, String input) async {
    final revision = (_fieldRevisions[id] ?? 0) + 1;
    _fieldRevisions[id] = revision;
    double value;
    try {
      value = FinanceNumber.parse(input);
    } on FormatException {
      setState(() => _fieldErrors[id] = context.tr('finance_number_invalid'));
      return;
    }
    setState(() => _fieldErrors.remove(id));
    final Map<String, dynamic> changes;
    final VoidCallback commit;
    if (id == 'savings_total' || id == 'savings_goal') {
      changes = {
        id == 'savings_total'
                ? FamilyFinanceStore.savedKey
                : FamilyFinanceStore.savingsGoalKey:
            value,
      };
      commit = () {
        if (id == 'savings_total') {
          _totalSaved = value;
        } else {
          _monthlySavingsGoal = value;
        }
      };
    } else {
      changes = {FamilyFinanceStore.amountsKey: {id: value}};
      commit = () => _monthlyAmounts[id] = value;
    }
    final saved = await _write(changes, commit,
      mergeAmounts: id != 'savings_total' && id != 'savings_goal');
    if (!mounted || _fieldRevisions[id] != revision) return;
    if (!saved) {
      setState(() => _fieldErrors[id] = context.tr('family_hub_save_error'));
    }
  }

  Future<void> _claimLegacy() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => FamilyHubAccountModal(
        expectedScope: _scope,
        builder: (ctx) => AlertDialog(
          title: Text(context.tr('finance_legacy_title')),
          content: Text(context.tr('finance_legacy_confirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.tr('family_hub_legacy_claim')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _claiming = true);
    try {
      await _store.claimLegacy(expectedScope: _scope);
      _store.requireScope(_scope);
      if (!mounted) return;
      for (final controller in _controllers.values) {
        controller.clear();
      }
      await _loadSavedData();
      if (!mounted) return;
      for (final entry in _controllers.entries) {
        final amount = entry.key == 'savings_total'
            ? _totalSaved
            : entry.key == 'savings_goal'
            ? _monthlySavingsGoal
            : _monthlyAmounts[entry.key] ?? 0;
        entry.value.text = amount > 0 ? _inputAmount(amount) : '';
      }
    } catch (error) {
      debugPrint('FamilienGeld legacy claim: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('family_hub_legacy_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    var opened = false;
    if (uri != null) {
      try {
        if (await canLaunchUrl(uri)) {
          opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint('FamilienGeld._openUrl: $e');
      }
    }
    // Konnte der Link nicht geöffnet werden, bekommt der Nutzer eine klare
    // Rückmeldung statt stillschweigendem Nichts.
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('finance_link_open_failed')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Feature 5: Übersicht teilen
  Future<void> _shareOverview() async {
    final total = _monthlyAmounts.values.fold(0.0, (a, b) => a + b);
    final sb = StringBuffer();
    sb.writeln(
      context.tr(
        'finance_share_title',
        values: {'flag': _country.flag, 'country': _countryName},
      ),
    );
    sb.writeln('');
    if (total > 0) {
      sb.writeln(
        context.tr(
          'finance_share_monthly_costs',
          values: {'amount': _country.formatAmount(total)},
        ),
      );
      sb.writeln(
        context.tr(
          'finance_share_yearly_costs',
          values: {'amount': _country.formatAmount(total * 12)},
        ),
      );
      sb.writeln('');
    }
    sb.writeln(context.tr('finance_share_possible_benefits'));
    for (final b in _country.benefits) {
      final symbol = b.status == BenefitStatus.universal
          ? '\u2705'
          : b.status == BenefitStatus.incomeDependent
          ? '\u{1F7E0}'
          : '\u{1F535}';
      sb.writeln(
        '$symbol ${_benefitText(b, 'name')}${b.amount != null ? ' \u00B7 ${_benefitText(b, 'amount')}' : ''}',
      );
    }
    if (_children.isNotEmpty) {
      sb.writeln('');
      sb.writeln(context.tr('finance_share_next_milestones'));
      final now = _now;
      for (final child in _children) {
        final upcoming = FinanceMilestoneTimeline.upcoming(
          _country.milestones, child.birthDate, now).take(2);
        for (final estimate in upcoming) {
          final m = estimate.milestone;
          sb.writeln(
            '${m.emoji} ${_milestoneLabel(m)} \u00B7 ~${_country.formatAmount(m.estimatedCost)} (${_estimateTime(estimate)})',
          );
        }
      }
    }
    sb.writeln('');
    sb.writeln(context.tr('finance_share_footer'));
    await Share.share(
      sb.toString(),
      subject: context.tr('finance_share_subject'),
    );
  }

  String get _countryName => context.tr('finance_country_${_country.code}');

  String _categoryLabel(MonthlyCategory category) =>
      context.tr('finance_category_${category.id}');

  String _milestoneLabel(MilestoneCost milestone) =>
      context.tr('finance_milestone_${milestone.id}');

  String _estimateTime(FinanceMilestoneEstimate estimate) => context.tr(
    estimate.monthsLeft == 1 ? 'finance_estimated_one_month' : 'finance_estimated_months',
    values: {'months': estimate.monthsLeft, 'year': estimate.date.year},
  );

  String? _milestoneNote(MilestoneCost milestone) {
    if (milestone.note == null) return null;
    if (_country.code != 'de') return milestone.note;
    return context.tr('finance_milestone_${milestone.id}_note');
  }

  String _benefitText(SocialBenefit benefit, String field) {
    if (_country.code == 'de') {
      final parts = context.tr('finance_benefit_de_${benefit.id}').split('|');
      final index = switch (field) {
        'name' => 0,
        'description' => 1,
        'amount' => 2,
        'eligibility' => 3,
        _ => -1,
      };
      if (index >= 0 && index < parts.length) return parts[index];
    }
    return switch (field) {
      'name' => benefit.name,
      'description' => benefit.description,
      'amount' => benefit.amount ?? '',
      'eligibility' => benefit.eligibility ?? '',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('finance_load_failed')),
              TextButton(
                onPressed: _loadSavedData,
                child: Text(context.tr('family_hub_retry')),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        if (_hasLegacy)
          Material(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(context.tr('finance_legacy_notice')),
                    if (_store.userId != null)
                      TextButton(
                        onPressed: _claiming || _pendingWrites > 0
                            ? null
                            : _claimLegacy,
                        child: Text(context.tr('finance_legacy_title')),
                      ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: AbsorbPointer(
            absorbing: _claiming || _switchingCountry,
            child: _countrySelected
                ? _mainScreen(context)
                : _countrySelector(context),
          ),
        ),
      ],
    );
  }

  // ─── Country Selector (erster Besuch) ─────────────────────────────────────
  Widget _countrySelector(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStringsManager.getString(
            languageService.currentLanguage,
            'familien_geld_title',
          ),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Text('\u{1F30D}', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 16),
              Text(
                AppStringsManager.getString(
                  languageService.currentLanguage,
                  'country_question',
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                AppStringsManager.getString(
                  languageService.currentLanguage,
                  'country_hint',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: CountryFinanceData.availableCountries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final c = CountryFinanceData.availableCountries[i];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          onTap: _pendingWrites > 0
                              ? null
                              : () => _selectCountry(c.code),
                          leading: Text(
                            c.flag,
                            style: const TextStyle(fontSize: 28),
                          ),
                          title: Text(
                            context.tr('finance_country_${c.code}'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '${c.currency} (${c.currencySymbol})',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Main Screen mit 3 Tabs ───────────────────────────────────────────────
  Widget _mainScreen(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_country.flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              AppStringsManager.getString(
                languageService.currentLanguage,
                'familien_geld_title',
              ),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, size: 20),
            tooltip: context.tr('tooltip_share_overview'),
            onPressed: _pendingWrites > 0 || _fieldErrors.isNotEmpty
                ? null
                : _shareOverview,
          ),
          IconButton(
            icon: const Icon(Icons.language_rounded, size: 20),
            tooltip: context.tr('tooltip_change_country'),
            onPressed: _pendingWrites > 0
                ? null
                : () => setState(() => _countrySelected = false),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: context.tr('finance_tab_overview')),
            Tab(text: context.tr('finance_tab_benefits')),
            Tab(text: context.tr('finance_tab_milestones')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _schnellcheckTab(theme),
          _leistungenTab(theme),
          _meilensteineTab(theme),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: SCHNELLCHECK
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _schnellcheckTab(ThemeData theme) {
    final total = _monthlyAmounts.values.fold(0.0, (a, b) => a + b);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Übersichts-Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF16A34A).withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                const Text('\u{1F4B0}', style: TextStyle(fontSize: 28)),
                const SizedBox(height: 8),
                Text(
                  AppStringsManager.getString(
                    languageService.currentLanguage,
                    'monthly_child_costs',
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  total > 0
                      ? context.tr(
                          'finance_amount_per_month',
                          values: {'amount': _country.formatAmount(total)},
                        )
                      : context.tr('finance_not_entered'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: total > 0
                        ? const Color(0xFF16A34A)
                        : theme.colorScheme.outline,
                  ),
                ),
                if (total > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    context.tr(
                      'finance_amount_per_year',
                      values: {'amount': _country.formatAmount(total * 12)},
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppStringsManager.getString(
              languageService.currentLanguage,
              'your_monthly_costs',
            ),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStringsManager.getString(
              languageService.currentLanguage,
              'money_once_hint',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 14),
          // Kategorien
          ..._country.categories.map((cat) => _categoryRow(theme, cat)),
          const SizedBox(height: 20),
          // KI-Tipp
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFF97316).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('\u{1F4A1}', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStringsManager.getString(
                          languageService.currentLanguage,
                          'saving_tip',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFEA580C),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr(
                          _country.code == 'de'
                              ? 'finance_saving_tip_de'
                              : 'finance_saving_tip_generic',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF9A3412),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Feature 1: Steuer-Spar — DE: Kita-Kosten absetzbar (2/3-Regel).
          if (_country.code == 'de') ...[
            const SizedBox(height: 12),
            _buildTaxSavingsHint(theme),
          ],
          // AT: Seit 2019 ersetzt der Familienbonus Plus die frühere
          // Absetzbarkeit der Kinderbetreuungskosten. Daher KEINE Kita-abhängige
          // Rechnung, sondern ein korrekter Hinweis auf den fixen Absetzbetrag.
          if (_country.code == 'at') ...[
            const SizedBox(height: 12),
            _buildFamilienbonusHint(theme),
          ],
          const SizedBox(height: 12),
          // Feature 4: Monat ist eng
          _buildKnappSection(theme),
          const SizedBox(height: 16),
          _disclaimerBox(theme),
        ],
      ),
    );
  }

  Widget _categoryRow(ThemeData theme, MonthlyCategory cat) {
    final amount = _monthlyAmounts[cat.id] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Text(cat.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _categoryLabel(cat),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (cat.typicalAmount != null)
                    Text(
                      context.tr(
                        'finance_average_amount',
                        values: {
                          'amount': _country.formatAmount(cat.typicalAmount!),
                        },
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 90,
              child: TextField(
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: '0',
                  errorText: _fieldErrors[cat.id],
                  suffixText: _country.currencySymbol,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                controller: _controllerFor(cat.id, amount),
                onChanged: (v) async => await _saveNumber(cat.id, v),
                onSubmitted: (v) async => await _saveNumber(cat.id, v),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: LEISTUNGEN (Was steht euch zu?)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _leistungenTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                const Text('\u{1F4CB}', style: TextStyle(fontSize: 28)),
                const SizedBox(height: 8),
                Text(
                  AppStringsManager.getString(
                    languageService.currentLanguage,
                    'what_you_deserve',
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(
                    'finance_benefits_country_intro',
                    values: {'country': _countryName},
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B21A8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // KI-Wegweiser: personalisierte Orientierung zur eigenen Situation
          _benefitGuideCard(theme),
          const SizedBox(height: 16),
          // Feature 2: Eligibility Quick-Check
          _buildEligibilityCheck(theme),
          const SizedBox(height: 16),
          // Leistungen-Liste
          ..._filteredBenefits.map((b) => _benefitCard(theme, b)),
          const SizedBox(height: 16),
          _disclaimerBox(theme),
        ],
      ),
    );
  }

  /// Wiederverwendbarer Hinweis: keine Rechts-/Finanzberatung, nur Orientierung,
  /// Beträge ohne Gewähr. Wird in allen drei Tabs gezeigt, weil überall
  /// konkrete €-Zahlen (Steuer, Spar-Empfehlung, Leistungen) erscheinen.
  Widget _disclaimerBox(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('\u{26A0}\u{FE0F}', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('finance_legal_disclaimer'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF92400E),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('finance_amounts_disclaimer'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF92400E),
                    height: 1.3,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Einstieg in den KI-Leistungs-Wegweiser (personalisierte Orientierung).
  Widget _benefitGuideCard(ThemeData theme) {
    final borderRadius = BorderRadius.circular(18);
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BenefitGuideScreen(
              country: _country,
              isSingleParent: _isSingleParent,
              now: widget.now,
            ),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('\u{2728}', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('finance_guide_title'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('finance_guide_subtitle'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _benefitCard(ThemeData theme, SocialBenefit b) {
    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    switch (b.status) {
      case BenefitStatus.universal:
        statusColor = const Color(0xFF16A34A);
        statusLabel = context.tr('finance_status_universal');
        statusIcon = Icons.check_circle_rounded;
        break;
      case BenefitStatus.incomeDependent:
        statusColor = const Color(0xFFF97316);
        statusLabel = context.tr('finance_status_income_dependent');
        statusIcon = Icons.info_rounded;
        break;
      case BenefitStatus.checkRequired:
        statusColor = const Color(0xFF2563EB);
        statusLabel = context.tr('finance_status_check_required');
        statusIcon = Icons.help_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _benefitText(b, 'name'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 3),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _benefitText(b, 'description'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
          if (b.amount != null) ...[
            const SizedBox(height: 6),
            Text(
              '\u{1F4B0} ${_benefitText(b, 'amount')}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF16A34A),
              ),
            ),
          ],
          if (b.eligibility != null) ...[
            const SizedBox(height: 4),
            Text(
              '\u{1F464} ${_benefitText(b, 'eligibility')}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
          if (b.url != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.lightImpact();
                _openUrl(b.url!);
              },
              child: Text(
                AppStringsManager.getString(
                  languageService.currentLanguage,
                  'common_check_here',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ),
          ],
          // Antragshelfer Button (nur für DE mit vorhandenen Daten)
          if (_country.code == 'de' &&
              BenefitApplicationDE.getById(b.id) != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  final appData = BenefitApplicationDE.getById(b.id)!;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AntragshelferScreen(benefit: appData),
                    ),
                  );
                },
                icon: const Icon(Icons.assignment_turned_in_rounded, size: 16),
                label: Text(context.tr('finance_start_application_helper')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF16A34A),
                  side: const BorderSide(color: Color(0xFF16A34A)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 3: MEILENSTEINE (Was kommt auf euch zu?)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _meilensteineTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFF97316).withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                const Text('\u{1F3AF}', style: TextStyle(fontSize: 28)),
                const SizedBox(height: 8),
                Text(
                  AppStringsManager.getString(
                    languageService.currentLanguage,
                    'whats_coming',
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _children.isEmpty
                      ? context.tr('finance_create_profile_for_milestones')
                      : context.tr('finance_based_on_children_age'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF9A3412),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Feature 3: Spar-Ziel für nächsten Meilenstein
          _buildSavingsGoal(theme),
          const SizedBox(height: 16),
          // Meilensteine pro Kind
          if (_children.isNotEmpty)
            ..._children.map((child) => _childMilestones(theme, child))
          else
            ...FinanceMilestoneTimeline.sorted(_country.milestones)
                .map((m) => _milestoneCard(theme, m, null)),
          // Spar-Empfehlung
          if (_children.isNotEmpty) ...[
            const SizedBox(height: 16),
            _savingRecommendation(theme),
          ],
          const SizedBox(height: 16),
          _disclaimerBox(theme),
        ],
      ),
    );
  }

  Widget _childMilestones(ThemeData theme, ChildEntry child) {
    final now = _now;
    final upcoming = FinanceMilestoneTimeline.upcoming(
      _country.milestones, child.birthDate, now);

    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 6),
          child: Text(
            '\u{1F476} ${child.name.isNotEmpty ? child.name : context.tr('child_label')} (${child.ageDisplay})',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        ...upcoming.take(4).map((estimate) =>
            _milestoneCard(theme, estimate.milestone, estimate)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _milestoneCard(ThemeData theme, MilestoneCost m,
      FinanceMilestoneEstimate? estimate) {

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(m.emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _milestoneLabel(m),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_milestoneNote(m) case final note?)
                  Text(
                    note,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                if (estimate != null)
                  Text(
                    _estimateTime(estimate),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF8B5CF6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '~${_country.formatAmount(m.estimatedCost)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFF97316),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _savingRecommendation(ThemeData theme) {
    // Berechne Gesamtkosten der naechsten 5 Jahre
    final now = _now;
    double totalUpcoming = 0;
    for (final child in _children) {
      for (final estimate in FinanceMilestoneTimeline.withinFiveYears(
        _country.milestones, child.birthDate, now)) {
        totalUpcoming += estimate.milestone.estimatedCost;
      }
    }

    if (totalUpcoming == 0) return const SizedBox.shrink();

    final monthlyTarget = (totalUpcoming / 60)
        .ceilToDouble(); // 5 Jahre = 60 Monate

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF16A34A).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('\u{1F4A1}', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStringsManager.getString(
                    languageService.currentLanguage,
                    'saving_recommendation',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(
                    'finance_five_year_recommendation',
                    values: {
                      'total': _country.formatAmount(totalUpcoming),
                      'monthly': _country.formatAmount(monthlyTarget),
                    },
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF166534),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE 1: Steuer-Spar-Berechnung
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTaxSavingsHint(ThemeData theme) {
    final kitaMonthly = _monthlyAmounts['kita'] ?? 0;
    if (kitaMonthly == 0) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const Text('\u{1F4B0}', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _country.code == 'de'
                    ? context.tr('finance_enter_childcare_de')
                    : context.tr('finance_enter_childcare_generic'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // DE: Kinderbetreuungskosten sind zu 2/3 absetzbar, max. 4.000 €/Jahr/Kind
    // als Sonderausgabe. Nur für Deutschland aufgerufen.
    const double deductibleMax = 4000.0;
    final kitaAnnual = kitaMonthly * 12;
    final double deductiblePart = kitaAnnual * 2 / 3;
    final double deductible = deductiblePart.clamp(0, deductibleMax);
    final estimatedSavings = deductible * 0.30; // ~30% Grenzsteuersatz

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _showTaxDetail = !_showTaxDetail),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('\u{1F4B0}', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('finance_tax_saving_potential'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF065F46),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr(
                          'finance_tax_saving_summary',
                          values: {
                            'deductible': _country.formatAmount(deductible),
                            'savings': _country.formatAmount(estimatedSavings),
                          },
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF065F46),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _showTaxDetail
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: const Color(0xFF10B981),
                  size: 20,
                ),
              ],
            ),
            if (_showTaxDetail) ...[
              const SizedBox(height: 10),
              const Divider(color: Color(0xFF10B981), height: 1),
              const SizedBox(height: 10),
              _taxDetailRow(
                theme,
                context.tr('finance_tax_childcare_year'),
                _country.formatAmount(kitaAnnual),
              ),
              _taxDetailRow(
                theme,
                context.tr('finance_tax_deductible_share'),
                _country.formatAmount(deductiblePart),
              ),
              _taxDetailRow(
                theme,
                context.tr('finance_tax_max_expense'),
                _country.formatAmount(deductibleMax),
              ),
              _taxDetailRow(
                theme,
                context.tr('finance_tax_actual_deductible'),
                _country.formatAmount(deductible),
              ),
              _taxDetailRow(
                theme,
                context.tr('finance_tax_estimated_saving'),
                _country.formatAmount(estimatedSavings),
                highlight: true,
              ),
              const SizedBox(height: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openUrl(
                  'https://www.bundesfinanzministerium.de/Web/DE/Themen/Steuern/Steuerarten/Einkommensteuer/einkommensteuer.html',
                ),
                child: Text(
                  context.tr('finance_tax_more_info'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF059669),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// AT: Hinweis auf den Familienbonus Plus (fixer Steuerabsetzbetrag pro Kind).
  /// Bewusst OHNE Kita-abhängige Rechnung — die frühere Absetzbarkeit der
  /// Kinderbetreuungskosten gibt es seit 2019 nicht mehr.
  Widget _buildFamilienbonusHint(ThemeData theme) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openUrl(
        'https://www.oesterreich.gv.at/de/landingpages/familienbonusplus',
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('\u{1F4B0}', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('finance_familienbonus_title'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF065F46),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr('finance_familienbonus_body'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF065F46),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('finance_tax_more_info'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF059669),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _taxDetailRow(
    ThemeData theme,
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFF065F46),
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              color: highlight
                  ? const Color(0xFF047857)
                  : const Color(0xFF065F46),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE 2: Eligibility Quick-Check
  // ═══════════════════════════════════════════════════════════════════════════
  List<SocialBenefit> get _filteredBenefits {
    if (!_eligibilityDone) return _country.benefits;
    return _country.benefits.where((b) {
      if (b.status == BenefitStatus.universal) return true;
      if (b.status == BenefitStatus.incomeDependent) return _incomeLevel <= 1;
      // checkRequired: unterhaltsvorschuss nur für Alleinerziehende
      if (b.id == 'unterhaltsvorschuss') return _isSingleParent;
      return true;
    }).toList();
  }

  Widget _buildEligibilityCheck(ThemeData theme) {
    if (_eligibilityDone) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Text('\u{2705}', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr('finance_benefits_filtered'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5B21B6),
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _pendingWrites > 0 ? null : () => _saveEligibility(false),
              child: Text(
                AppStringsManager.getString(
                  languageService.currentLanguage,
                  'change_action',
                ),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF7C3AED),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('\u{1F50D}', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                AppStringsManager.getString(
                  languageService.currentLanguage,
                  'quick_check',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4C1D95),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Frage 1: Berufstaetigkeit
          Text(
            AppStringsManager.getString(
              languageService.currentLanguage,
              'employed_question',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              _eligChip(
                theme,
                context.tr('yes_answer'),
                _draftEmployee,
                () => setState(() => _draftEmployee = true),
              ),
              _eligChip(
                theme,
                context.tr('finance_no_parental_leave'),
                !_draftEmployee,
                () => setState(() => _draftEmployee = false),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Frage 2: Alleinerziehend
          Text(
            AppStringsManager.getString(
              languageService.currentLanguage,
              'single_parent',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              _eligChip(
                theme,
                context.tr('yes_answer'),
                _draftSingleParent,
                () => setState(() => _draftSingleParent = true),
              ),
              _eligChip(
                theme,
                context.tr('no_answer'),
                !_draftSingleParent,
                () => setState(() => _draftSingleParent = false),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Frage 3: Einkommen
          Text(
            AppStringsManager.getString(
              languageService.currentLanguage,
              'net_income',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              _eligChip(
                theme,
                context.tr('finance_income_low'),
                _draftIncome == 0,
                () => setState(() => _draftIncome = 0),
              ),
              _eligChip(
                theme,
                context.tr('finance_income_medium'),
                _draftIncome == 1,
                () => setState(() => _draftIncome = 1),
              ),
              _eligChip(
                theme,
                context.tr('finance_income_high'),
                _draftIncome == 2,
                () => setState(() => _draftIncome = 2),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
              ),
              onPressed: _pendingWrites > 0
                  ? null
                  : () => _saveEligibility(true),
              child: Text(
                AppStringsManager.getString(
                  languageService.currentLanguage,
                  'filter_benefits',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _eligChip(
    ThemeData theme,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _pendingWrites > 0 ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF7C3AED)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF7C3AED)
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: selected ? Colors.white : theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE 3: Spar-Ziel für naechsten Meilenstein
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSavingsGoal(ThemeData theme) {
    // Naechsten Meilenstein finden
    MilestoneCost? nextMilestone;
    FinanceMilestoneEstimate? nextEstimate;
    final now = _now;
    if (_children.isNotEmpty) {
      for (final child in _children) {
        for (final estimate in FinanceMilestoneTimeline.upcoming(
          _country.milestones, child.birthDate, now)) {
          if (nextEstimate == null || estimate.date.isBefore(nextEstimate.date)) {
            nextEstimate = estimate;
            nextMilestone = estimate.milestone;
          }
        }
      }
    } else {
      // Ohne Kinderprofil: erstes Meilenstein zeigen
      if (_country.milestones.isNotEmpty) {
        nextMilestone = FinanceMilestoneTimeline.sorted(_country.milestones).first;
      }
    }

    if (nextMilestone == null) return const SizedBox.shrink();

    final target = nextMilestone.estimatedCost;
    final monthsLeft = nextEstimate?.monthsLeft ?? nextMilestone.childAgeYears * 12;
    final needed = (target - _totalSaved).clamp(0, target);
    final autoGoal = monthsLeft > 0 ? (needed / monthsLeft) : 0.0;
    final progress = (_totalSaved / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF97316).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(nextMilestone.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.tr('saving_goal')} ${_milestoneLabel(nextMilestone)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFEA580C),
                      ),
                    ),
                    Text(
                      nextEstimate == null
                          ? '~${_country.formatAmount(target)}'
                          : '${_estimateTime(nextEstimate)} · ~${_country.formatAmount(target)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF9A3412),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Fortschrittsbalken
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFFFD7B0),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFF97316),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${context.tr('saved_amount')} ${_country.formatAmount(_totalSaved)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF9A3412),
                ),
              ),
              Text(
                '${context.tr('goal_amount')} ${_country.formatAmount(target)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF9A3412),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Eingabe: aktuell gespart
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: context.tr('finance_saved_so_far'),
                    errorText: _fieldErrors['savings_total'],
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  controller: _controllerFor('savings_total', _totalSaved),
                  onChanged: (v) async => await _saveNumber('savings_total', v),
                  onSubmitted: (v) async => await _saveNumber('savings_total', v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: context.tr('finance_savings_rate_month'),
                    errorText: _fieldErrors['savings_goal'],
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  controller: _controllerFor(
                    'savings_goal',
                    _monthlySavingsGoal,
                  ),
                  onChanged: (v) async => await _saveNumber('savings_goal', v),
                  onSubmitted: (v) async => await _saveNumber('savings_goal', v),
                ),
              ),
            ],
          ),
          if (_monthlySavingsGoal > 0 && monthsLeft > 0) ...[
            const SizedBox(height: 8),
            Text(
              context.tr(
                _monthlySavingsGoal >= autoGoal
                    ? 'finance_goal_months_on_time'
                    : 'finance_goal_months_shortfall',
                values: {
                  'amount': _country.formatAmount(_monthlySavingsGoal),
                  'months': monthsLeft,
                },
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF9A3412),
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else if (autoGoal > 0) ...[
            const SizedBox(height: 8),
            Text(
              context.tr(
                'finance_monthly_recommendation',
                values: {'amount': _country.formatAmount(autoGoal)},
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF9A3412),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE 4: Monat ist eng
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildKnappSection(ThemeData theme) {
    final resources = _country.code == 'de'
        ? [
            ('finance_support_de_food', 'https://www.tafel.de/suche'),
            (
              'finance_support_de_education',
              'https://familienportal.de/familienportal/familienleistungen/bildung-und-teilhabe',
            ),
            (
              'finance_support_de_debt',
              'https://www.verbraucherzentrale.de/beratung',
            ),
            (
              'finance_support_de_clothing',
              'https://www.caritas.de/hilfeundberatung/onlineberatung/',
            ),
          ]
        : _country.code == 'at'
        ? [
            ('finance_support_at_food', 'https://www.wienertafel.at/'),
            ('finance_support_debt', 'https://www.schuldnerberatung.at/'),
            (
              'finance_support_caritas',
              'https://www.caritas.at/hilfe-beratung',
            ),
          ]
        : [
            ('finance_support_food_bank', 'https://eurofoodbank.org/'),
            (
              'finance_support_family_advice',
              'https://www.unicef.org/parenting/',
            ),
          ];

    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _showKnappSection = !_showKnappSection),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _showKnappSection
                  ? const Color(0xFFFEF2F2)
                  : theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _showKnappSection
                    ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Text('\u{1F91D}', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppStringsManager.getString(
                      languageService.currentLanguage,
                      'month_tight',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _showKnappSection
                          ? const Color(0xFFB91C1C)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  _showKnappSection
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_showKnappSection) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    'finance_free_support_in',
                    values: {'country': _countryName},
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 10),
                ...resources.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openUrl(r.$2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.link_rounded,
                            size: 14,
                            color: Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              context.tr(r.$1),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFDC2626),
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
