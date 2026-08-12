import 'package:flutter/material.dart';
import 'package:parentpeak/config/api_config.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/backend_service_factory.dart';

class BackendStatusScreen extends StatefulWidget {
  const BackendStatusScreen({super.key});

  @override
  State<BackendStatusScreen> createState() => _BackendStatusScreenState();
}

class _BackendStatusScreenState extends State<BackendStatusScreen> {
  bool _loading = true;
  List<_EndpointCheck> _checks = [];
  String? _baseUrl;
  bool _hasToken = false;

  String get _currentUserId =>
      AuthService.instance.currentUser?.uid ?? 'host_demo_001';

  @override
  void initState() {
    super.initState();
    _runChecks();
  }

  Future<void> _runChecks() async {
    setState(() {
      _loading = true;
      _checks = [];
      _baseUrl = APIConfig.getBackendBaseUrl();
      _hasToken = (APIConfig.getBackendApiToken() ?? '').isNotEmpty;
    });

    final apiClient = BackendServiceFactory.createApiClient();
    if (apiClient == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    final checks = <_EndpointCheck>[];

    final endpoints = <Map<String, String>>[
      {'label': 'Health', 'path': APIConfig.getBackendHealthPath()},
      {'label': 'Todos', 'path': APIConfig.getBackendTodosPath()},
      {'label': 'Shopping', 'path': APIConfig.getBackendShoppingPath()},
      {'label': 'Kalender', 'path': APIConfig.getBackendCalendarEventsPath()},
      {'label': 'Fotos', 'path': APIConfig.getBackendPhotosPath()},
      {
        'label': 'Parent Matching',
        'path': APIConfig.getBackendParentMatchingProfilesPath(),
      },
      {
        'label': 'Familienkontakte',
        'path': '${APIConfig.getBackendFamilyContactsPath()}?userId=$_currentUserId',
      },
      {'label': 'Events', 'path': APIConfig.getBackendEventsPath()},
      {
        'label': 'Event-Einladungen',
        'path': '${APIConfig.getBackendEventInvitationsPath()}?userId=$_currentUserId',
      },
      {
        'label': 'Host Invite-Only',
        'path': '${APIConfig.getBackendHostedInviteOnlyEventsPath()}?hostUserId=$_currentUserId',
      },
      {
        'label': 'Payment-Transaktionen',
        'path': '${APIConfig.getBackendPaymentsHostPath()}/$_currentUserId',
      },
    ];

    for (final endpoint in endpoints) {
      final label = endpoint['label']!;
      final path = endpoint['path']!;
      final watch = Stopwatch()..start();
      try {
        final payload = await apiClient.getJson(path);
        watch.stop();
        final shape = _payloadShape(payload);
        checks.add(_EndpointCheck(
          label: label,
          path: path,
          ok: true,
          detail: 'Erreichbar ($shape)',
          latencyMs: watch.elapsedMilliseconds,
        ));
      } catch (e) {
        watch.stop();
        checks.add(_EndpointCheck(
          label: label,
          path: path,
          ok: false,
          detail: e.toString(),
          latencyMs: watch.elapsedMilliseconds,
        ));
      }
    }

    if (!mounted) return;
    setState(() {
      _checks = checks;
      _loading = false;
    });
  }

  String _payloadShape(dynamic payload) {
    if (payload is List) return 'Liste';
    if (payload is Map) {
      final keys = payload.keys.take(4).join(', ');
      return keys.isEmpty ? 'Objekt' : 'Objekt: $keys';
    }
    return payload.runtimeType.toString();
  }

  String _tokenState() {
    return _hasToken ? 'gesetzt' : 'fehlt';
  }

  Color _summaryColor(ThemeData theme) {
    if (_checks.isEmpty) return theme.colorScheme.primary;
    final hasFailure = _checks.any((c) => !c.ok);
    return hasFailure ? theme.colorScheme.error : Colors.green[700]!;
  }

  String _summaryText() {
    if (_checks.isEmpty) {
      if ((_baseUrl ?? '').isEmpty) {
        return 'BACKEND_BASE_URL ist nicht gesetzt.';
      }
      return 'Noch keine Prüfungen ausgeführt.';
    }

    final success = _checks.where((c) => c.ok).length;
    final successfulChecks = _checks.where((c) => c.ok).toList();
    if (successfulChecks.isEmpty) {
      return '$success/${_checks.length} Endpunkte erreichbar';
    }
    final totalMs =
        successfulChecks.fold<int>(0, (sum, c) => sum + c.latencyMs);
    final avg = (totalMs / successfulChecks.length).round();
    return '$success/${_checks.length} Endpunkte erreichbar • Ø $avg ms';
  }

  Future<void> _showFoodOfferModerationPanel() async {
    final apiClient = BackendServiceFactory.createApiClient();
    if (apiClient == null) return;

    List<_FoodOfferReport> reports = const <_FoodOfferReport>[];
    var isLoading = true;
    String? errorMessage;
    String selectedFilter = 'offen';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        Future<void> loadReports(StateSetter setModalState) async {
          setModalState(() {
            isLoading = true;
            errorMessage = null;
          });
          try {
            final payload = await apiClient.getJson('/api/food-feed/reports?maxResults=50');
            final rawReports = (payload is Map<String, dynamic> ? payload['reports'] : null) as List?;
            final fetched = (rawReports ?? const [])
                .whereType<Map>()
                .map((item) => _FoodOfferReport.fromMap(Map<String, dynamic>.from(item)))
                .toList();
            setModalState(() {
              reports = fetched;
              isLoading = false;
            });
          } catch (e) {
            setModalState(() {
              errorMessage = 'Moderationsdaten konnten nicht geladen werden.';
              isLoading = false;
            });
          }
        }

        Future<void> resolveReport(
          StateSetter setModalState,
          _FoodOfferReport report,
          String action,
        ) async {
          try {
            await apiClient.postJsonAny('/api/food-feed/reports/${report.id}/resolve', {
              'action': action,
            });
            await loadReports(setModalState);
          } catch (_) {
            setModalState(() {
              errorMessage = 'Moderationsaktion konnte nicht gespeichert werden.';
            });
          }
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            if (isLoading && reports.isEmpty && errorMessage == null) {
              loadReports(setModalState);
            }

            final visibleReports = reports.where((report) {
              switch (selectedFilter) {
                case 'bearbeitet':
                  return report.isResolved;
                default:
                  return !report.isResolved;
              }
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'GemeinsamSatt Moderation',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: () => loadReports(setModalState),
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Neu laden',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hier siehst du Meldungen aus dem Versorgungs-Feed und kannst Angebote als bearbeitet oder freigegeben markieren.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    children: [
                      ChoiceChip(
                        label: const Text('Offen'),
                        selected: selectedFilter == 'offen',
                        onSelected: (_) => setModalState(() => selectedFilter = 'offen'),
                      ),
                      ChoiceChip(
                        label: const Text('Bearbeitet'),
                        selected: selectedFilter == 'bearbeitet',
                        onSelected: (_) => setModalState(() => selectedFilter = 'bearbeitet'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isLoading && reports.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else if (errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(errorMessage!),
                    )
                  else if (visibleReports.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        selectedFilter == 'bearbeitet'
                            ? 'Keine bearbeiteten Meldungen.'
                            : 'Keine offenen Meldungen.',
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 460),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: visibleReports.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final report = visibleReports[index];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        report.recipeTitle,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: report.isResolved
                                            ? const Color(0xFFD1FAE5)
                                            : const Color(0xFFFDE68A),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(report.isResolved ? 'Bearbeitet' : 'Offen'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Meldegrund: ${report.reason}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                if (report.details.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    report.details,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  'Reporter: ${report.reportedById} • ${report.createdAtLabel}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (!report.isResolved) ...[
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      OutlinedButton(
                                        onPressed: () => resolveReport(setModalState, report, 'dismissed'),
                                        child: const Text('Freigeben'),
                                      ),
                                      const SizedBox(width: 10),
                                      FilledButton(
                                        onPressed: () => resolveReport(setModalState, report, 'resolved'),
                                        child: const Text('Als bearbeitet markieren'),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backend Status'),
        actions: [
          if (_hasToken)
            IconButton(
              onPressed: _showFoodOfferModerationPanel,
              icon: const Icon(Icons.gpp_maybe_rounded),
              tooltip: 'GemeinsamSatt Moderation',
            ),
          IconButton(
            onPressed: _runChecks,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Neu pruefen',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Konfiguration',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _kv(
                    'Base URL',
                    (_baseUrl ?? '').isEmpty ? 'nicht gesetzt' : _baseUrl!,
                  ),
                  const SizedBox(height: 8),
                  _kv('API Token', _tokenState()),
                  const SizedBox(height: 8),
                  _kv('Family ID', APIConfig.getBackendFamilyId()),
                  const SizedBox(height: 8),
                  _kv('Schema Version', APIConfig.getBackendApiVersion()),
                  const SizedBox(height: 8),
                  _kv('Health Path', APIConfig.getBackendHealthPath()),
                  const SizedBox(height: 8),
                  _kv('Events Path', APIConfig.getBackendEventsPath()),
                  const SizedBox(height: 8),
                  _kv('Payments Path', APIConfig.getBackendPaymentsHostPath()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: _summaryColor(theme).withValues(alpha: 0.1),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
              leading:
                  Icon(Icons.cloud_done_rounded, color: _summaryColor(theme)),
              title: Text(
                _summaryText(),
                style: TextStyle(
                  color: _summaryColor(theme),
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text('Pruefung gegen konfigurierte Endpunkte'),
            )
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          ..._checks.map((check) {
            final color =
                check.ok ? Colors.green[700]! : theme.colorScheme.error;
            return Card(
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                leading: Icon(
                  check.ok ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: color,
                ),
                title: Text(check.label),
                subtitle: Text(
                    '${check.path}\n${check.detail}\nLatenz: ${check.latencyMs} ms'),
                isThreeLine: true,
              )
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            key,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _EndpointCheck {
  final String label;
  final String path;
  final bool ok;
  final String detail;
  final int latencyMs;

  const _EndpointCheck({
    required this.label,
    required this.path,
    required this.ok,
    required this.detail,
    required this.latencyMs,
  });
}

class _FoodOfferReport {
  final String id;
  final String recipeTitle;
  final String reportedById;
  final String reason;
  final String details;
  final String status;
  final DateTime? createdAt;

  const _FoodOfferReport({
    required this.id,
    required this.recipeTitle,
    required this.reportedById,
    required this.reason,
    required this.details,
    required this.status,
    required this.createdAt,
  });

  bool get isResolved => status == 'resolved' || status == 'dismissed';

  String get createdAtLabel {
    final value = createdAt;
    if (value == null) return 'unbekannt';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  factory _FoodOfferReport.fromMap(Map<String, dynamic> map) {
    final recipe = map['recipe'] is Map<String, dynamic>
        ? map['recipe'] as Map<String, dynamic>
        : map['recipe'] is Map
            ? Map<String, dynamic>.from(map['recipe'] as Map)
            : const <String, dynamic>{};

    return _FoodOfferReport(
      id: (map['id'] ?? '').toString(),
      recipeTitle: (recipe['title'] ?? 'Unbekanntes Angebot').toString(),
      reportedById: (map['reportedById'] ?? '').toString(),
      reason: (map['reason'] ?? '').toString(),
      details: (map['details'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      createdAt: map['createdAt'] is String
          ? DateTime.tryParse(map['createdAt'] as String)
          : null,
    );
  }
}
