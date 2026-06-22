import 'package:flutter/material.dart';

/// A [FittedBox] hard-wired to [BoxFit.scaleDown] so its child is laid out at
/// natural size and then shrunk uniformly to fit the available space — never
/// enlarged, never overflowing.
///
/// This is the recurring cockpit pattern: a number or label that must stay
/// legible at full size but cannot be allowed to overflow when the slot is
/// short (landscape, large values, etc.). Extracting it keeps the intent
/// readable at the call site and guarantees identical fit/alignment everywhere.
class ShrinkToFit extends StatelessWidget {
  const ShrinkToFit({
    super.key,
    required this.child,
    this.alignment = Alignment.center,
  });

  /// The widget laid out at natural size and then scaled down to fit.
  final Widget child;

  /// How to align the (possibly shrunk) child within the available space.
  /// Defaults to [Alignment.center], matching the original inline [FittedBox]s.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: child,
    );
  }
}