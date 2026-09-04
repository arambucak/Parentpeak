import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/localization_extension.dart';
import 'package:flutter/services.dart';
import 'package:parentpeak/logic/event_discovery_agent.dart';
import 'package:parentpeak/models/discovered_event.dart';

class EventDiscoverScreen extends StatefulWidget {
  const EventDiscoverScreen({super.key});

  @override
  State<EventDiscoverScreen> createState() => _EventDiscoverScreenState();
}

class _EventDiscoverScreenState extends State<EventDiscoverScreen> {
  final _agent = EventDiscoveryAgent.instance;
  final _cityCtrl = TextEditingController(text: 'Berlin');
  List<DiscoveredEvent> _events = [];
  bool _isLoading = false;
  String? _errorMessage;
  DiscoveredEventCategory? _selectedCategory;
  final Set<String> _interested = {};

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final city = _cityCtrl.text.trim();
    if (city.isEmpty) return;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await _agent.discoverEvents(city: city);
      if (!mounted) return;
      setState(() {
        _events = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Suche fehlgeschlagen. Bitte noch einmal versuchen.';
        _isLoading = false;
      });
    }
  }

  List<DiscoveredEvent> get _filtered {
    if (_selectedCategory == null) return _events;
    return _events.where((e) => e.category == _selectedCategory).toList();
  }

  void _toggleInterest(String id) {
    setState(() {
      if (_interested.contains(id)) {
        _interested.remove(id);
      } else {
        _interested.add(id);
      }
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(context.tr('event_discover_title')),
        backgroundColor: const Color(0xFF0C2B2E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHeader(theme),
          _buildCategoryFilter(theme),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _buildBody(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C1B1F), Color(0xFF126C69)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0C2B2E).withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Passende Angebote in deiner Stadt',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _buildSearchBar(theme),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _cityCtrl,
        onTap: () =>
            SystemChannels.textInput.invokeMethod<void>('TextInput.show'),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _search(),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.15),
          hintText: 'Stadt eingeben...',
          hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
          prefixIcon:
              const Icon(Icons.location_on_rounded, color: Colors.white70, size: 18),
          suffixIcon: IconButton(
            icon: const Icon(Icons.search_rounded,
                color: Colors.white, size: 20),
            onPressed: _search,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(ThemeData theme) {
    final categories = [
      null,
      DiscoveredEventCategory.theater,
      DiscoveredEventCategory.kino,
      DiscoveredEventCategory.sport,
      DiscoveredEventCategory.natur,
      DiscoveredEventCategory.basteln,
      DiscoveredEventCategory.musik,
      DiscoveredEventCategory.museum,
      DiscoveredEventCategory.familienzentrum,
      DiscoveredEventCategory.festival,
    ];

    return Container(
      height: 56,
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      color: const Color(0xFF0C2B2E),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length,
        itemBuilder: (context, i) {
          final cat = categories[i];
          final label = cat == null ? 'Alle' : _categoryEvent(cat).categoryLabel;
          final isSelected = _selectedCategory == cat;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(label, style: const TextStyle(fontSize: 12.5)),
              onSelected: (_) =>
                  setState(() => _selectedCategory = isSelected ? null : cat),
              backgroundColor:
                  Colors.white.withValues(alpha: 0.1),
              selectedColor: const Color(0xFF0EA5A4),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.normal,
              ),
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              visualDensity: VisualDensity.compact,
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return Center(
        key: const ValueKey('loading'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Suche Events in ${_cityCtrl.text}...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        key: const ValueKey('error'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(_errorMessage!,
                style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Erneut versuchen'),
            ),
          ],
        ),
      );
    }

    final events = _filtered;

    if (events.isEmpty) {
      return Center(
        key: const ValueKey('empty'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Keine Events gefunden.',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Neu suchen'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      key: const ValueKey('list'),
      onRefresh: _search,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: events.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _buildKiBadge(theme);
          return _buildEventCard(events[index - 1], theme);
        },
      ),
    );
  }

  Widget _buildKiBadge(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0EA5A4).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF0EA5A4).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded,
              size: 18, color: Color(0xFF0EA5A4)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Diese Events wurden automatisch für ${_cityCtrl.text} zusammengestellt. Zum Aktualisieren nach unten ziehen.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: const Color(0xFF0EA5A4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(DiscoveredEvent event, ThemeData theme) {
    final isInterested = _interested.contains(event.id);
    final color = _categoryColor(event.category);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showEventDetail(event),
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kategorie-Header
            Container(
              height: 6,
              color: color,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          event.categoryLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (event.price != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: event.price == 'kostenlos'
                                ? Colors.green.withValues(alpha: 0.1)
                                : theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            event.price!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: event.price == 'kostenlos'
                                  ? Colors.green.shade700
                                  : theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    event.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    event.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Meta-Infos
                  _buildMeta(
                      Icons.location_on_outlined, event.location, theme),
                  if (event.eventDate != null)
                    _buildMeta(Icons.calendar_today_outlined,
                        _formatDate(event.eventDate!), theme),
                  if (event.isRecurring && event.recurringNote != null)
                    _buildMeta(
                        Icons.repeat_rounded, event.recurringNote!, theme),
                  if (event.organizer != null)
                    _buildMeta(
                        Icons.business_outlined, event.organizer!, theme),
                  const SizedBox(height: 10),
                  // Altersgruppen
                  Wrap(
                    spacing: 6,
                    children: event.ageLabels
                        .map((label) => Chip(
                              label: Text(label,
                                  style: const TextStyle(fontSize: 11)),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              backgroundColor: theme
                                  .colorScheme.secondaryContainer
                                  .withValues(alpha: 0.5),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  // Aktionsleiste
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _toggleInterest(event.id),
                          icon: Icon(
                            isInterested
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 18,
                            color: isInterested
                                ? Colors.amber
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          label: Text(
                            isInterested ? 'Interessiert' : 'Interessiert?',
                            style: TextStyle(
                              fontSize: 13,
                              color: isInterested
                                  ? Colors.amber.shade700
                                  : null,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isInterested
                                  ? Colors.amber
                                  : theme.colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: () => _showEventDetail(event),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Details', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeta(IconData icon, String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  void _showEventDetail(DiscoveredEvent event) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _EventDetailSheet(
        event: event,
        isInterested: _interested.contains(event.id),
        onToggleInterest: () => _toggleInterest(event.id),
      ),
    );
  }

  Color _categoryColor(DiscoveredEventCategory cat) {
    switch (cat) {
      case DiscoveredEventCategory.theater:
        return const Color(0xFFE11D48);
      case DiscoveredEventCategory.kino:
        return const Color(0xFF7C3AED);
      case DiscoveredEventCategory.sport:
        return const Color(0xFF059669);
      case DiscoveredEventCategory.musik:
        return const Color(0xFFD97706);
      case DiscoveredEventCategory.natur:
        return const Color(0xFF16A34A);
      case DiscoveredEventCategory.basteln:
        return const Color(0xFFDB2777);
      case DiscoveredEventCategory.familienzentrum:
        return const Color(0xFF2563EB);
      case DiscoveredEventCategory.museum:
        return const Color(0xFF6B7280);
      case DiscoveredEventCategory.festival:
        return const Color(0xFFEA580C);
      case DiscoveredEventCategory.spielplatz:
        return const Color(0xFF0EA5E9);
      case DiscoveredEventCategory.sonstiges:
        return const Color(0xFF0EA5A4);
    }
  }

  DiscoveredEvent _categoryEvent(DiscoveredEventCategory cat) =>
      DiscoveredEvent(
        id: '',
        title: '',
        description: '',
        category: cat,
        ageLabels: const [],
        location: '',
        cityHint: '',
        discoveredAt: DateTime.now(),
      );

  String _formatDate(DateTime d) {
    final weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return '${weekdays[d.weekday - 1]}, ${d.day}.${d.month}.${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} Uhr';
  }
}

// ─── Detail-Sheet ─────────────────────────────────────────────────────────────

class _EventDetailSheet extends StatelessWidget {
  const _EventDetailSheet({
    required this.event,
    required this.isInterested,
    required this.onToggleInterest,
  });

  final DiscoveredEvent event;
  final bool isInterested;
  final VoidCallback onToggleInterest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Zieh-Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0EA5A4).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          event.categoryLabel,
                          style: const TextStyle(
                            color: Color(0xFF0EA5A4),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.auto_awesome_rounded,
                          size: 16, color: Color(0xFF0EA5A4)),
                      const SizedBox(width: 4),
                      Text('KI-Agent',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: const Color(0xFF0EA5A4))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    event.title,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    event.description,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 14),
                  _detailRow(Icons.location_on_rounded, 'Ort',
                      event.location, theme),
                  if (event.organizer != null)
                    _detailRow(Icons.business_rounded, 'Veranstalter',
                        event.organizer!, theme),
                  if (event.eventDate != null)
                    _detailRow(Icons.calendar_today_rounded, 'Datum',
                        _formatDate(event.eventDate!), theme),
                  if (event.isRecurring && event.recurringNote != null)
                    _detailRow(Icons.repeat_rounded, 'Wiederholung',
                        event.recurringNote!, theme),
                  if (event.price != null)
                    _detailRow(Icons.payments_outlined, 'Preis',
                        event.price!, theme),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: event.ageLabels
                        .map((l) => Chip(
                              label: Text(l,
                                  style: const TextStyle(fontSize: 12)),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () {
                        onToggleInterest();
                        Navigator.pop(context);
                      },
                      icon: Icon(isInterested
                          ? Icons.star_rounded
                          : Icons.star_border_rounded),
                      label: Text(isInterested
                          ? 'Nicht mehr interessiert'
                          : 'Ich bin interessiert'),
                      style: FilledButton.styleFrom(
                        backgroundColor: isInterested
                            ? Colors.amber
                            : null,
                        foregroundColor: isInterested
                            ? Colors.black87
                            : null,
                      ),
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

  Widget _detailRow(
      IconData icon, String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0EA5A4)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return '${weekdays[d.weekday - 1]}, ${d.day}.${d.month}.${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} Uhr';
  }
}
