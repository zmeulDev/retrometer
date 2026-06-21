import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'models.dart';
import 'rally_math.dart';
import 'services/device_service.dart';
import 'services/gps_service.dart';

/// Owns the single active stage: its [StageConfig] and live [StageTelemetry].
///
/// Drives a high-accuracy GPS position stream while in progress, accumulating
/// distance (km) and speed (km/h). Keeps the screen awake via wakelock for the
/// duration of the stage.
class StageController extends Notifier<RallyState> {
  StreamSubscription<Position>? _positionSub;

  @override
  RallyState build() {
    final device = ref.read(deviceServiceProvider);
    ref.onDispose(() {
      _positionSub?.cancel();
      _positionSub = null;
      device.disableWakelock();
    });
    return const RallyState();
  }

  StageConfig get config => state.config;
  StageTelemetry get telemetry => state.telemetry;

  /// Update the stage configuration (name / target average / max limit).
  /// No-op while a stage is in progress.
  void updateConfig(StageConfig config) {
    if (telemetry.status == StageStatus.inProgress) return;
    state = state.copyWith(config: config);
  }

  /// Begin the stage: reset distance, record start time, enable wakelock,
  /// request location permission, and subscribe to the GPS stream.
  Future<void> startStage() async {
    if (telemetry.status == StageStatus.inProgress) return;

    final gps = ref.read(gpsServiceProvider);
    if (!await gps.isLocationServiceEnabled()) return;
    var permission = await gps.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await gps.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final start = DateTime.now();
    state = state.copyWith(
      telemetry: telemetry.copyWith(
        startTime: start,
        currentDistance: 0.0,
        currentSpeed: 0.0,
        status: StageStatus.inProgress,
      ),
    );

    await ref.read(deviceServiceProvider).enableWakelock();
    await _subscribeGps(gps);
  }

  /// Begin the stage using a planned stage's configuration (name / target /
  /// max limit), then delegates to [startStage]. Used by the auto-start
  /// monitor and by manual "start this planned stage" actions.
  Future<void> startStageFromPlan(PlannedStage plan) async {
    if (telemetry.status == StageStatus.inProgress) return;
    state = state.copyWith(
      config: StageConfig(
        id: plan.id,
        name: plan.name,
        targetAvgSpeed: plan.targetAvgSpeed,
        maxSpeedLimit: plan.maxSpeedLimit,
        endLatitude: plan.endLatitude,
        endLongitude: plan.endLongitude,
        endGeofenceRadiusM: plan.endGeofenceRadiusM,
        autoStop: plan.autoStop,
        totalDistanceKm: plan.totalDistanceKm,
        allocatedTimeSeconds: plan.allocatedTimeSeconds,
      ),
    );
    await startStage();
  }

  Future<void> _subscribeGps(GpsService gps) async {
    await _positionSub?.cancel();
    Position? last;

    _positionSub = gps.positionStream().listen((pos) async {
      final double addedMetres;
      final double speedKmh;

      if (last != null) {
        addedMetres = gps.distanceBetween(
          startLatitude: last!.latitude,
          startLongitude: last!.longitude,
          endLatitude: pos.latitude,
          endLongitude: pos.longitude,
        );
      } else {
        addedMetres = 0.0;
      }

      // position.speed is in m/s and may be NaN / -1 when unavailable.
      if (!pos.speed.isNaN && pos.speed >= 0) {
        speedKmh = pos.speed * 3.6;
      } else if (last != null) {
        final dtMs = pos.timestamp.difference(last!.timestamp).inMilliseconds;
        speedKmh = dtMs > 0
            ? (addedMetres / 1000.0) / (dtMs / 3600000.0)
            : telemetry.currentSpeed;
      } else {
        speedKmh = 0.0;
      }

      final hadPreviousFix = last != null;
      last = pos;

      state = state.copyWith(
        telemetry: telemetry.copyWith(
          currentDistance: telemetry.currentDistance + addedMetres / 1000.0,
          currentSpeed: speedKmh,
          latitude: pos.latitude,
          longitude: pos.longitude,
        ),
      );

      // Auto-stop: once we have at least two fixes (so the first fix at the
      // start can't trip it), stop the stage when the device enters the
      // finish geofence. Only when a finish is set and auto-stop is enabled.
      final cfg = config;
      if (hadPreviousFix &&
          cfg.autoStop &&
          cfg.endLatitude != null &&
          cfg.endLongitude != null) {
        final dToEnd = gps.distanceBetween(
          startLatitude: pos.latitude,
          startLongitude: pos.longitude,
          endLatitude: cfg.endLatitude!,
          endLongitude: cfg.endLongitude!,
        );
        if (dToEnd <= cfg.endGeofenceRadiusM) {
          await ref.read(deviceServiceProvider).haptic();
          stopStage();
          return;
        }
      }
    });
  }

  /// Stop the stage: cancel GPS, release wakelock, mark completed. Distance
  /// and start time are retained for review.
  void stopStage() {
    if (telemetry.status != StageStatus.inProgress) return;
    _positionSub?.cancel();
    _positionSub = null;
    ref.read(deviceServiceProvider).disableWakelock();
    state = state.copyWith(
      telemetry: telemetry.copyWith(status: StageStatus.completed),
    );
  }

  /// Reset to idle, clearing telemetry and cancelling any subscription.
  void resetStage() {
    _positionSub?.cancel();
    _positionSub = null;
    ref.read(deviceServiceProvider).disableWakelock();
    state = state.copyWith(telemetry: const StageTelemetry());
  }

