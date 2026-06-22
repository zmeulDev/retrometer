import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../state_providers.dart';
import '../theme/retrometer_theme.dart';

/// Center cockpit zone (45%): the Δ indicator with a clear AVANS / ÎNTÂRZIERE
/// / LA TIMP label and an over-speed alert overlay. Repaint-isolated.
class DeltaIndicator extends ConsumerWidget {
  const DeltaIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final band = ref.watch(deltaBandProvider);
    final delta = ref.watch(deltaSecondsProvider);
    final overSpeed = ref.watch(isOverSpeedProvider);
    final name = ref.watch(
      stageControllerProvider.select((s) => s.config.name),
    );
    final target = ref.watch(
      stageControllerProvider.select((s) => s.config.targetAvgSpeed),
    );
    final speed = ref.watch(
      stageControllerProvider.select((s) => s.telemetry.currentSpeed),
    );
    final avgReal = ref.watch(actualAvgSpeedProvider);

    final Color bgColor;
    final Color fgColor;
    final String label;
    switch (band) {
      case DeltaBand.onTime:
        bgColor = RetrometerColors.onTimeBg;
        fgColor = RetrometerColors.onTimeFg;
        label = 'LA TIMP';
      case DeltaBand.advance: // ahead → red
        bgColor = RetrometerColors.advanceBg;
        fgColor = RetrometerColors.advanceFg;
        label = 'AVANS';
      case DeltaBand.delay: // late → yellow
        bgColor = RetrometerColors.delayBg;
        fgColor = RetrometerColors.delayFg;
        label = 'ÎNTÂRZIERE';
    }

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: fgColor.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              padding:
                  const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: RetrometerTextStyles.bandLabel(fgColor),
                    ),
                    Text(
                      _formatDelta(delta),
                      style: RetrometerTextStyles.deltaNumberColored(fgColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'țintă ${_fmtSpeed(target)} / '
                      'reală ${avgReal == null ? '—' : _fmtSpeed(avgReal)} / '
                      'acum ${speed.toStringAsFixed(0)} km/h',
                      style: RetrometerTextStyles.deltaSubtitle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: RetrometerTextStyles.deltaStageName,
                    ),
                  ],
                ),
              ),
            ),
            if (overSpeed)
              const Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: OverSpeedAlert(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pulsing "⚠ OVER SPEED" banner overlaid on the Δ zone when the current
/// speed exceeds the configured maximum.
class OverSpeedAlert extends StatefulWidget {
  const OverSpeedAlert({super.key});

  @override
  State<OverSpeedAlert> createState() => _OverSpeedAlertState();
}

class _OverSpeedAlertState extends State<OverSpeedAlert>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red, width: 1),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
        alignment: Alignment.center,
        child: const Text(
          '⚠ OVER SPEED',
          style: RetrometerTextStyles.overSpeed,
        ),
      ),
    );
  }
}

String _formatDelta(double delta) {
  final sign = delta < 0 ? '-' : '+';
  return '$sign ${delta.abs().toStringAsFixed(1)}';
}

/// Speed display: whole numbers without a decimal (40), fractional with one
/// (35.9) — so a target average entered as 35.9 shows as 35.9, not 36.
String _fmtSpeed(double v) =>
    v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);