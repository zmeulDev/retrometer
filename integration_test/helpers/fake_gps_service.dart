import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:retrometer/services/gps_service.dart';

/// Injectable GPS service for integration tests.
///
/// - [controller] is the broadcast stream the stage controller and the locality
///   feed subscribe to; the test pushes synthetic [Position]s into it.
/// - [fixedDistanceBetween], when set, makes every `distanceBetween` call return
///   that many metres (handy for asserting an exact accumulated distance). When
///   `null`, the real haversine distance between the two coordinates is used.
/// - [lastKnownPosition] / [currentPositionResult] drive the auto-start
///   monitor's one-shot fix sources (Pass 2). Leaving both `null` makes the
///   monitor report "no GPS fix" — useful to prove a prompt came from the time
///   path (Pass 1), not the location path.
class FakeGpsService implements GpsService {
  FakeGpsService({
    this.permission = LocationPermission.whileInUse,
    this.serviceEnabled = true,
    this.fixedDistanceBetween,
    this.lastKnownPosition,
    this.currentPositionResult,
  });

  LocationPermission permission;
  bool serviceEnabled;
  double? fixedDistanceBetween;
  Position? lastKnownPosition;
  Position? currentPositionResult;

  /// Number of times [isLocationServiceEnabled] was called. The auto-start
  /// monitor only touches GPS in Pass 2; the locality feed calls it on mount.
  int isLocationServiceEnabledCalls = 0;

  final StreamController<Position> controller =
      StreamController<Position>.broadcast();

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<bool> isLocationServiceEnabled() async {
    isLocationServiceEnabledCalls++;
    return serviceEnabled;
  }

  @override
  Future<Position?> getLastKnownPosition() async => lastKnownPosition;

  @override
  Future<Position> getCurrentPosition({Duration? timeLimit}) async {
    final result = currentPositionResult;
    if (result == null) {
      throw TimeoutException('no fresh fix', timeLimit ?? Duration.zero);
    }
    return result;
  }

  @override
  Stream<Position> positionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 0,
  }) =>
      controller.stream;

  @override
  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    final fixed = fixedDistanceBetween;
    if (fixed != null) return fixed;
    return _haversineMetres(startLatitude, startLongitude, endLatitude, endLongitude);
  }
}

/// Great-circle distance in metres between two lat/lng pairs.
double _haversineMetres(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180.0;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(a)));
}