import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:retrometer/main.dart';
import 'package:retrometer/services/competition_repository.dart';
import 'package:retrometer/services/device_service.dart';
import 'package:retrometer/services/gps_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

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
/// Competitions now persist to SQLite (see [CompetitionRepository]), so each
/// pump mounts a throwaway test database at `retrometer_test.db` under the
/// device's databases path. By default ([resetDb] true) the file is deleted
/// first, so the pump starts from an empty DB — which lets the legacy
/// `retrometer.competitions` blob in [prefs] migrate in on first load (empty DB
/// ⇒ one-way import). Pass `resetDb: false` on a "restart" pump so the fresh
/// [ProviderScope] rehydrates from the same DB the previous pump wrote.
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
  bool resetDb = true,
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
  final repo = await _testRepository(reset: resetDb);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gpsServiceProvider.overrideWithValue(g),
        deviceServiceProvider.overrideWithValue(d),
        competitionRepositoryProvider.overrideWithValue(repo),
      ],
      child: child,
    ),
  );
  return ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
    listen: false,
  );
}

/// Per-pump SQLite repository at a stable test path under the device's
/// databases directory. When [reset] is true the file is deleted first so the
/// pump starts from an empty DB (legacy blob in prefs then migrates in).
Future<CompetitionRepository> _testRepository({bool reset = true}) async {
  final dir = await getDatabasesPath();
  final dbPath = path.join(dir, 'retrometer_test.db');
  if (reset) {
    await databaseFactory.deleteDatabase(dbPath);
  }
  return SqliteCompetitionRepository(
    databaseFactory: databaseFactory,
    pathProvider: () async => dbPath,
  );
}