  /// Manually nudge the accumulated distance for sync with physical markers.
  /// Emits a short haptic. Only while in progress.
  void adjustDistance(double offset) {
    if (telemetry.status != StageStatus.inProgress) return;
    final next =
        (telemetry.currentDistance + offset).clamp(0.0, double.infinity);
    state = state.copyWith(
      telemetry: telemetry.copyWith(currentDistance: next),
    );
    ref.read(deviceServiceProvider).haptic();
  }
}

/// NotifierProvider for [StageController].
final stageControllerProvider =
    NotifierProvider<StageController, RallyState>(StageController.new);

/// A 1 Hz wall-clock tick used to refresh elapsed-time / delta displays
/// independently of GPS cadence. Emits `DateTime.now()` immediately and then
/// once per second.
final clockTickProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  await for (final _ in Stream.periodic(const Duration(seconds: 1))) {
    yield DateTime.now();
  }
});

/// Elapsed wall-clock seconds since the stage started (0 while idle).
final elapsedSecondsProvider = Provider<int>((ref) {
  final start = ref.watch(
    stageControllerProvider.select((s) => s.telemetry.startTime),
  );
  if (start == null) return 0;
  final now = ref.watch(clockTickProvider).valueOrNull ?? start;
  return now.difference(start).inSeconds;
});

/// The Δ indicator in **seconds**: `t_real - t_ideal`.
///
/// `t_ideal = distance_km / target_kmph` (hours) → × 3600 = seconds.
/// `t_real` is elapsed wall-clock since start, with millisecond resolution so
/// the display can show one decimal.
final deltaSecondsProvider = Provider<double>((ref) {
  final start = ref.watch(
    stageControllerProvider.select((s) => s.telemetry.startTime),
  );
  final distance = ref.watch(
    stageControllerProvider.select((s) => s.telemetry.currentDistance),
  );
  final target = ref.watch(
    stageControllerProvider.select((s) => s.config.targetAvgSpeed),
  );
  if (start == null || target <= 0) return 0.0;
  final now = ref.watch(clockTickProvider).valueOrNull ?? start;
  return deltaSeconds(
    start: start,
    now: now,
    distanceKm: distance,
    targetKmh: target,
  );
});

/// Colour band derived from [deltaSecondsProvider] (±1 s tolerance).
final deltaBandProvider = Provider<DeltaBand>((ref) {
  return deltaBandFor(ref.watch(deltaSecondsProvider));
});

/// Whether the current speed exceeds the configured max limit.
final isOverSpeedProvider = Provider<bool>((ref) {
  final speed = ref.watch(
    stageControllerProvider.select((s) => s.telemetry.currentSpeed),
  );
  final max = ref.watch(
    stageControllerProvider.select((s) => s.config.maxSpeedLimit),
  );
  return speed > max;
});

String _pickLocality(Placemark p) {
  for (final v in [
    p.locality,
    p.subLocality,
    p.administrativeArea,
    p.country,
  ]) {
    if (v != null && v.trim().isNotEmpty) return v.trim();
  }
  return '—';
}

/// Latest GPS fix, kept current whenever the cockpit is mounted — i.e. while
/// the app is open and on the main screen, **independent of stage state**.
/// This is what powers the locality readout when no stage is running.
///
/// Uses a lower accuracy + a 100 m distance filter than the stage stream: the
/// locality feed only needs ~1 km resolution, so we avoid keeping the GPS at
/// full throttle while idle. The stage controller keeps its own
/// high-accuracy subscription for distance/speed during a stage.
///
/// If the location service is off or permission is denied, the stream errors
/// and the locality falls back to '—' (rather than spinning forever).
final positionProvider = StreamProvider<Position>((ref) async* {
  final gps = ref.read(gpsServiceProvider);
  if (!await gps.isLocationServiceEnabled()) {
    throw StateError('location service disabled');
  }
  var permission = await gps.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await gps.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw StateError('location permission denied');
  }
  yield* gps.positionStream(
    accuracy: LocationAccuracy.low,
    distanceFilter: 100,
  );
});

/// ~1 km grid cell key for the latest fix, used to throttle reverse geocoding.
/// `null` before the first fix (or when the position stream is unavailable).
/// Watching this means the locality is re-resolved only when the crew moves to
/// a new ~1 km cell — not on every 100 m fix.
final localityCellProvider = Provider<String?>((ref) {
  return ref.watch(
    positionProvider.select((async) {
      final p = async.valueOrNull;
      return p == null ? null : _posCell(p);
    }),
  );
});

String _posCell(Position p) =>
    '${p.latitude.toStringAsFixed(2)},${p.longitude.toStringAsFixed(2)}';

/// Name of the current locality, reverse-geocoded from the latest GPS fix.
/// Re-resolves only when the fix moves to a new ~1 km cell. Returns '—' before
/// the first fix, if permission/service is unavailable, or if geocoding fails
/// (e.g. fully offline with no on-device geocoder). Updates continuously while
/// the app is open, even when no stage is running.
final localityProvider =
    AsyncNotifierProvider<LocalityNotifier, String>(LocalityNotifier.new);

class LocalityNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final cell = ref.watch(localityCellProvider);
    if (cell == null) return '—';
    final pos = ref.read(positionProvider).valueOrNull;
    if (pos == null) return '—';
    try {
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isEmpty) return '—';
      return _pickLocality(placemarks.first);
    } on Exception {
      return '—';
    }
  }
}