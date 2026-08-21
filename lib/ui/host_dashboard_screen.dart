import 'package:flutter/material.dart';
import 'package:parentpeak/logic/auth_service.dart';
import 'package:parentpeak/logic/event_service.dart';
import 'package:parentpeak/logic/family_circle_service.dart';
import 'package:parentpeak/logic/participation_service.dart';
import 'package:parentpeak/models/family_contact.dart';
import 'package:parentpeak/models/meetup_event.dart';
import 'package:parentpeak/models/event_participation.dart';
import 'package:parentpeak/l10n/app_localizations_all.dart';
import 'package:parentpeak/main.dart';

class HostDashboardScreen extends StatefulWidget {
  const HostDashboardScreen({super.key});

  @override
  State<HostDashboardScreen> createState() => _HostDashboardScreenState();
}

class _HostDashboardScreenState extends State<HostDashboardScreen> {
  final _eventService = EventService();
  final _familyCircleService = FamilyCircleService.instance;

  String _t(String key) =>
      AppStringsManager.getString(languageService.currentLanguage, key);
  final _participationService = ParticipationService();

  List<MeetupEvent> _hostedEvents = [];
  List<EventParticipation> _pendingRequests = [];
  Map<String, FamilyContact> _contactsById = {};
  bool _isLoading = true;
  String? _errorMessage;

  String? get _currentUserId => AuthService.instance.currentUser?.uid;
  String get _currentUserName =>
      AuthService.instance.currentUser?.displayName ?? 'Du';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final currentHostId = _currentUserId;
    if (currentHostId == null || currentHostId.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _hostedEvents = [];
        _pendingRequests = [];
        _contactsById = {};
        _errorMessage = 'Bitte melde dich an, um dein Host-Dashboard zu sehen.';
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final myEvents = await _eventService.getDiscoverableEventsForUser(
        viewerUserId: currentHostId,
        viewerLatitude: 52.5200,
        viewerLongitude: 13.4050,
      );
      final hostedEvents =
          myEvents.where((e) => e.hosterId == currentHostId).toList();

      final requests =
          await _eventService.getPendingRequestsForHost(currentHostId);
      final contacts = await _familyCircleService.getConnectedContacts(
          userId: currentHostId);

      setState(() {
        _hostedEvents = hostedEvents;
        _pendingRequests = requests;
        _contactsById = {
          for (final contact in contacts) contact.userId: contact
        };
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  String _displayNameFor(String userId) {
    if (userId == _currentUserId) return _currentUserName;
    return _contactsById[userId]?.displayName ?? userId;
  }

  Future<void> _approveRequest(String requestId) async {
    try {
      await _participationService.approveParticipation(requestId);
      setState(() {
        _pendingRequests.removeWhere((r) => r.id == requestId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('host_request_approved'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  Future<void> _declineRequest(String requestId) async {
    try {
      await _participationService.declineParticipation(requestId);
      setState(() {
        _pendingRequests.removeWhere((r) => r.id == requestId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('host_request_declined'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('host_dashboard_title')),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Statistiken
                      _buildStatsSection(context),
                      const SizedBox(height: 24),

                      // Ausstehende Anfragen
                      _buildPendingRequestsSection(context),
                      const SizedBox(height: 24),

                      // Meine Aktivitäten
                      _buildMyEventsSection(context),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    int totalParticipants = 0;
    for (final event in _hostedEvents) {
      totalParticipants += event.currentParticipants;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistiken',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.event,
                label: 'Aktivitäten',
                value: _hostedEvents.length.toString(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.people,
                label: 'Teilnehmer',
                value: totalParticipants.toString(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.schedule,
                label: 'Ausstehend',
                value: _pendingRequests.length.toString(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingRequestsSection(BuildContext context) {
    if (_pendingRequests.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ausstehende Anfragen',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _pendingRequests.length.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber[900],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: _pendingRequests
              .map((request) => _buildRequestCard(context, request))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildRequestCard(BuildContext context, EventParticipation request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nutzer: ${_displayNameFor(request.userId)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Angefordert: ${request.requestedAt.day}.${request.requestedAt.month}.${request.requestedAt.year}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _declineRequest(request.id),
                    child: Text(_t('host_decline')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveRequest(request.id),
                    child: Text(_t('host_approve')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyEventsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Meine Aktivitäten',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        if (_hostedEvents.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'Du hast noch keine Aktivitäten erstellt',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          )
        else
          Column(
            children: _hostedEvents
                .map((event) => _buildEventCard(context, event))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildEventCard(BuildContext context, MeetupEvent event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: event.photoUrl.isEmpty ? const Color(0xFFE0F2FE) : null,
            image: event.photoUrl.isEmpty
                ? null
                : DecorationImage(
                    image: NetworkImage(event.photoUrl),
                    fit: BoxFit.cover,
                  ),
          ),
          child: event.photoUrl.isEmpty
              ? const Icon(
                  Icons.celebration_rounded,
                  color: Color(0xFF2563EB),
                )
              : null,
        ),
        title: Text(event.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${event.eventDate.day}.${event.eventDate.month}.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                Icon(Icons.people, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${event.currentParticipants}/${event.maxParticipants}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: event.status == EventStatus.active
                ? Colors.green[100]
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            event.status == EventStatus.active ? 'AKTIV' : 'BEENDET',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: event.status == EventStatus.active
                  ? Colors.green[700]
                  : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
}
