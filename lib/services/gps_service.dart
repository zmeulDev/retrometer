import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Force raw GPS via Android's `LocationManager` instead of the
/// FusedLocationProvider. FusedLocation on some devices (observed on the A059
/// Xiaomi mid-range) reports `position.speed == 0` while moving, accuracy up to
/// 600m, and throttles the fix rate to ~12s regardless of `intervalDuration`.
/// Raw GPS typically populates `speed` (Doppler-derived) and gives a steady
/// ~1s interval under open sky (a rally is open sky).
///
/// **Enabled for the Pixel 9 Pro XL track test.** Verified necessary on the
/// A059 (FusedLocation ignored `intervalDuration: 1s`, cadence stayed ~12s,
/// `rawSpeedMps > 0` on only 1/15 fixes). The Pixel has dual-frequency L1+L5
/// GNSS; raw GPS should give 1Hz + real speed + ~3–5m accuracy. If raw
/// `LocationManager` proves unreliable on a given Android build, flip back to
/// `false` (FusedLocation) — the derived-speed + accuracy-gate paths in
/// `state_providers.dart` remain as fallback. Check the telemetry log after a
/// run: `rawSpeedMps > 0` on good-accuracy fixes + steady ~1s `dtMs`.
const bool kForceAndroidLocationManager = true;

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
  /// save battery — it only needs ~1 km resolution.
  Stream<Position> positionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 0,
  });

  /// The last known position stored on the device, or `null` if none. This is
  /// instant (no cold-start) and is good enough for a hundreds-of-metres
  /// geofence check — the auto-start monitor uses it as its fast path.
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
  }) =>
      Geolocator.getPositionStream(
        locationSettings: _locationSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter,
          // On Android, request a steady 1 Hz fix rate so the derived speed
          // (distance/time) isn't amplified by large, irregular dt — and the
          // odometer accumulates smoothly. Ignored on other platforms.
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