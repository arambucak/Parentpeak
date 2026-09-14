import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:parentpeak/logic/advanced_balance_provider.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/finance_storage_service.dart';
import 'package:parentpeak/logic/receipt_ocr_service.dart';
import 'package:parentpeak/models/care_activity.dart';
import 'package:parentpeak/models/expense.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';

String _t(String key) =>
    AppStringsManager.getString(languageService.currentLanguage, key);


class FinanceBudgetScreen extends StatefulWidget {
  const FinanceBudgetScreen({super.key});

  @override
  State<FinanceBudgetScreen> createState() => _FinanceBudgetScreenState();
}

class _FinanceBudgetScreenState extends State<FinanceBudgetScreen> {
  late final AdvancedBalanceProvider _provider;
  late final FinanceStorageService _storage;
  final ReceiptOcrService _ocrService = ReceiptOcrService();

  static const String _mamaId = 'mama';
  static const String _papaId = 'papa';

  bool _loading = true;
  bool _saving = false;
  bool _pendingSave = false;
  bool _importingReceipt = false;
  String? _syncInfo;
  ExpenseCategory? _expenseCategoryFilter;


  @override
  void initState() {
    super.initState();
    _storage = BackendServiceFactory.createFinanceStorageService();
    _provider = AdvancedBalanceProvider(
      defaultSplitByParent: const {
        _mamaId: 0.6,
        _papaId: 0.4,
      },
      parentIds: const [_mamaId, _papaId],
    );
    _provider.addListener(_onProviderChanged);
    _loadSnapshot();
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderChanged);
    _provider.dispose();
    super.dispose();
  }

  Future<void> _loadSnapshot() async {
    final snapshot = await _storage.loadSnapshot();
    _provider.applySnapshot(
      expenses: snapshot.expenses,
      careActivities: snapshot.careActivities,
      opportunities: snapshot.savingsOpportunities,
      notify: false,
    );

    if (!mounted) return;
    setState(() {
      _syncInfo = _storage.lastSyncError;
      _loading = false;
    });
  }

  void _onProviderChanged() {
    _persistSnapshot();
  }

  Future<void> _persistSnapshot() async {
    if (_saving) {
      _pendingSave = true;
      return;
    }

    _saving = true;
    do {
      _pendingSave = false;
      await _storage.saveSnapshot(
        FinanceStorageSnapshot(
          expenses: _provider.expenses,
          careActivities: _provider.careActivities,
          savingsOpportunities: _provider.opportunities,
        ),
      );
      if (!mounted) continue;
      setState(() {
        _syncInfo = _storage.lastSyncError;
      });
    } while (_pendingSave);

    _saving = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final contentMaxWidth = viewportWidth >= 1280
        ? 1040.0
        : viewportWidth >= 980
            ? 920.0
            : double.infinity;
    final horizontalPadding = viewportWidth >= 980 ? 24.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('finance_title')),
        actions: [
          IconButton(
            tooltip: _t('finance_export_csv'),
            onPressed: _exportCsv,
            icon: const Icon(Icons.table_view_rounded),
          ),
          IconButton(
            tooltip: _t('finance_export_pdf'),
            onPressed: _exportPdf,
            icon: const Icon(Icons.picture_as_pdf_rounded),
          ),
          IconButton(
            tooltip: _t('finance_qr_settlement'),
            onPressed: _showSettlementQr,
            icon: const Icon(Icons.qr_code_2_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FBFF), Color(0xFFF3F7FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : AnimatedBuilder(
                animation: _provider,
                builder: (context, _) {
                  final settlement = _provider.finalSettlementByParent;
                  final mamaNet = settlement[_mamaId] ?? 0;
                  final papaNet = settlement[_papaId] ?? 0;
                  final visibleExpenses = _expenseCategoryFilter == null
                      ? _provider.filteredExpenses
                      : _provider.filteredExpenses
                          .where(
                              (item) => item.category == _expenseCategoryFilter)
                          .toList();
                  final groupedExpenses = _groupExpensesByDate(visibleExpenses);
                  final groupedCareActivities =
                      _groupCareByDate(_provider.filteredCareActivities);

                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentMaxWidth),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          14,
                          horizontalPadding,
                          28,
                        ),
                        children: [
                          if (_syncInfo != null && _syncInfo!.trim().isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(_syncInfo!),
                            ),
                          _HeroCard(theme: theme),
                          const SizedBox(height: 12),
                          _MonthSelector(
                            selectedMonth: _provider.selectedMonth,
                            options: _lastMonths(8),
                            onChanged: (month) =>
                                _provider.setSelectedMonth(month),
                          ),
                          const SizedBox(height: 10),
                          _BalanceStrip(
                            monthlyExpenses:
                                _provider.monthlyNetHouseholdExpenses,
                            careCredits: _provider.monthlyCareCredits,
                            savingsPotential:
                                _provider.secondHandSavingsPotential,
                          ),
                          const SizedBox(height: 10),
                          _MonthlyCategoryOverview(
                            familyCost: _sumCategory(ExpenseCategory.groceries),
                            babyCost: _sumCategory(ExpenseCategory.baby),
                            personalCost:
                                _sumCategory(ExpenseCategory.personal),
                            depositValue: _sumCategory(ExpenseCategory.deposit),
                            savingsPotential:
                                _provider.secondHandSavingsPotential,
                            formatter: _currency,
                          ),
                          const SizedBox(height: 10),
                          _SettlementCard(
                            mamaNet: mamaNet,
                            papaNet: papaNet,
                            formatter: _currency,
                            explanation:
                                _buildSettlementExplanation(mamaNet, papaNet),
                            insights: _buildSettlementInsights(),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _t('finance_quick_start'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ActionChip(
                                avatar: const Icon(Icons.camera_alt_rounded,
                                    size: 18),
                                label: Text(
                                  _importingReceipt
                                      ? _t('finance_scan_running')
                                      : _t('finance_scan_receipt'),
                                ),
                                onPressed: _importingReceipt
                                    ? null
                                    : _startReceiptImport,
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.favorite_rounded,
                                    size: 18),
                                label: Text(_t('finance_add_care')),
                                onPressed: _addManualCareActivity,
                              ),
                              ActionChip(
                                avatar:
                                    const Icon(Icons.sell_rounded, size: 18),
                                label: Text(_t('finance_add_saving')),
                                onPressed: _addManualSavingsOpportunity,
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.add_card_rounded,
                                    size: 18),
                                label: Text(_t('finance_add_manual')),
                                onPressed: _addManualExpense,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _SectionTitle(
                            title: _t('finance_recent_ocr'),
                            subtitle:
                                '${visibleExpenses.length} ${_t('finance_entries_in')} ${DateFormat('MMMM yyyy', 'de_DE').format(_provider.selectedMonth)}',
                          ),
                          const SizedBox(height: 8),
                          _CategoryFilterBar(
                            selected: _expenseCategoryFilter,
                            onSelected: (value) {
                              setState(() {
                                _expenseCategoryFilter = value;
                              });
                            },
                            labelBuilder: _categoryLabel,
                            colorBuilder: _categoryColor,
                          ),
                          const SizedBox(height: 8),
                          if (visibleExpenses.isEmpty)
                            const _EmptyHint(
                                text: 'Keine Belege für den gewählten Monat.')
                          else
                            ...groupedExpenses.entries.take(6).expand(
                                  (entry) => [
                                    _DateGroupHeader(
                                        label: _formatExpenseDate(entry.key)),
                                    ...entry.value.map(
                                      (expense) => _ListItemCard(
                                        leadingIcon: Icons.receipt_rounded,
                                        title: expense.title,
                                        subtitle:
                                            '${_splitTypeLabel(expense.splitType.name)} · bezahlt von ${_parentLabel(expense.paidById)}',
                                        badgeText:
                                            _categoryLabel(expense.category),
                                        badgeColor:
                                            _categoryColor(expense.category),
                                        trailing: _currency(expense.amount),
                                        onTap: () =>
                                            _openExpenseActions(expense),
                                      ),
                                    ),
                                  ],
                                ),
                          const SizedBox(height: 12),
                          _SectionTitle(
                            title: _t('finance_care_activities'),
                            subtitle:
                                '${_provider.filteredCareActivities.length} ${_t('finance_entries_in')} · ${_currency(_provider.monthlyCareCredits)} Bonus',
                          ),
                          const SizedBox(height: 8),
                          if (_provider.filteredCareActivities.isEmpty)
                            const _EmptyHint(
                              text:
                                  'Keine Care-Aktivitaeten für den gewählten Monat.',
                            )
                          else
                            ...groupedCareActivities.entries.expand(
                              (entry) => [
                                _DateGroupHeader(
                                    label: _formatExpenseDate(entry.key)),
                                ...entry.value.map(
                                  (activity) => _ListItemCard(
                                    leadingIcon:
                                        Icons.volunteer_activism_rounded,
                                    title:
                                        _careTypeLabel(activity.activityType),
                                    subtitle:
                                        '${_parentLabel(activity.parentId)} · ${activity.durationHours.toStringAsFixed(1)} h',
                                    trailing:
                                        '+ ${_currency(activity.financialCreditValue)}',
                                    onTap: () => _openCareActions(activity),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _startReceiptImport() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: Text(_t('finance_camera')),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: Text(_t('finance_gallery')),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null || !mounted) return;

    setState(() {
      _importingReceipt = true;
    });

    try {
      final lines = await _ocrService.extractLinesFromImage(source);
      if (!mounted) return;

      final drafts = _buildDraftsFromOcr(lines);
      if (drafts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('finance_no_items_recognized'))),
        );
        return;
      }

      final confirmed = await _openSplitEditor(drafts);
      if (!mounted || confirmed == null || confirmed.isEmpty) return;

      final receiptId = 'ocr-${DateTime.now().millisecondsSinceEpoch}';
      final expenses = confirmed
          .map(
            (item) => Expense(
              id: '$receiptId-${item.title.hashCode.abs()}-${item.amount.toStringAsFixed(2)}',
              title: item.title,
              amount: item.amount,
              date: _provider.selectedMonth,
              paidById: item.paidById,
              category: item.category,
              splitType: item.splitType,
              customSplitByParent: item.customSplit,
              sourceReceiptId: receiptId,
            ),
          )
          .toList();

      _provider.addExpenses(expenses);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('budget_positions_imported')
            .replaceAll('{count}', '${expenses.length}'))),
      );
    } on ReceiptOcrUnsupportedException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
      _addManualExpense();
    } catch (e) {
      debugPrint('FinanceBudgetScreen._importReceiptFromPhoto(): failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('finance_ocr_failed'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _importingReceipt = false;
        });
      }
    }
  }

  List<DateTime> _lastMonths(int count) {
    final now = DateTime.now();
    final firstOfCurrentMonth = DateTime(now.year, now.month, 1);
    return List<DateTime>.generate(
      count,
      (index) => DateTime(
          firstOfCurrentMonth.year, firstOfCurrentMonth.month - index, 1),
    );
  }

  List<_ReceiptDraftItem> _buildDraftsFromOcr(List<String> lines) {
    final amountPattern = RegExp(r'(\d+[\.,]\d{2})');
    const ignoredMarkers = <String>[
      'summe',
      'gesamt',
      'total',
      'mwst',
      'ust',
      'karte',
      'ec-zahlung',
      'zahlung',
      'bar',
      'wechselgeld',
      'rueckgeld',
      'beleg',
      'filiale',
      'rabatt',
      'coupon',
      'kassenbon',
      'steuer',
      'visa',
      'mastercard',
    ];
    final drafts = <_ReceiptDraftItem>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final lowerLine = trimmed.toLowerCase();
      if (ignoredMarkers.any(lowerLine.contains)) continue;

      final matches = amountPattern.allMatches(trimmed).toList();
      if (matches.isEmpty) continue;

      final match = matches.last;
      final firstAmount = matches.first.group(1)?.replaceAll(',', '.');

      final rawAmount = match.group(1)!.replaceAll(',', '.');
      final amount = double.tryParse(rawAmount);
      if (amount == null || amount <= 0) continue;

      if (lowerLine.contains('pfand')) {
        drafts.add(
          _ReceiptDraftItem(
            title: 'Pfand / Rueckgabe',
            amount: amount,
            category: ExpenseCategory.deposit,
            paidById: _mamaId,
            splitType: ExpenseSplitType.standardSplit,
            customSplit: const {
              _mamaId: 0.6,
              _papaId: 0.4,
            },
          ),
        );
        continue;
      }

      var title = trimmed.replaceAll(match.group(0)!, '').trim();
      if (firstAmount != null && firstAmount != rawAmount) {
        title = title.replaceFirst(firstAmount, '').trim();
      }
      title = title
          .replaceFirst(
              RegExp(r'^\d+\s*(stk|st|x)\b', caseSensitive: false), '')
          .trim();
      title = title.replaceFirst(RegExp(r'^\d+\s*[xX]\s*'), '').trim();
      title =
          title.replaceFirst(RegExp(r'^\d+[\.,]\d{2}\s*[xX]\s*'), '').trim();
      title = title
          .replaceFirst(
              RegExp(r'^\d+[\.,]?\d*\s*(kg|g|ml|l)\b', caseSensitive: false),
              '')
          .trim();
      title = title
          .replaceAll(
              RegExp(r'\b\d+[\.,]?\d*\s*(kg|g|ml|l|stk|st)\b',
                  caseSensitive: false),
              '')
          .trim();
      title = title.replaceFirst(RegExp(r'^\d+\s+'), '').trim();
      title = title.replaceFirst(RegExp(r'^[A-Z0-9]{5,}\s+'), '').trim();
      title = title.replaceAll(RegExp(r'\b[A-Z0-9]{6,}\b'), '').trim();
      title = title.replaceAll(RegExp(r'\b[xX]\b'), ' ');
      title = title.replaceAll(RegExp(r'\s+-\s+'), ' ');
      title = title.replaceAll(RegExp(r'\s*/\s*'), ' ');
      title = title.replaceAll(RegExp(r'\s{2,}'), ' ');

      if (title.length < 2) continue;

      final normalizedTitle = title.isEmpty ? 'Unbekannter Posten' : title;
      final lower = normalizedTitle.toLowerCase();

      final isPersonal = lower.contains('rasier') ||
          lower.contains('deo') ||
          lower.contains('kosmetik') ||
          lower.contains('parfum');
      final isBaby = lower.contains('windel') ||
          lower.contains('baby') ||
          lower.contains('milchpulver');

      final category = isBaby
          ? ExpenseCategory.baby
          : isPersonal
              ? ExpenseCategory.personal
              : ExpenseCategory.groceries;

      drafts.add(
        _ReceiptDraftItem(
          title: normalizedTitle,
          amount: amount,
          category: category,
          paidById: _mamaId,
          splitType: isPersonal
              ? ExpenseSplitType.individual
              : ExpenseSplitType.intelligentOcrSplit,
          customSplit: isPersonal
              ? {_mamaId: 1}
              : {
                  _mamaId: 0.6,
                  _papaId: 0.4,
                },
        ),
      );
    }

    return drafts;
  }

  double _sumCategory(ExpenseCategory category) {
    return _provider.filteredExpenses
        .where((item) => item.category == category)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  Future<void> _addManualExpense() async {
    final drafts = await _openSplitEditor(
      const [
        _ReceiptDraftItem(
          title: 'Neue Position',
          amount: 0.0,
          category: ExpenseCategory.groceries,
          paidById: _mamaId,
          splitType: ExpenseSplitType.standardSplit,
          customSplit: {
            _mamaId: 0.6,
            _papaId: 0.4,
          },
        ),
      ],
    );

    if (!mounted || drafts == null || drafts.isEmpty) return;

    final receiptId = 'manual-${DateTime.now().millisecondsSinceEpoch}';
    final expenses = drafts
        .where((item) => item.title.trim().isNotEmpty && item.amount > 0)
        .map(
          (item) => Expense(
            id: '$receiptId-${item.title.hashCode.abs()}-${item.amount.toStringAsFixed(2)}',
            title: item.title,
            amount: item.amount,
            date: _provider.selectedMonth,
            paidById: item.paidById,
            category: item.category,
            splitType: item.splitType,
            customSplitByParent: item.customSplit,
            sourceReceiptId: receiptId,
          ),
        )
        .toList();

    if (expenses.isEmpty) return;
    _provider.addExpenses(expenses);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('${expenses.length} manuelle Positionen hinzugefuegt.')),
    );
  }

  Map<DateTime, List<Expense>> _groupExpensesByDate(List<Expense> expenses) {
    final grouped = <DateTime, List<Expense>>{};
    for (final expense in expenses) {
      final key =
          DateTime(expense.date.year, expense.date.month, expense.date.day);
      grouped.putIfAbsent(key, () => <Expense>[]).add(expense);
    }

    final entries = grouped.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return {for (final entry in entries) entry.key: entry.value};
  }

  Map<DateTime, List<CareActivity>> _groupCareByDate(
      List<CareActivity> activities) {
    final grouped = <DateTime, List<CareActivity>>{};
    for (final activity in activities) {
      final key =
          DateTime(activity.date.year, activity.date.month, activity.date.day);
      grouped.putIfAbsent(key, () => <CareActivity>[]).add(activity);
    }

    final entries = grouped.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return {for (final entry in entries) entry.key: entry.value};
  }

  String _formatExpenseDate(DateTime date) {
    return DateFormat('EEEE, dd.MM.', 'de_DE').format(date);
  }

  List<String> _buildSettlementInsights() {
    final insights = <String>[];
    final expenses = _provider.filteredExpenses;
    if (expenses.isEmpty) {
      return const ['Noch keine Ausgaben in diesem Monat erfasst.'];
    }

    double sumByCategory(ExpenseCategory category) {
      return expenses
          .where((item) => item.category == category)
          .fold(0.0, (sum, item) => sum + item.amount);
    }

    final babyTotal = sumByCategory(ExpenseCategory.baby);
    final depositTotal = sumByCategory(ExpenseCategory.deposit);
    final personalTotal = sumByCategory(ExpenseCategory.personal);
    final groceriesTotal = sumByCategory(ExpenseCategory.groceries);
    final total = _provider.monthlyNetHouseholdExpenses;

    if (total > 0 && babyTotal > 0 && babyTotal / total >= 0.25) {
      insights.add(
          'Babykosten praegen diesen Monat den groessten Teil eurer Alltagsausgaben.');
    }

    if (_provider.monthlyCareCredits >= 40) {
      insights.add(
          'Der Care-Bonus reduziert den Ausgleich spuerbar und macht unsichtbare Arbeit sichtbar.');
    }

    if (_provider.secondHandSavingsPotential >= 50) {
      insights.add(
          'Second-Hand-Treffer zeigen gerade spuerbares Sparpotenzial für diesen Monat.');
    }

    if (depositTotal > 0) {
      insights.add(
          'Pfand wurde separat erkannt und verfaelscht eure Familienkosten dadurch nicht mehr so stark.');
    }

    if (personalTotal > groceriesTotal && personalTotal > 0) {
      insights.add(
          'Persönliche Ausgaben liegen aktuell über den Familien-Lebensmitteln. Ein kurzer Beleg-Check lohnt sich.');
    }

    if (insights.isEmpty) {
      insights.add(
          'Familienkosten und Ausgleich wirken diesen Monat insgesamt recht ausgewogen.');
    }

    return insights.take(2).toList();
  }

  Future<List<_ReceiptDraftItem>?> _openSplitEditor(
    List<_ReceiptDraftItem> items,
  ) async {
    final editable = items.map((item) => item.copyWith()).toList();

    return showModalBottomSheet<List<_ReceiptDraftItem>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 14,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 14,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Split-Korrektur vor Uebernahme',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(_t('cancel')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          setModalState(() {
                            editable.add(
                              const _ReceiptDraftItem(
                                title: 'Neue Position',
                                amount: 0.0,
                                category: ExpenseCategory.groceries,
                                paidById: _mamaId,
                                splitType: ExpenseSplitType.standardSplit,
                                customSplit: {
                                  _mamaId: 0.6,
                                  _papaId: 0.4,
                                },
                              ),
                            );
                          });
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: Text(_t('finance_add_position_manual')),
                      ),
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: editable.length,
                        itemBuilder: (context, index) {
                          final item = editable[index];
                          return Card(
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      _InlineBadge(
                                        text: _categoryLabel(item.category),
                                        color: _categoryColor(item.category),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    initialValue: item.title,
                                    decoration: InputDecoration(
                                      labelText: _t('finance_label_title'),
                                      isDense: true,
                                    ),
                                    onChanged: (value) {
                                      setModalState(() {
                                        editable[index] = item.copyWith(
                                          title: value.trim().isEmpty
                                              ? 'Unbekannter Posten'
                                              : value.trim(),
                                        );
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    initialValue:
                                        item.amount.toStringAsFixed(2),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: InputDecoration(
                                      labelText: _t('finance_label_amount'),
                                      suffixText: 'EUR',
                                      isDense: true,
                                    ),
                                    onChanged: (value) {
                                      final parsed = double.tryParse(
                                        value.replaceAll(',', '.'),
                                      );
                                      if (parsed == null || parsed <= 0) return;
                                      setModalState(() {
                                        editable[index] =
                                            item.copyWith(amount: parsed);
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    initialValue: item.paidById,
                                    decoration: InputDecoration(
                                      labelText: _t('finance_label_paid_by'),
                                      isDense: true,
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: _mamaId,
                                        child: Text(_t('finance_mama')),
                                      ),
                                      DropdownMenuItem(
                                        value: _papaId,
                                        child: Text(_t('finance_papa')),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setModalState(() {
                                        editable[index] = item.copyWith(
                                          paidById: value,
                                          customSplit: item.splitType ==
                                                  ExpenseSplitType.individual
                                              ? {value: 1}
                                              : item.customSplit,
                                        );
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<ExpenseCategory>(
                                    initialValue: item.category,
                                    decoration: const InputDecoration(
                                      labelText: 'Kategorie',
                                      isDense: true,
                                    ),
                                    items: ExpenseCategory.values
                                        .map(
                                          (category) => DropdownMenuItem(
                                            value: category,
                                            child:
                                                Text(_categoryLabel(category)),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setModalState(() {
                                        editable[index] =
                                            item.copyWith(category: value);
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<ExpenseSplitType>(
                                    initialValue: item.splitType,
                                    decoration: InputDecoration(
                                      labelText: _t('finance_label_split_type'),
                                      isDense: true,
                                    ),
                                    isExpanded: true,
                                    items: [
                                      DropdownMenuItem(
                                        value: ExpenseSplitType
                                            .intelligentOcrSplit,
                                        child: Text(_t('finance_ocr_split')),
                                      ),
                                      DropdownMenuItem(
                                        value: ExpenseSplitType.individual,
                                        child: Text(
                                            _t('finance_individual_split')),
                                      ),
                                      DropdownMenuItem(
                                        value: ExpenseSplitType.standardSplit,
                                        child:
                                            Text(_t('finance_standard_split')),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setModalState(() {
                                        editable[index] = item.copyWith(
                                          splitType: value,
                                          customSplit: value ==
                                                  ExpenseSplitType.individual
                                              ? {item.paidById: 1}
                                              : {
                                                  _mamaId: 0.6,
                                                  _papaId: 0.4,
                                                },
                                        );
                                      });
                                    },
                                  ),
                                  if (item.splitType !=
                                      ExpenseSplitType.individual) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      'Familien-Split feinjustieren',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Slider(
                                      value: (item.customSplit?[_mamaId] ?? 0.6)
                                          .clamp(0.0, 1.0),
                                      min: 0,
                                      max: 1,
                                      divisions: 20,
                                      label:
                                          'Mama ${((item.customSplit?[_mamaId] ?? 0.6) * 100).round()}% · Papa ${((1 - (item.customSplit?[_mamaId] ?? 0.6)) * 100).round()}%',
                                      onChanged: (value) {
                                        setModalState(() {
                                          editable[index] = item.copyWith(
                                            customSplit: {
                                              _mamaId: value,
                                              _papaId: 1 - value,
                                            },
                                          );
                                        });
                                      },
                                    ),
                                    Text(
                                      'Mama ${((item.customSplit?[_mamaId] ?? 0.6) * 100).round()}% · Papa ${((1 - (item.customSplit?[_mamaId] ?? 0.6)) * 100).round()}%',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(editable),
                        child: Text(_t('finance_apply_positions')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addManualCareActivity() async {
    final draft = CareActivity(
      id: 'care-${DateTime.now().millisecondsSinceEpoch}',
      parentId: _mamaId,
      activityType: CareActivityType.other,
      durationHours: 1,
      financialCreditValue: 10,
      date: _provider.selectedMonth,
      note: '',
    );

    final created = await _openCareEditor(draft);
    if (!mounted || created == null) return;

    _provider.addCareActivity(created);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('finance_care_saved'))),
    );
  }

  Future<void> _addManualSavingsOpportunity() async {
    final goalController = TextEditingController();
    final retailController = TextEditingController(text: '100');
    final secondHandController = TextEditingController(text: '60');
    final distanceController = TextEditingController(text: '2');
    final marketplaceController = TextEditingController(text: 'Kleinanzeigen');

    final created = await showDialog<SavingsOpportunity>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_t('finance_add_saving')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: goalController,
                  decoration: InputDecoration(
                      labelText: _t('finance_label_product_goal')),
                ),
                TextField(
                  controller: retailController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: _t('finance_label_retail_price')),
                ),
                TextField(
                  controller: secondHandController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: _t('finance_label_secondhand_price')),
                ),
                TextField(
                  controller: distanceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      InputDecoration(labelText: _t('finance_label_distance')),
                ),
                TextField(
                  controller: marketplaceController,
                  decoration: InputDecoration(
                      labelText: _t('finance_label_marketplace')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_t('cancel')),
            ),
            FilledButton(
              onPressed: () {
                final goal = goalController.text.trim();
                final retail = double.tryParse(
                    retailController.text.trim().replaceAll(',', '.'));
                final secondHand = double.tryParse(
                    secondHandController.text.trim().replaceAll(',', '.'));
                final distance = double.tryParse(
                    distanceController.text.trim().replaceAll(',', '.'));
                final marketplace = marketplaceController.text.trim();

                if (goal.isEmpty ||
                    retail == null ||
                    secondHand == null ||
                    distance == null ||
                    marketplace.isEmpty) {
                  return;
                }

                Navigator.of(dialogContext).pop(
                  SavingsOpportunity(
                    id: 'deal-${DateTime.now().millisecondsSinceEpoch}',
                    goal: goal,
                    retailPrice: retail,
                    secondHandPrice: secondHand,
                    distanceKm: distance,
                    marketplace: marketplace,
                  ),
                );
              },
              child: Text(_t('finance_save')),
            ),
          ],
        );
      },
    );

    goalController.dispose();
    retailController.dispose();
    secondHandController.dispose();
    distanceController.dispose();
    marketplaceController.dispose();

    if (!mounted || created == null) return;

    _provider.addSavingsOpportunity(created);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sparchance gespeichert: ${created.marketplace}, Potenzial ${_currency(created.savings)}.',
        ),
      ),
    );
  }

  Future<void> _exportCsv() async {
    final lines = <String>[
      'typ,titel,betrag,datum,meta',
      ..._provider.filteredExpenses.map((item) =>
          'expense,${_escapeCsv(item.title)},${item.amount.toStringAsFixed(2)},${item.date.toIso8601String()},${_escapeCsv(_splitTypeLabel(item.splitType.name))}'),
      ..._provider.filteredCareActivities.map((item) =>
          'care,${_escapeCsv(_careTypeLabel(item.activityType))},${item.financialCreditValue.toStringAsFixed(2)},${item.date.toIso8601String()},${_escapeCsv(_parentLabel(item.parentId))}'),
      ..._provider.filteredOpportunities.map((item) =>
          'saving,${_escapeCsv(item.goal)},${item.savings.toStringAsFixed(2)},${DateTime.now().toIso8601String()},${_escapeCsv(item.marketplace)}'),
    ];

    final content = lines.join('\n');
    final file = XFile.fromData(
      utf8.encode(content),
      mimeType: 'text/csv',
      name: 'parentpeak_finanz_export.csv',
    );

    await Share.shareXFiles([file], text: 'Parentpeak Finanzexport (CSV)');
  }

  Future<void> _exportPdf() async {
    final month =
        DateFormat('MMMM yyyy', 'de_DE').format(_provider.selectedMonth);
    final settlement = _provider.finalSettlementByParent;
    final mamaNet = settlement[_mamaId] ?? 0;
    final papaNet = settlement[_papaId] ?? 0;

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Parentpeak Finanzen - $month',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Monatskosten: ${_currency(_provider.monthlyTotalExpenses)}'),
          pw.Text('Care-Bonus: ${_currency(_provider.monthlyCareCredits)}'),
          pw.Text(
              'Sparpotenzial: ${_currency(_provider.secondHandSavingsPotential)}'),
          pw.SizedBox(height: 10),
          pw.Text('Monatsausgleich',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(
              'Mama: ${mamaNet >= 0 ? '+' : '-'} ${_currency(mamaNet.abs())}'),
          pw.Text(
              'Papa: ${papaNet >= 0 ? '+' : '-'} ${_currency(papaNet.abs())}'),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'parentpeak_finanzen_$month.pdf',
    );
  }

  Future<void> _showSettlementQr() async {
    final settlement = _provider.finalSettlementByParent;
    final payload = {
      'month': DateFormat('yyyy-MM').format(_provider.selectedMonth),
      'mamaNet': (settlement[_mamaId] ?? 0).toStringAsFixed(2),
      'papaNet': (settlement[_papaId] ?? 0).toStringAsFixed(2),
      'currency': 'EUR',
    };
    final encoded = jsonEncode(payload);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_t('finance_qr_settlement')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(data: encoded, size: 180),
              const SizedBox(height: 12),
              Text(
                'Scan für direkten Monatsausgleich zwischen Elternteilen.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: encoded));
                if (!mounted) return;
                Navigator.of(this.context).pop();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text(_t('finance_qr_copied'))),
                );
              },
              child: Text(_t('finance_copy_data')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_t('finance_close')),
            ),
          ],
        );
      },
    );
  }

  String _buildSettlementExplanation(double mamaNet, double papaNet) {
    if (mamaNet.abs() < 0.01 && papaNet.abs() < 0.01) {
      return 'Diesen Monat ist euer Ausgleich praktisch im Gleichgewicht.';
    }

    if (mamaNet > 0 && papaNet < 0) {
      return 'Papa gleicht an Mama ${_currency(mamaNet.abs())} aus, damit Ausgaben und Care-Fairness wieder zusammenpassen.';
    }

    if (papaNet > 0 && mamaNet < 0) {
      return 'Mama gleicht an Papa ${_currency(papaNet.abs())} aus, damit Ausgaben und Care-Fairness wieder zusammenpassen.';
    }

    return 'Eure Zahlen zeigen gerade eine unklare Verteilung. Ein kurzer Blick auf die letzten Belege lohnt sich.';
  }

  Future<void> _openExpenseActions(Expense expense) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: Text(_t('finance_edit_expense')),
                onTap: () => Navigator.of(context).pop('edit'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: Text(_t('finance_delete_expense')),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'delete') {
      _provider.removeExpense(expense.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('finance_expense_removed'))),
      );
      return;
    }

    final edited = await _openExpenseEditor(expense);
    if (!mounted || edited == null) return;

    _provider.updateExpense(edited);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('finance_expense_updated'))),
    );
  }

  Future<void> _openCareActions(CareActivity activity) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: Text(_t('finance_edit_care')),
                onTap: () => Navigator.of(context).pop('edit'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: Text(_t('finance_delete_care')),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'delete') {
      _provider.removeCareActivity(activity.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('finance_care_removed'))),
      );
      return;
    }

    final edited = await _openCareEditor(activity);
    if (!mounted || edited == null) return;

    _provider.updateCareActivity(edited);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('finance_care_updated'))),
    );
  }

  Future<CareActivity?> _openCareEditor(CareActivity activity) async {
    final hoursController =
        TextEditingController(text: activity.durationHours.toStringAsFixed(1));
    final creditController = TextEditingController(
      text: activity.financialCreditValue.toStringAsFixed(2),
    );
    final noteController = TextEditingController(text: activity.note ?? '');

    var parentId = activity.parentId;
    var activityType = activity.activityType;

    final result = await showModalBottomSheet<CareActivity>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 14,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 14,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Care-Eintrag bearbeiten',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: parentId,
                      decoration: InputDecoration(
                          labelText: _t('finance_label_parent')),
                      items: [
                        DropdownMenuItem(
                            value: _mamaId, child: Text(_t('finance_mama'))),
                        DropdownMenuItem(
                            value: _papaId, child: Text(_t('finance_papa'))),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() {
                          parentId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<CareActivityType>(
                      initialValue: activityType,
                      decoration: InputDecoration(
                          labelText: _t('finance_label_care_type')),
                      items: CareActivityType.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(_careTypeLabel(item)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() {
                          activityType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: hoursController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: _t('finance_label_hours'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: creditController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: _t('finance_label_credit_value'),
                        suffixText: 'EUR',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration:
                          InputDecoration(labelText: _t('finance_label_note')),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          final hours = double.tryParse(
                            hoursController.text.replaceAll(',', '.'),
                          );
                          final credit = double.tryParse(
                            creditController.text.replaceAll(',', '.'),
                          );
                          if (hours == null ||
                              hours <= 0 ||
                              credit == null ||
                              credit < 0) {
                            return;
                          }

                          Navigator.of(context).pop(
                            activity.copyWith(
                              parentId: parentId,
                              activityType: activityType,
                              durationHours: hours,
                              financialCreditValue: credit,
                              note: noteController.text.trim(),
                              clearNote: noteController.text.trim().isEmpty,
                            ),
                          );
                        },
                        child: Text(_t('finance_save')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    hoursController.dispose();
    creditController.dispose();
    noteController.dispose();
    return result;
  }

  Future<Expense?> _openExpenseEditor(
    Expense expense, {
    String dialogTitle = 'Ausgabe bearbeiten',
  }) async {
    final titleController = TextEditingController(text: expense.title);
    final amountController =
        TextEditingController(text: expense.amount.toStringAsFixed(2));

    ExpenseCategory category = expense.category;
    String paidById = expense.paidById;
    ExpenseSplitType splitType = expense.splitType;
    var mamaShare =
        (expense.customSplitByParent?[_mamaId] ?? 0.6).clamp(0.0, 1.0);

    final result = await showModalBottomSheet<Expense>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 14,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 14,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dialogTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: titleController,
                      decoration:
                          InputDecoration(labelText: _t('finance_label_title')),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: _t('finance_label_amount'),
                        suffixText: 'EUR',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: paidById,
                      decoration: InputDecoration(
                          labelText: _t('finance_label_paid_by')),
                      items: [
                        DropdownMenuItem(
                            value: _mamaId, child: Text(_t('finance_mama'))),
                        DropdownMenuItem(
                            value: _papaId, child: Text(_t('finance_papa'))),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() {
                          paidById = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ExpenseCategory>(
                      initialValue: category,
                      decoration: InputDecoration(
                          labelText: _t('finance_label_category')),
                      items: ExpenseCategory.values
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(_categoryLabel(item)),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() {
                          category = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ExpenseSplitType>(
                      initialValue: splitType,
                      decoration: InputDecoration(
                          labelText: _t('finance_label_split_type')),
                      items: [
                        DropdownMenuItem(
                          value: ExpenseSplitType.intelligentOcrSplit,
                          child: Text(_t('finance_ocr_split')),
                        ),
                        DropdownMenuItem(
                          value: ExpenseSplitType.standardSplit,
                          child: Text(_t('finance_standard_split')),
                        ),
                        DropdownMenuItem(
                          value: ExpenseSplitType.individual,
                          child: Text(_t('finance_individual_split')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() {
                          splitType = value;
                        });
                      },
                    ),
                    if (splitType != ExpenseSplitType.individual) ...[
                      const SizedBox(height: 8),
                      Slider(
                        value: mamaShare,
                        min: 0,
                        max: 1,
                        divisions: 20,
                        label:
                            'Mama ${(mamaShare * 100).round()}% · Papa ${((1 - mamaShare) * 100).round()}%',
                        onChanged: (value) {
                          setModalState(() {
                            mamaShare = value;
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          final amount = double.tryParse(
                            amountController.text.replaceAll(',', '.'),
                          );
                          if (amount == null || amount <= 0) {
                            return;
                          }

                          Navigator.of(context).pop(
                            expense.copyWith(
                              title: titleController.text.trim().isEmpty
                                  ? expense.title
                                  : titleController.text.trim(),
                              amount: amount,
                              paidById: paidById,
                              category: category,
                              splitType: splitType,
                              customSplitByParent:
                                  splitType == ExpenseSplitType.individual
                                      ? {paidById: 1}
                                      : {
                                          _mamaId: mamaShare,
                                          _papaId: 1 - mamaShare,
                                        },
                            ),
                          );
                        },
                        child: Text(_t('finance_save')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    amountController.dispose();
    return result;
  }

  String _currency(double value) {
    final format = NumberFormat.currency(locale: 'de_DE', symbol: 'EUR ');
    return format.format(value);
  }

  String _escapeCsv(String input) {
    final escaped = input.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _parentLabel(String id) {
    if (id == _mamaId) return 'Mama';
    if (id == _papaId) return 'Papa';
    return id;
  }

  String _splitTypeLabel(String value) {
    switch (value) {
      case 'standardSplit':
        return 'Standard-Split';
      case 'individual':
        return 'Individuell';
      case 'intelligentOcrSplit':
        return 'OCR-Split';
      default:
        return value;
    }
  }

  String _careTypeLabel(CareActivityType type) {
    switch (type) {
      case CareActivityType.childSickCare:
        return 'Krankes Kind betreut';
      case CareActivityType.kindergartenOrganization:
        return 'Kita-Organisation';
      case CareActivityType.householdCare:
        return 'Haushalts-Care';
      case CareActivityType.appointmentCoordination:
        return 'Termine koordiniert';
      case CareActivityType.emotionalSupport:
        return 'Emotionale Entlastung';
      case CareActivityType.other:
        return 'Sonstige Care-Arbeit';
    }
  }

  String _categoryLabel(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.groceries:
        return 'Familie';
      case ExpenseCategory.baby:
        return 'Baby';
      case ExpenseCategory.deposit:
        return 'Pfand';
      case ExpenseCategory.personal:
        return 'Persoenlich';
      case ExpenseCategory.transport:
        return 'Mobilität';
      case ExpenseCategory.health:
        return 'Gesundheit';
      case ExpenseCategory.leisure:
        return 'Freizeit';
      case ExpenseCategory.housing:
        return 'Wohnen';
      case ExpenseCategory.other:
        return 'Sonstiges';
    }
  }

  Color _categoryColor(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.groceries:
        return const Color(0xFF1D4ED8);
      case ExpenseCategory.baby:
        return const Color(0xFF7C3AED);
      case ExpenseCategory.deposit:
        return const Color(0xFF0F766E);
      case ExpenseCategory.personal:
        return const Color(0xFFB45309);
      case ExpenseCategory.transport:
        return const Color(0xFF0F766E);
      case ExpenseCategory.health:
        return const Color(0xFFDC2626);
      case ExpenseCategory.leisure:
        return const Color(0xFFDB2777);
      case ExpenseCategory.housing:
        return const Color(0xFF475569);
      case ExpenseCategory.other:
        return const Color(0xFF64748B);
    }
  }
}

class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({
    required this.selected,
    required this.onSelected,
    required this.labelBuilder,
    required this.colorBuilder,
  });

  final ExpenseCategory? selected;
  final ValueChanged<ExpenseCategory?> onSelected;
  final String Function(ExpenseCategory category) labelBuilder;
  final Color Function(ExpenseCategory category) colorBuilder;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_t('all')),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          ...ExpenseCategory.values.map(
            (category) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(labelBuilder(category)),
                selected: selected == category,
                selectedColor: colorBuilder(category).withValues(alpha: 0.18),
                onSelected: (_) => onSelected(category),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptDraftItem {
  const _ReceiptDraftItem({
    required this.title,
    required this.amount,
    required this.category,
    required this.paidById,
    required this.splitType,
    required this.customSplit,
  });

  final String title;
  final double amount;
  final ExpenseCategory category;
  final String paidById;
  final ExpenseSplitType splitType;
  final Map<String, double>? customSplit;

  _ReceiptDraftItem copyWith({
    String? title,
    double? amount,
    ExpenseCategory? category,
    String? paidById,
    ExpenseSplitType? splitType,
    Map<String, double>? customSplit,
  }) {
    return _ReceiptDraftItem(
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      paidById: paidById ?? this.paidById,
      splitType: splitType ?? this.splitType,
      customSplit: customSplit ?? this.customSplit,
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.selectedMonth,
    required this.options,
    required this.onChanged,
  });

  final DateTime selectedMonth;
  final List<DateTime> options;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final display = DateFormat('MMMM yyyy', 'de_DE');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded, size: 18),
          const SizedBox(width: 8),
          Text(_t('finance_month')),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DateTime>(
                isExpanded: true,
                value: selectedMonth,
                items: options
                    .map(
                      (month) => DropdownMenuItem<DateTime>(
                        value: month,
                        child: Text(display.format(month)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) onChanged(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'finance_hero_title'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'finance_hero_subtitle'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceStrip extends StatelessWidget {
  const _BalanceStrip({
    required this.monthlyExpenses,
    required this.careCredits,
    required this.savingsPotential,
  });

  final double monthlyExpenses;
  final double careCredits;
  final double savingsPotential;

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.currency(locale: 'de_DE', symbol: 'EUR ');
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Nettohaushalt',
            value: format.format(monthlyExpenses),
            color: const Color(0xFF1D4ED8),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: 'Care-Bonus',
            value: format.format(careCredits),
            color: const Color(0xFF7C3AED),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: 'Sparchance',
            value: format.format(savingsPotential),
            color: const Color(0xFF0F766E),
          ),
        ),
      ],
    );
  }
}

class _MonthlyCategoryOverview extends StatelessWidget {
  const _MonthlyCategoryOverview({
    required this.familyCost,
    required this.babyCost,
    required this.personalCost,
    required this.depositValue,
    required this.savingsPotential,
    required this.formatter,
  });

  final double familyCost;
  final double babyCost;
  final double personalCost;
  final double depositValue;
  final double savingsPotential;
  final String Function(double value) formatter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStringsManager.getString(
              languageService.currentLanguage, 'finance_monthly_mix'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 160,
              child: _MetricCard(
                label: 'Familie',
                value: formatter(familyCost),
                color: const Color(0xFF1D4ED8),
              ),
            ),
            SizedBox(
              width: 160,
              child: _MetricCard(
                label: 'Baby',
                value: formatter(babyCost),
                color: const Color(0xFF7C3AED),
              ),
            ),
            SizedBox(
              width: 160,
              child: _MetricCard(
                label: 'Persoenlich',
                value: formatter(personalCost),
                color: const Color(0xFFB45309),
              ),
            ),
            SizedBox(
              width: 160,
              child: _MetricCard(
                label: 'Second-Hand',
                value: formatter(savingsPotential),
                color: const Color(0xFF0F766E),
              ),
            ),
            SizedBox(
              width: 160,
              child: _MetricCard(
                label: 'Pfand',
                value: formatter(depositValue),
                color: const Color(0xFF0F766E),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettlementCard extends StatelessWidget {
  const _SettlementCard({
    required this.mamaNet,
    required this.papaNet,
    required this.formatter,
    required this.explanation,
    required this.insights,
  });

  final double mamaNet;
  final double papaNet;
  final String Function(double value) formatter;
  final String explanation;
  final List<String> insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'finance_fair_settlement'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Formel: reale Ausgaben minus Soll-Anteil plus Care-Guthaben',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            explanation,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (insights.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...insights.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 8),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style:
                            theme.textTheme.bodySmall?.copyWith(height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _settlementRow(context, 'Mama', mamaNet),
          const SizedBox(height: 6),
          _settlementRow(context, 'Papa', papaNet),
        ],
      ),
    );
  }

  Widget _settlementRow(BuildContext context, String name, double value) {
    final color =
        value >= 0 ? const Color(0xFF0F766E) : const Color(0xFFB91C1C);
    final prefix = value >= 0 ? '+' : '-';

    return Row(
      children: [
        Expanded(
          child: Text(name, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          '$prefix ${formatter(value.abs())}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DateGroupHeader extends StatelessWidget {
  const _DateGroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _ListItemCard extends StatelessWidget {
  const _ListItemCard({
    required this.leadingIcon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.badgeText,
    this.badgeColor,
    this.onTap,
  });

  final IconData leadingIcon;
  final String title;
  final String subtitle;
  final String trailing;
  final String? badgeText;
  final Color? badgeColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              Icon(leadingIcon, size: 19, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (badgeText != null && badgeColor != null) ...[
                      const SizedBox(height: 4),
                      _InlineBadge(text: badgeText!, color: badgeColor!),
                    ],
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                trailing,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.more_horiz_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
    );
  }
}

class _InlineBadge extends StatelessWidget {
  const _InlineBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
