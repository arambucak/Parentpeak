import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:parentpeak/logic/location_autocomplete_service.dart';

/// Ergebnis des Location-Pickers.
class PickedLocation {
  final String displayName;
  final String city;
  final String postcode;
  final double lat;
  final double lon;

  const PickedLocation({
    required this.displayName,
    required this.city,
    required this.postcode,
    required this.lat,
    required this.lon,
  });
}

/// Moderner Location-Picker — 3 Wege:
/// 1. GPS "Mein Standort" (1 Tap)
/// 2. Suche mit Autocomplete
/// 3. Karte mit Pin (ziehen)
///
/// Wird als kompaktes Widget angezeigt. Tap oeffnet Bottom-Sheet mit Karte.
class LocationPickerWidget extends StatefulWidget {
  final PickedLocation? initialLocation;
  final void Function(PickedLocation) onLocationPicked;
  final String hint;

  const LocationPickerWidget({
    super.key,
    this.initialLocation,
    required this.onLocationPicked,
    this.hint = 'Standort waehlen',
  });

  @override
  State<LocationPickerWidget> createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget> {
  PickedLocation? _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _picked != null
                ? const Color(0xFF8B5CF6).withValues(alpha: 0.4)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _picked != null
                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.location_on_rounded,
              size: 18,
              color: _picked != null
                  ? const Color(0xFF8B5CF6)
                  : theme.colorScheme.outline,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _picked?.displayName ?? widget.hint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight:
                      _picked != null ? FontWeight.w600 : FontWeight.w400,
                  color: _picked != null ? null : theme.colorScheme.outline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (_picked != null && _picked!.postcode.isNotEmpty)
                Text(
                  _picked!.postcode,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
            ],
          )),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: theme.colorScheme.outline),
        ]),
      ),
    );
  }

  void _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<PickedLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LocationPickerSheet(initial: _picked),
    );
    if (result != null) {
      setState(() => _picked = result);
      widget.onLocationPicked(result);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOTTOM-SHEET mit Karte + Suche + GPS
// ═══════════════════════════════════════════════════════════════════════════════

class _LocationPickerSheet extends StatefulWidget {
  final PickedLocation? initial;
  const _LocationPickerSheet({this.initial});

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _mapCtrl = MapController();
  List<LocationSuggestion> _suggestions = [];
  bool _searching = false;
  bool _gpsLoading = false;
  Timer? _debounce;

  // Default: Berlin Mitte
  LatLng _pinPosition = const LatLng(52.520008, 13.404954);
  String _currentLabel = '';
  String _currentCity = '';
  String _currentPostcode = '';

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _pinPosition = LatLng(widget.initial!.lat, widget.initial!.lon);
      _currentLabel = widget.initial!.displayName;
      _currentCity = widget.initial!.city;
      _currentPostcode = widget.initial!.postcode;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2))),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(children: [
              Text('Standort waehlen',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                iconSize: 22,
              ),
            ]),
          ),
          // GPS Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: _gpsLoading ? null : _useGps,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  _gpsLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF16A34A)))
                      : const Icon(Icons.my_location_rounded,
                          size: 18, color: Color(0xFF16A34A)),
                  const SizedBox(width: 10),
                  Text('Mein Standort verwenden',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF16A34A))),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Stadt, Stadtteil oder PLZ suchen...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _suggestions = []);
                        })
                    : null,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFF8B5CF6), width: 1.5)),
                isDense: true,
              ),
            ),
          ),
          // Suggestions
          if (_suggestions.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                itemBuilder: (_, i) {
                  final s = _suggestions[i];
                  return ListTile(
                    dense: true,
                    leading: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          color:
                              const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.place_rounded,
                          size: 14, color: Color(0xFF8B5CF6)),
                    ),
                    title: Text(s.shortLabel,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: s.postcode.isNotEmpty
                        ? Text(s.postcode,
                            style: TextStyle(
                                fontSize: 11, color: theme.colorScheme.outline))
                        : null,
                    onTap: () => _selectSuggestion(s),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          // Map
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(children: [
                  FlutterMap(
                    mapController: _mapCtrl,
                    options: MapOptions(
                      initialCenter: _pinPosition,
                      initialZoom: 13,
                      onTap: (_, latLng) => _movePin(latLng),
                    ),
                    children: [
                      TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                      MarkerLayer(markers: [
                        Marker(
                          point: _pinPosition,
                          width: 40,
                          height: 40,
                          child: const _AnimatedPin(),
                        ),
                      ]),
                    ],
                  ),
                  // Crosshair hint
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                        child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Text(
                          'Tippe auf die Karte oder ziehe den Pin',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w500)),
                    )),
                  ),
                ]),
              ),
            ),
          ),
          // Confirm button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _currentLabel.isEmpty ? null : _confirm,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(_currentLabel.isEmpty
                      ? 'Waehle einen Ort'
                      : 'Bestaetigen: $_currentLabel'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                )),
          ),
        ]),
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    if (text.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _searching = true);
      final results = await LocationAutocompleteService.instance
          .searchImmediate(text.trim());
      if (mounted)
        setState(() {
          _suggestions = results;
          _searching = false;
        });
    });
  }

  void _selectSuggestion(LocationSuggestion s) {
    final pos = LatLng(s.lat, s.lon);
    setState(() {
      _pinPosition = pos;
      _currentLabel = s.shortLabel;
      _currentCity = s.city;
      _currentPostcode = s.postcode;
      _suggestions = [];
      _searchCtrl.text = s.shortLabel;
    });
    _mapCtrl.move(pos, 14);
  }

  void _movePin(LatLng pos) async {
    setState(() => _pinPosition = pos);
    _mapCtrl.move(pos, _mapCtrl.camera.zoom);
    // Reverse geocode
    await _reverseGeocode(pos);
  }

  Future<void> _useGps() async {
    setState(() => _gpsLoading = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Standort-Berechtigung wurde abgelehnt.')),
            );
          }
          setState(() => _gpsLoading = false);
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10)),
      );

      final pos = LatLng(position.latitude, position.longitude);
      setState(() => _pinPosition = pos);
      _mapCtrl.move(pos, 15);
      await _reverseGeocode(pos);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPS-Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    try {
      final results = await LocationAutocompleteService.instance
          .searchImmediate('${pos.latitude},${pos.longitude}');
      if (results.isNotEmpty && mounted) {
        setState(() {
          _currentLabel = results.first.shortLabel;
          _currentCity = results.first.city;
          _currentPostcode = results.first.postcode;
        });
      }
    } catch (_) {}
  }

  void _confirm() {
    Navigator.pop(
        context,
        PickedLocation(
          displayName: _currentLabel,
          city: _currentCity,
          postcode: _currentPostcode,
          lat: _pinPosition.latitude,
          lon: _pinPosition.longitude,
        ));
  }
}

// ─── Animated Pin ────────────────────────────────────────────────────────────

class _AnimatedPin extends StatefulWidget {
  const _AnimatedPin();

  @override
  State<_AnimatedPin> createState() => _AnimatedPinState();
}

class _AnimatedPinState extends State<_AnimatedPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _bounce = Tween<double>(begin: 0, end: -8)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward().then((_) => _ctrl.reverse());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounce,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _bounce.value),
        child: child,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4))
            ],
          ),
          child: const Icon(Icons.location_on_rounded,
              size: 18, color: Colors.white),
        ),
        Container(
          width: 3,
          height: 6,
          decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(2)),
        ),
      ]),
    );
  }
}
