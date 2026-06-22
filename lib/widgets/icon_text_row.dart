import 'package:flutter/material.dart';

import '../theme/retrometer_theme.dart';
import 'cards.dart';

/// A row of an icon + gap + (expanded) text, with optional [trailing] widget
/// and optional tap. The shared micro-pattern behind the About nav rows, the
/// guide rows, and the disclosure bullets — so they no longer each re-roll a
/// `Row(Icon, SizedBox, Expanded(Text))`.
///
/// When [onTap] is non-null the row is wrapped in a borderless [TappableCard]
/// (surface fill, radius 10) so the ripple is consistent with the rest of the
/// app; otherwise it's a plain padded row.
class IconTextRow extends StatelessWidget {
  const IconTextRow({
    super.key,
    required this.icon,
    required this.text,
    this.iconColor,
    this.iconSize = 22,
    this.gap = 12,
    this.style,
    this.onTap,
    this.trailing,
    this.verticalPadding = 0,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.maxLines,
    this.overflow,
  });

  final IconData icon;
  final String text;
  final Color? iconColor;
  final double iconSize;
  final double gap;
  final TextStyle? style;
  final VoidCallback? onTap;
  final Widget? trailing;
  final double verticalPadding;
  final CrossAxisAlignment crossAxisAlignment;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Icon(icon, color: iconColor ?? context.colors.textSecondary, size: iconSize),
        SizedBox(width: gap),
        Expanded(
          child: Text(
            text,
            style: style,
            maxLines: maxLines,
            overflow: overflow,
          ),
        ),
        ?trailing,
      ],
    );
    if (onTap == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        child: content,
      );
    }
    return TappableCard(
      color: context.colors.surface,
      radius: RetrometerRadii.chip,
      border: BorderSide.none,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: RetrometerSpacing.s16, vertical: 14),
        child: content,
      ),
    );
  }
}

/// Convenience: an [IconTextRow] that's tappable and ends with a chevron —
/// the standard "go to screen X" row used on the About screen.
class ListActionRow extends StatelessWidget {
  const ListActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconTextRow(
      icon: icon,
      text: label,
      iconColor: context.colors.primary,
      style: context.text.meta,
      onTap: onTap,
      trailing: Icon(Icons.chevron_right,
          color: context.colors.textSecondary, size: 22),
    );
  }
}