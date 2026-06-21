import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../location_disclosure.dart';
import '../services/gps_service.dart';
import '../theme/retrometer_theme.dart';

/// An address text field with a search button that geocodes the typed address
/// via [locationFromAddress] and reports the resolved coordinates through
/// [onResolved]. Owns its own controller + loading/error state, so the caller
/// only needs to react to resolved coordinates (e.g. update lat/lng fields).
///
/// Offline or no-result cases surface an error line under the field.
class AddressSearchField extends StatefulWidget {
  const AddressSearchField({
    super.key,
    required this.hintText,
    required this.onResolved,
  });

  final String hintText;
  final void Function(double latitude, double longitude) onResolved;

  @override
  State<AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends State<AddressSearchField> {
  final TextEditingController _addressCtrl = TextEditingController();
  bool _geocoding = false;
  String? _error;

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _geocode() async {
    final query = _addressCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _geocoding = true;
      _error = null;
    });
    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) {
        setState(() => _error = 'Adresa nu a fost găsită.');
      } else {
        final loc = locations.first;
        widget.onResolved(loc.latitude, loc.longitude);
      }
    } on Exception {
      setState(() => _error = 'Geocodare indisponibilă (offline?).');
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addressCtrl,
                style: const TextStyle(color: RetrometerColors.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: widget.hintText,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: _geocoding
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: RetrometerColors.primary),
                    )
                  : const Icon(Icons.search, color: RetrometerColors.primary),
              tooltip: 'Caută adresă',
              onPressed: _geocoding ? null : _geocode,
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_error!, style: RetrometerTextStyles.fieldError),
          ),
      ],
    );
  }
}

/// A "Locația mea" button that requests the location disclosure + permission,
/// grabs the first GPS fix, and reports it through [onResolved]. Silently
/// leaves the coordinates unchanged if the crew refuses or no fix arrives
/// (matching the previous inline behaviour).
class MyLocationButton extends StatelessWidget {
  const MyLocationButton({
    super.key,
    required this.onResolved,
  });

  final void Function(double latitude, double longitude) onResolved;

  Future<void> _resolve(BuildContext context) async {
    // Resolve dependencies up front, before any await.
    final container = ProviderScope.containerOf(context, listen: false);
    final gps = container.read(gpsServiceProvider);
    if (!await maybeShowLocationDisclosure(context)) return;
    if (!context.mounted) return;
    if (!await gps.isLocationServiceEnabled()) return;
    var perm = await gps.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await gps.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }
    try {
      final pos =
          await gps.positionStream().first.timeout(const Duration(seconds: 10));
      onResolved(pos.latitude, pos.longitude);
    } on Exception {
      // ignore — leave coords as-is
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: const Icon(Icons.my_location, color: RetrometerColors.primary),
      label: const Text('Locația mea',
          style: TextStyle(color: RetrometerColors.primary)),
      onPressed: () => _resolve(context),
    );
  }
}