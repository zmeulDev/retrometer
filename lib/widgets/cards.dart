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
    this.onTap,
    required this.child,
    this.color,
    this.radius = RetrometerRadii.card,
    this.border,
  });

  /// Tap handler. `null` makes the card read-only (no ripple, no cursor).
  final VoidCallback? onTap;
  final Widget child;
  final Color? color;
  final double radius;
  final BorderSide? border;

  @override
  Widget build(BuildContext context) {
    final side = border ?? BorderSide(color: context.colors.divider);
    return Material(
      color: color ?? context.colors.surface,
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

/// A read-only rounded, bordered surface — the non-tappable counterpart of
/// [TappableCard]. Same `Material` + `RoundedRectangleBorder` chrome, no
/// ripple. Optional [alignment]/[padding] match `Container(decoration +
/// alignment + padding)` semantics so it drops in where a plain decorated
/// box was used for layout (cockpit zones, over-speed alert).
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.color,
    this.radius = RetrometerRadii.card,
    this.border,
    this.alignment,
    this.padding,
  });

  final Widget child;
  final Color? color;
  final double radius;
  final BorderSide? border;
  final AlignmentGeometry? alignment;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final side = border ?? BorderSide(color: context.colors.divider);
    Widget content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    if (alignment != null) {
      content = Align(alignment: alignment!, child: content);
    }
    return Material(
      color: color ?? context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: side,
      ),
      child: content,
    );
  }
}