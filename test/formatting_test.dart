import 'package:flutter_test/flutter_test.dart';

import 'package:retrometer/utils/formatting.dart';

void main() {
  group('two', () {
    test('zero-pads single digits', () {
      expect(two(5), '05');
      expect(two(0), '00');
    });

    test('leaves double digits as-is', () {
      expect(two(12), '12');
      expect(two(59), '59');
    });
  });

  group('fmtSpeed', () {
    test('whole numbers drop the decimal', () {
      expect(fmtSpeed(40), '40');
      expect(fmtSpeed(0), '0');
    });

    test('fractional numbers keep one decimal', () {
      expect(fmtSpeed(35.9), '35.9');
      expect(fmtSpeed(18.0), '18'); // 18.0 is whole → "18"
    });
  });

  group('formatElapsed', () {
    test('formats mm:ss', () {
      expect(formatElapsed(0), '00:00');
      expect(formatElapsed(65), '01:05');
      expect(formatElapsed(599), '09:59');
      expect(formatElapsed(3600), '60:00');
    });

    test('clamps negatives to zero', () {
      expect(formatElapsed(-5), '00:00');
    });
  });

  group('fmtCoord / fmtCoordNullable', () {
    test('five decimals by default', () {
      expect(fmtCoord(45.123456789), '45.12346');
    });

    test('nullable returns empty on null', () {
      expect(fmtCoordNullable(null), '');
      expect(fmtCoordNullable(24.5), '24.50000');
    });

    test('honours digits', () {
      expect(fmtCoord(1.5, digits: 2), '1.50');
    });
  });

  group('fmtCoordPair', () {
    test('fallback when either is null', () {
      expect(fmtCoordPair(null, 24.0), 'fără locație');
      expect(fmtCoordPair(45.0, null), 'fără locație');
    });

    test('lat, lng without radius', () {
      expect(fmtCoordPair(45.12, 24.34), '45.12000, 24.34000');
    });

    test('appends radius when given', () {
      expect(
        fmtCoordPair(45.0, 24.0, radiusM: 200),
        '45.00000, 24.00000 (±200 m)',
      );
    });

    test('custom fallback', () {
      expect(fmtCoordPair(null, null, fallback: '—'), '—');
    });
  });

  group('formatTime', () {
    test('HH:mm or em-dash', () {
      expect(formatTime(null), '—');
      expect(formatTime(DateTime(2026, 6, 22, 9, 5)), '09:05');
      expect(formatTime(DateTime(2026, 6, 22, 14, 30)), '14:30');
    });
  });

  group('newId', () {
    test('prefixes with the given token', () {
      final id = newId('stage');
      expect(id.startsWith('stage-'), isTrue);
      // The suffix is the epoch millis — a run of digits.
      final suffix = id.substring('stage-'.length);
      expect(int.tryParse(suffix), isNotNull);
    });
  });

  group('roundToMinute', () {
    test('drops seconds and milliseconds', () {
      expect(
        roundToMinute(DateTime(2026, 6, 22, 9, 5, 37, 999)),
        DateTime(2026, 6, 22, 9, 5),
      );
    });
  });
}