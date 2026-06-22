import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrometer/main.dart';
import 'package:retrometer/services/device_service.dart';
import 'package:retrometer/services/gps_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_device_service.dart';
import 'fake_gps_service.dart';

/// Mocks the geocoding method channel to return empty results, so the cockpit's
/// locality feed (which reverse-geocodes every fresh fix) doesn't hit a missing
/// plugin in the headless test. The locality then falls back to '—'.
void _mockGeocoding() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('flutter.baseflow.com/geocoding'),
    (MethodCall call) async {
      switch (call.method) {
        case 'placemarkFromCoordinates':
        case 'locationFromAddress':
        case 'placemarkFromAddress':
          return <dynamic>[];
        case 'isPresent':
          return true;
        default:
          return null;
      }
    },
  );
}

/// Pumps the full [RetrometerApp] under a [ProviderScope] that overrides the
/// GPS and device services with fakes, so the suite runs headlessly without
/// touching platform channels.
///
/// [prefs] are merged on top of the defaults that skip onboarding + location
/// disclosure (so START / auto-start confirm don't surface those dialogs). Pass
/// `resetPrefs: false` on a "restart" pump to preserve values written by a
/// previous pump (e.g. the persistence test).
///
/// Returns the active [ProviderContainer] so the test can read/Drive providers
/// directly. The fakes are created when not supplied, but to push fixes into
/// the GPS stream the caller should create the [FakeGpsService] themselves and
/// pass it in.
Future<ProviderContainer> pumpRetrometer(
  WidgetTester tester, {
  FakeGpsService? gps,
  FakeDeviceService? device,
  Map<String, Object> prefs = const {},
  bool resetPrefs = true,
  Widget child = const RetrometerApp(),
}) async {
  if (resetPrefs) {
    SharedPreferences.setMockInitialValues({
      'retrometer.onboarded': true,
      'retrometer.location_disclosure_shown': true,
      ...prefs,
    });
  }
  _mockGeocoding();
  final g = gps ?? FakeGpsService();
  final d = device ?? FakeDeviceService();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gpsServiceProvider.overrideWithValue(g),
        deviceServiceProvider.overrideWithValue(d),
      ],
      child: child,
    ),
  );
  return ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
    listen: false,
  );
}