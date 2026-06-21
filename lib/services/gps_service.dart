import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

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
        locationSettings: LocationSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter,
        ),
      );

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