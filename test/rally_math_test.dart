import 'package:flutter_test/flutter_test.dart';
import 'package:retrometer/models.dart';
import 'package:retrometer/rally_math.dart';

void main() {
  group('idealSeconds', () {
    test('converts km / kmh to seconds', () {
      // 10 km at 40 km/h → 0.25 h → 900 s.
      expect(idealSeconds(distanceKm: 10, targetKmh: 40), 900);
    });

    test('zero distance ⇒ zero ideal time', () {
      expect(idealSeconds(distanceKm: 0, targetKmh: 40), 0);
    });

    test('non-positive target ⇒ zero (no division by zero)', () {
      expect(idealSeconds(distanceKm: 10, targetKmh: 0), 0);
      expect(idealSeconds(distanceKm: 10, targetKmh: -5), 0);
    });
  });

  group('deltaSeconds', () {
    final start = DateTime(2026, 1, 1, 10, 0, 0);

    test('negative (ahead) when real time < ideal', () {
      // 10 km at 40 km/h → ideal 900 s. Real elapsed 800 s → Δ = -100.
      final now = start.add(const Duration(seconds: 800));
      expect(
        deltaSeconds(start: start, now: now, distanceKm: 10, targetKmh: 40),
        closeTo(-100, 1e-6),
      );
    });

    test('positive (late) when real time > ideal', () {
      final now = start.add(const Duration(seconds: 950));
      expect(
        deltaSeconds(start: start, now: now, distanceKm: 10, targetKmh: 40),
        closeTo(50, 1e-6),
      );
    });

    test('zero when exactly on ideal pace', () {
      final now = start.add(const Duration(seconds: 900));
      expect(
        deltaSeconds(start: start, now: now, distanceKm: 10, targetKmh: 40),
        closeTo(0, 1e-6),
      );
    });

    test('millisecond resolution preserved', () {
      final now = start.add(const Duration(milliseconds: 900500));
      expect(
        deltaSeconds(start: start, now: now, distanceKm: 10, targetKmh: 40),
        closeTo(0.5, 1e-6),
      );
    });
  });

  group('deltaBandFor', () {
    test('onTime within ±1 s', () {
      expect(deltaBandFor(0), DeltaBand.onTime);
      expect(deltaBandFor(1.0), DeltaBand.onTime);
      expect(deltaBandFor(-1.0), DeltaBand.onTime);
    });

    test('advance when Δ < -1', () {
      expect(deltaBandFor(-1.5), DeltaBand.advance);
      expect(deltaBandFor(-100), DeltaBand.advance);
    });

    test('delay when Δ > 1', () {
      expect(deltaBandFor(1.5), DeltaBand.delay);
      expect(deltaBandFor(100), DeltaBand.delay);
    });
  });
}