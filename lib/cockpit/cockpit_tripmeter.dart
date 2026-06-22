import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state_providers.dart';
import '../theme/retrometer_theme.dart';
import '../widgets/cards.dart';
import '../widgets/shrink_to_fit.dart';

/// Bottom cockpit zone (40%): the trip-meter distance readout flanked by the
/// two blind-touch ±10 m / ±100 m (long-press) adjust zones.
class TripmeterBar extends ConsumerWidget {
  const TripmeterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(stageControllerProvider.notifier);
    return ColoredBox(
      color: context.colors.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Row(
          children: [
            Expanded(
              flex: 30,
              child: AdjustZone(
                sign: '−',
                onTap: () => controller.adjustDistance(-0.01),
                onLongPress: () => controller.adjustDistance(-0.1),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              flex: 40,
              child: RepaintBoundary(child: DistanceReadout()),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 30,
              child: AdjustZone(
                sign: '+',
                onTap: () => controller.adjustDistance(0.01),
                onLongPress: () => controller.adjustDistance(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A blind-touch adjust zone: tap = ±10 m, long-press = ±100 m. The [sign]
/// is shown large inside a knurled restomod knob so it's identifiable without
/// looking at the screen.
class AdjustZone extends StatelessWidget {
  const AdjustZone({
    super.key,
    required this.sign,
    required this.onTap,
    required this.onLongPress,
  });

  final String sign;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: SurfaceCard(
        radius: RetrometerRadii.tile,
        alignment: Alignment.center,
        child: ShrinkToFit(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _KnurlRing(sign: sign),
              const SizedBox(height: 2),
              Text(
                '10 m',
                style: context.text.adjustAmount,
              ),
              Text(
                'lung: 100 m',
                style: context.text.adjustLong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A flat restomod knob: concentric rings + a radial knurl (drawn via
/// `CustomPaint`) with the +/- [sign] centered on top. Purely decorative
/// chrome around the existing sign text (which stays `find.text`-able).
class _KnurlRing extends StatelessWidget {
  const _KnurlRing({required this.sign});

  final String sign;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring.
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.dividerStrong, width: 1),
              color: colors.surfaceElevated,
            ),
          ),
          // Radial knurl between the two rings.
          Padding(
            padding: const EdgeInsets.all(5),
            child: CustomPaint(
              size: const Size(86, 86),
              painter: _KnurlPainter(color: colors.divider),
            ),
          ),
          // Inner ring.
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.dividerStrong, width: 1),
            ),
          ),
          // The sign, on top.
          Text(
            sign,
            style: context.text.adjustSign,
          ),
        ],
      ),
    );
  }
}

/// Draws the radial knurl ticks around a circle (the flat analog of a
/// repeating conic gradient).
class _KnurlPainter extends CustomPainter {
  const _KnurlPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const ticks = 30;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final center = Offset(size.width / 2, size.height / 2);
    final outer = size.width / 2;
    final inner = outer - 6;
    for (var i = 0; i < ticks; i++) {
      final angle = (i / ticks) * 2 * math.pi;
      final dx = math.cos(angle);
      final dy = math.sin(angle);
      canvas.drawLine(
        Offset(center.dx + dx * inner, center.dy + dy * inner),
        Offset(center.dx + dx * outer, center.dy + dy * outer),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_KnurlPainter oldDelegate) => oldDelegate.color != color;
}

/// An etched label plate: a small recessed plate (labelPlate fill) with wide-
/// tracked label-ink text — the engraved-nameplate flavor for tiny unit labels
/// like "km". Purely additive chrome around the existing [text].
class _LabelPlate extends StatelessWidget {
  const _LabelPlate({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.labelPlate,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.dividerStrong, width: 1),
      ),
      child: Text(
        text,
        style: style.copyWith(
          color: colors.labelInk,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

/// The accumulated-trip-distance readout (km), repaint-isolated from the
/// adjust zones so taps don't repaint the number.
class DistanceReadout extends ConsumerWidget {
  const DistanceReadout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distance = ref.watch(
      stageControllerProvider.select((s) => s.telemetry.currentDistance),
    );
    return SurfaceCard(
      color: context.colors.surfaceElevated,
      radius: RetrometerRadii.tile,
      border: BorderSide(
        color: context.colors.primary.withValues(alpha: 0.3),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The number gets its own FittedBox (inside a loose Flexible so it
          // can also shrink to fit the slot's height) — it scales down for
          // large values (100.00, 999.99) without also shrinking the "km" unit
          // below, which stays a legible fixed size.
          Flexible(
            fit: FlexFit.loose,
            child: ShrinkToFit(
              child: Text(
                distance.toStringAsFixed(2),
                style: context.text.distanceNumber,
              ),
            ),
          ),
          _LabelPlate(
            text: 'km',
            style: context.text.distanceUnit,
          ),
        ],
      ),
    );
  }
}