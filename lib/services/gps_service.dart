import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Whether to force Android's raw `LocationManager` over the
/// `FusedLocationProvider`.
///
/// `false` (the default) uses FusedLocationProvider - the same source Google
/// Maps / Waze rely on, which **populates `position.speed`** (the chipset's
/// Doppler/fused velocity) and delivers ~1 Hz fixes. The speed reading in
/// `state_providers.dart` trusts `position.speed` as its primary source, so a
/// provider that returns `speed == 0` makes the displayed speed wrong.
///
/// An earlier build set this to `true` to work around a weak FusedLocation on
/// the Xiaomi A059 (0 speed, ~12 s cadence). Verified on the Pixel 9 Pro XL:
/// raw `LocationManager` (true) returns `speed == 0` on **every** fix and
/// ~13 s cadence - so the raw-LM path is what broke speed here. Other apps on
/// the same Pixel display real speed -> FusedLocation populates it; flip to
/// `false`. Verify with the telemetry log after a run: `rawSpeedMps > 0` on
/// most fixes + steady ~1 s `dtMs`.
const bool kForceAndroidLocationManager = false;

/// Thin, injectable wrapper around `geolocator`.
///
/// Abstract so tests can feed synthetic [Position]s into the controller without
/// touching the platform. The production implementation delegates to the static
/// `Geolocator` API.
abstract class GpsService {
  /// Current permission state (does not prompt).
  Future<LocationPermission> checkPermission();

  /// Prompts the user for "while in use" location access if not yet decided.
  Future<LocationPermission> requestPermission();

  /// Whether the device GPS is enabled / service available.
  Future<bool> isLocationServiceEnabled();

  /// Position stream. Defaults to high accuracy with `distanceFilter: 0`
  /// (every fix) so the stage controller can accumulate distance itself. The
  /// always-on locality feed passes a lower accuracy + a distance filter to
  /// save battery - it only needs ~1 km resolution. Set [bestForNavigation]
  /// for the stage stream: navigation-grade accuracy (what map apps use),
  /// fastest fixes + a populated `position.speed`.
  Stream<Position> positionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 0,
    bool bestForNavigation = false,
  });

  /// The last known position stored on the device, or `null` if none. This is
  /// instant (no cold-start) and is good enough for a hundreds-of-metres
  /// geofence check - the auto-start monitor uses it as its fast path.
  Future<Position?> getLastKnownPosition();

  /// A fresh one-shot position. Throws `TimeoutException` if no fix arrives
  /// within [timeLimit]. Used as a fallback when [getLastKnownPosition] is
  /// missing or stale.
  Future<Position> getCurrentPosition({Duration? timeLimit});

  /// Great-circle distance in **metres** between two coordinates.
  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  });
}

class GeolocatorGpsService implements GpsService {
  const GeolocatorGpsService();

  @override
  Future<LocationPermission> checkPermission() =>
      Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Stream<Position> positionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 0,
    bool bestForNavigation = false,
  }) =>
      Geolocator.getPositionStream(
        locationSettings: _locationSettings(
          accuracy:
              bestForNavigation ? LocationAccuracy.bestForNavigation : accuracy,
          distanceFilter: distanceFilter,
          // On Android, request a steady 1 Hz fix rate so the speed (and the
          // odometer, integrated from `position.speed`) update in real time.
          // Ignored on other platforms.
          intervalDuration: const Duration(seconds: 1),
        ),
      );

  @override
  Future<Position?> getLastKnownPosition() => Geolocator.getLastKnownPosition();

  @override
  Future<Position> getCurrentPosition({Duration? timeLimit}) =>
      Geolocator.getCurrentPosition(
        locationSettings: _locationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeLimit,
        ),
      );

  /// Builds platform-aware location settings. On Android uses `AndroidSettings`
  /// with a 1 Hz interval (for the stream) and the `kForceAndroidLocationManager`
  /// flag; elsewhere falls back to the generic `LocationSettings`. `intervalDuration`
  /// is only applied where non-null (the one-shot `getCurrentPosition` omits it).
  static LocationSettings _locationSettings({
    required LocationAccuracy accuracy,
    int distanceFilter = 0,
    Duration? timeLimit,
    Duration? intervalDuration,
  }) {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        forceLocationManager: kForceAndroidLocationManager,
        intervalDuration: intervalDuration,
        timeLimit: timeLimit,
      );
    }
    return LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
      timeLimit: timeLimit,
    );
  }

  @override
  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) =>
      Geolocator.distanceBetween(
        startLatitude,
        startLongitude,
        endLatitude,
        endLongitude,
      );
}

/// Riverpod provider for the GPS service. Override in tests with a fake.
final gpsServiceProvider = Provider<GpsService>((ref) => const GeolocatorGpsService());