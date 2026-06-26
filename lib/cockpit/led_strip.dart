import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../competition_providers.dart';
import '../models.dart';
import '../state_providers.dart';
import '../theme/retrometer_theme.dart';

/// A fixed-height restomod status strip: flat LED dots + stencil labels for
/// GPS · STAGE · OVER-SPD · AUTO-START, lit from live cockpit state. Placed
/// above the three cockpit zones in [CockpitView]; its fixed height keeps the
/// `Expanded` zones below it flexing correctly (no landscape overflow).
class LedStrip extends ConsumerWidget {
  const LedStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      stageControllerProvider.select((s) => s.telemetry.status),
    );
    final overSpeed = ref.watch(isOverSpeedProvider);
    final autoStatus = ref.watch(autoStartMonitorProvider);

    final stageLit = status != StageStatus.idle;
    final overLit = overSpeed;
    // Auto-start LED lights when a stage is armed and waiting for its trigger
    // (pending prompt or a scheduled stage due soon).
    final autoLit = autoStatus.pendingPrompt != null ||
        (autoStatus.nextDueName != null && autoStatus.nextDueName!.isNotEmpty);

    return SizedBox(
      height: 22,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: Row(
          children: [
            _GpsLed(),
            const SizedBox(width: 12),
            _Led(
              label: 'STAGE',
              on: stageLit,
              onColor: context.colors.running,
            ),
            const SizedBox(width: 12),
            _Led(
              label: 'OVER-SPD',
              on: overLit,
              onColor: context.colors.danger,
            ),
            const Spacer(),
            _Led(
              label: 'AUTO-START',
              on: autoLit,
              onColor: context.colors.warn,
            ),
          ],
        ),
      ),
    );
  }
}

/// GPS status LED: green (fix), amber (searching), red (unavailable). Watches
/// [gpsFixStatusProvider], which keeps the low-accuracy position stream alive
/// while the cockpit is mounted — independent of whether a stage is running.
class _GpsLed extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fix = ref.watch(gpsFixStatusProvider);
    final colors = context.colors;
    final Color dotColor;
    switch (fix) {
      case GpsFixStatus.fixed:
        dotColor = colors.running;
      case GpsFixStatus.searching:
        dotColor = colors.warn;
      case GpsFixStatus.unavailable:
        dotColor = colors.danger;
    }
    return _Led(
      label: 'GPS',
      // Always "lit" (colored) — the color carries the state, not on/off.
      on: true,
      onColor: dotColor,
    );
  }
}

/// A single LED: a flat dot + stencil label, dim when off and tinted when on.
class _Led extends StatelessWidget {
  const _Led({required this.label, required this.on, required this.onColor});

  final String label;
  final bool on;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dotColor = on ? onColor : colors.dividerStrong;
    final ink = on ? colors.textPrimary : colors.textFaint;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            border: Border.all(color: dotColor, width: 1),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          // The strip is a fixed 22 px decorative status bar; the four stencil
          // labels would otherwise grow with the device text scale and overflow
          // horizontally (e.g. 1.5×–2× accessibility). Pin them to 1.0 so the
          // strip never overflows — the cockpit's primary readouts (Δ, speeds,
          // distance) still scale via ShrinkToFit.
          textScaler: TextScaler.linear(1.0),
          style: TextStyle(
            fontFamily: 'SairaStencil',
            fontSize: 9,
            letterSpacing: 0.6,
            color: ink,
          ),
        ),
      ],
    );
  }
}