import 'package:flutter/material.dart';

import '../theme/retrometer_theme.dart';

/// A rounded, bordered, tappable card — the standard surface tile used across
/// the app (competition tiles, stage tiles).
///
/// Builds a `Material` with a `RoundedRectangleBorder` shape (carrying both the
/// corner radius and the border) and an `InkWell` clipped to the same radius for
/// the ripple. Centralizing this avoids the `Material` assertion that forbids
/// passing both `shape` and `borderRadius` at once.
class TappableCard extends StatelessWidget {
  const TappableCard({
    super.key,
    required this.onTap,
    required this.child,
    this.color,
    this.radius = 14,
    this.border,
  });

  final VoidCallback onTap;
  final Widget child;
  final Color? color;
  final double radius;
  final BorderSide? border;

  @override
  Widget build(BuildContext context) {
    final side = border ?? const BorderSide(color: RetrometerColors.divider);
    return Material(
      color: color ?? RetrometerColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: side,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: child,
      ),
    );
  }
}