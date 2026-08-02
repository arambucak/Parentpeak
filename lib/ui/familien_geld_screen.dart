import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:parentpeak/config/country_finance_data.dart';
import 'package:parentpeak/models/country_finance_config.dart';
import 'package:parentpeak/models/family_profile_model.dart';

/// Familien-Geld — Ruhiger Finanz-Helfer fuer Eltern.
///
/// 3 Tabs:
/// 1. Schnellcheck — Monatliche Fixkosten-Uebersicht
/// 2. Leistungen — Was steht euch zu? (Laender-spezifisch)
/// 3. Meilensteine — Was kommt auf euch zu? (Kind-Alter-basiert)
class FamilienGeldScreen extends StatefulWidget {
  const FamilienGeldScreen({super.key});

  @override
  State<FamilienGeldScreen> createState() => _FamilienGeldScreenState();
}

class _FamilienGeldScreenState extends State<FamilienGeldScreen>
    with SingleTickerProviderStateMixin {
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

  // Feature 3: Spar-Ziel
  double _monthlySavingsGoal = 0;
  double _totalSaved = 0;

  // Feature 4: Monat ist eng
  bool _showKnappSection = false;

  // Persistente TextField-Controller (verhindert Reset beim setState)
  final Map<String, TextEditingController> _controllers = {};

  TextEditingController _controllerFor(String id, double amount) {
    if (!_controllers.containsKey(id)) {
      _controllers[id] =
          TextEditingController(text: amount > 0 ? amount.toStringAsFixed(0) : '');
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
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('famgeld.country');
    if (code != null) {
      _country = CountryFinanceData.getByCode(code);
      _countrySelected = true;
    }
    final amountsRaw = prefs.getString('famgeld.amounts');
    if (amountsRaw != null) {
      _monthlyAmounts = Map<String, double>.from((jsonDecode(amountsRaw) as Map)
          .map((k, v) => MapEntry(k, (v as num).toDouble())));
    }
    // Kinder aus Profil laden
    final profile = await FamilyMatchProfile.load();
    if (profile != null) _children = profile.children;

    // Feature 2: Eligibility Quick-Check
    _eligibilityDone = prefs.getBool('famgeld.eligibility_done') ?? false;
    _isEmployee = prefs.getBool('famgeld.is_employee') ?? true;
    _isSingleParent = prefs.getBool('famgeld.is_single_parent') ?? false;
    _incomeLevel = prefs.getInt('famgeld.income_level') ?? 1;

    // Feature 3: Spar-Ziel
    _monthlySavingsGoal = prefs.getDouble('famgeld.monthly_savings_goal') ?? 0;
    _totalSaved = prefs.getDouble('famgeld.total_saved') ?? 0;

    if (mounted) setState(() {});
  }

  Future<void> _saveCountry(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('famgeld.country', code);
  }

  Future<void> _saveAmounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('famgeld.amounts', jsonEncode(_monthlyAmounts));
  }

  Future<void> _saveEligibility() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('famgeld.eligibility_done', _eligibilityDone);
    await prefs.setBool('famgeld.is_employee', _isEmployee);
    await prefs.setBool('famgeld.is_single_parent', _isSingleParent);
    await prefs.setInt('famgeld.income_level', _incomeLevel);
  }

  Future<void> _saveSavingsGoal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('famgeld.monthly_savings_goal', _monthlySavingsGoal);
    await prefs.setDouble('famgeld.total_saved', _totalSaved);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Feature 5: Uebersicht teilen
  Future<void> _shareOverview() async {
    final total = _monthlyAmounts.values.fold(0.0, (a, b) => a + b);
    final sb = StringBuffer();
    sb.writeln('${_country.flag} Familien-Geld Uebersicht \u2013 ${_country.name}');
    sb.writeln('');
    if (total > 0) {
      sb.writeln('\u{1F4B0} Monatliche Kinderkosten: ~${_country.formatAmount(total)}/Monat');
      sb.writeln('   ${_country.formatAmount(total * 12)}/Jahr');
      sb.writeln('');
    }
    sb.writeln('\u{1F4CB} Moegliche Leistungen:');
    for (final b in _country.benefits) {
      final symbol = b.status == BenefitStatus.universal
          ? '\u2705'
          : b.status == BenefitStatus.incomeDependent
              ? '\u{1F7E0}'
              : '\u{1F535}';
      sb.writeln('$symbol ${b.name}${b.amount != null ? ' \u00B7 ${b.amount}' : ''}');
    }
    if (_children.isNotEmpty) {
      sb.writeln('');
      sb.writeln('\u{1F3AF} Naechste Meilensteine:');
      for (final child in _children) {
        final ageYears = (child.ageMonths / 12).round();
        final upcoming =
            _country.milestones.where((m) => m.childAgeYears > ageYears).take(2);
        for (final m in upcoming) {
          final years = m.childAgeYears - ageYears;
          sb.writeln(
              '${m.emoji} ${m.label} \u00B7 ~${_country.formatAmount(m.estimatedCost)} (in $years J.)');
        }
      }
    }
    sb.writeln('');
    sb.writeln('\u{1F4F1} Erstellt mit ParentPeak \u2013 Dein Eltern-Begleiter');
    await Share.share(sb.toString(), subject: 'Familien-Geld Uebersicht');
  }

  @override
  Widget build(BuildContext context) {
    if (!_countrySelected) return _countrySelector(context);
    return _mainScreen(context);
  }

  // ─── Country Selector (erster Besuch) ─────────────────────────────────────
  Widget _countrySelector(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Familien-Geld'), elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            const SizedBox(height: 20),
            const Text('\u{1F30D}', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 16),
            Text('In welchem Land lebt eure Familie?',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('Wir zeigen euch passende Leistungen und Kosten.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
                textAlign: TextAlign.center),
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
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.4)),
                  ),
                  child: ListTile(
                    onTap: () {
                      setState(() {
                        _country = c;
                        _countrySelected = true;
                      });
                      _saveCountry(c.code);
                    },
                    leading: Text(c.flag, style: const TextStyle(fontSize: 28)),
                    title: Text(c.name,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    subtitle: Text('${c.currency} (${c.currencySymbol})',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                    trailing:
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                );
              },
            )),
          ]),
        ),
      ),
    );
  }

  // ─── Main Screen mit 3 Tabs ───────────────────────────────────────────────
  Widget _mainScreen(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_country.flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          const Text('Familien-Geld'),
        ]),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, size: 20),
            tooltip: 'Uebersicht teilen',
            onPressed: _shareOverview,
          ),
          IconButton(
            icon: const Icon(Icons.language_rounded, size: 20),
            tooltip: 'Land aendern',
            onPressed: () => setState(() => _countrySelected = false),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Ueberblick'),
            Tab(text: 'Leistungen'),
            Tab(text: 'Meilensteine'),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Uebersichts-Card
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
                color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Text('\u{1F4B0}', style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text('Monatliche Kinderkosten',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              total > 0
                  ? '~${_country.formatAmount(total)}/Monat'
                  : 'Noch nicht eingetragen',
              style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: total > 0
                      ? const Color(0xFF16A34A)
                      : theme.colorScheme.outline),
            ),
            if (total > 0) ...[
              const SizedBox(height: 6),
              Text('${_country.formatAmount(total * 12)}/Jahr',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
          ]),
        ),
        const SizedBox(height: 20),
        Text('Eure monatlichen Kosten',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Einmal eintragen — keine taegliche Eingabe noetig.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline)),
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
                color: const Color(0xFFF97316).withValues(alpha: 0.2)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('\u{1F4A1}', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Spar-Tipp',
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFEA580C))),
                  const SizedBox(height: 2),
                  Text(
                    _country.code == 'de'
                        ? 'Kita-Gebuehren sind steuerlich absetzbar — bis zu 4.000\u{20AC}/Jahr pro Kind als Sonderausgabe.'
                        : 'Pruefe ob Kinderbetreuungskosten in deinem Land steuerlich absetzbar sind.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: const Color(0xFF9A3412), height: 1.3),
                  ),
                ])),
          ]),
        ),
        // Feature 1: Steuer-Spar-Berechnung (DE + AT)
        if (_country.code == 'de' || _country.code == 'at') ...[
          const SizedBox(height: 12),
          _buildTaxSavingsHint(theme),
        ],
        const SizedBox(height: 12),
        // Feature 4: Monat ist eng
        _buildKnappSection(theme),
      ]),
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
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Text(cat.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(cat.label,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (cat.typicalAmount != null)
                  Text(
                      'Durchschnitt: ~${_country.formatAmount(cat.typicalAmount!)}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline)),
              ])),
          SizedBox(
            width: 90,
            child: TextField(
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: '0',
                suffixText: _country.currencySymbol,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              controller: _controllerFor(cat.id, amount),
              onChanged: (v) {
                _monthlyAmounts[cat.id] = double.tryParse(v) ?? 0;
                _saveAmounts();
                setState(() {});
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: LEISTUNGEN (Was steht euch zu?)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _leistungenTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            const Text('\u{1F4CB}', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text('Was steht euch zu?',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Diese Leistungen koennten fuer euch in ${_country.name} relevant sein.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: const Color(0xFF6B21A8)),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
        const SizedBox(height: 16),
        // Feature 2: Eligibility Quick-Check
        _buildEligibilityCheck(theme),
        const SizedBox(height: 16),
        // Leistungen-Liste
        ..._filteredBenefits.map((b) => _benefitCard(theme, b)),
        const SizedBox(height: 16),
        // Disclaimer
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('\u{26A0}\u{FE0F}', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
              'Dies ist keine Rechtsberatung. Bitte pruefe deine Ansprueche beim zustaendigen Amt oder einer Beratungsstelle.',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: const Color(0xFF92400E), height: 1.3),
            )),
          ]),
        ),
      ]),
    );
  }

  Widget _benefitCard(ThemeData theme, SocialBenefit b) {
    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    switch (b.status) {
      case BenefitStatus.universal:
        statusColor = const Color(0xFF16A34A);
        statusLabel = 'Fuer alle';
        statusIcon = Icons.check_circle_rounded;
        break;
      case BenefitStatus.incomeDependent:
        statusColor = const Color(0xFFF97316);
        statusLabel = 'Einkommensabhaengig';
        statusIcon = Icons.info_rounded;
        break;
      case BenefitStatus.checkRequired:
        statusColor = const Color(0xFF2563EB);
        statusLabel = 'Pruefung noetig';
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
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(b.name,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(statusIcon, size: 12, color: statusColor),
              const SizedBox(width: 3),
              Text(statusLabel,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: statusColor)),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
        Text(b.description,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, height: 1.3)),
        if (b.amount != null) ...[
          const SizedBox(height: 6),
          Text('\u{1F4B0} ${b.amount}',
              style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700, color: const Color(0xFF16A34A))),
        ],
        if (b.eligibility != null) ...[
          const SizedBox(height: 4),
          Text('\u{1F464} ${b.eligibility}',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ],
        if (b.url != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _openUrl(b.url!);
            },
            child: Text('\u{1F517} Hier pruefen \u{2192}',
                style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8B5CF6))),
          ),
        ],
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 3: MEILENSTEINE (Was kommt auf euch zu?)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _meilensteineTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                color: const Color(0xFFF97316).withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            const Text('\u{1F3AF}', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text('Was kommt auf euch zu?',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              _children.isEmpty
                  ? 'Erstelle ein Profil im Eltern-Netzwerk um personalisierte Meilensteine zu sehen.'
                  : 'Basierend auf dem Alter eurer Kinder:',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: const Color(0xFF9A3412)),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
        const SizedBox(height: 16),
        // Feature 3: Spar-Ziel fuer naechsten Meilenstein
        _buildSavingsGoal(theme),
        const SizedBox(height: 16),
        // Meilensteine pro Kind
        if (_children.isNotEmpty)
          ..._children.map((child) => _childMilestones(theme, child))
        else
          ..._country.milestones.map((m) => _milestoneCard(theme, m, null)),
        // Spar-Empfehlung
        if (_children.isNotEmpty) ...[
          const SizedBox(height: 16),
          _savingRecommendation(theme),
        ],
      ]),
    );
  }

  Widget _childMilestones(ThemeData theme, ChildEntry child) {
    final ageYears = (child.ageMonths / 12).round();
    final upcoming =
        _country.milestones.where((m) => m.childAgeYears > ageYears).toList();

    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 6),
        child: Text(
          '\u{1F476} ${child.name.isNotEmpty ? child.name : "Kind"} (${child.ageDisplay})',
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      ...upcoming.take(4).map((m) => _milestoneCard(theme, m, ageYears)),
      const SizedBox(height: 12),
    ]);
  }

  Widget _milestoneCard(ThemeData theme, MilestoneCost m, int? currentAge) {
    final yearsUntil = currentAge != null ? m.childAgeYears - currentAge : null;
    final year = yearsUntil != null ? DateTime.now().year + yearsUntil : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF97316).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
              child: Text(m.emoji, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m.label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          if (m.note != null)
            Text(m.note!,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          if (year != null)
            Text(
                yearsUntil == 1
                    ? 'Naechstes Jahr ($year)'
                    : 'In $yearsUntil Jahren ($year)',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF8B5CF6),
                    fontWeight: FontWeight.w600)),
        ])),
        Column(children: [
          Text('~${_country.formatAmount(m.estimatedCost)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800, color: const Color(0xFFF97316))),
        ]),
      ]),
    );
  }

  Widget _savingRecommendation(ThemeData theme) {
    // Berechne Gesamtkosten der naechsten 5 Jahre
    final now = DateTime.now().year;
    double totalUpcoming = 0;
    for (final child in _children) {
      final ageYears = (child.ageMonths / 12).round();
      for (final m in _country.milestones) {
        final eventYear = now + (m.childAgeYears - ageYears);
        if (eventYear > now && eventYear <= now + 5) {
          totalUpcoming += m.estimatedCost;
        }
      }
    }

    if (totalUpcoming == 0) return const SizedBox.shrink();

    final monthlyTarget =
        (totalUpcoming / 60).ceilToDouble(); // 5 Jahre = 60 Monate

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('\u{1F4A1}', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Spar-Empfehlung',
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700, color: const Color(0xFF16A34A))),
          const SizedBox(height: 4),
          Text(
            'In den naechsten 5 Jahren kommen ca. ${_country.formatAmount(totalUpcoming)} auf euch zu. '
            'Mit ~${_country.formatAmount(monthlyTarget)}/Monat seid ihr vorbereitet.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: const Color(0xFF166534), height: 1.4),
          ),
        ])),
      ]),
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
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Text('\u{1F4B0}', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _country.code == 'de'
                  ? 'Trag deine Kita-Kosten oben ein \u2013 dann berechne ich deine Steuerersparnis.'
                  : 'Trag deine Kinderbetreuungskosten ein \u2013 dann zeige ich die Absetzbarkeit.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ]),
      );
    }

    final double deductibleMax = _country.code == 'de' ? 4000.0 : 2300.0;
    final kitaAnnual = kitaMonthly * 12;
    final double deductiblePart = _country.code == 'de' ? kitaAnnual * 2 / 3 : kitaAnnual;
    final double deductible = deductiblePart.clamp(0, deductibleMax);
    final estimatedSavings = deductible * 0.30; // ~30% Grenzsteuersatz

    return GestureDetector(
      onTap: () => setState(() => _showTaxDetail = !_showTaxDetail),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('\u{1F4B0}', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'Steuer-Spar-Potenzial',
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700, color: const Color(0xFF065F46)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Bis zu ${_country.formatAmount(deductible)} absetzbar \u2192 ca. ${_country.formatAmount(estimatedSavings)} Steuerersparnis/Jahr',
                  style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF065F46), height: 1.3),
                ),
              ]),
            ),
            Icon(
              _showTaxDetail ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              color: const Color(0xFF10B981),
              size: 20,
            ),
          ]),
          if (_showTaxDetail) ...[
            const SizedBox(height: 10),
            const Divider(color: Color(0xFF10B981), height: 1),
            const SizedBox(height: 10),
            _taxDetailRow(theme, 'Kita-Kosten/Jahr', _country.formatAmount(kitaAnnual)),
            if (_country.code == 'de')
              _taxDetailRow(theme, 'Davon absetzbar (2/3)', _country.formatAmount(deductiblePart)),
            _taxDetailRow(theme, 'Max. Sonderausgabe', _country.formatAmount(deductibleMax)),
            _taxDetailRow(theme, 'Tats\u00e4chlich absetzbar', _country.formatAmount(deductible)),
            _taxDetailRow(theme, 'Gesch\u00e4tzte Ersparnis (30%)', _country.formatAmount(estimatedSavings), highlight: true),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _openUrl(
                _country.code == 'de'
                    ? 'https://www.bundesfinanzministerium.de/Web/DE/Themen/Steuern/Steuerarten/Einkommensteuer/einkommensteuer.html'
                    : 'https://www.bmf.gv.at/themen/steuern/privatpersonen/kinderbetreuungskosten.html',
              ),
              child: Text(
                '\u{1F517} Mehr Infos beim Finanzamt \u2192',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF059669), fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _taxDetailRow(ThemeData theme, String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: theme.textTheme.labelSmall?.copyWith(color: const Color(0xFF065F46))),
        ),
        Text(
          value,
          style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              color: highlight ? const Color(0xFF047857) : const Color(0xFF065F46)),
        ),
      ]),
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
      // checkRequired: unterhaltsvorschuss nur fuer Alleinerziehende
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
          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Text('\u{2705}', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Leistungen gefiltert basierend auf eurer Situation.',
              style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF5B21B6)),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _eligibilityDone = false;
              _saveEligibility();
            }),
            child: Text('Aendern',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF7C3AED), fontWeight: FontWeight.w700)),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('\u{1F50D}', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text('Schnell-Pruefung: Was passt zu euch?',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF4C1D95))),
        ]),
        const SizedBox(height: 12),
        // Frage 1: Berufstaetigkeit
        Text('Bist du berufstaetig?',
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          _eligChip(theme, 'Ja', _isEmployee, () => setState(() => _isEmployee = true)),
          _eligChip(theme, 'Nein / Elternzeit', !_isEmployee, () => setState(() => _isEmployee = false)),
        ]),
        const SizedBox(height: 10),
        // Frage 2: Alleinerziehend
        Text('Alleinerziehend?',
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          _eligChip(theme, 'Ja', _isSingleParent, () => setState(() => _isSingleParent = true)),
          _eligChip(theme, 'Nein', !_isSingleParent, () => setState(() => _isSingleParent = false)),
        ]),
        const SizedBox(height: 10),
        // Frage 3: Einkommen
        Text('Haushaltsnetto/Monat (ca.)?',
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          _eligChip(theme, 'Unter 2.000\u20ac', _incomeLevel == 0, () => setState(() => _incomeLevel = 0)),
          _eligChip(theme, '2.000\u20134.000\u20ac', _incomeLevel == 1, () => setState(() => _incomeLevel = 1)),
          _eligChip(theme, '\u00dcber 4.000\u20ac', _incomeLevel == 2, () => setState(() => _incomeLevel = 2)),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
            onPressed: () {
              setState(() => _eligibilityDone = true);
              _saveEligibility();
            },
            child: const Text('Leistungen filtern'),
          ),
        ),
      ]),
    );
  }

  Widget _eligChip(ThemeData theme, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7C3AED) : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? const Color(0xFF7C3AED) : theme.colorScheme.outlineVariant),
        ),
        child: Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
                color: selected ? Colors.white : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE 3: Spar-Ziel fuer naechsten Meilenstein
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSavingsGoal(ThemeData theme) {
    // Naechsten Meilenstein finden
    MilestoneCost? nextMilestone;
    int? yearsLeft;
    if (_children.isNotEmpty) {
      for (final child in _children) {
        final ageYears = (child.ageMonths / 12).floor();
        for (final m in _country.milestones) {
          if (m.childAgeYears > ageYears) {
            final yrs = m.childAgeYears - ageYears;
            if (yearsLeft == null || yrs < yearsLeft) {
              yearsLeft = yrs;
              nextMilestone = m;
            }
            break;
          }
        }
      }
    } else {
      // Ohne Kinderprofil: erstes Meilenstein zeigen
      if (_country.milestones.isNotEmpty) {
        nextMilestone = _country.milestones.first;
        yearsLeft = nextMilestone.childAgeYears;
      }
    }

    if (nextMilestone == null) return const SizedBox.shrink();

    final target = nextMilestone.estimatedCost;
    final monthsLeft = (yearsLeft! * 12).toDouble();
    final needed = (target - _totalSaved).clamp(0, target);
    final autoGoal = monthsLeft > 0 ? (needed / monthsLeft) : 0.0;
    final progress = (_totalSaved / target).clamp(0.0, 1.0);

    final goalController = TextEditingController(
      text: _monthlySavingsGoal > 0 ? _monthlySavingsGoal.toStringAsFixed(0) : '',
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(nextMilestone.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Spar-Ziel: ${nextMilestone.label}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700, color: const Color(0xFFEA580C))),
              Text(
                'In $yearsLeft Jahr${yearsLeft == 1 ? '' : 'en'} \u00b7 ~${_country.formatAmount(target)}',
                style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF9A3412)),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        // Fortschrittsbalken
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: const Color(0xFFFFD7B0),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF97316)),
          ),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Gespart: ${_country.formatAmount(_totalSaved)}',
              style: theme.textTheme.labelSmall?.copyWith(color: const Color(0xFF9A3412))),
          Text('Ziel: ${_country.formatAmount(target)}',
              style: theme.textTheme.labelSmall?.copyWith(color: const Color(0xFF9A3412))),
        ]),
        const SizedBox(height: 12),
        // Eingabe: aktuell gespart
        Row(children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Bisher gespart (\u20ac)',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onSubmitted: (v) {
                final val = double.tryParse(v) ?? _totalSaved;
                setState(() => _totalSaved = val);
                _saveSavingsGoal();
              },
              controller: TextEditingController(
                  text: _totalSaved > 0 ? _totalSaved.toStringAsFixed(0) : ''),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Spar-Rate/Monat (\u20ac)',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              controller: goalController,
              onSubmitted: (v) {
                final val = double.tryParse(v) ?? _monthlySavingsGoal;
                setState(() => _monthlySavingsGoal = val);
                _saveSavingsGoal();
              },
            ),
          ),
        ]),
        if (_monthlySavingsGoal > 0 && monthsLeft > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Mit ${_country.formatAmount(_monthlySavingsGoal)}/Monat hast du das Ziel ${_monthlySavingsGoal >= autoGoal ? 'rechtzeitig' : 'fast'} in $yearsLeft Jahr${yearsLeft == 1 ? '' : 'en'} erreicht.',
            style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF9A3412), fontStyle: FontStyle.italic),
          ),
        ] else if (autoGoal > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Empfehlung: ${_country.formatAmount(autoGoal)}/Monat zuruecklegen.',
            style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF9A3412)),
          ),
        ],
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FEATURE 4: Monat ist eng
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildKnappSection(ThemeData theme) {
    final resources = _country.code == 'de'
        ? [
            ('Lebensmittelhilfe \u2013 Tafel Deutschland', 'https://www.tafel.de/infos-hilfe/tafel-suche/'),
            ('Bildung & Teilhabe (BuT) beantragen', 'https://www.bmas.de/DE/Arbeit/Grundsicherung/Bildungspaket/bildungspaket.html'),
            ('Kostenlose Schuldnerberatung (VZ)', 'https://www.verbraucherzentrale.de/themen/geld-versicherungen/kredit-und-schulden/schuldnerberatung'),
            ('Kleiderkammer \u2013 Caritasverband', 'https://www.caritas.de/hilfeundberatung/onlineberatung/sozialedienste'),
          ]
        : _country.code == 'at'
            ? [
                ('Lebensmittelhilfe \u2013 Tafel Oesterreich', 'https://www.tafel.at/'),
                ('Kostenlose Schuldnerberatung', 'https://www.schuldnerberatung.at/'),
                ('Caritas Beratungsstellen', 'https://www.caritas.at/hilfe-einrichtungen/beratung/'),
              ]
            : [
                ('Lokale Lebensmittelbank finden', 'https://www.foodbankingeurope.org/'),
                ('Familienhilfe & Beratung', 'https://www.unicef.org/parenting/'),
              ];

    return Column(children: [
      GestureDetector(
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
          child: Row(children: [
            const Text('\u{1F91D}', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Monat ist eng? Hilfe finden',
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _showKnappSection
                          ? const Color(0xFFB91C1C)
                          : theme.colorScheme.onSurface)),
            ),
            Icon(
              _showKnappSection
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ]),
        ),
      ),
      if (_showKnappSection) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.25)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Kostenlose Anlaufstellen in ${_country.name}:',
              style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700, color: const Color(0xFF991B1B)),
            ),
            const SizedBox(height: 10),
            ...resources.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _openUrl(r.$2),
                child: Row(children: [
                  const Icon(Icons.link_rounded, size: 14, color: Color(0xFFDC2626)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(r.$1,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFDC2626),
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: const Color(0xFFDC2626))),
                  ),
                ]),
              ),
            )),
          ]),
        ),
      ],
    ]);
  }
}
