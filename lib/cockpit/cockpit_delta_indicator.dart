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
    final status = ref.watch(
      stageControllerProvider.select((s) => s.telemetry.status),
    );
    // Locality header (left zone): reverse-geocoded from the latest fix. '—'
    // before the first fix / when geocoding is unavailable. The icon lights up
    // (primary) only when we actually have a GPS fix.
    final localityAsync = ref.watch(localityProvider);
    final locality = localityAsync.valueOrNull ??
        (localityAsync.isLoading ? '…' : '—');
    final hasFix = ref.watch(positionProvider).hasValue;

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
    // Only flash while a stage is actually running — paused/completed stages
    // hold their final band without pulsing, so PAUZĂ / STOP visibly "freeze".
    final flashOn =
        status == StageStatus.inProgress && band != DeltaBand.onTime && !reduced;
    if (flashOn) {
      if (!_flash.isAnimating) _flash.repeat(reverse: false);
    } else {
      if (_flash.isAnimating) _flash.stop();
      _flash.reset();
    }

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Cap the locality label at ~55% of the band width so it can never
            // push into the centered Δ readout; long names ellipsize.
            final locMaxWidth = (constraints.maxWidth * 0.55).clamp(60.0, 220.0);
            return Stack(
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Hero (top): band label + Δ number. Top-aligned so the
                      // label sits at the top of the zone (below the tick-mark
                      // + locality overlays); the leftover slot space reads as
                      // the spacer above the footer.
                      Expanded(
                        flex: 2,
                        child: ShrinkToFit(
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 18),
                              Text(
                                label,
                                style: context.text.bandLabel(fgColor),
                              ),
                            
                              Text(
                                _formatDelta(delta),
                                style:
                                    context.text.deltaNumberColored(fgColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Footer (bottom): stage name on its own line, then the
                      // three-speed row on a separate line beneath it. Bottom-
                      // aligned so it pins to the bottom of the zone.
                      Expanded(
                        flex: 1,
                        child: ShrinkToFit(
                          alignment: Alignment.bottomCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(name, style: context.text.deltaStageName),
                              const SizedBox(height: 12),
                              _SpeedIconRow(
                                target: target,
                                avgReal: avgReal,
                                now: speed,
                                overSpeed: overSpeed,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Locality header pinned to the top-left, just below the
                // tick-mark gauge row. Icon lights up only with a real fix.
                Positioned(
                  top: 20,
                  left: 14,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: locMaxWidth),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 13,
                          color: hasFix
                              ? colors.primary
                              : colors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            locality,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.topBarText().copyWith(
                                  color: colors.textSecondary,
                                ),
                          ),
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
            );
          },
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

/// The three live speeds under the stage name, laid out as an instrument
/// cluster: one cell per speed, each with an icon, a big tabular value, and a
/// tiny stencil caption so the readout is unambiguous at a glance.
/// - 🚩 flag → ȚINTĂ (planned target average)
/// - ⟂ timeline → REALĂ (actual average so far)
/// - ⊙ gps_fixed → ACUM (instantaneous speed)
///
/// All three are speeds, so the `km/h` unit is shown once at the end. Sits in
/// the footer `ShrinkToFit` (its own scaling region), beneath the stage name.
class _SpeedIconRow extends StatelessWidget {
  const _SpeedIconRow({
    required this.target,
    required this.avgReal,
    required this.now,
    required this.overSpeed,
  });

  final double target;
  final double? avgReal;
  final double now;

  /// When true (stage running + over the max limit), the ACUM cell lights up
  /// red — an intuitive in-row cue that mirrors the OverSpeedAlert banner.
  final bool overSpeed;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final colors = context.colors;
    final valueStyle = t.deltaNumber.copyWith(
      fontSize: 34,
      color: colors.textSecondary,
      height: 1.05,
    );
    final captionStyle = t.badge.copyWith(
      color: colors.textMuted,
      fontSize: 10,
      letterSpacing: 1.4,
    );
    final iconColor = colors.textSecondary;
    const iconSize = 26.0;
    // Local copy so the null check promotes (fields aren't auto-promoted).
    final avg = avgReal;
    final divider = Container(
      width: 1,
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: colors.dividerStrong,
    );
    // NaN/-1 speed (GPS unavailable) renders as an em dash, matching the
    // avg-real "no data" convention.
    final nowStr = now.isNaN || now < 0 ? '—' : now.toStringAsFixed(0);
    // The instant speed is the only one that can exceed the limit, so only the
    // ACUM cell lights up red when over-speed.
    final nowAccent = overSpeed ? colors.danger : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _SpeedCell(
          icon: Icons.flag_outlined,
          value: fmtSpeed(target),
          caption: 'ȚINTĂ',
          valueStyle: valueStyle,
          captionStyle: captionStyle,
          iconColor: iconColor,
          iconSize: iconSize,
        ),
        divider,
        _SpeedCell(
          icon: Icons.timeline,
          value: avg == null ? '—' : fmtSpeed(avg),
          caption: 'REALĂ',
          valueStyle: valueStyle,
          captionStyle: captionStyle,
          iconColor: iconColor,
          iconSize: iconSize,
        ),
        divider,
        _SpeedCell(
          icon: Icons.gps_fixed,
          value: nowStr,
          caption: 'ACUM',
          valueStyle: nowAccent != null
              ? valueStyle.copyWith(color: nowAccent)
              : valueStyle,
          captionStyle: captionStyle,
          iconColor: nowAccent ?? iconColor,
          iconSize: iconSize,
        ),
        const SizedBox(width: 12),
        Text(
          'km/h',
          style: t.deltaSubtitle.copyWith(
            fontSize: 18,
            color: colors.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// One speed cell of the [_SpeedIconRow]: icon, big tabular value, tiny stencil
/// caption — stacked vertically so each speed reads as a labeled gauge.
class _SpeedCell extends StatelessWidget {
  const _SpeedCell({
    required this.icon,
    required this.value,
    required this.caption,
    required this.valueStyle,
    required this.captionStyle,
    required this.iconColor,
    required this.iconSize,
  });

  final IconData icon;
  final String value;
  final String caption;
  final TextStyle valueStyle;
  final TextStyle captionStyle;
  final Color iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: iconSize, color: iconColor),
        const SizedBox(height: 3),
        Text(value, style: valueStyle),
        const SizedBox(height: 2),
        Text(caption, style: captionStyle),
      ],
    );
  }
}