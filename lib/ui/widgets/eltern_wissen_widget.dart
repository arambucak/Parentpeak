import 'package:flutter/material.dart';
import 'package:parentpeak/logic/eltern_wissen_service.dart';
import 'package:parentpeak/models/eltern_wissen_faq.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';

/// Eltern-Wissen Widget — Impuls + Schnelle Hilfe (Suchfeld).
///
/// Wird in den Impulse-Screen integriert.
/// Zeigt: 1 personalisierter Impuls oben + Suchfeld + Ergebnisse.
class ElternWissenWidget extends StatefulWidget {
  final VoidCallback? onOpenChat; // Fallback -> KI-Chat
  final String?
      initialTopic; // Vorausgefülltes Suchthema (z.B. von Soforthilfe)

  const ElternWissenWidget({super.key, this.onOpenChat, this.initialTopic});

  @override
  State<ElternWissenWidget> createState() => _ElternWissenWidgetState();
}

class _ElternWissenWidgetState extends State<ElternWissenWidget> {
  final _service = ElternWissenService.instance;
  final _searchCtrl = TextEditingController();
  ElternWissenEntry? _impuls;
  List<ElternWissenEntry> _results = [];
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _service.initialize();
    if (mounted)
      setState(() {
        _impuls = _service.getDailyImpuls();
        _initialized = true;
      });
    // Soforthilfe-Thema vorauffüllen wenn übergeben
    if (widget.initialTopic != null && widget.initialTopic!.isNotEmpty) {
      _searchCtrl.text = widget.initialTopic!;
      _onSearch(widget.initialTopic!);
    }
  }

  void _onSearch(String query) {
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    final results = _service.search(query);
    setState(() => _results = results);
  }

  static const _topicCards = [
    {
      'emoji': '\u{1F4A2}',
      'label': 'Wut & Trotz',
      'hint': 'Wutanfaelle, Hauen',
      'search': 'wut',
      'color': '0xFFDC2626'
    },
    {
      'emoji': '\u{1F634}',
      'label': 'Schlafen',
      'hint': 'Einschlafen, Nacht',
      'search': 'schlafen',
      'color': '0xFF8B5CF6'
    },
    {
      'emoji': '\u{1F6AB}',
      'label': 'Grenzen',
      'hint': 'Nein sagen, Regeln',
      'search': 'grenzen',
      'color': '0xFF2563EB'
    },
    {
      'emoji': '\u{1F35D}',
      'label': 'Essen',
      'hint': 'Picky Eater',
      'search': 'essen',
      'color': '0xFFF97316'
    },
    {
      'emoji': '\u{1F46B}',
      'label': 'Geschwister',
      'hint': 'Streit, Eifersucht',
      'search': 'geschwister',
      'color': '0xFF0EA5A4'
    },
    {
      'emoji': '\u{1F4F1}',
      'label': 'Medien',
      'hint': 'Bildschirmzeit',
      'search': 'bildschirm',
      'color': '0xFF6B21A8'
    },
  ];

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Impuls des Tages (personalisiert)
      if (_impuls != null && _results.isEmpty) _impulsCard(theme, _impuls!),
      // Themen-Karten Carousel (3-5 Karten horizontal)
      if (_results.isEmpty) ...[
        const SizedBox(height: 14),
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'common_topics'),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _topicCards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final topic = _topicCards[i];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _searchCtrl.text = topic['search']!;
                  _onSearch(topic['search']!);
                },
                child: Container(
                  width: 130,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(int.parse(topic['color']!))
                            .withValues(alpha: 0.08),
                        Color(int.parse(topic['color']!))
                            .withValues(alpha: 0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Color(int.parse(topic['color']!))
                            .withValues(alpha: 0.2)),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(topic['emoji']!,
                            style: const TextStyle(fontSize: 22)),
                        const Spacer(),
                        Text(topic['label']!,
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700, fontSize: 11)),
                        Text(topic['hint']!,
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline, fontSize: 9)),
                      ]),
                ),
              );
            },
          ),
        ),
      ],
      const SizedBox(height: 14),
      // Suchfeld
      TextField(
        controller: _searchCtrl,
        onChanged: _onSearch,
        decoration: InputDecoration(
            hintText: AppStringsManager.getString(
              languageService.currentLanguage, 'knowledge_search_hint'),
          hintStyle: TextStyle(fontSize: 13, color: theme.colorScheme.outline),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _results = []);
                  })
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Color(0xFF8B5CF6), width: 1.5)),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerLow,
        ),
      ),
      // Ergebnisse
      if (_results.isNotEmpty) ...[
        const SizedBox(height: 12),
        ..._results.map((e) => _resultCard(theme, e)),
      ],
      // Kein Ergebnis -> KI-Fallback
      if (_searchCtrl.text.trim().length >= 3 && _results.isEmpty) ...[
        const SizedBox(height: 12),
        _noResultCard(theme),
      ],
    ]);
  }

  Widget _impulsCard(ThemeData theme, ElternWissenEntry entry) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
        ),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('\u{1F4AC}', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
              AppStringsManager.getString(
                  languageService.currentLanguage, 'your_impulse_today'),
              style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700, color: const Color(0xFF16A34A))),
        ]),
        const SizedBox(height: 10),
        Text(entry.question,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(entry.akut,
            style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF166534),
                height: 1.4,
                fontStyle: FontStyle.italic)),
      ]),
    );
  }

  Widget _resultCard(ThemeData theme, ElternWissenEntry entry) {
    return _ExpandableResultCard(entry: entry);
  }

  Widget _noResultCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.15)),
      ),
      child: Column(children: [
        const Text('\u{1F914}', style: TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'no_entry_yet'),
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
            AppStringsManager.getString(
                languageService.currentLanguage, 'ask_ai_hint'),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
            textAlign: TextAlign.center),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: widget.onOpenChat,
          icon: const Icon(Icons.tips_and_updates_rounded, size: 16),
          label: Text(AppStringsManager.getString(
              languageService.currentLanguage, 'ask_ai_btn')),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF8B5CF6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
    );
  }
}

