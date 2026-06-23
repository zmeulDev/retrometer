import 'dart:async';
import 'dart:math' as math;

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
  /// No-op while a stage is in progress or paused.
  void updateConfig(StageConfig config) {
    if (telemetry.status == StageStatus.inProgress ||
        telemetry.status == StageStatus.paused) {
      return;
    }
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
        maxSpeedKmh: 0.0,
        minSpeedKmh: null,
        pausedSince: null,
        pauseOffsetSeconds: 0,
        result: null,
      ),
    );

    await ref.read(deviceServiceProvider).enableWakelock();
    await _subscribeGps(gps);
  }

  /// Pause an in-progress stage: freeze the elapsed timer (record `pausedSince`)
  /// and stop accumulating distance by cancelling the GPS subscription. The
  /// wakelock is released so the screen can sleep. Resume with [resumeStage].
  void pauseStage() {
    if (telemetry.status != StageStatus.inProgress) return;
    _positionSub?.cancel();
    _positionSub = null;
    ref.read(deviceServiceProvider).disableWakelock();
    state = state.copyWith(
      telemetry: telemetry.copyWith(
        status: StageStatus.paused,
        pausedSince: DateTime.now(),
      ),
    );
  }

  /// Resume a paused stage: fold the paused interval into `pauseOffsetSeconds`
  /// (so the timer continues without a jump), clear `pausedSince`, return to
  /// in-progress, re-arm the wakelock, and re-subscribe to the GPS stream. The
  /// fresh subscription starts with no previous fix, so the first post-resume
  /// fix establishes a new baseline (no distance jump from a stale fix).
  Future<void> resumeStage() async {
    if (telemetry.status != StageStatus.paused) return;
    final pausedSince = telemetry.pausedSince;
    final extra = pausedSince == null
        ? 0
        : DateTime.now().difference(pausedSince).inSeconds;
    state = state.copyWith(
      telemetry: telemetry.copyWith(
        status: StageStatus.inProgress,
        pausedSince: null,
        pauseOffsetSeconds: telemetry.pauseOffsetSeconds + extra,
      ),
    );
    await ref.read(deviceServiceProvider).enableWakelock();
    await _subscribeGps(ref.read(gpsServiceProvider));
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

      final newMax = math.max(telemetry.maxSpeedKmh, speedKmh);
      final newMin = telemetry.minSpeedKmh == null
          ? speedKmh
          : math.min(telemetry.minSpeedKmh!, speedKmh);

      state = state.copyWith(
        telemetry: telemetry.copyWith(
          currentDistance: telemetry.currentDistance + addedMetres / 1000.0,
          currentSpeed: speedKmh,
          latitude: pos.latitude,
          longitude: pos.longitude,
          maxSpeedKmh: newMax,
          minSpeedKmh: newMin,
        ),
      );

      // Finish prompt (location): once we have at least two fixes (so the
      // first fix at the start can't trip it), raise the finish-confirmation
      // prompt when the device enters the finish geofence — instead of
      // silently auto-stopping. Only when a finish is set and auto-stop is
      // enabled. The prompt is once-per-stage (the notifier guards it).
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
          ref.read(stageFinishProvider.notifier).requestLocationFinish();
          return;
        }
      }
    });
  }

  /// Stop the stage: cancel GPS, release wakelock, snapshot the result
  /// (max/min/avg speed, distance, elapsed, completion time) onto telemetry,
  /// and mark completed. The result-persister provider picks up the snapshot
  /// and writes it onto the owning planned stage. Distance and start time are
  /// retained for review.
  void stopStage() {
    // Definitive stop, allowed from both in-progress and paused.
    final status = telemetry.status;
    if (status != StageStatus.inProgress && status != StageStatus.paused) {
      return;
    }
    _positionSub?.cancel();
    _positionSub = null;
    ref.read(deviceServiceProvider).disableWakelock();
    final result = _buildResult();
    state = state.copyWith(
      telemetry: telemetry.copyWith(
        status: StageStatus.completed,
        result: result,
      ),
    );
  }

  /// Snapshot a [StageResult] from the current telemetry: avg = totalDistance /
  /// elapsedHours (physically correct, no float drift); max/min from the live
  /// aggregates; elapsed from startTime to now, excluding paused intervals
  /// (frozen at `pausedSince` if currently paused).
  StageResult _buildResult() {
    final t = telemetry;
    final elapsed = stageElapsedSeconds(t, DateTime.now());
    final avg = elapsed > 0 ? t.currentDistance / (elapsed / 3600.0) : 0.0;
    return StageResult(
      maxSpeedKmh: t.maxSpeedKmh,
      minSpeedKmh: t.minSpeedKmh,
      avgSpeedKmh: avg,
      totalDistanceKm: t.currentDistance,
      elapsedSeconds: elapsed,
      completedAt: DateTime.now(),
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

/// Why a stage-finish prompt was raised.
enum StageFinishReason { time, location }

/// Surfaces a "ați ajuns la finalul stagiului — opriți?" confirmation instead
/// of silently auto-stopping. Holds the pending finish reason (`time` when the
/// elapsed reaches `allocatedTimeSeconds`, `location` when the device enters
/// the finish geofence) and a once-per-stage guard so the prompt can't
/// reappear at every GPS fix after a dismiss.
///
/// The location signal arrives imperatively from [StageController._subscribeGps]
/// via [requestLocationFinish]; the time signal is derived here by *listening*
/// (not watching) [elapsedSecondsProvider] so the 1 Hz tick checks the
/// condition without rebuilding this notifier — an imperative `request` set
/// would otherwise be clobbered by the rebuild. State is `null` when no prompt
/// is pending.
class StageFinishNotifier extends Notifier<StageFinishReason?> {
  bool _promptedThisStage = false;

  @override
  StageFinishReason? build() {
    final status = ref.watch(
      stageControllerProvider.select((s) => s.telemetry.status),
    );
    // Re-arm the once-per-stage guard when the stage is no longer running —
    // idle (reset) or completed (stopped) — so the next stage gets a fresh
    // prompt. `paused` keeps the guard (a pause isn't a new stage).
    if (status == StageStatus.idle || status == StageStatus.completed) {
      _promptedThisStage = false;
    }
    // Listen (not watch): the elapsed tick drives the time check without
    // rebuilding this notifier (which would reset state to null and clobber an
    // imperative location prompt).
    ref.listen<int>(elapsedSecondsProvider, (prev, next) {
      _maybeTimeFinish(next);
    });
    return null;
  }

  void _maybeTimeFinish(int elapsed) {
    if (_promptedThisStage) return;
    final s = ref.read(stageControllerProvider);
    if (s.telemetry.status != StageStatus.inProgress) return;
    final allocated = s.config.allocatedTimeSeconds;
    if (allocated > 0 && elapsed >= allocated) {
      _setPending(StageFinishReason.time);
    }
  }

  /// Location-finish signal from [StageController._subscribeGps]: the device
  /// entered the finish geofence. Idempotent per stage (no-op if already
  /// prompted).
  void requestLocationFinish() {
    if (_promptedThisStage) return;
    _setPending(StageFinishReason.location);
  }

  void _setPending(StageFinishReason reason) {
    _promptedThisStage = true;
    try {
      state = reason;
    } on StateError {
      // provider disposed mid-call — ignore.
    }
  }

  /// Dismiss the prompt without stopping (snooze for the rest of this stage).
  void dismiss() {
    try {
      state = null;
    } on StateError {
      // ignore
    }
  }

  /// Confirm the prompt: stop the stage and clear the prompt. [stopStage] is
  /// synchronous, so this returns immediately (the `Future<void>` keeps the
  /// listener's `await` happy and leaves room for a future async stop).
  Future<void> confirm() async {
    ref.read(stageControllerProvider.notifier).stopStage();
    try {
      state = null;
    } on StateError {
      // ignore
    }
  }
}

final stageFinishProvider =
    NotifierProvider<StageFinishNotifier, StageFinishReason?>(
        StageFinishNotifier.new);

/// Elapsed stage seconds excluding paused intervals. Raw elapsed is
/// `now - startTime`; while paused the clock is frozen at `pausedSince`, and
/// the cumulative `pauseOffsetSeconds` is subtracted so pauses don't count.
/// Shared by the live [elapsedSecondsProvider] and the stage-result snapshot.
int stageElapsedSeconds(StageTelemetry t, DateTime now) {
  final start = t.startTime;
  if (start == null) return 0;
  final effectiveNow = t.pausedSince ?? now;
  final raw = effectiveNow.difference(start).inSeconds;
  final elapsed = raw - t.pauseOffsetSeconds;
  return elapsed < 0 ? 0 : elapsed;
}

/// A 1 Hz wall-clock tick used to refresh elapsed-time / delta displays
/// independently of GPS cadence. Emits `DateTime.now()` immediately and then
/// once per second.
final clockTickProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  await for (final _ in Stream.periodic(const Duration(seconds: 1))) {
    yield DateTime.now();
  }
});

