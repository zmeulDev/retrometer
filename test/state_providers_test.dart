import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:retrometer/models.dart';
import 'package:retrometer/services/device_service.dart';
import 'package:retrometer/services/gps_service.dart';
import 'package:retrometer/services/telemetry_logger.dart';
import 'package:retrometer/state_providers.dart';

/// Fake GPS service: emits positions pushed into [controller], and reports a
/// fixed [metresPerStep] for every `distanceBetween` call.
class _FakeGpsService implements GpsService {
  _FakeGpsService();

  /// Metres reported for every consecutive position pair.
  static const double metresPerStep = 100;

  /// Per-call distance overrides. Each `distanceBetween` call pops the first
  /// entry; when empty it falls back to [metresPerStep]. Used to simulate a
  /// genuine stop (distance 0) for a 0-speed fix without disturbing the default
  /// movement distance of the other fixes.
  final List<double> distanceOverrides = [];

  final StreamController<Position> controller =
      StreamController<Position>.broadcast();

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Stream<Position> positionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 0,
  }) =>
      controller.stream;

  // Auto-start monitor paths aren't exercised here.
  @override
  Future<Position?> getLastKnownPosition() async => null;

  @override
  Future<Position> getCurrentPosition({Duration? timeLimit}) =>
      throw UnimplementedError();

  @override
  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) =>
      distanceOverrides.isNotEmpty
          ? distanceOverrides.removeAt(0)
          : metresPerStep;
}

/// Records wakelock/haptic calls without touching platform channels.
class _FakeDeviceService implements DeviceService {
  int enableCalls = 0;
  int disableCalls = 0;
  int hapticCalls = 0;

  @override
  Future<void> enableWakelock() async => enableCalls++;

  @override
  Future<void> disableWakelock() async => disableCalls++;

  @override
  Future<void> haptic({int durationMs = 30}) async => hapticCalls++;
}

/// Captures every logger call as a record so tests can assert what was logged
/// without touching disk. Mirrors the [TelemetryLogger] surface; stage events
/// carry their [extra] map and generic events their [data] map.
class _RecordingLogger implements TelemetryLogger {
  final List<Map<String, Object?>> records = [];

  @override
  void fix({
    required Position pos,
    required double addedMetres,
    required int dtMs,
    required double? gpsSpeedKmh,
    required double speedKmh,
    required double distanceKm,
    required double maxSpeedKmh,
    required double? minSpeedKmh,
    required bool baseline,
    required StageStatus status,
  }) {
    records.add({
      'type': 'fix',
      'rawSpeedMps': pos.speed,
      'gpsSpeedKmh': gpsSpeedKmh,
      'speedKmh': speedKmh,
      'addedM': addedMetres,
      'dtMs': dtMs,
      'distKm': distanceKm,
      'maxKmh': maxSpeedKmh,
      'minKmh': minSpeedKmh,
      'baseline': baseline,
      'status': status.name,
    });
  }

  @override
  void stageEvent({
    required String type,
    required StageConfig config,
    StageTelemetry? telemetry,
    Map<String, Object?> extra = const {},
  }) {
    records.add({
      'type': type,
      'stageId': config.id,
      'telemetry': telemetry,
      'extra': extra,
    });
  }

  @override
  void event({required String type, Map<String, Object?> data = const {}}) {
    records.add({'type': type, 'data': data});
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}
}

Position _pos({required double speed, DateTime? at}) => Position(
      longitude: 0,
      latitude: 0,
      timestamp: at ?? DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: speed,
      speedAccuracy: 0,
    );