/// Ausklappbare Ergebnis-Karte (Akut-Modus + Vertiefung).
class _ExpandableResultCard extends StatefulWidget {
  final ElternWissenEntry entry;
  const _ExpandableResultCard({required this.entry});

  @override
  State<_ExpandableResultCard> createState() => _ExpandableResultCardState();
}

class _ExpandableResultCardState extends State<_ExpandableResultCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = widget.entry;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Frage + Akut-Antwort (immer sichtbar)
        Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('\u{2753} ${e.question}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('\u{1F4A1}', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(e.akut,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF9A3412),
                            fontWeight: FontWeight.w600,
                            height: 1.4))),
              ]),
            ),
          ]),
        ),
        // "Mehr erfahren" Toggle
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: _expanded
                  ? BorderRadius.zero
                  : const BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Row(children: [
              Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: const Color(0xFF8B5CF6)),
              const SizedBox(width: 6),
              Text(_expanded ? 'Weniger' : 'Ausfuehrlich verstehen',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8B5CF6))),
            ]),
          ),
        ),
        // Vertiefung (ausklappbar)
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 12),
              // Beduerfnis
              _section(theme, '\u{1F50D}', 'Was dahinter steckt', e.beduerfnis),
              const SizedBox(height: 10),
              // GfK-Satz
              _section(
                  theme, '\u{1F4AC}', 'Was du sagen kannst (GfK)', e.gfkSatz),
              const SizedBox(height: 10),
              // Aktionen
              Text(
                  AppStringsManager.getString(
                      languageService.currentLanguage, 'what_you_can_do'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              ...e.aktion.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('\u{2022} ',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF8B5CF6))),
                          Expanded(
                              child: Text(a,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(height: 1.3))),
                        ]),
                  )),
              const SizedBox(height: 10),
              // Ermutigung
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('\u{1F49A}', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(e.ermutigung,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF166534),
                                  fontStyle: FontStyle.italic,
                                  height: 1.3))),
                    ]),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _section(ThemeData theme, String emoji, String title, String text) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$emoji $title:',
          style:
              theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(text,
          style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant, height: 1.4)),
    ]);
  }
}