/// Elapsed wall-clock seconds since the stage started (0 while idle). Excludes
/// paused intervals: while paused the value is frozen at `pausedSince`, and on
/// resume the cumulative `pauseOffsetSeconds` keeps it jump-free. Once stopped
/// (`completed`) the value is frozen at the snapshot's [StageResult.elapsedSeconds]
/// — the timer does not keep advancing after STOP.
final elapsedSecondsProvider = Provider<int>((ref) {
  final start = ref.watch(
    stageControllerProvider.select((s) => s.telemetry.startTime),
  );
  if (start == null) return 0;
  final status = ref.watch(
    stageControllerProvider.select((s) => s.telemetry.status),
  );
  switch (status) {
    case StageStatus.completed:
      // Frozen at the stop instant — the live clock tick is intentionally not
      // watched, so the display holds instead of drifting after STOP.
      final result = ref.watch(
        stageControllerProvider.select((s) => s.telemetry.result),
      );
      return result?.elapsedSeconds ?? 0;
    case StageStatus.paused:
      final pausedSince = ref.watch(
        stageControllerProvider.select((s) => s.telemetry.pausedSince),
      );
      final pauseOffset = ref.watch(
        stageControllerProvider.select((s) => s.telemetry.pauseOffsetSeconds),
      );
      final elapsed =
          (pausedSince ?? start).difference(start).inSeconds - pauseOffset;
      return elapsed < 0 ? 0 : elapsed;
    case StageStatus.idle:
      return 0;
    case StageStatus.inProgress:
      final pausedSince = ref.watch(
        stageControllerProvider.select((s) => s.telemetry.pausedSince),
      );
      final pauseOffset = ref.watch(
        stageControllerProvider.select((s) => s.telemetry.pauseOffsetSeconds),
      );
      final now = ref.watch(clockTickProvider).valueOrNull ?? start;
      final effectiveNow = pausedSince ?? now;
      final elapsed = effectiveNow.difference(start).inSeconds - pauseOffset;
      return elapsed < 0 ? 0 : elapsed;
  }
});

