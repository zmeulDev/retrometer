import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrometer/main.dart';
import 'package:retrometer/models.dart';
import 'package:retrometer/services/competition_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory repository so the responsive sweep doesn't touch disk (avoids
/// the macOS ffi-temp-dir flakiness); the cockpit at idle only needs an empty
/// `loadAll()`.
class _FakeRepo implements CompetitionRepository {
  @override
  Future<List<Competition>> loadAll() async => const [];

  @override
  Future<void> saveCompetitions(List<Competition> competitions) async {}

  @override
  Future<void> appendHistory(String competitionId, StageRunHistory entry) async {}
}

/// Regression guard for the cockpit rendering without overflow across the
/// geometry + accessibility-text-scale matrix that broke on the Pixel 9 Pro XL
/// (1008×2244 px @ density 360 ⇒ ~448×997 logical). The integration suite runs
/// at the device's real `font_scale` (1.15) and edge-to-edge (no insets); this
/// sweep also covers phone landscape and large accessibility scales (1.5–2×)
/// so a future change can't quietly reintroduce a 15 px overflow.
void main() {
  // (label, logical size, system padding) — Pixel 9 Pro XL portrait/landscape.
  const cases = <(String, Size, FakeViewPadding)>[
    ('portrait', Size(448, 997), FakeViewPadding.zero),
    ('portrait cutout', Size(448, 997), FakeViewPadding(top: 66)),
    ('landscape', Size(997, 448), FakeViewPadding(bottom: 41)),
  ];

  for (final ts in [1.0, 1.15, 1.3, 1.5, 2.0]) {
    for (final c in cases) {
      testWidgets('cockpit does not overflow: ${c.$1} @ ${ts}x text', (tester) async {
        tester.view.physicalSize = c.$2;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = c.$3;
        tester.platformDispatcher.textScaleFactorTestValue = ts;
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues({'retrometer.onboarded': true});

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              competitionRepositoryProvider.overrideWithValue(_FakeRepo()),
            ],
            child: const RetrometerApp(),
          ),
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 300));
        await tester.pump();

        expect(tester.takeException(), isNull,
            reason: '${c.$1} at textScale $ts overflowed');
      });
    }
  }
}