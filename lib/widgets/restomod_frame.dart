import 'package:flutter/material.dart';

import '../theme/retrometer_theme.dart';

/// A flat restomod "gauge bezel": a double hairline rule (outer + inner) drawn
/// with color only — zero shadows/glow. Wraps the cockpit so the whole dash
/// reads as a single instrument panel.
///
/// Purely additive chrome: the [child] is laid out at the same size as without
/// the frame (the rules are drawn within the frame's own padding), so wrapping
/// `CockpitView` in this does not change its type or layout.
class RestomodFrame extends StatelessWidget {
  const RestomodFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(4),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: DecoratedBox(
        // Outer rule.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.divider, width: 1),
        ),
        child: Padding(
          padding: padding,
          child: DecoratedBox(
            // Inner rule.
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.dividerStrong, width: 1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}