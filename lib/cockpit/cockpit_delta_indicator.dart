import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../state_providers.dart';
import '../theme/retrometer_theme.dart';
import '../utils/formatting.dart';
import '../widgets/cards.dart';
import '../widgets/shrink_to_fit.dart';

/// Center cockpit zone (45%): the Δ indicator with a clear AVANS / ÎNTÂRZIERE
/// / LA TIMP label and an over-speed alert overlay. Repaint-isolated.
///
/// **Δ flash:** AVANS / ÎNTÂRZIERE flash hard (full-zone saturated wash + a
/// pulsing top accent bar), ~700ms with a hard cut, to grab attention at 100%.
/// LA TIMP stays calm and steady. Respects `MediaQuery.disableAnimationsOf` —
/// when reduced motion is requested the flash is replaced by a steady tint.
class DeltaIndicator extends ConsumerStatefulWidget {
  const DeltaIndicator({super.key});

  @override
  ConsumerState<DeltaIndicator> createState() => _DeltaIndicatorState();
}

class _DeltaIndicatorState extends ConsumerState<DeltaIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash;

  @override
  void initState() {
    super.initState();
    _flash = AnimationController(
      vsync: this,
      duration: RetrometerDurations.deltaFlash,
    );
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    final colors = context.colors;
    final Color bgColor;
    final Color fgColor;
    final String label;
    switch (band) {
      case DeltaBand.onTime:
        bgColor = colors.onTimeBg;
        fgColor = colors.onTimeFg;
        label = 'LA TIMP';
      case DeltaBand.advance: // ahead → red
        bgColor = colors.advanceBg;
        fgColor = colors.advanceFg;
        label = 'AVANS';
      case DeltaBand.delay: // late → amber
        bgColor = colors.delayBg;
        fgColor = colors.delayFg;
        label = 'ÎNTÂRZIERE';
    }

    final reduced = MediaQuery.disableAnimationsOf(context);
    final flashOn = band != DeltaBand.onTime && !reduced;
    if (flashOn) {
      if (!_flash.isAnimating) _flash.repeat(reverse: false);
    } else {
      if (_flash.isAnimating) _flash.stop();
      _flash.reset();
    }

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedContainer(
              duration: RetrometerDurations.bandTransition,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(RetrometerRadii.band),
                border: Border.all(
                  color: fgColor.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              padding:
                  const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              child: ShrinkToFit(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Leave room for the tick-mark row pinned above the content.
                    const SizedBox(height: 10),
                    Text(
                      label,
                      style: context.text.bandLabel(fgColor),
                    ),
                    Text(
                      _formatDelta(delta),
                      style: context.text.deltaNumberColored(fgColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'țintă ${fmtSpeed(target)} / '
                      'reală ${avgReal == null ? '—' : fmtSpeed(avgReal)} / '
                      'acum ${speed.toStringAsFixed(0)} km/h',
                      style: context.text.deltaSubtitle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: context.text.deltaStageName,
                    ),
                  ],
                ),
              ),
            ),
            // Tick-mark gauge row pinned to the top — analog flavor, flat.
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: IgnorePointer(
                child: CustomPaint(
                  size: const Size(double.infinity, 8),
                  painter: _TickPainter(color: colors.dividerStrong),
                ),
              ),
            ),
            // Pulsing accent bar at the very top center (the flash signal).
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _flash,
                  builder: (context, _) {
                    double markH;
                    double markO;
                    if (!flashOn) {
                      markH = 3;
                      markO = 1;
                    } else {
                      final bright = _flash.value < 0.28;
                      markH = bright ? 8 : 3;
                      markO = bright ? 1 : 0.35;
                    }
                    return Opacity(
                      opacity: markO,
                      child: Container(
                        width: 60,
                        height: markH,
                        decoration: BoxDecoration(
                          color: fgColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Hard on/off wash overlay (the flash itself), clipped to the band.
            if (band != DeltaBand.onTime)
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(RetrometerRadii.band),
                    child: AnimatedBuilder(
                      animation: _flash,
                      builder: (context, _) {
                        final double wash;
                        if (!flashOn) {
                          wash = reduced ? 0.22 : 0.05;
                        } else {
                          wash = _flash.value < 0.28 ? 0.40 : 0.05;
                        }
                        return ColoredBox(
                          color: fgColor.withValues(alpha: wash),
                        );
                      },
                    ),
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

/// Draws a row of tick marks (alternating long/short) — the analog-gauge flavor
/// strip pinned across the top of the Δ zone. Flat, no shadow.
class _TickPainter extends CustomPainter {
  const _TickPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const count = 41;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final dx = size.width / (count - 1);
    for (var i = 0; i < count; i++) {
      final x = i * dx;
      final long = i.isOdd;
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x, long ? size.height - 8 : size.height - 4),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TickPainter oldDelegate) => oldDelegate.color != color;
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
    final colors = context.colors;
    return FadeTransition(
      opacity: _ctrl,
      child: SurfaceCard(
        color: colors.scrim,
        radius: RetrometerRadii.chip,
        border: BorderSide(color: colors.danger, width: 1),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
        alignment: Alignment.center,
        child: Text(
          '⚠ OVER SPEED',
          style: context.text.overSpeed,
        ),
      ),
    );
  }
}

String _formatDelta(double delta) {
  final sign = delta < 0 ? '-' : '+';
  return '$sign ${delta.abs().toStringAsFixed(1)}';
}