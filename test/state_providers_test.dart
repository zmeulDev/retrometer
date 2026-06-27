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
    bool bestForNavigation = false,
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

Position _pos({required double speed, DateTime? at, double accuracy = 0}) =>
    Position(
      longitude: 0,
      latitude: 0,
      timestamp: at ?? DateTime.now(),
      accuracy: accuracy,
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

    // Fixes are 1 s apart (the clamp + spike-rejector need a real interval;
    // same-instant timestamps would clamp dt to 200 ms and over-reject).
    final t0 = DateTime(2026, 6, 24, 12, 0, 0);
    // First fix seeds `last` (baseline): speed 10 m/s → 36 km/h, 0 km added.
    gps.controller.add(_pos(speed: 10, at: t0));
    await Future<void>.delayed(Duration.zero);
    // Second fix: 20 m/s (72 km/h) over 1 s → odometer += 20 m = 0.02 km
    // (integrated from position.speed, not haversine). The 36→72 jump in 1 s
    // is exactly the spike threshold (36 km/h/s) so it is accepted, not held.
    gps.controller.add(_pos(speed: 20, at: t0.add(const Duration(seconds: 1))));
    await Future<void>.delayed(Duration.zero);

    final telemetry = container.read(stageControllerProvider).telemetry;
    expect(telemetry.currentDistance, closeTo(0.02, 1e-9));
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
    final t0 = DateTime(2026, 6, 24, 12, 0, 0);
    gps.controller.add(_pos(speed: 10, at: t0));
    await Future<void>.delayed(Duration.zero);
    // Second fix: distanceBetween → 100 m ≤ 200 m radius → finish prompt.
    gps.controller.add(_pos(speed: 20, at: t0.add(const Duration(seconds: 1))));
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
    final t0 = DateTime(2026, 6, 24, 12, 0, 0);
    gps.controller.add(_pos(speed: 10, at: t0));
    await Future<void>.delayed(Duration.zero);
    gps.controller.add(_pos(speed: 20, at: t0.add(const Duration(seconds: 1))));
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
    final t0 = DateTime(2026, 6, 24, 12, 0, 0);
    gps.controller.add(_pos(speed: 10, at: t0));
    await Future<void>.delayed(Duration.zero);
    gps.controller.add(_pos(speed: 20, at: t0.add(const Duration(seconds: 1))));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(stageFinishProvider), StageFinishReason.location);

    await container.read(stageFinishProvider.notifier).confirm();
    expect(container.read(stageFinishProvider), isNull);
    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.completed,
    );
  });

  test(
      'time-finish dismiss does not suppress the location-finish prompt (per-reason guard)',
      () async {
    // Regression for the A059 stg7 case: a 45s allocatedTime finish fired and
    // was dismissed, which tripped the shared once-per-stage guard and silenced
    // the geofence arrival 16 min later. The guard is now per-reason, so a
    // dismissed time prompt still lets the location prompt fire.
    final plan = PlannedStage(
      id: 's7',
      name: 'stg7',
      startTime: DateTime.now(),
      latitude: 0,
      longitude: 0,
      endLatitude: 1.0,
      endLongitude: 1.0,
      endGeofenceRadiusM: 200,
      autoStop: true,
      allocatedTimeSeconds: 1,
    );
    await readController().startStageFromPlan(plan);
    // Register the finish notifier early (elapsed 0) so its elapsed listener
    // catches the 1 s allocation crossing.
    container.read(stageFinishProvider);

    // Wait for the time-finish prompt (1 Hz clock → ~1 s).
    StageFinishReason? reason;
    for (var i = 0; i < 30 && reason == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      reason = container.read(stageFinishProvider);
    }
    expect(reason, StageFinishReason.time);

    // Crew dismisses the (false-alarm) time prompt.
    container.read(stageFinishProvider.notifier).dismiss();
    expect(container.read(stageFinishProvider), isNull);

    // ...then actually arrives at the finish geofence. The location prompt
    // must still fire (this is the bug — it used to stay null).
    final t0 = DateTime(2026, 6, 24, 12, 0, 0);
    gps.controller.add(_pos(speed: 10, at: t0)); // seeds `last`
    await Future<void>.delayed(Duration.zero);
    gps.controller.add(
        _pos(speed: 20, at: t0.add(const Duration(seconds: 1)))); // 100 m ≤ 200 m
    await Future<void>.delayed(Duration.zero);

    expect(container.read(stageFinishProvider), StageFinishReason.location);
    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.inProgress,
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
    final t0 = DateTime(2026, 6, 24, 12, 0, 0);
    gps.controller.add(_pos(speed: 10, at: t0)); // seeds `last`, 0 km
    await Future<void>.delayed(Duration.zero);
    // 20 m/s over 1 s → odometer += 0.02 km (integrated from position.speed).
    gps.controller.add(_pos(speed: 20, at: t0.add(const Duration(seconds: 1))));
    await Future<void>.delayed(Duration.zero);
    final before =
        container.read(stageControllerProvider).telemetry.currentDistance;
    expect(before, closeTo(0.02, 1e-9));

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
      closeTo(0.02, 1e-9),
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

    // First post-resume fix re-seeds `last` (0 km), second adds 0.02 km — no
    // jump from a stale pre-pause fix.
    final t0 = DateTime(2026, 6, 24, 12, 0, 0);
    gps.controller.add(_pos(speed: 10, at: t0));
    await Future<void>.delayed(Duration.zero);
    gps.controller.add(_pos(speed: 20, at: t0.add(const Duration(seconds: 1))));
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(stageControllerProvider).telemetry.currentDistance,
      closeTo(0.02, 1e-9),
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
    final t0 = DateTime(2026, 6, 24, 12, 0, 0);
    gps.controller.add(_pos(speed: 10, at: t0));
    await Future<void>.delayed(Duration.zero);
    gps.controller.add(_pos(speed: 20, at: t0.add(const Duration(seconds: 1))));
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

    final t0 = DateTime(2026, 6, 24, 12, 0, 0);
    gps.controller.add(_pos(speed: 10, at: t0)); // 10 m/s → 36 km/h
    await Future<void>.delayed(Duration.zero);
    gps.controller.add(
        _pos(speed: 20, at: t0.add(const Duration(seconds: 1)))); // → 72 km/h
    await Future<void>.delayed(Duration.zero);

    final t1 = container.read(stageControllerProvider).telemetry;
    expect(t1.maxSpeedKmh, closeTo(72, 1e-9));
    expect(t1.minSpeedKmh, closeTo(36, 1e-9));

    // A 0-speed fix must count toward the min — stops are legit readings, not
    // filtered out. position.speed == 0 is trusted directly (no derivation),
    // and the odometer integrator adds nothing while stopped.
    gps.controller
        .add(_pos(speed: 0, at: t0.add(const Duration(seconds: 2))));
    await Future<void>.delayed(Duration.zero);

    final t2 = container.read(stageControllerProvider).telemetry;
    expect(t2.minSpeedKmh, closeTo(0, 1e-9));
    expect(t2.maxSpeedKmh, closeTo(72, 1e-9));
  });

  test('speed is read from position.speed (FusedLocation populates it)',
      () async {
    // The primary path: the chipset reports a real velocity in position.speed,
    // which we trust (gated by accuracy + clamped + spike-checked). This is
    // what Google Maps / Waze do — no distance/time derivation.
    await readController().startStage();

    final t0 = DateTime(2026, 6, 24, 12, 0, 0);
    // Establish a moving baseline (72 km/h) so the next fix's 108 km/h is a
    // plausible 36 km/h/s step — within the spike cap, so it's accepted. (A
    // 0→108 km/h jump in 1 s is physically impossible and would be rejected.)
    gps.controller.add(_pos(speed: 20, at: t0, accuracy: 10));
    await Future<void>.delayed(Duration.zero);
    // 30 m/s (108 km/h) reported by the GPS, good accuracy → trusted directly.
    gps.controller
        .add(_pos(speed: 30, at: t0.add(const Duration(seconds: 1)), accuracy: 10));
    await Future<void>.delayed(Duration.zero);

    final t = container.read(stageControllerProvider).telemetry;
    expect(t.maxSpeedKmh, closeTo(108, 1e-6));
    expect(t.minSpeedKmh, closeTo(72, 1e-6));
    expect(t.currentSpeed, closeTo(108, 1e-6));
    // Odometer integrated from speed: 30 m/s × 1 s = 0.03 km (not haversine).
    expect(t.currentDistance, closeTo(0.03, 1e-6));
  });

  test('stationary at a light: jitter must not produce a phantom speed',
      () async {
    // Regression for the reported "34 km/h while stopped at a traffic light".
    // The old derive path turned sub-noise jitter (a few metres between fixes
    // while stationary) into a non-zero speed. Now position.speed == 0 is
    // trusted directly and the odometer integrates speed (0 here), so neither
    // the speed nor the distance creep.
    await readController().startStage();

    final t0 = DateTime(2026, 6, 24, 12, 0, 0);
    gps.controller.add(_pos(speed: 0, at: t0, accuracy: 10)); // baseline, stopped
    await Future<void>.delayed(Duration.zero);
    // Several stationary fixes with a few metres of haversine jitter each.
    for (var i = 1; i <= 4; i++) {
      gps.distanceOverrides.add(5.0); // jitter, ignored by the speed integrator
      gps.controller
          .add(_pos(speed: 0, at: t0.add(Duration(seconds: i)), accuracy: 10));
      await Future<void>.delayed(Duration.zero);
    }

    final t = container.read(stageControllerProvider).telemetry;
    expect(t.currentSpeed, 0.0);
    expect(t.maxSpeedKmh, 0.0);
    // Jitter never reached the odometer (speed-based, not haversine-based).
    expect(t.currentDistance, 0.0);
  });

  test(
      'cold-start: speed=0 while moving falls back to displacement-derived speed',
      () async {
    // Regression for the Pixel drive test: the chipset reported speed=0 on
    // ~20% of fixes while the car was moving (GPS cold-start), so the readout
    // showed 0 km/h at 30+ and the odometer added nothing. The displacement
    // fallback derives the speed from distance/time and advances the odometer
    // by the actual displacement, keeping the readout alive until Doppler
    // warms up.
    await readController().startStage();

    final t0 = DateTime(2026, 6, 24, 12, 0, 0);
    // Baseline: a moving fix with a real Doppler speed so `last` is seeded.
    gps.controller.add(_pos(speed: 8, at: t0, accuracy: 10)); // ~28.8 km/h
    await Future<void>.delayed(Duration.zero);
    // Cold-start fix: chipset reports speed=0, but the car moved 60 m in 6 s
    // (= 36 km/h). Good accuracy (10 m), displacement (60 m) clears the jitter
    // floor (max(10, 2*10) = 20 m) → derived = 36 km/h, accepted and shown;
    // the odometer advances by the actual 60 m (0.06 km), not 0.
    gps.distanceOverrides.add(60.0);
    gps.controller.add(
        _pos(speed: 0, at: t0.add(const Duration(seconds: 6)), accuracy: 10));
    await Future<void>.delayed(Duration.zero);

    final t = container.read(stageControllerProvider).telemetry;
    expect(t.currentSpeed, closeTo(36, 1e-6));
    expect(t.currentDistance, closeTo(0.06, 1e-6));
    // The fallback fired and was logged so a track-test record proves it.
    final fallbacks = logger.records
        .where((r) => r['type'] == 'speed_fallback')
        .map((r) => r['data'] as Map<String, Object?>)
        .toList();
    expect(fallbacks, isNotEmpty);
    expect((fallbacks.last['derivedKmh'] as num).toDouble(), closeTo(36, 1e-6));
  });

  test(
      'cold-start: a teleport while "stopped" (speed=0, junk displacement) is not faked into motion',
      () async {
    // The jitter floor + physical clamp must keep the A059 derivation junk out:
    // a 0-speed fix whose fake displacement implies an implausible speed must
    // NOT turn into a phantom reading (derived capped to null → speed 0,
    // odometer untouched).
    await readController().startStage();

    final t0 = DateTime(2026, 6, 24, 12, 0, 0);
    gps.controller.add(_pos(speed: 0, at: t0, accuracy: 10)); // stopped baseline
    await Future<void>.delayed(Duration.zero);
    // 0 speed, 1 s later, but the fake "moved" 100 m → 360 km/h, above the
    // physical ceiling → no fallback: speed stays 0, odometer stays 0.
    gps.distanceOverrides.add(100.0);
    gps.controller.add(
        _pos(speed: 0, at: t0.add(const Duration(seconds: 1)), accuracy: 10));
    await Future<void>.delayed(Duration.zero);

    final t = container.read(stageControllerProvider).telemetry;
    expect(t.currentSpeed, 0.0);
    expect(t.currentDistance, 0.0);
  });

  test('a speed spike is rejected (impossible acceleration)', () async {
    // Regression for the reported "180 km/h in the city". A single junk fix
    // claiming a huge speed can't snap the readout: the |dv|/dt rate cap holds
    // the previous accepted speed and logs the rejection.
    await readController().startStage();

    final t0 = DateTime(2026, 6, 24, 12, 0, 0);
    // Establish a steady 50.4 km/h (14 m/s) over two fixes.
    gps.controller.add(_pos(speed: 14, at: t0, accuracy: 10));
    await Future<void>.delayed(Duration.zero);
    gps.controller
        .add(_pos(speed: 14, at: t0.add(const Duration(seconds: 1)), accuracy: 10));
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(stageControllerProvider).telemetry.currentSpeed,
      closeTo(50.4, 1e-6),
    );

    // A 56 m/s (201.6 km/h) fix 1 s later → |201.6 − 50.4| / 1 s = 151 km/h/s,
    // far above the 36 km/h/s cap → rejected, speed held, max unchanged.
    gps.distanceOverrides.add(50.0);
    gps.controller.add(
        _pos(speed: 56, at: t0.add(const Duration(seconds: 2)), accuracy: 10));
    await Future<void>.delayed(Duration.zero);

    final t = container.read(stageControllerProvider).telemetry;
    expect(t.currentSpeed, closeTo(50.4, 1e-6));
    expect(t.maxSpeedKmh, closeTo(50.4, 1e-6));
    expect(
      logger.records.where((r) =>
          r['type'] == 'fix_rejected' &&
          (r['data'] as Map<String, Object?>)['reason'] == 'spike'),
      isNotEmpty,
    );
  });

  test(
      'poor-accuracy fix is rejected: speed held, odometer untouched, baseline kept',
      () async {
    // A 600 m-accuracy fix can teleport hundreds of metres; it must not update
    // the speed, must not add to the odometer, and must not advance the
    // baseline (so it can't poison the next interval).
    await readController().startStage();

    final t0 = DateTime(2026, 6, 24, 12, 0, 0);
    // Establish 50.4 km/h (14 m/s), good accuracy. Odometer += 0.014 km.
    gps.controller.add(_pos(speed: 14, at: t0, accuracy: 10));
    await Future<void>.delayed(Duration.zero);
    gps.controller
        .add(_pos(speed: 14, at: t0.add(const Duration(seconds: 1)), accuracy: 10));
    await Future<void>.delayed(Duration.zero);
    final before =
        container.read(stageControllerProvider).telemetry.currentDistance;
    expect(before, closeTo(0.014, 1e-6));

    // Poor-accuracy fix (teleports 1 km via the haversine override): rejected.
    gps.distanceOverrides.add(1000.0);
    gps.controller.add(
        _pos(speed: 14, at: t0.add(const Duration(seconds: 2)), accuracy: 600));
    await Future<void>.delayed(Duration.zero);

    final t = container.read(stageControllerProvider).telemetry;
    expect(t.currentSpeed, closeTo(50.4, 1e-6));
    expect(t.maxSpeedKmh, closeTo(50.4, 1e-6));
    // The teleport added nothing to the odometer.
    expect(t.currentDistance, closeTo(0.014, 1e-6));
    expect(
      logger.records.where((r) =>
          r['type'] == 'fix_rejected' &&
          (r['data'] as Map<String, Object?>)['reason'] == 'poor_accuracy'),
      isNotEmpty,
    );
  });

  test('speed is clamped to the physical ceiling (baseline fix)', () async {
    // A baseline fix (no previous fix → no spike check) reporting an absurd
    // speed is clamped to the physical ceiling rather than displayed raw.
    await readController().startStage();

    final t0 = DateTime(2026, 6, 24, 12, 0, 0);
    // 100 m/s = 360 km/h → clamped to 250 km/h.
    gps.controller.add(_pos(speed: 100, at: t0, accuracy: 10));
    await Future<void>.delayed(Duration.zero);

    final t = container.read(stageControllerProvider).telemetry;
    expect(t.currentSpeed, closeTo(250, 1e-6));
    expect(t.maxSpeedKmh, closeTo(250, 1e-6));
  });

  test('stopStage snapshots a StageResult with max/min/distance/completedAt',
      () async {
    await readController().startStage();

    // First fix seeds `last` (0 km); two moving fixes each integrate 0.02 km
    // (20 m/s × 1 s) → 0.04 km total and a 72 km/h max; a final genuine stop
    // (speed 0) pins the min at 0 (deceleration to 0 is always accepted).
    final t0 = DateTime(2026, 6, 24, 12, 0, 0);
    gps.controller.add(_pos(speed: 10, at: t0)); // 36 km/h, +0 km
    await Future<void>.delayed(Duration.zero);
    gps.controller.add(_pos(speed: 20, at: t0.add(const Duration(seconds: 1))));
    await Future<void>.delayed(Duration.zero);
    gps.controller.add(_pos(speed: 20, at: t0.add(const Duration(seconds: 2))));
    await Future<void>.delayed(Duration.zero);
    gps.controller.add(_pos(speed: 0, at: t0.add(const Duration(seconds: 3))));
    await Future<void>.delayed(Duration.zero);

    readController().stopStage();

    final result = container.read(stageControllerProvider).telemetry.result;
    expect(result, isNotNull);
    expect(result!.maxSpeedKmh, closeTo(72, 1e-9));
    expect(result.minSpeedKmh, closeTo(0, 1e-9));
    expect(result.totalDistanceKm, closeTo(0.04, 1e-9));
    expect(result.completedAt, isNotNull);
  });

  test('startStage resets max/min/result between stages', () async {
    await readController().startStage();
    gps.controller.add(_pos(speed: 20)); // 72 km/h (baseline, no spike check)
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
    // Feed two fixes 1 s apart so distance accumulates (the first seeds `last`).
    final t0 = DateTime(2026, 6, 24, 12, 0, 0);
    gps.controller.add(_pos(speed: 10, at: t0));
    await Future<void>.delayed(Duration.zero);
    gps.controller.add(_pos(speed: 20, at: t0.add(const Duration(seconds: 1))));
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

  test('fix events are logged with position.speed as the speed source',
      () async {
    // The logger records the chipset's position.speed (raw + km/h) and the
    // accepted speed, so a pulled log shows whether the device actually
    // reported a velocity (the FusedLocation health check after a track test).
    await readController().startStage();

    final t0 = DateTime(2026, 6, 24, 12, 0, 0);
    // Moving baseline (72 km/h) so the 108 km/h step is plausible (within the
    // spike cap) and accepted; the log then records the real reported velocity.
    gps.controller.add(_pos(speed: 20, at: t0, accuracy: 10));
    await Future<void>.delayed(Duration.zero);
    // 30 m/s (108 km/h) reported by the GPS, good accuracy → trusted.
    gps.controller
        .add(_pos(speed: 30, at: t0.add(const Duration(seconds: 1)), accuracy: 10));
    await Future<void>.delayed(Duration.zero);

    final fixes = logger.records.where((r) => r['type'] == 'fix').toList();
    expect(fixes.length, greaterThanOrEqualTo(2));
    final moving = fixes.last;
    expect(moving['rawSpeedMps'], 30.0); // GPS reported the real velocity
    expect(moving['gpsSpeedKmh'], 108.0); // ... so the GPS speed is 108 km/h
    expect((moving['speedKmh'] as num).toDouble(), closeTo(108, 1e-6));
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