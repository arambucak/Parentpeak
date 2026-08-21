import 'dart:async';

import 'package:flutter/material.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';
import 'package:parentpeak/logic/kettenbrecher_ai_service.dart';
import 'package:parentpeak/logic/kettenbrecher_backend_service.dart';
import 'package:parentpeak/logic/kettenbrecher_service.dart';
import 'package:parentpeak/logic/weekly_planner_storage_service.dart';
import 'package:parentpeak/models/cooking_hub.dart';
import 'package:parentpeak/models/day_plan.dart';
import 'package:parentpeak/models/guerilla_recipe.dart';
import 'package:parentpeak/models/kitchen_sos.dart';
import 'package:parentpeak/models/kitchen_sos_response.dart';
import 'package:parentpeak/models/local_help_profile.dart';
import 'package:parentpeak/models/recipe.dart';
import 'package:parentpeak/ui/next_gen_food_feed.dart';
import 'package:parentpeak/ui/weekly_planner_screen.dart';
import 'package:parentpeak/ui/widgets/clean_weekly_planner_view.dart';
import 'package:parentpeak/ui/widgets/meal_planner_card.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';

class KettenbrecherDashboard extends StatefulWidget {
  const KettenbrecherDashboard({super.key});

  @override
  State<KettenbrecherDashboard> createState() => _KettenbrecherDashboardState();
}

class _KettenbrecherDashboardState extends State<KettenbrecherDashboard> {
  static const String _me = 'mama_fatih';
  static const GeoCoordinates _myLocation = GeoCoordinates(
    latitude: 52.5200,
    longitude: 13.4050,
  );

  double _tarnLevel = 55;
  bool _loading = true;
  bool _aiGenerating = false;
  KitchenSos? _activeSos;
  Map<String, dynamic>? _lastSosPushPayload;
  String? _syncInfo;
  Timer? _syncInfoClearTimer;

  String _t(String key) =>
      AppStringsManager.getString(languageService.currentLanguage, key);

  final KettenbrecherService _service = const KettenbrecherService();
  final KettenbrecherAiService _aiService = KettenbrecherAiService();
  late final KettenbrecherBackendService _backend;
  late final WeeklyPlannerStorageService _plannerStorage;
  final TextEditingController _promptController = TextEditingController(
    text: 'Bitte sehr cremig, ohne sichtbare Gemuesestuecke und tomatig.',
  );

  late final Recipe _baseRecipe = _buildBaseRecipe();
  late GuerillaRecipe _recipe = _buildInitialRecipe();
  late CookingHub _hub = _buildInitialHub();
  List<DayPlan> _weekPlans = const [];
  List<LocalHelpProfile> _helpProfiles = [];
  final Map<String, KitchenSosResponse> _responderStates = {};

  @override
  void initState() {
    super.initState();
    _backend = BackendServiceFactory.createKettenbrecherBackendService();
    _plannerStorage = BackendServiceFactory.createWeeklyPlannerStorageService();
    _bootstrap();
  }

  @override
  void dispose() {
    _syncInfoClearTimer?.cancel();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todayPlan = _planForDate(DateTime.now());
    final todayRecipe = _recipeForPlan(todayPlan);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final contentMaxWidth = viewportWidth >= 1280
        ? 1040.0
        : viewportWidth >= 980
            ? 920.0
            : double.infinity;
    final horizontalPadding = viewportWidth >= 980 ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFD),
        elevation: 0,
        foregroundColor: const Color(0xFF1A2A3A),
        title: const Text(
          'Essensplaner X',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                horizontalPadding, 4, horizontalPadding, 32),
            children: [
              if (_loading) const LinearProgressIndicator(),
              if (_syncInfo != null && _syncInfo!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildSyncBanner(_syncInfo!),
                ),
              const SizedBox(height: 12),
              _buildPageHeader(),
              const SizedBox(height: 16),
              MealPlannerCard(
                hub: _hub,
                kitaStatus: _deriveKitaHarmonyStatus(
                  todayPlan: todayPlan,
                  todayRecipe: todayRecipe,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CleanWeeklyPlannerView(
                      hub: _hub,
                      recipes: [_baseRecipe, _recipe],
                      weekPlans: _weekPlans,
                      onSosTap: _triggerSos,
                    ),
                  ),
                ),
                onSosTap: _triggerSos,
              ),
              const SizedBox(height: 16),
              _buildActionRow(),
              const SizedBox(height: 16),
              _buildGuerillaCard(),
              if (_activeSos != null) ...[
                const SizedBox(height: 10),
                _buildSosResponseCard(_activeSos!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
    });