/// The Δ indicator in **seconds**: `t_real - t_ideal`.
///
/// `t_ideal = distance_km / target_kmph` (hours) → × 3600 = seconds.
/// `t_real` is elapsed wall-clock since start (millisecond resolution, so the
/// display can show one decimal), **excluding paused intervals**
/// (`pauseOffsetSeconds` is subtracted). While `paused` the value is frozen at
/// `pausedSince`; once `completed` it is frozen at the snapshot's
/// [StageResult.completedAt] — so Δ stops drifting and the flash stops
/// pulsing after PAUZĂ / STOP. `t_real` is computed inline (rather than via
/// [deltaSeconds]) so the pause offset can be applied.
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
  final status = ref.watch(
    stageControllerProvider.select((s) => s.telemetry.status),
  );
  final pauseOffset = ref.watch(
    stageControllerProvider.select((s) => s.telemetry.pauseOffsetSeconds),
  );
  // Resolve the effective "now" per status. Only `inProgress` consumes the
  // live clock tick; paused/completed are pinned so the clock tick no longer
  // drives a rebuild (Δ holds instead of drifting).
  final DateTime effectiveNow;
  switch (status) {
    case StageStatus.paused:
      final pausedSince = ref.watch(
        stageControllerProvider.select((s) => s.telemetry.pausedSince),
      );
      effectiveNow = pausedSince ?? start;
    case StageStatus.completed:
      final result = ref.watch(
        stageControllerProvider.select((s) => s.telemetry.result),
      );
      effectiveNow = result?.completedAt ?? start;
    case StageStatus.idle:
      return 0.0;
    case StageStatus.inProgress:
      effectiveNow = ref.watch(clockTickProvider).valueOrNull ?? start;
  }
  final tReal =
      effectiveNow.difference(start).inMilliseconds / 1000.0 - pauseOffset;
  return tReal - idealSeconds(distanceKm: distance, targetKmh: target);
});

/// Colour band derived from [deltaSecondsProvider] (±1 s tolerance).
final deltaBandProvider = Provider<DeltaBand>((ref) {
  return deltaBandFor(ref.watch(deltaSecondsProvider));
});

/// Whether the current speed exceeds the configured max limit. Only true while
/// a stage is actually in progress — paused/completed stages never flag
/// over-speed (the alert unmounts and stops pulsing on PAUZĂ / STOP).
final isOverSpeedProvider = Provider<bool>((ref) {
  final status = ref.watch(
    stageControllerProvider.select((s) => s.telemetry.status),
  );
  if (status != StageStatus.inProgress) return false;
  final speed = ref.watch(
    stageControllerProvider.select((s) => s.telemetry.currentSpeed),
  );
  final max = ref.watch(
    stageControllerProvider.select((s) => s.config.maxSpeedLimit),
  );
  return speed > max;
});

/// Real average speed (km/h) over the stage so far — `totalDistanceKm /
/// elapsedHours`. `null` while no time has elapsed (before the first second
/// tick), so the UI can show "—". Narrow `select`s keep rebuilds bounded.
final actualAvgSpeedProvider = Provider<double?>((ref) {
  final distance = ref.watch(
    stageControllerProvider.select((s) => s.telemetry.currentDistance),
  );
  final elapsed = ref.watch(elapsedSecondsProvider);
  if (elapsed <= 0) return null;
  return distance / (elapsed / 3600.0);
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

/// GPS fix quality for the status-strip LED: green once a fix arrives, amber
/// while searching, red when the service/permission is unavailable. Watching
/// this keeps [positionProvider] alive while the cockpit is mounted.
final gpsFixStatusProvider = Provider<GpsFixStatus>((ref) {
  final async = ref.watch(positionProvider);
  if (async.hasValue) return GpsFixStatus.fixed;
  if (async.hasError) return GpsFixStatus.unavailable;
  return GpsFixStatus.searching;
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