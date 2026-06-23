import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../competition_providers.dart';
import '../theme/retrometer_theme.dart';
import '../utils/formatting.dart';
import '../widgets/editor_sheet.dart';
import '../widgets/form_fields.dart';
import '../widgets/location_field.dart';

/// Opens the stage editor as a full-screen page. On save, adds [existing]
/// (when editing) or a new stage to competition [competitionId].
Future<void> showStageEditor(
  BuildContext context,
  WidgetRef ref,
  String competitionId,
  PlannedStage? existing,
) async {
  final result = await Navigator.of(context).push<StageDraft>(
    MaterialPageRoute(
      builder: (context) => StageEditor(existing: existing),
    ),
  );
  if (result == null) return;
  final notifier = ref.read(competitionsProvider.notifier);
  final stage = PlannedStage(
    id: existing?.id ?? newId('stage'),
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
  String? _nameError;

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
              ? roundToMinute(DateTime.now().add(const Duration(minutes: 30)))
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
    _latCtrl = TextEditingController(text: fmtCoordNullable(_draft.latitude));
    _lngCtrl = TextEditingController(text: fmtCoordNullable(_draft.longitude));
    _radiusCtrl = TextEditingController(
        text: _draft.geofenceRadiusM.toStringAsFixed(0));
    _endLatCtrl = TextEditingController(
        text: _draft.endLatitude == null ? '' : fmtCoord(_draft.endLatitude!));
    _endLngCtrl = TextEditingController(
        text: _draft.endLongitude == null ? '' : fmtCoord(_draft.endLongitude!));
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

  /// Apply resolved coordinates to a pair of lat/lng fields, then rebuild.
  void _applyCoords(
    double lat,
    double lng, {
    required TextEditingController latCtrl,
    required TextEditingController lngCtrl,
    required void Function(double lat, double lng) setter,
  }) {
    setter(lat, lng);
    latCtrl.text = fmtCoord(lat);
    lngCtrl.text = fmtCoord(lng);
    setState(() {});
  }

  /// Apply resolved coordinates to the start location fields.
  void _setStart(double lat, double lng) => _applyCoords(
        lat,
        lng,
        latCtrl: _latCtrl,
        lngCtrl: _lngCtrl,
        setter: (la, ln) {
          _draft.latitude = la;
          _draft.longitude = ln;
        },
      );

  /// Apply resolved coordinates to the finish location fields.
  void _setEnd(double lat, double lng) => _applyCoords(
        lat,
        lng,
        latCtrl: _endLatCtrl,
        lngCtrl: _endLngCtrl,
        setter: (la, ln) {
          _draft.endLatitude = la;
          _draft.endLongitude = ln;
        },
      );

  /// Shared structure of a geofence location block (start or finish),
  /// wrapped in an [EditorSectionCard].
  Widget _geofenceSection({
    required String title,
    required String addressHint,
    required TextEditingController latCtrl,
    required TextEditingController lngCtrl,
    required TextEditingController radiusCtrl,
    required String latLabel,
    required String lngLabel,
    required String radiusLabel,
    required double radiusValue,
    required ValueChanged<double> onLatChanged,
    required ValueChanged<double> onLngChanged,
    required ValueChanged<double> onRadiusChanged,
    required void Function(double lat, double lng) onResolved,
  }) {
    return EditorSectionCard(
      title: title,
      children: [
        AddressSearchField(hintText: addressHint, onResolved: onResolved),
        Row(
          children: [
            Expanded(
              child: CoordField(
                label: latLabel,
                controller: latCtrl,
                onChanged: onLatChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CoordField(
                label: lngLabel,
                controller: lngCtrl,
                onChanged: onLngChanged,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: NumberField(
                label: radiusLabel,
                value: radiusValue,
                onChanged: (v) {
                  onRadiusChanged(v);
                  radiusCtrl.text = v.toStringAsFixed(0);
                },
                controller: radiusCtrl,
              ),
            ),
            const SizedBox(width: 8),
            MyLocationButton(onResolved: onResolved),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return EditorPageScaffold(
      title: widget.existing == null ? 'Stage nou' : 'Editare stage',
      onSave: _save,
      children: [
        EditorSectionCard(
          title: 'Identitate & timp',
          children: [
            LabeledTextField(
              controller: _nameCtrl,
              label: 'Nume',
              errorText: _nameError,
              onChanged: (v) {
                _draft.name = v;
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            DateTimeField(
              value: _draft.startTime,
              onChanged: (dt) => setState(() => _draft.startTime = dt),
            ),
            NumberField(
              label: 'Viteză medie țintă (km/h)',
              value: _draft.targetAvgSpeed,
              decimals: 1,
              onChanged: (v) => _draft.targetAvgSpeed = v,
            ),
            NumberField(
              label: 'Limită maximă (km/h)',
              value: _draft.maxSpeedLimit,
              decimals: 1,
              onChanged: (v) => _draft.maxSpeedLimit = v,
            ),
          ],
        ),
        _geofenceSection(
          title: 'Locație start (geofence)',
          addressHint: 'Adresă (ex. Str. Mare 12, Sibiu)',
          latCtrl: _latCtrl,
          lngCtrl: _lngCtrl,
          radiusCtrl: _radiusCtrl,
          latLabel: 'Lat',
          lngLabel: 'Lng',
          radiusLabel: 'Rază geofence (m)',
          radiusValue: _draft.geofenceRadiusM,
          onLatChanged: (v) => _draft.latitude = v,
          onLngChanged: (v) => _draft.longitude = v,
          onRadiusChanged: (v) => _draft.geofenceRadiusM = v,
          onResolved: _setStart,
        ),
        EditorSectionCard(
          title: 'Traseu',
          children: [
            NumberField(
              label: 'Distanță totală (km)',
              value: _draft.totalDistanceKm,
              decimals: 2,
              controller: _distCtrl,
              onChanged: (v) => _draft.totalDistanceKm = v,
            ),
            _AllocatedTimeField(
              minController: _allocMinCtrl,
              secController: _allocSecCtrl,
              onChanged: (seconds) =>
                  _draft.allocatedTimeSeconds = seconds,
            ),
          ],
        ),
        _geofenceSection(
          title: 'Locație finală (geofence auto-stop)',
          addressHint: 'Adresă sosire (ex. Str. Mare 99, Sibiu)',
          latCtrl: _endLatCtrl,
          lngCtrl: _endLngCtrl,
          radiusCtrl: _endRadiusCtrl,
          latLabel: 'Lat final',
          lngLabel: 'Lng final',
          radiusLabel: 'Rază sosire (m)',
          radiusValue: _draft.endGeofenceRadiusM,
          onLatChanged: (v) => _draft.endLatitude = v,
          onLngChanged: (v) => _draft.endLongitude = v,
          onRadiusChanged: (v) => _draft.endGeofenceRadiusM = v,
          onResolved: _setEnd,
        ),
        EditorSectionCard(
          title: 'Declanșare auto',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Auto-stop la ajungere în geofence',
                  style: TextStyle(color: context.colors.textPrimary)),
              value: _draft.autoStop,
              onChanged: (v) => setState(() => _draft.autoStop = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Auto-start (timp SAU locație)',
                  style: TextStyle(color: context.colors.textPrimary)),
              value: _draft.autoStart,
              onChanged: (v) => setState(() => _draft.autoStart = v),
            ),
            Text(
              'Auto-start are nevoie de timp sau locație de start; altfel nu '
              'se poate porni automat. Lasă coordonatele goale pentru un stage '
              'doar-pe-timp; lasă ora de start goală pentru un stage doar-pe-locație.',
              style: context.text.metaMuted,
            ),
          ],
        ),
      ],
    );
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Introdu un nume.');
      return;
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
    Navigator.of(context).pop(draft);
  }
}

/// A compact `mm:ss` allocated-time entry. Two narrow digit-only fields with a
/// shared label and a helper line noting that `0:00` means "no time limit".
/// Reports the total seconds via [onChanged] whenever either field changes.
class _AllocatedTimeField extends StatelessWidget {
  const _AllocatedTimeField({
    required this.minController,
    required this.secController,
    required this.onChanged,
  });

  final TextEditingController minController;
  final TextEditingController secController;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Timp total alocat', style: context.text.fieldLabel),
            ),
            SizedBox(
              width: 60,
              child: TextField(
                controller: minController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: context.text.fieldInput,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'min',
                  hintStyle:
                      TextStyle(color: context.colors.hint, fontSize: 12),
                ),
                onChanged: (s) {
                  final m = int.tryParse(s) ?? 0;
                  final sec = int.tryParse(secController.text) ?? 0;
                  onChanged(m * 60 + sec);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(':',
                  style: TextStyle(
                      color: context.colors.textSecondary, fontSize: 20)),
            ),
            SizedBox(
              width: 60,
              child: TextField(
                controller: secController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: context.text.fieldInput,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'sec',
                  hintStyle:
                      TextStyle(color: context.colors.hint, fontSize: 12),
                ),
                onChanged: (s) {
                  final sec = int.tryParse(s) ?? 0;
                  final m = int.tryParse(minController.text) ?? 0;
                  onChanged(m * 60 + sec);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('0:00 = fără limită de timp',
            style: context.text.metaMuted),
      ],
    );
  }
}