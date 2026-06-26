import 'package:flutter/material.dart';

/// A compact [IconButton] with zero padding and a small square touch target,
/// shrinking further in [compact] mode (narrow bars). The shared shape behind
/// the cockpit header nav buttons and the stage-config gear — previously each
/// re-rolled the same `constraints` + `padding` + `size` ternary.
class CompactIconButton extends StatelessWidget {
  const CompactIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.compact,
    required this.onPressed,
    this.expandedIconSize = 20,
    this.expandedTouchSize = 32,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final bool compact;
  final VoidCallback? onPressed;
  final double expandedIconSize;
  final double expandedTouchSize;

  @override
  Widget build(BuildContext context) {
    final touch = compact ? 30.0 : expandedTouchSize;
    // `constraints` alone is only a floor — the Material 3 default
    // `MaterialTapTargetSize.padded` still inflates the button to 48×48,
    // defeating compact mode (and eating the cockpit's short landscape zone).
    // Pin the exact tap size via the style + shrinkWrap so the button really
    // is `touch`×`touch`.
    return IconButton(
      icon: Icon(icon, color: color, size: compact ? 18 : expandedIconSize),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        minimumSize: Size(touch, touch),
        maximumSize: Size(touch, touch),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
    );
  }
}