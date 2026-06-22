import 'package:geolocator/geolocator.dart';

/// Build a synthetic [Position] for the integration-test fake GPS stream.
///
/// [speed] is in m/s (the unit `Position.speed` uses); the stage controller
/// converts it to km/h via `* 3.6`. [timestamp] should progress between fixes
/// so the controller's fallback speed calc has a real delta if [speed] is NaN.
Position fakePosition({
  double latitude = 45.0,
  double longitude = 24.0,
  double speed = 0,
  required DateTime timestamp,
}) {
  return Position(
    longitude: longitude,
    latitude: latitude,
    timestamp: timestamp,
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: speed,
    speedAccuracy: 0,
  );
}