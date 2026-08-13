import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parentpeak/l10n/app_localizations.dart';
import '../models/trusted_device.dart';
import 'revoke_confirmation_dialog.dart';

class DeviceManagementScreen extends StatefulWidget {
  final List<TrustedDevice> devices;
  final Future<bool> Function(String deviceUuid, String deviceName) onRevoke;

  const DeviceManagementScreen(
      {Key? key, required this.devices, required this.onRevoke})
      : super(key: key);

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  late List<TrustedDevice> _devices;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _devices = widget.devices.map((d) => d).toList();
  }

  String _formatDate(BuildContext ctx, DateTime date) {
    return DateFormat.yMMMd(Localizations.localeOf(ctx).toString())
        .add_Hm()
        .format(date);
  }

  Future<void> _confirmAndRevoke(TrustedDevice device) async {
    if (device.isPriorityApprover) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).cannotRemovePriority)));
      return;
    }

    final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => RevokeConfirmationDialog(deviceName: device.deviceName));
    if (confirmed != true) return;

    setState(() => _busy.add(device.deviceUuid));
    try {
      final ok = await widget.onRevoke(device.deviceUuid, device.deviceName);
      if (ok) {
        setState(() {
          final idx = _devices.indexWhere((d) => d.deviceUuid == device.deviceUuid);
          if (idx != -1) {
            _devices[idx] = TrustedDevice(
              deviceUuid: device.deviceUuid,
              deviceName: device.deviceName,
              status: DeviceStatus.revoked,
              revokedAt: DateTime.now(),
              isPriorityApprover: device.isPriorityApprover,
            );
          }
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(AppLocalizations.of(context).deviceRemoved)),
          ]),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).deviceRemoveError),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Fehler: $e')));
    } finally {
      setState(() => _busy.remove(device.deviceUuid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final active  = _devices.where((d) => d.status == DeviceStatus.active).toList();
    final revoked = _devices.where((d) => d.status == DeviceStatus.revoked).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          // ── Hero AppBar ──
          SliverAppBar(
            expandedHeight: 175,
            pinned: true,
            backgroundColor: const Color(0xFF2563EB),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 46, 20, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.phonelink_setup_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Vertrauensgeraete',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                          Text('Zugriff verwalten und sichern',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ]),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        _statPill('${active.length} aktiv', Icons.check_circle_rounded, Colors.white),
                        const SizedBox(width: 8),
                        _statPill('${revoked.length} entfernt', Icons.block_rounded,
                          Colors.white.withValues(alpha: 0.7)),
                      ]),
                    ]),
                  ),
                ),
              ),
              title: const Text('Vertrauensgeraete',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
              titlePadding: const EdgeInsets.only(left: 54, bottom: 16),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Erklärung ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.info_rounded, color: Color(0xFF2563EB), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Vertrauensgeraete sind Smartphones oder Tablets, von denen aus euer Familienraum zugegriffen werden darf. Entfernt ihr ein Geraet, verliert es sofort den Zugriff.',
                        style: TextStyle(color: Color(0xFF1E40AF), fontSize: 13, height: 1.4),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),

                // ── Aktive Geraete ──
                if (active.isNotEmpty) ...[
                  _sectionLabel(Icons.check_circle_rounded, 'Aktive Geraete', const Color(0xFF059669)),
                  const SizedBox(height: 10),
                  ...active.map((d) => _deviceCard(d, context)),
                  const SizedBox(height: 22),
                ],

                // ── Entfernte Geraete ──
                if (revoked.isNotEmpty) ...[
                  _sectionLabel(Icons.block_rounded, 'Entfernte Geraete', Colors.black38),
                  const SizedBox(height: 10),
                  ...revoked.map((d) => _deviceCard(d, context)),
                ],

                if (_devices.isEmpty)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(children: [
                      Icon(Icons.devices_rounded, size: 52, color: Colors.black26),
                      SizedBox(height: 12),
                      Text('Keine Geraete registriert',
                        style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w600)),
                    ]),
                  )),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statPill(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _sectionLabel(IconData icon, String text, Color color) {
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 7),
      Text(text, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
    ]);
  }

  Widget _deviceCard(TrustedDevice device, BuildContext ctx) {
    final isRevoked = device.status == DeviceStatus.revoked;
    final isBusy    = _busy.contains(device.deviceUuid);

    const activeColor  = Color(0xFF059669);
    final revokedColor = Colors.red.shade400;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isRevoked
                ? Colors.red.withValues(alpha: 0.15)
                : const Color(0xFF059669).withValues(alpha: 0.15),
          ),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12, offset: const Offset(0, 4),
          )],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Icon
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: isRevoked
                    ? Colors.red.withValues(alpha: 0.08)
                    : const Color(0xFF059669).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isRevoked ? Icons.block_rounded : Icons.phone_android_rounded,
                color: isRevoked ? revokedColor : activeColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(device.deviceName,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isRevoked
                          ? Colors.red.withValues(alpha: 0.10)
                          : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        isRevoked ? Icons.block_rounded : Icons.check_circle_rounded,
                        size: 11,
                        color: isRevoked ? revokedColor : activeColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isRevoked ? 'Entfernt' : 'Aktiv',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: isRevoked ? revokedColor : activeColor,
                        ),
                      ),
                    ]),
                  ),
                ]),

                if (device.isPriorityApprover) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.star_rounded, size: 11, color: Color(0xFFD97706)),
                      SizedBox(width: 4),
                      Text('Prioritaets-Approver',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
                    ]),
                  ),
                ],

                if (isRevoked && device.revokedAt != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.access_time_rounded, size: 13, color: Colors.black38),
                    const SizedBox(width: 4),
                    Text(
                      AppLocalizations.of(ctx).removedAt(_formatDate(ctx, device.revokedAt!)),
                      style: const TextStyle(color: Colors.black45, fontSize: 12),
                    ),
                  ]),
                ],

                if (!isRevoked) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: isBusy
                        ? const Center(child: SizedBox(width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2)))
                        : OutlinedButton.icon(
                            key: Key('revoke-${device.deviceUuid}'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () => _confirmAndRevoke(device),
                            icon: const Icon(Icons.link_off_rounded, size: 17),
                            label: Text(AppLocalizations.of(ctx).removeDevice,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
