import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parentpeak/models/cooking_hub.dart';
import 'package:parentpeak/models/day_plan.dart';
import 'package:parentpeak/models/recipe.dart';

class CleanWeeklyPlannerView extends StatefulWidget {
  const CleanWeeklyPlannerView({
    super.key,
    required this.hub,
    required this.recipes,
    required this.weekPlans,
    this.onSosTap,
    this.onKitaLunchChanged,
  });

  final CookingHub hub;
  final List<Recipe> recipes;
  final List<DayPlan> weekPlans;
  final VoidCallback? onSosTap;
  final void Function(DateTime date, String kitaLunch)? onKitaLunchChanged;

  @override
  State<CleanWeeklyPlannerView> createState() => _CleanWeeklyPlannerViewState();
}

class _CleanWeeklyPlannerViewState extends State<CleanWeeklyPlannerView> {
  double _energyLevel = 0.5;
  bool _tarnModeActive = false;
  int _selectedDayIndex = 0;

  static const List<String> _weekdays = [
    'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So',
  ];
  static const List<String> _weekdaysFull = [
    'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag',
    'Freitag', 'Samstag', 'Sonntag',
  ];

  List<DateTime> get _weekDates {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  Recipe? get _todayRecipe {
    if (widget.recipes.isEmpty) return null;
    final energyIndex = ((_energyLevel * (widget.recipes.length - 1)).round())
        .clamp(0, widget.recipes.length - 1);
    return widget.recipes[energyIndex];
  }

  DayPlan? _planForDate(DateTime date) {
    for (final plan in widget.weekPlans) {
      if (_sameDay(plan.date, date)) {
        return plan;
      }
    }
    return null;
  }

  Recipe? _recipeById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final recipe in widget.recipes) {
      if (recipe.id == id) {
        return recipe;
      }
    }
    return null;
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _hubCookForDay(DateTime day) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    final userId = widget.hub.weeklyRotationalPlanner[key];
    if (userId == null) return 'Du kochst';
    const labels = {
      'mama_fatih': 'Familie Fatih',
      'mueller': 'Familie Müller',
      'kaya': 'Familie Kaya',
      'nguyen': 'Familie Nguyen',
    };
    return labels[userId] ?? userId;
  }

  bool _isTodayDate(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final dates = _weekDates;
    final recipe = _todayRecipe;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A2A3A),
        title: const Text(
          'Dein Wochenplan',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          if (widget.onSosTap != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: TextButton.icon(
                onPressed: widget.onSosTap,
                icon: const Icon(Icons.sos_rounded,
                    color: Color(0xFFD91022), size: 18),
                label: const Text(
                  'SOS',
                  style: TextStyle(
                    color: Color(0xFFD91022),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildQuickActions(),
          const SizedBox(height: 20),
          _buildWeekDaySelector(dates),
          const SizedBox(height: 16),
          _buildSelectedDayDetail(dates[_selectedDayIndex], recipe),
          const SizedBox(height: 20),
          _buildWeekOverview(dates),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final dayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todaysCook = widget.hub.weeklyRotationalPlanner[dayKey];
    const labels = {
      'mama_fatih': 'Familie Fatih',
      'mueller': 'Familie Müller',
      'kaya': 'Familie Kaya',
      'nguyen': 'Familie Nguyen',
    };
    final hubLabel = todaysCook != null
        ? (labels[todaysCook] ?? todaysCook)
        : 'Du bist dran';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Schnelleinstellungen',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8395A7),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 14),
          _buildEnergySlider(),
          const SizedBox(height: 14),
          _buildGuerillaToogle(),
          const SizedBox(height: 14),
          _buildHubStatusRow(hubLabel),
        ],
      ),
    );
  }

  Widget _buildEnergySlider() {
    final labels = ['Erschöpft', 'Ok', 'Topfit'];
    final idx = (_energyLevel * 2).round().clamp(0, 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.battery_charging_full_rounded,
                    size: 16, color: Color(0xFF3B72E8)),
                SizedBox(width: 6),
                Text(
                  'Wie fit bist du heute?',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1A2A3A),
                  ),
                ),
              ],
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F0FF),
                borderRadius: BorderRadius.all(Radius.circular(99)),
              ),
              child: Text(
                labels[idx],
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3B72E8),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: const Color(0xFF3B72E8),
            inactiveTrackColor: const Color(0xFFE2E8F4),
            thumbColor: const Color(0xFF3B72E8),
            overlayColor: const Color(0x223B72E8),
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            min: 0,
            max: 1,
            value: _energyLevel,
            onChanged: (value) => setState(() => _energyLevel = value),
          ),
        ),
      ],
    );
  }

  Widget _buildGuerillaToogle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Row(
          children: [
            Icon(Icons.eco_rounded, size: 16, color: Color(0xFF2E9E5B)),
            SizedBox(width: 6),
            Text(
              'Gemüse-Tarnmodus',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF1A2A3A),
              ),
            ),
          ],
        ),
        Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _tarnModeActive ? 'Aktiv' : 'Inaktiv',
                key: ValueKey<bool>(_tarnModeActive),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _tarnModeActive
                      ? const Color(0xFF2E9E5B)
                      : const Color(0xFF8395A7),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Switch.adaptive(
              value: _tarnModeActive,
              activeTrackColor: const Color(0xFF2E9E5B),
              onChanged: (value) => setState(() => _tarnModeActive = value),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHubStatusRow(String hubLabel) {
    return Row(
      children: [
        const Icon(Icons.people_rounded, size: 16, color: Color(0xFF8B5CF6)),
        const SizedBox(width: 6),
        const Text(
          'Koch-Hub heute:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF1A2A3A),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            hubLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF8B5CF6),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildWeekDaySelector(List<DateTime> dates) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final date = dates[index];
          final isToday = _isTodayDate(date);
          final isSelected = index == _selectedDayIndex;

          return GestureDetector(
            onTap: () => setState(() => _selectedDayIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              width: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF3B72E8)
                    : isToday
                        ? const Color(0xFFE8F0FF)
                        : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isSelected
                    ? [
                        const BoxShadow(
                          color: Color(0x333B72E8),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekdays[index],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF8395A7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color:
                          isSelected ? Colors.white : const Color(0xFF1A2A3A),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedDayDetail(DateTime date, Recipe? fallbackRecipe) {
    final cookLabel = _hubCookForDay(date);
    final dayName = _weekdaysFull[date.weekday - 1];
    final plan = _planForDate(date);
    final plannedRecipe = _recipeById(plan?.dinnerRecipeId);
    final recipe = plannedRecipe ?? fallbackRecipe;
    final recipeName = recipe != null
      ? (_tarnModeActive
        ? '${recipe.title} (Tarnmodus aktiv)'
        : recipe.title)
      : 'Noch kein Rezept geplant';
    final kitaLunch = (plan?.kitaLunch.trim() ?? '').isEmpty
      ? 'Kein Kita-Mittag hinterlegt'
      : 'Kita: ${plan!.kitaLunch.trim()}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B72E8), Color(0xFF6A9CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x333B72E8),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dayName,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            recipeName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.people_rounded, color: Colors.white70, size: 14),
              const SizedBox(width: 5),
              Text(
                cookLabel,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              if (recipe != null) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${recipe.durationMinutes} Min.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            kitaLunch,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekOverview(List<DateTime> dates) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Die ganze Woche',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A2A3A),
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(7, (index) {
          final date = dates[index];
          final isToday = _isTodayDate(date);
          final cookLabel = _hubCookForDay(date);
          final dayName = _weekdaysFull[date.weekday - 1];
          final plan = _planForDate(date);
          final recipe = _recipeById(plan?.dinnerRecipeId);
          final mealLabel = recipe?.title ?? 'Noch kein Abendessen geplant';
          final kitaLunch = (plan?.kitaLunch.trim() ?? '').isEmpty
              ? 'Kita: -'
              : 'Kita: ${plan!.kitaLunch.trim()}';

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isToday ? const Color(0xFFE8F0FF) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: isToday
                  ? Border.all(color: const Color(0xFF3B72E8), width: 1.5)
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
              onTap: () => setState(() => _selectedDayIndex = index),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isToday
                      ? const Color(0xFF3B72E8)
                      : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color:
                          isToday ? Colors.white : const Color(0xFF1A2A3A),
                    ),
                  ),
                ),
              ),
              title: Text(
                dayName,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isToday
                      ? const Color(0xFF3B72E8)
                      : const Color(0xFF1A2A3A),
                ),
              ),
              subtitle: Text(
                '$cookLabel\n$mealLabel\n$kitaLunch',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8395A7),
                ),
                maxLines: 3,
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFCBD5E1),
                size: 20,
              ),
            )
            ),
          );
        }),
      ],
    );
  }
}