void main() {
  late _FakeGpsService gps;
  late _FakeDeviceService device;
  late _RecordingLogger logger;
  late ProviderContainer container;

  setUp(() {
    gps = _FakeGpsService();
    device = _FakeDeviceService();
    logger = _RecordingLogger();
    container = ProviderContainer(
      overrides: [
        gpsServiceProvider.overrideWithValue(gps),
        deviceServiceProvider.overrideWithValue(device),
        telemetryLoggerProvider.overrideWithValue(logger),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    gps.controller.close();
  });

  StageController readController() =>
      container.read(stageControllerProvider.notifier);

  test('startStage enables wakelock and subscribes to GPS', () async {
    await readController().startStage();
    expect(device.enableCalls, 1);
    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.inProgress,
    );
  });

  test('GPS positions accumulate distance (km) and speed (km/h)', () async {
    await readController().startStage();

    // First fix seeds `last`; no distance added yet.
    gps.controller.add(_pos(speed: 10)); // 10 m/s → 36 km/h
    await Future<void>.delayed(Duration.zero);
    // Second fix: distanceBetween returns 100 m → +0.1 km.
    gps.controller.add(_pos(speed: 20)); // 20 m/s → 72 km/h
    await Future<void>.delayed(Duration.zero);

    final telemetry = container.read(stageControllerProvider).telemetry;
    expect(telemetry.currentDistance, closeTo(0.1, 1e-9));
    expect(telemetry.currentSpeed, closeTo(72, 1e-9));
  });

  test('adjustDistance nudges by offset and fires haptic', () async {
    await readController().startStage();
    readController().adjustDistance(0.01);
    expect(
      container.read(stageControllerProvider).telemetry.currentDistance,
      closeTo(0.01, 1e-9),
    );
    expect(device.hapticCalls, 1);
  });

  test('adjustDistance clamps at zero and ignores negative offsets below 0',
      () async {
    await readController().startStage();
    readController().adjustDistance(-0.05);
    expect(
      container.read(stageControllerProvider).telemetry.currentDistance,
      0,
    );
  });

  test('adjustDistance is a no-op when idle', () async {
    readController().adjustDistance(0.01);
    expect(
      container.read(stageControllerProvider).telemetry.currentDistance,
      0,
    );
    expect(device.hapticCalls, 0);
  });

  test('stopStage releases wakelock and marks completed', () async {
    await readController().startStage();
    readController().stopStage();
    expect(device.disableCalls, 1);
    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.completed,
    );
  });

  test('resetStage returns to idle with cleared distance', () async {
    await readController().startStage();
    readController().adjustDistance(0.5);
    readController().resetStage();
    final t = container.read(stageControllerProvider).telemetry;
    expect(t.status, StageStatus.idle);
    expect(t.currentDistance, 0);
  });

  test('updateConfig is blocked while in progress', () async {
    await readController().startStage();
    readController().updateConfig(const StageConfig(
      id: 'x',
      name: 'blocked',
      targetAvgSpeed: 99,
      maxSpeedLimit: 99,
    ));
    expect(
      container.read(stageControllerProvider).config.targetAvgSpeed,
      isNot(99),
    );
  });

  test('location finish raises the prompt (no silent auto-stop)', () async {
    final plan = PlannedStage(
      id: 's1',
      name: 'Etapa',
      startTime: DateTime.now(),
      latitude: 0,
      longitude: 0,
      endLatitude: 1.0,
      endLongitude: 1.0,
      endGeofenceRadiusM: 200,
      autoStop: true,
    );
    await readController().startStageFromPlan(plan);
    // Keep the finish notifier alive so its state is observable.
    container.read(stageFinishProvider);
    // First fix seeds `last`; the finish check needs a previous fix.
    gps.controller.add(_pos(speed: 10));
    await Future<void>.delayed(Duration.zero);
    // Second fix: distanceBetween → 100 m ≤ 200 m radius → finish prompt.
    gps.controller.add(_pos(speed: 20));
    await Future<void>.delayed(Duration.zero);

    // The stage is NOT silently stopped — a finish prompt is pending instead.
    expect(container.read(stageFinishProvider), StageFinishReason.location);
    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.inProgress,
    );
    expect(device.hapticCalls, greaterThanOrEqualTo(1));
  });

  test('location finish is skipped when autoStop is disabled', () async {
    final plan = PlannedStage(
      id: 's2',
      name: 'Etapa',
      startTime: DateTime.now(),
      latitude: 0,
      longitude: 0,
      endLatitude: 1.0,
      endLongitude: 1.0,
      endGeofenceRadiusM: 200,
      autoStop: false,
    );
    await readController().startStageFromPlan(plan);
    container.read(stageFinishProvider);
    gps.controller.add(_pos(speed: 10));
    await Future<void>.delayed(Duration.zero);
    gps.controller.add(_pos(speed: 20));
    await Future<void>.delayed(Duration.zero);

    // No finish prompt, stage still running.
    expect(container.read(stageFinishProvider), isNull);
    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.inProgress,
    );
  });

  test('time finish raises the prompt when elapsed reaches allocatedTime',
      () async {
    readController().updateConfig(const StageConfig(
      id: 's',
      name: 'Timp',
      targetAvgSpeed: 40,
      maxSpeedLimit: 60,
      allocatedTimeSeconds: 1,
    ));
    await readController().startStage();
    // Register the finish notifier early (elapsed 0) so its elapsed listener
    // catches the crossing of the 1 s allocation on the next 1 Hz tick.
    container.read(stageFinishProvider);

    // Poll up to ~3 s for the 1 Hz clock to tick elapsed to 1.
    StageFinishReason? reason;
    for (var i = 0; i < 30 && reason == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      reason = container.read(stageFinishProvider);
    }
    expect(reason, StageFinishReason.time);
    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.inProgress,
    );
  });

  test('confirm() stops the stage and clears the finish prompt', () async {
    final plan = PlannedStage(
      id: 's3',
      name: 'Etapa',
      startTime: DateTime.now(),
      latitude: 0,
      longitude: 0,
      endLatitude: 1.0,
      endLongitude: 1.0,
      endGeofenceRadiusM: 200,
      autoStop: true,
    );
    await readController().startStageFromPlan(plan);
    container.read(stageFinishProvider);
    gps.controller.add(_pos(speed: 10));
    await Future<void>.delayed(Duration.zero);
    gps.controller.add(_pos(speed: 20));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(stageFinishProvider), StageFinishReason.location);

    await container.read(stageFinishProvider.notifier).confirm();
    expect(container.read(stageFinishProvider), isNull);
    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.completed,
    );
  });

  // --- pause / resume -------------------------------------------------------

  test('stageElapsedSeconds excludes paused intervals (pure helper)', () {
    final start = DateTime(2026, 1, 1, 10, 0, 0);
    // 60s of running, no pause → 60.
    final running = StageTelemetry(startTime: start);
    expect(
      stageElapsedSeconds(running, start.add(const Duration(seconds: 60))),
      60,
    );
    // Paused 40s in: elapsed frozen at the pause moment regardless of `now`.
    final paused = StageTelemetry(
      startTime: start,
      pausedSince: start.add(const Duration(seconds: 40)),
    );
    expect(
      stageElapsedSeconds(paused, start.add(const Duration(seconds: 90))),
      40,
    );
    // After a 20s pause resumed: 90s wall − 20s paused → 70s elapsed.
    final resumed = StageTelemetry(
      startTime: start,
      pauseOffsetSeconds: 20,
    );
    expect(
      stageElapsedSeconds(resumed, start.add(const Duration(seconds: 90))),
      70,
    );
    // Guard: never negative.
    final clamped = StageTelemetry(startTime: start, pauseOffsetSeconds: 9999);
    expect(
      stageElapsedSeconds(clamped, start.add(const Duration(seconds: 10))),
      0,
    );
  });

  test('pauseStage freezes distance: fixes during pause are ignored', () async {
    await readController().startStage();
    gps.controller.add(_pos(speed: 10)); // seeds `last`
    await Future<void>.delayed(Duration.zero);
    gps.controller.add(_pos(speed: 20)); // +0.1 km
    await Future<void>.delayed(Duration.zero);
    final before =
        container.read(stageControllerProvider).telemetry.currentDistance;
    expect(before, closeTo(0.1, 1e-9));

    readController().pauseStage();
    final t = container.read(stageControllerProvider).telemetry;
    expect(t.status, StageStatus.paused);
    expect(t.pausedSince, isNotNull);
    // Wakelock released on pause (start armed it once).
    expect(device.disableCalls, 1);

    // The GPS subscription is cancelled, so further fixes do nothing.
    gps.controller.add(_pos(speed: 30));
    gps.controller.add(_pos(speed: 40));
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(stageControllerProvider).telemetry.currentDistance,
      closeTo(0.1, 1e-9),
    );
  });

  test('resumeStage returns to inProgress and re-subscribes GPS', () async {
    await readController().startStage();
    expect(device.enableCalls, 1);
    readController().pauseStage();

    await readController().resumeStage();
    final t = container.read(stageControllerProvider).telemetry;
    expect(t.status, StageStatus.inProgress);
    expect(t.pausedSince, isNull);
    // Wakelock re-armed on resume.
    expect(device.enableCalls, 2);

    // First post-resume fix re-seeds `last` (0 m), second adds 0.1 km — no
    // jump from a stale pre-pause fix.
    gps.controller.add(_pos(speed: 10));
    await Future<void>.delayed(Duration.zero);
    gps.controller.add(_pos(speed: 20));
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(stageControllerProvider).telemetry.currentDistance,
      closeTo(0.1, 1e-9),
    );
  });

  test('stopStage finalizes from paused', () async {
    await readController().startStage();
    readController().pauseStage();
    readController().stopStage();
    final t = container.read(stageControllerProvider).telemetry;
    expect(t.status, StageStatus.completed);
    expect(t.result, isNotNull);
  });

  test('pauseStage is a no-op when idle', () async {
    readController().pauseStage();
    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.idle,
    );
    expect(device.disableCalls, 0);
  });

  test('updateConfig is blocked while paused', () async {
    await readController().startStage();
    readController().pauseStage();
    readController().updateConfig(const StageConfig(
      id: 'x',
      name: 'blocked',
      targetAvgSpeed: 99,
      maxSpeedLimit: 99,
    ));
    expect(
      container.read(stageControllerProvider).config.targetAvgSpeed,
      isNot(99),
    );
  });

  // --- pause/stop freeze Δ + over-speed (regression for the cockpit bugs) ---

  test('pause freezes Δ: deltaSecondsProvider stops drifting while paused',
      () async {
    readController().updateConfig(const StageConfig(
      id: 'x',
      name: 'freeze',
      targetAvgSpeed: 40,
      maxSpeedLimit: 120,
    ));
    await readController().startStage();
    // Seed distance so t_ideal is non-zero and Δ is meaningful.
    gps.controller.add(_pos(speed: 10));
    await Future<void>.delayed(Duration.zero);
    gps.controller.add(_pos(speed: 20));
    await Future<void>.delayed(Duration.zero);

    readController().pauseStage();
    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.paused,
    );

    // While paused the provider resolves "now" to pausedSince (a fixed
    // instant) and does not watch clockTick — so Δ is frozen across wall-clock
    // time. (Pre-fix, Δ kept drifting into ÎNTÂRZIERE during a pause.)
    final deltaAtPause = container.read(deltaSecondsProvider);
    await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 200));
    final deltaAfterWait = container.read(deltaSecondsProvider);
    expect(deltaAfterWait, closeTo(deltaAtPause, 1e-9));

    // Elapsed is frozen too while paused.
    final elapsedAtPause = container.read(elapsedSecondsProvider);
    await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 200));
    expect(container.read(elapsedSecondsProvider), elapsedAtPause);
  });

  test('stop freezes Δ and clears over-speed: no drift / flashing after STOP',
      () async {
    readController().updateConfig(const StageConfig(
      id: 'x',
      name: 'stop',
      targetAvgSpeed: 40,
      maxSpeedLimit: 30, // low so the fix below is over-speed
    ));
    await readController().startStage();
    gps.controller.add(_pos(speed: 14)); // ~50 km/h → over the 30 limit
    await Future<void>.delayed(Duration.zero);
    expect(container.read(isOverSpeedProvider), isTrue);

    readController().stopStage();
    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.completed,
    );

    // Over-speed clears on STOP — the alert unmounts and stops pulsing.
    expect(container.read(isOverSpeedProvider), isFalse);

    // Δ freezes at the stop instant (result.completedAt) and does not drift
    // with the 1 Hz clock tick after STOP. (Pre-fix, Δ kept advancing and the
    // flash kept pulsing after STOP.)
    final deltaAtStop = container.read(deltaSecondsProvider);
    await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 200));
    expect(
      container.read(deltaSecondsProvider),
      closeTo(deltaAtStop, 1e-9),
    );

    // Elapsed freezes at the snapshot's elapsedSeconds after STOP.
    final elapsedAtStop = container.read(elapsedSecondsProvider);
    await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 200));
    expect(container.read(elapsedSecondsProvider), elapsedAtStop);
  });

  test('resume makes Δ live again (no jump from the frozen pause value)',
      () async {
    readController().updateConfig(const StageConfig(
      id: 'x',
      name: 'resume',
      targetAvgSpeed: 40,
      maxSpeedLimit: 120,
    ));
    await readController().startStage();
    gps.controller.add(_pos(speed: 10));
    await Future<void>.delayed(Duration.zero);

    readController().pauseStage();
    final deltaFrozen = container.read(deltaSecondsProvider);
    await readController().resumeStage();
    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.inProgress,
    );
    // On resume the provider watches clockTick again, so Δ advances from the
    // frozen value rather than staying stuck (and pauseOffset keeps it
    // jump-free — no sudden lurch).
    //
    // Prime the lazy clock stream first: while paused the inProgress branch
    // (which watches clockTickProvider) isn't evaluated, so the stream isn't
    // built until the first post-resume read. Without this priming read + pump
    // the 1.2s wait would elapse before the stream even starts, leaving
    // valueOrNull null and Δ stuck at 0.
    container.read(deltaSecondsProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 200));
    expect(
      container.read(deltaSecondsProvider),
      greaterThanOrEqualTo(deltaFrozen),
    );
  });

  // --- per-stage speed telemetry --------------------------------------------

  test('maxSpeedKmh/minSpeedKmh aggregate from fixes (min includes 0)',
      () async {
    await readController().startStage();

    gps.controller.add(_pos(speed: 10)); // 10 m/s → 36 km/h
    await Future<void>.delayed(Duration.zero);
    gps.controller.add(_pos(speed: 20)); // 20 m/s → 72 km/h
    await Future<void>.delayed(Duration.zero);

    final t1 = container.read(stageControllerProvider).telemetry;
    expect(t1.maxSpeedKmh, closeTo(72, 1e-9));
    expect(t1.minSpeedKmh, closeTo(36, 1e-9));

    // A 0-speed fix must count toward the min — stops are legit readings, not
    // filtered out. The fix is a genuine stop: distance 0 (so the new
    // moving-threshold logic trusts the 0 rather than deriving a speed).
    gps.distanceOverrides.add(0.0);
    gps.controller.add(_pos(speed: 0)); // 0 km/h, stopped
    await Future<void>.delayed(Duration.zero);

    final t2 = container.read(stageControllerProvider).telemetry;
    expect(t2.minSpeedKmh, closeTo(0, 1e-9));
    expect(t2.maxSpeedKmh, closeTo(72, 1e-9));
  });

  test('speed is derived from distance/time when GPS reports 0 while moving',
      () async {
    // Reproduces the A059 behavior: FusedLocation returns position.speed == 0
    // even while the device is moving. Pre-fix, max/min stayed at 0 for the
    // whole stage; post-fix, the speed is derived from the distance between
    // fixes once it crosses the moving threshold.
    await readController().startStage();

    final t0 = DateTime(2026, 6, 24, 12, 0, 0);
    // First fix seeds `last` (no distance call); speed 0 → reads 0.
    gps.controller.add(_pos(speed: 0, at: t0));
    await Future<void>.delayed(Duration.zero);
    // Second fix: moved 30 m in 1 s → 108 km/h. GPS reports 0 but we crossed
    // the threshold, so the derived speed is used.
    gps.distanceOverrides.add(30.0);
    gps.controller.add(_pos(speed: 0, at: t0.add(const Duration(seconds: 1))));
    await Future<void>.delayed(Duration.zero);

    final t = container.read(stageControllerProvider).telemetry;
    expect(t.maxSpeedKmh, closeTo(108, 1e-6));
    expect(t.minSpeedKmh, closeTo(0, 1e-6));
    expect(t.currentSpeed, closeTo(108, 1e-6));
  });

  test('stopStage snapshots a StageResult with max/min/distance/completedAt',
      () async {
    await readController().startStage();

    // First fix seeds `last` (0 distance); two moving fixes each add 0.1 km
    // (metresPerStep=100) → 0.2 km total and a 72 km/h max; a final genuine
    // stop (distance 0, speed 0) pins the min at 0.
    gps.controller.add(_pos(speed: 10)); // 36 km/h, +0 km
    await Future<void>.delayed(Duration.zero);
    gps.controller.add(_pos(speed: 20)); // 72 km/h, +0.1 km
    await Future<void>.delayed(Duration.zero);
    gps.controller.add(_pos(speed: 20)); // 72 km/h, +0.1 km
    await Future<void>.delayed(Duration.zero);
    gps.distanceOverrides.add(0.0);
    gps.controller.add(_pos(speed: 0)); // 0 km/h, stopped, +0 km
    await Future<void>.delayed(Duration.zero);

    readController().stopStage();

    final result = container.read(stageControllerProvider).telemetry.result;
    expect(result, isNotNull);
    expect(result!.maxSpeedKmh, closeTo(72, 1e-9));
    expect(result.minSpeedKmh, closeTo(0, 1e-9));
    expect(result.totalDistanceKm, closeTo(0.2, 1e-9));
    expect(result.completedAt, isNotNull);
  });

  test('startStage resets max/min/result between stages', () async {
    await readController().startStage();
    gps.controller.add(_pos(speed: 20)); // 72 km/h
    await Future<void>.delayed(Duration.zero);
    readController().stopStage();
    expect(
      container.read(stageControllerProvider).telemetry.result,
      isNotNull,
    );

    // Restart: aggregates must be cleared before any new fix arrives.
    await readController().startStage();
    final t = container.read(stageControllerProvider).telemetry;
    expect(t.maxSpeedKmh, closeTo(0, 1e-9));
    expect(t.minSpeedKmh, isNull);
    expect(t.result, isNull);
  });

  test('actualAvgSpeedProvider is null at idle and follows distance/elapsed',
      () async {
    // Before starting: startTime null → elapsed 0 → null.
    expect(container.read(actualAvgSpeedProvider), isNull);

    await readController().startStage();
    // Feed two fixes so distance accumulates (the first fix seeds `last`).
    gps.controller.add(_pos(speed: 10));
    await Future<void>.delayed(Duration.zero);
    gps.controller.add(_pos(speed: 20));
    await Future<void>.delayed(Duration.zero);

    // Give the 1 Hz clock a chance to tick.
    await Future<void>.delayed(const Duration(seconds: 1));
    await Future<void>.delayed(Duration.zero);

    // Deterministic: assert the relationship regardless of whether the tick
    // has advanced elapsed past 0 yet (avoids CI flakiness on wall-clock
    // boundaries).
    final elapsed = container.read(elapsedSecondsProvider);
    final distance =
        container.read(stageControllerProvider).telemetry.currentDistance;
    final avg = container.read(actualAvgSpeedProvider);
    if (elapsed > 0) {
      expect(avg, closeTo(distance / (elapsed / 3600.0), 1e-6));
    } else {
      expect(avg, isNull);
    }
  });

  // --- GPS fix status LED ---------------------------------------------------

  test('gpsFixStatusProvider is searching then fixed as fixes arrive',
      () async {
    // Reading the LED provider builds the position stream (async* — it awaits
    // the service/permission checks before subscribing). Before any fix
    // arrives it is loading → searching.
    container.read(gpsFixStatusProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(container.read(gpsFixStatusProvider), GpsFixStatus.searching);
    // Emit a fix → fixed.
    gps.controller.add(_pos(speed: 10));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(container.read(gpsFixStatusProvider), GpsFixStatus.fixed);
  });

  // --- telemetry logging -----------------------------------------------------

  test('fix events are logged with the distance/time-derived speed (A059)',
      () async {
    // FusedLocation reports speed == 0 while moving (the A059 case); once the
    // moving threshold is crossed the logger records the derived speed, and the
    // raw GPS speed fields make that derivation visible in the log.
    await readController().startStage();

    final t0 = DateTime(2026, 6, 24, 12, 0, 0);
    gps.controller.add(_pos(speed: 0, at: t0)); // baseline, seeds `last`
    await Future<void>.delayed(Duration.zero);
    gps.distanceOverrides.add(30.0);
    gps.controller.add(_pos(speed: 0, at: t0.add(const Duration(seconds: 1))));
    await Future<void>.delayed(Duration.zero);

    final fixes = logger.records.where((r) => r['type'] == 'fix').toList();
    expect(fixes.length, greaterThanOrEqualTo(2));
    final moving = fixes.last;
    expect(moving['rawSpeedMps'], 0.0); // GPS reported nothing
    expect(moving['gpsSpeedKmh'], 0.0); // ... so the GPS speed is 0 too
    expect((moving['speedKmh'] as num).toDouble(), closeTo(108, 1e-6));
    expect((moving['addedM'] as num).toDouble(), closeTo(30, 1e-9));
    expect(moving['dtMs'], 1000);
    expect(moving['baseline'], isFalse);
    // The baseline fix (first) is flagged so the analyzer can distinguish it.
    expect(fixes.first['baseline'], isTrue);
  });

  test('stage lifecycle events are logged: start → pause → resume → stop',
      () async {
    await readController().startStage();
    readController().pauseStage();
    await readController().resumeStage();
    readController().stopStage();

    final types = logger.records
        .where((r) => r['type'] is String && (r['type'] != 'fix'))
        .map((r) => r['type'] as String)
        .toList();
    // The lifecycle is emitted in order; stop carries the finalized result.
    expect(types, containsAllInOrder(['start', 'pause', 'resume', 'stop']));
    final stop = logger.records.firstWhere((r) => r['type'] == 'stop');
    final extra = stop['extra'] as Map<String, Object?>;
    expect(extra['result'], isNotNull);
    final result = extra['result'] as Map<String, Object?>;
    expect(result.containsKey('maxSpeedKmh'), isTrue);
    expect(result.containsKey('totalDistanceKm'), isTrue);
  });
}