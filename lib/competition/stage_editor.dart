import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../competition_providers.dart';
import '../theme/retrometer_theme.dart';
import '../widgets/form_fields.dart';
import '../widgets/location_field.dart';

/// Opens the stage editor sheet. On save, adds [existing] (when editing) or a
/// new stage to competition [competitionId].
Future<void> showStageEditor(
  BuildContext context,
  WidgetRef ref,
  String competitionId,
  PlannedStage? existing,
) async {
  final result = await showModalBottomSheet<StageDraft>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StageEditor(existing: existing),
  );
  if (result == null) return;
  final notifier = ref.read(competitionsProvider.notifier);
  final stage = PlannedStage(
    id: existing?.id ?? _newId(),
    name: result.name,
    startTime: result.startTime,
    targetAvgSpeed: result.targetAvgSpeed,
    maxSpeedLimit: result.maxSpeedLimit,
    latitude: result.latitude,
    longitude: result.longitude,
    geofenceRadiusM: result.geofenceRadiusM,
    autoStart: result.autoStart,
    started: existing?.started ?? false,
    endLatitude: result.endLatitude,
    endLongitude: result.endLongitude,
    endGeofenceRadiusM: result.endGeofenceRadiusM,
    autoStop: result.autoStop,
    totalDistanceKm: result.totalDistanceKm,
    allocatedTimeSeconds: result.allocatedTimeSeconds,
  );
  if (existing == null) {
    await notifier.addStage(competitionId, stage);
  } else {
    await notifier.updateStage(competitionId, stage);
  }
}

class StageDraft {
  StageDraft({
    required this.name,
    required this.startTime,
    required this.targetAvgSpeed,
    required this.maxSpeedLimit,
    required this.latitude,
    required this.longitude,
    required this.geofenceRadiusM,
    required this.autoStart,
    required this.endLatitude,
    required this.endLongitude,
    required this.endGeofenceRadiusM,
    required this.autoStop,
    required this.totalDistanceKm,
    required this.allocatedTimeSeconds,
  });

  String name;
  /// Scheduled start. `null` = no time trigger (location-only stage).
  DateTime? startTime;
  double targetAvgSpeed;
  double maxSpeedLimit;
  /// Start geofence centre. `null` = no location trigger (time-only stage).
  double? latitude;
  double? longitude;
  double geofenceRadiusM;
  bool autoStart;
  double? endLatitude;
  double? endLongitude;
  double endGeofenceRadiusM;
  bool autoStop;
  double totalDistanceKm;
  int allocatedTimeSeconds;
}

class StageEditor extends StatefulWidget {
  const StageEditor({super.key, this.existing});

  final PlannedStage? existing;

  @override
  State<StageEditor> createState() => _StageEditorState();
}