    final fallbackHub = _buildInitialHub();
    const fallbackProfiles = <LocalHelpProfile>[];
    final weekStart = _currentWeekStart();
    final fallbackWeekPlans = _emptyWeekPlans(weekStart);

    final loadedHub = await _backend.loadCookingHub(fallbackHub: fallbackHub);
    final loadedProfiles = await _backend.loadLocalHelpProfiles(
      fallbackProfiles: fallbackProfiles,
    );
    final loadedWeekPlans = await _plannerStorage.loadWeek(weekStart);

    if (!mounted) return;

    final syncMessage = _backend.lastSyncError ?? _plannerStorage.lastSyncError;

    setState(() {
      _hub = loadedHub;
      _helpProfiles = loadedProfiles;
      _weekPlans =
          loadedWeekPlans.isNotEmpty ? loadedWeekPlans : fallbackWeekPlans;
      _syncInfo = syncMessage;
      _loading = false;
    });
    _scheduleSyncInfoAutoClear(_syncInfo);
  }

  DateTime _currentWeekStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
  }

  List<DayPlan> _emptyWeekPlans(DateTime weekStart) {
    return List<DayPlan>.generate(
      7,
      (index) {
        final date = weekStart.add(Duration(days: index));
        return DayPlan(
          date: date,
          dinnerRecipeId: null,
          kitaLunch: '',
          isChaosDay: false,
          leftoverCode: null,
        );
      },
    );
  }

  DayPlan? _planForDate(DateTime date) {
    for (final plan in _weekPlans) {
      if (_sameDay(plan.date, date)) {
        return plan;
      }
    }
    return null;
  }

  Recipe? _recipeForPlan(DayPlan? plan) {
    final recipeId = plan?.dinnerRecipeId;
    if (recipeId == null || recipeId.isEmpty) return null;

    for (final recipe in [_baseRecipe, _recipe]) {
      if (recipe.id == recipeId) {
        return recipe;
      }
    }

    return null;
  }

  KitaHarmonyStatus _deriveKitaHarmonyStatus({
    required DayPlan? todayPlan,
    required Recipe? todayRecipe,
  }) {
    if (todayPlan == null) return KitaHarmonyStatus.unbekannt;

    final lunchText = todayPlan.kitaLunch.trim();
    if (lunchText.isEmpty) return KitaHarmonyStatus.unbekannt;
    if (todayRecipe == null) return KitaHarmonyStatus.unbekannt;

    final dinnerCategory = _categorizeMealText(todayRecipe.title);
    final lunchCategory = _categorizeMealText(lunchText);
    if (dinnerCategory.isEmpty || lunchCategory.isEmpty) {
      return KitaHarmonyStatus.unbekannt;
    }

    if (dinnerCategory == lunchCategory) {
      return KitaHarmonyStatus.ueberschneidung;
    }

    return KitaHarmonyStatus.harmonisch;
  }

  String _categorizeMealText(String value) {
    final text = value.toLowerCase();
    if (text.contains('reis') || text.contains('milchreis')) return 'reis';
    if (text.contains('pasta') || text.contains('nudel')) return 'pasta';
    if (text.contains('kartoffel')) return 'kartoffel';
    if (text.contains('suppe') || text.contains('eintopf')) return 'suppe';
    if (text.contains('pizza')) return 'pizza';
    return '';
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildPageHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weniger Stress\nbeim Abendessen',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A2A3A),
            height: 1.25,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Einfach planen, Nachbarn einbinden und im Notfall schnell Hilfe bekommen.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF8395A7),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2D62F0),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NextGenFoodFeedScreen()),
            ),
            icon: const Icon(Icons.ondemand_video_rounded, size: 18),
            label: Text(_t('ketten_community_feed')),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WeeklyPlannerScreen()),
            ),
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            label: Text(_t('ketten_weekly_plan')),
          ),
        ),
      ],
    );
  }

  Widget _buildGuerillaCard() {
    final steps = _visibleTarnSteps(_recipe, _tarnLevel);

    return _sectionFrame(
      title: '1) Rezept kinderfreundlich machen',
      subtitle: 'Einfach anpassen',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wie stark soll das Gemuese „unsichtbar“ sein?',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFEF6A3A),
                    thumbColor: const Color(0xFFB63E16),
                    overlayColor: const Color(0x33EF6A3A),
                  ),
                  child: Slider(
                    min: 0,
                    max: 100,
                    value: _tarnLevel,
                    onChanged: (value) {
                      setState(() {
                        _tarnLevel = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4DA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_tarnLevel.round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Rezept: ${_recipe.title}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _promptController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Dein Wunsch',
              hintText: 'z. B. cremig, keine Stuecke, tomatig',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(240, 46),
              ),
              onPressed: _regenerateFromPrompt,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(_t('ketten_regenerate')),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(220, 44),
              ),
              onPressed: _aiGenerating || !_aiService.isAvailable
                  ? null
                  : _regenerateFromGemini,
              icon: _aiGenerating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.psychology_alt_rounded),
              label: Text(
                _aiService.isAvailable
                    ? 'Mehr Ideen mit KI'
                    : 'KI nicht verfuegbar',
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (steps.isEmpty)
            Text(_t('ketten_recipe_unchanged'))
          else
            ...steps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3EE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${step.hiddenIngredient} unauffaellig einbauen',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text('So geht\'s: ${step.camouflageMethod}'),
                      Text('Konsistenz: ${step.textureHint}'),
                      Text('Optik: ${step.colorHint}'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSosResponseCard(KitchenSos sos) {
    final responders = _service.findTrustedNearbyResponders(
      requesterUserId: _me,
      senderLocation: sos.geoCoordinates,
      allParents: _nearbyParentsForSos(),
      helpProfiles: _helpProfiles,
      radiusMeters: 500,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFFFEDEE),
        border: Border.all(color: const Color(0xFFFFCFD3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SOS gesendet',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text('Empfaenger im 500m Radius: ${responders.length} Eltern'),
          if (_lastSosPushPayload != null) ...[
            const SizedBox(height: 4),
            Text('Push-Prioritaet: ${_lastSosPushPayload!['priority']}'),
            Text(
                'Dispatch: ${_lastSosPushPayload!['dispatchStatus'] ?? 'sent'}'),
            if ((_lastSosPushPayload!['dispatchStatus']?.toString() ?? '') ==
                'local_only')
              const Text(
                'Hinweis: Backend derzeit nicht erreichbar, SOS wurde lokal vorgemerkt.',
                style: TextStyle(
                    color: Color(0xFF8A4B00), fontWeight: FontWeight.w600),
              ),
          ],
          const SizedBox(height: 8),
          ...responders.take(3).map(
                (id) => _buildResponderStatusRow(sos, id),
              ),
        ],
      ),
    );
  }

  Widget _buildSyncBanner(String message) {
    final severity = _syncSeverity(message);
    final colors = _syncBannerColors(severity);
    final icon = _syncBannerIcon(severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.$2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colors.$3),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.$4, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: _clearSyncInfo,
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            tooltip: 'Hinweis schliessen',
            icon: Icon(Icons.close_rounded, color: colors.$3),
          ),
        ],
      ),
    );
  }

  Widget _buildResponderStatusRow(KitchenSos sos, String responderId) {
    final state = _responderStates[responderId];
    final statusLabel = state == null ? 'pending' : state.status.name;
    final etaText =
        state?.etaMinutes == null ? '' : ' · ETA ${state!.etaMinutes}m';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ${_displayName(responderId)} ($statusLabel$etaText)'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              ActionChip(
                label: Text(_t('ketten_accept')),
                onPressed: () => _updateResponderAction(
                  sos: sos,
                  responderUserId: responderId,
                  status: KitchenSosResponseStatus.accepted,
                  etaMinutes: 10,
                ),
              ),
              ActionChip(
                label: Text(_t('ketten_on_way')),
                onPressed: () => _updateResponderAction(
                  sos: sos,
                  responderUserId: responderId,
                  status: KitchenSosResponseStatus.enRoute,
                  etaMinutes: 6,
                ),
              ),
              ActionChip(
                label: Text(_t('ketten_done')),
                onPressed: () => _updateResponderAction(
                  sos: sos,
                  responderUserId: responderId,
                  status: KitchenSosResponseStatus.resolved,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionFrame({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF516072)),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Future<void> _triggerSos() async {
    final now = DateTime.now();
    final sos = KitchenSos(
      id: 'sos-${now.millisecondsSinceEpoch}',
      senderId: _me,
      geoCoordinates: _myLocation,
      status: KitchenSosStatus.active,
      createdAt: now,
    );

    final responders = _service.findTrustedNearbyResponders(
      requesterUserId: _me,
      senderLocation: sos.geoCoordinates,
      allParents: _nearbyParentsForSos(),
      helpProfiles: _helpProfiles,
      radiusMeters: 500,
    );

    final dispatchResult = await _backend.triggerKitchenSos(
      sos: sos,
      recipientUserIds: responders,
      radiusMeters: 500,
    );

    if (!mounted) return;

    setState(() {
      _activeSos = sos;
      _syncInfo = _backend.lastSyncError ??
          _dispatchFeedback(_extractDispatchStatus(dispatchResult));
      _lastSosPushPayload = _service.prepareSosPushPayload(
        sos: sos,
        recipientUserIds: responders,
        radiusMeters: 500,
      );
      _lastSosPushPayload!['dispatchStatus'] =
          _extractDispatchStatus(dispatchResult);
      _responderStates.clear();
      for (final responder in responders) {
        _responderStates[responder] = KitchenSosResponse(
          sosId: sos.id,
          responderUserId: responder,
          status: KitchenSosResponseStatus.pending,
          updatedAt: DateTime.now(),
        );
      }
    });
    _scheduleSyncInfoAutoClear(_syncInfo);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          responders.isEmpty
              ? 'SOS gesetzt, aber aktuell keine vertrauensbasierten Helfer im Radius.'
              : 'SOS versendet. ${responders.length} vertrauensbasierte Helfer informiert.',
        ),
      ),
    );
  }

  void _regenerateFromPrompt() {
    final prompt = _promptController.text.trim();
    final promptRecipe = _service.generateGuerillaRecipeFromPrompt(
      baseRecipe: _baseRecipe,
      parentPrompt: prompt,
      candidateHealthyIngredients: const [
        'zucchini',
        'linsen',
        'spinat',
        'karotte'
      ],
    );

    setState(() {
      _recipe = promptRecipe;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Neuer Vorschlag ist bereit (${promptRecipe.aiTarnMapping.length} Schritte).'),
      ),
    );
  }

  Future<void> _regenerateFromGemini() async {
    setState(() {
      _aiGenerating = true;
    });

    final rawJson = await _aiService.generateGuerillaMappingJson(
      baseRecipeTitle: _baseRecipe.title,
      parentPrompt: _promptController.text.trim(),
      candidateIngredients: const ['zucchini', 'linsen', 'spinat', 'karotte'],
    );

    if (!mounted) return;

    if (rawJson == null || rawJson.trim().isEmpty) {
      setState(() {
        _aiGenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_t('ketten_ai_failed'))),
      );
      return;
    }

    final parsed = _service.generateGuerillaRecipeFromGeminiJson(
      baseRecipe: _baseRecipe,
      jsonText: rawJson,
    );

    setState(() {
      _aiGenerating = false;
      if (parsed != null) {
        _recipe = parsed;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          parsed == null
              ? 'Die KI-Antwort war nicht nutzbar. Bitte erneut versuchen.'
              : 'KI-Vorschlag uebernommen (${parsed.aiTarnMapping.length} Schritte).',
        ),
      ),
    );
  }

  Future<void> _updateResponderAction({
    required KitchenSos sos,
    required String responderUserId,
    required KitchenSosResponseStatus status,
    int? etaMinutes,
  }) async {
    final updated = await _backend.updateKitchenSosResponderAction(
      sosId: sos.id,
      responderUserId: responderUserId,
      status: status,
      etaMinutes: etaMinutes,
    );

    if (!mounted) return;

    setState(() {
      _responderStates[responderUserId] = updated;
      _syncInfo = _backend.lastSyncError ?? _responderFeedback(updated.status);
    });
    _scheduleSyncInfoAutoClear(_syncInfo);

    final syncInfo = _backend.lastSyncError;
    if (syncInfo != null && syncInfo.contains('409')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Konflikt beim Status-Update. Bitte kurz aktualisieren und erneut tippen.'),
        ),
      );
    }
  }

  String _extractDispatchStatus(Map<String, dynamic> result) {
    final direct = result['status']?.toString();
    if (direct != null && direct.trim().isNotEmpty) {
      return direct;
    }

    final nested = result['dispatchStatus']?.toString();
    if (nested != null && nested.trim().isNotEmpty) {
      return nested;
    }

    return 'sent';
  }

  String _dispatchFeedback(String status) {
    if (status == 'local_only') {
      return 'SOS lokal vorgemerkt. Backend aktuell nicht erreichbar.';
    }
    return 'SOS erfolgreich an verfuegbare Helfer verteilt.';
  }

  String _responderFeedback(KitchenSosResponseStatus status) {
    switch (status) {
      case KitchenSosResponseStatus.pending:
        return 'Responder-Status: ausstehend.';
      case KitchenSosResponseStatus.accepted:
        return 'Responder hat die Hilfe angenommen.';
      case KitchenSosResponseStatus.enRoute:
        return 'Responder ist unterwegs.';
      case KitchenSosResponseStatus.resolved:
        return 'SOS-Unterstuetzung wurde als erledigt markiert.';
    }
  }

  _SyncBannerSeverity _syncSeverity(String message) {
    final text = message.toLowerCase();
    if (text.contains('500') || text.contains('serverfehler')) {
      return _SyncBannerSeverity.error;
    }
    if (text.contains('409') ||
        text.contains('konflikt') ||
        text.contains('404') ||
        text.contains('400') ||
        text.contains('lokal aktiv') ||
        text.contains('lokal vorgemerkt') ||
        text.contains('lokal ausgeliefert')) {
      return _SyncBannerSeverity.warning;
    }
    return _SyncBannerSeverity.info;
  }

  void _scheduleSyncInfoAutoClear(String? message) {
    _syncInfoClearTimer?.cancel();

    final normalized = message?.trim() ?? '';
    if (normalized.isEmpty) return;
    if (_syncSeverity(normalized) != _SyncBannerSeverity.info) return;

    _syncInfoClearTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      if ((_syncInfo?.trim() ?? '') != normalized) return;
      _clearSyncInfo();
    });
  }

  void _clearSyncInfo() {
    _syncInfoClearTimer?.cancel();
    if (!mounted || _syncInfo == null) return;
    setState(() {
      _syncInfo = null;
    });
  }

  (Color, Color, Color, Color) _syncBannerColors(_SyncBannerSeverity severity) {
    switch (severity) {
      case _SyncBannerSeverity.error:
        return (
          const Color(0xFFFFECEF),
          const Color(0xFFFFB8C1),
          const Color(0xFFAF1028),
          const Color(0xFF6E1020),
        );
      case _SyncBannerSeverity.warning:
        return (
          const Color(0xFFFFF5E8),
          const Color(0xFFFFD7A1),
          const Color(0xFF9A5B00),
          const Color(0xFF6D4707),
        );
      case _SyncBannerSeverity.info:
        return (
          const Color(0xFFEAF3FF),
          const Color(0xFFBBD8FF),
          const Color(0xFF1557B0),
          const Color(0xFF173D70),
        );
    }
  }

  IconData _syncBannerIcon(_SyncBannerSeverity severity) {
    switch (severity) {
      case _SyncBannerSeverity.error:
        return Icons.error_outline_rounded;
      case _SyncBannerSeverity.warning:
        return Icons.warning_amber_rounded;
      case _SyncBannerSeverity.info:
        return Icons.info_outline_rounded;
    }
  }

  List<AiTarnStep> _visibleTarnSteps(GuerillaRecipe recipe, double level) {
    return _service.visibleTarnSteps(recipe, level);
  }

  String _displayName(String userId) {
    const labels = {
      'mama_fatih': 'Familie Fatih',
      'mueller': 'Familie Mueller',
      'kaya': 'Familie Kaya',
      'nguyen': 'Familie Nguyen',
      'leonie': 'Leonie',
      'samir': 'Samir',
      'jasmin': 'Jasmin',
    };
    return labels[userId] ?? userId;
  }

  Map<String, GeoCoordinates> _nearbyParentsForSos() {
    return const <String, GeoCoordinates>{};
  }

  Recipe _buildBaseRecipe() {
    return const Recipe(
      id: 'guerilla-1',
      title: 'Kremige Familien-Lasagne',
      ingredients: [
        RecipeIngredient(name: 'Lasagneblaetter', amount: '250 g'),
        RecipeIngredient(name: 'Tomatensosse', amount: '500 ml'),
        RecipeIngredient(name: 'Kaese', amount: '150 g'),
      ],
      durationMinutes: 35,
      isPickEaterFriendly: true,
      isOnePot: false,
      hideVegetables: true,
    );
  }

  CookingHub _buildInitialHub() {
    return const CookingHub(
      id: 'hub-empty',
      hubName: 'Essensplaner',
      memberUserIds: [],
      weeklyRotationalPlanner: {},
    );
  }

  GuerillaRecipe _buildInitialRecipe() {
    return _service.generateGuerillaRecipe(
      baseRecipe: _baseRecipe,
      dislikedHealthyIngredients: const [],
    );
  }
}

enum _SyncBannerSeverity {
  info,
  warning,
  error,
}
