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
    return IconButton(
      icon: Icon(icon, color: color, size: compact ? 18 : expandedIconSize),
      tooltip: tooltip,
      constraints: BoxConstraints(minHeight: touch, minWidth: touch),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
    );
  }
}