import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:retrometer/models.dart';
import 'package:retrometer/services/device_service.dart';
import 'package:retrometer/services/gps_service.dart';
import 'package:retrometer/state_providers.dart';

/// Fake GPS service: emits positions pushed into [controller], and reports a
/// fixed [metresPerStep] for every `distanceBetween` call.
class _FakeGpsService implements GpsService {
  _FakeGpsService();

  /// Metres reported for every consecutive position pair.
  static const double metresPerStep = 100;

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
      metresPerStep;
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

Position _pos({required double speed}) => Position(
      longitude: 0,
      latitude: 0,
      timestamp: DateTime.now(),
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
  late ProviderContainer container;

  setUp(() {
    gps = _FakeGpsService();
    device = _FakeDeviceService();
    container = ProviderContainer(
      overrides: [
        gpsServiceProvider.overrideWithValue(gps),
        deviceServiceProvider.overrideWithValue(device),
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

  test('auto-stop fires when a GPS fix enters the finish geofence', () async {
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
    // First fix seeds `last`; auto-stop needs a previous fix.
    gps.controller.add(_pos(speed: 10));
    await Future<void>.delayed(Duration.zero);
    // Second fix: distanceBetween → 100 m ≤ 200 m radius → auto-stop.
    gps.controller.add(_pos(speed: 20));
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.completed,
    );
    expect(device.hapticCalls, greaterThanOrEqualTo(1));
  });

  test('auto-stop is skipped when autoStop is disabled', () async {
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
    gps.controller.add(_pos(speed: 10));
    await Future<void>.delayed(Duration.zero);
    gps.controller.add(_pos(speed: 20));
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.inProgress,
    );
  });
}