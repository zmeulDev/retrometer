import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:retrometer/about_view.dart';
import 'package:retrometer/guide_view.dart';
import 'package:retrometer/services/gps_service.dart';

/// Mocks the package_info_plus method channel with deterministic values so the
/// About screen can be tested without a real platform.
Future<void> _mockPackageInfo(Map<String, dynamic> data) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/package_info'),
    (MethodCall call) async {
      if (call.method == 'getAll') return data;
      return null;
    },
  );
}

const _packageInfo = <String, dynamic>{
  'appName': 'Retrometer',
  'packageName': 'com.zmeul.retrometer',
  'version': '1.0.0',
  'buildNumber': '1',
  'buildSignature': '',
  'installerStore': null,
};

/// Fake GPS service reporting a fixed [permission] and [serviceEnabled].
class _FakeGps implements GpsService {
  _FakeGps({this.permission = LocationPermission.whileInUse, this.serviceEnabled = true});

  final LocationPermission permission;
  final bool serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Stream<Position> positionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 0,
  }) =>
      const Stream<Position>.empty();

  @override
  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) =>
      0;
}

void main() {
  testWidgets('About screen shows the app version, a guide link, and permissions',
      (WidgetTester tester) async {
    await _mockPackageInfo(_packageInfo);

    await tester.pumpWidget(ProviderScope(
      overrides: [gpsServiceProvider.overrideWithValue(_FakeGps())],
      child: const MaterialApp(home: AboutScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Despre aplicație'), findsOneWidget);
    expect(find.text('Retrometer'), findsOneWidget);
    expect(find.text('Versiune 1.0.0'), findsOneWidget);

    // Permissions section: three rows for the three declared permissions.
    expect(find.text('Permisiuni'), findsOneWidget);
    expect(find.text('Locație (GPS)'), findsOneWidget);
    expect(find.text('Vibrație'), findsOneWidget);
    expect(find.text('Ecran aprins'), findsOneWidget);

    // Location granted (whileInUse) shows an "Acordată" chip.
    expect(find.text('Acordată · în folosire'), findsOneWidget);
    // Normal permissions are shown as granted at install time.
    expect(find.text('Acordată'), findsNWidgets(2));

    // Guide link opens the guide screen when tapped.
    expect(find.text('Ghid de utilizare'), findsOneWidget);
    await tester.tap(find.text('Ghid de utilizare'));
    await tester.pumpAndSettle();
    expect(find.byType(GuideScreen), findsOneWidget);
  });

  testWidgets('About screen reports a denied location permission',
      (WidgetTester tester) async {
    await _mockPackageInfo(_packageInfo);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        gpsServiceProvider.overrideWithValue(
            _FakeGps(permission: LocationPermission.denied)),
      ],
      child: const MaterialApp(home: AboutScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Refuzată'), findsOneWidget);
  });

  testWidgets('About screen reports a disabled GPS service',
      (WidgetTester tester) async {
    await _mockPackageInfo(_packageInfo);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        gpsServiceProvider.overrideWithValue(_FakeGps(serviceEnabled: false)),
      ],
      child: const MaterialApp(home: AboutScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('GPS oprit'), findsOneWidget);
  });

  testWidgets('About screen renders without overflow on a narrow screen',
      (WidgetTester tester) async {
    await _mockPackageInfo(_packageInfo);

    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [gpsServiceProvider.overrideWithValue(_FakeGps())],
      child: const MaterialApp(home: AboutScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Retrometer'), findsOneWidget);
    // No overflow reported (a flex overflow fails via FlutterError.onError).
  });
}