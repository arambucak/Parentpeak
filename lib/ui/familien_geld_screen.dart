import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadSavedData();
  }

  @override
  void dispose() {
    _tabs.dispose();
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
              controller: TextEditingController(
                  text: amount > 0 ? amount.toStringAsFixed(0) : ''),
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
        // Leistungen-Liste
        ..._country.benefits.map((b) => _benefitCard(theme, b)),
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
              // URL oeffnen (TODO: url_launcher)
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Link: ${b.url}')),
              );
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
}