class _StageEditorState extends State<StageEditor> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late final TextEditingController _radiusCtrl;
  late final TextEditingController _endLatCtrl;
  late final TextEditingController _endLngCtrl;
  late final TextEditingController _endRadiusCtrl;
  late final TextEditingController _distCtrl;
  late final TextEditingController _allocMinCtrl;
  late final TextEditingController _allocSecCtrl;
  late StageDraft _draft;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _draft = StageDraft(
      name: e?.name ?? '',
      // Only default the start time when creating a new stage; when editing,
      // round-trip null (a location-only stage stays location-only).
      startTime: e?.startTime ??
          (e == null
              ? _roundToMinute(DateTime.now().add(const Duration(minutes: 30)))
              : null),
      targetAvgSpeed: e?.targetAvgSpeed ?? 40.0,
      maxSpeedLimit: e?.maxSpeedLimit ?? 60.0,
      // Round-trip null coords (a time-only stage stays time-only); don't
      // silently default to 0,0.
      latitude: e?.latitude,
      longitude: e?.longitude,
      geofenceRadiusM: e?.geofenceRadiusM ?? 200.0,
      autoStart: e?.autoStart ?? true,
      endLatitude: e?.endLatitude,
      endLongitude: e?.endLongitude,
      endGeofenceRadiusM: e?.endGeofenceRadiusM ?? 200.0,
      autoStop: e?.autoStop ?? true,
      totalDistanceKm: e?.totalDistanceKm ?? 0.0,
      allocatedTimeSeconds: e?.allocatedTimeSeconds ?? 0,
    );
    _nameCtrl = TextEditingController(text: _draft.name);
    _latCtrl = TextEditingController(text: _fmtCoordNullable(_draft.latitude));
    _lngCtrl = TextEditingController(text: _fmtCoordNullable(_draft.longitude));
    _radiusCtrl = TextEditingController(
        text: _draft.geofenceRadiusM.toStringAsFixed(0));
    _endLatCtrl = TextEditingController(
        text: _draft.endLatitude == null ? '' : _fmtCoord(_draft.endLatitude!));
    _endLngCtrl = TextEditingController(
        text: _draft.endLongitude == null ? '' : _fmtCoord(_draft.endLongitude!));
    _endRadiusCtrl = TextEditingController(
        text: _draft.endGeofenceRadiusM.toStringAsFixed(0));
    _distCtrl = TextEditingController(
      text: _draft.totalDistanceKm == 0.0
          ? ''
          : _draft.totalDistanceKm.toStringAsFixed(2),
    );
    _allocMinCtrl = TextEditingController(
        text: (_draft.allocatedTimeSeconds ~/ 60).toString());
    _allocSecCtrl = TextEditingController(
        text: (_draft.allocatedTimeSeconds % 60).toString().padLeft(2, '0'));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _radiusCtrl.dispose();
    _endLatCtrl.dispose();
    _endLngCtrl.dispose();
    _endRadiusCtrl.dispose();
    _distCtrl.dispose();
    _allocMinCtrl.dispose();
    _allocSecCtrl.dispose();
    super.dispose();
  }

  /// Apply resolved coordinates to the start location fields.
  void _setStart(double lat, double lng) {
    _draft.latitude = lat;
    _draft.longitude = lng;
    _latCtrl.text = _fmtCoord(lat);
    _lngCtrl.text = _fmtCoord(lng);
    setState(() {});
  }

  /// Apply resolved coordinates to the finish location fields.
  void _setEnd(double lat, double lng) {
    _draft.endLatitude = lat;
    _draft.endLongitude = lng;
    _endLatCtrl.text = _fmtCoord(lat);
    _endLngCtrl.text = _fmtCoord(lng);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'Stage nou' : 'Editare stage',
              style: RetrometerTextStyles.sheetTitle,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: RetrometerColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Nume'),
              onChanged: (v) => _draft.name = v,
            ),
            const SizedBox(height: 16),
            DateTimeField(
              value: _draft.startTime,
              onChanged: (dt) => setState(() => _draft.startTime = dt),
            ),
            const SizedBox(height: 16),
            NumberField(
              label: 'Viteză medie țintă (km/h)',
              value: _draft.targetAvgSpeed,
              decimals: 1,
              onChanged: (v) => _draft.targetAvgSpeed = v,
            ),
            const SizedBox(height: 16),
            NumberField(
              label: 'Limită maximă (km/h)',
              value: _draft.maxSpeedLimit,
              decimals: 1,
              onChanged: (v) => _draft.maxSpeedLimit = v,
            ),
            const SizedBox(height: 20),
            const Text('Locație start (geofence)',
                style: RetrometerTextStyles.sectionLabel),
            const SizedBox(height: 8),
            AddressSearchField(
              hintText: 'Adresă (ex. Str. Mare 12, Sibiu)',
              onResolved: _setStart,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CoordField(
                    label: 'Lat',
                    controller: _latCtrl,
                    onChanged: (v) => _draft.latitude = v,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CoordField(
                    label: 'Lng',
                    controller: _lngCtrl,
                    onChanged: (v) => _draft.longitude = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: NumberField(
                    label: 'Rază geofence (m)',
                    value: _draft.geofenceRadiusM,
                    onChanged: (v) {
                      _draft.geofenceRadiusM = v;
                      _radiusCtrl.text = v.toStringAsFixed(0);
                    },
                    controller: _radiusCtrl,
                  ),
                ),
                const SizedBox(width: 8),
                MyLocationButton(onResolved: _setStart),
              ],
            ),
            const SizedBox(height: 8),
            NumberField(
              label: 'Distanță totală (km)',
              value: _draft.totalDistanceKm,
              decimals: 2,
              controller: _distCtrl,
              onChanged: (v) => _draft.totalDistanceKm = v,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('Timp total alocat',
                      style: RetrometerTextStyles.fieldLabel),
                ),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _allocMinCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: RetrometerTextStyles.fieldInput,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'min',
                      hintStyle: TextStyle(
                          color: RetrometerColors.hint, fontSize: 12),
                    ),
                    onChanged: (s) {
                      final m = int.tryParse(s) ?? 0;
                      _draft.allocatedTimeSeconds =
                          m * 60 + (_draft.allocatedTimeSeconds % 60);
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(':',
                      style: TextStyle(
                          color: RetrometerColors.textSecondary,
                          fontSize: 20)),
                ),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _allocSecCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: RetrometerTextStyles.fieldInput,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'sec',
                      hintStyle: TextStyle(
                          color: RetrometerColors.hint, fontSize: 12),
                    ),
                    onChanged: (s) {
                      final sec = int.tryParse(s) ?? 0;
                      _draft.allocatedTimeSeconds =
                          (_draft.allocatedTimeSeconds ~/ 60) * 60 + sec;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Locație finală (geofence auto-stop)',
                style: RetrometerTextStyles.sectionLabel),
            const SizedBox(height: 8),
            AddressSearchField(
              hintText: 'Adresă sosire (ex. Str. Mare 99, Sibiu)',
              onResolved: _setEnd,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CoordField(
                    label: 'Lat final',
                    controller: _endLatCtrl,
                    onChanged: (v) => _draft.endLatitude = v,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CoordField(
                    label: 'Lng final',
                    controller: _endLngCtrl,
                    onChanged: (v) => _draft.endLongitude = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: NumberField(
                    label: 'Rază sosire (m)',
                    value: _draft.endGeofenceRadiusM,
                    onChanged: (v) {
                      _draft.endGeofenceRadiusM = v;
                      _endRadiusCtrl.text = v.toStringAsFixed(0);
                    },
                    controller: _endRadiusCtrl,
                  ),
                ),
                const SizedBox(width: 8),
                MyLocationButton(onResolved: _setEnd),
              ],
            ),
            SwitchListTile(
              dense: true,
              title: const Text('Auto-stop la ajungere în geofence',
                  style: TextStyle(color: RetrometerColors.textPrimary)),
              value: _draft.autoStop,
              onChanged: (v) => setState(() => _draft.autoStop = v),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              dense: true,
              title: const Text('Auto-start (timp SAU locație)',
                  style: TextStyle(color: RetrometerColors.textPrimary)),
              value: _draft.autoStart,
              onChanged: (v) => setState(() => _draft.autoStart = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: const Text('Salvează'),
            ),
          ],
        ),
      ),
    );
  }

  bool _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introdu un nume.')),
      );
      return false;
    }
    // Empty coord fields mean "no location set" (nullable) — same as the finish
    // coords below. This lets the crew build a time-only stage by leaving the
    // start lat/lng blank.
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    final startCoords = (lat == null || lng == null) ? null : (lat, lng);
    final endLat = double.tryParse(_endLatCtrl.text.trim());
    final endLng = double.tryParse(_endLngCtrl.text.trim());
    final draft = StageDraft(
      name: name,
      startTime: _draft.startTime,
      targetAvgSpeed: _draft.targetAvgSpeed,
      maxSpeedLimit: _draft.maxSpeedLimit,
      latitude: startCoords?.$1,
      longitude: startCoords?.$2,
      geofenceRadiusM: _draft.geofenceRadiusM,
      autoStart: _draft.autoStart,
      endLatitude: (endLat == null || endLng == null) ? null : endLat,
      endLongitude: (endLat == null || endLng == null) ? null : endLng,
      endGeofenceRadiusM: _draft.endGeofenceRadiusM,
      autoStop: _draft.autoStop,
      totalDistanceKm: _draft.totalDistanceKm,
      allocatedTimeSeconds: _draft.allocatedTimeSeconds,
    );
    // Soft warning: auto-start can't fire without at least one trigger source.
    if (draft.autoStart &&
        draft.startTime == null &&
        (draft.latitude == null || draft.longitude == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Acest stage nu se poate auto-porni fără timp sau locație.'),
        ),
      );
    }
    Navigator.of(context).pop(draft);
    return true;
  }
}

// ---------------------------------------------------------------------------
// Helpers.
// ---------------------------------------------------------------------------

String _newId() => 'stage-${DateTime.now().millisecondsSinceEpoch}';

DateTime _roundToMinute(DateTime dt) =>
    DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);

String _fmtCoord(double v) => v.toStringAsFixed(5);

String _fmtCoordNullable(double? v) => v == null ? '' : _fmtCoord(v);