import 'package:flutter/material.dart';

import '../theme/retrometer_theme.dart';

/// An inline icon + text chip used in tile metadata rows (location, date,
/// category, …). Renders as a minimal `Row` (no background).
class MetaChip extends StatelessWidget {
  const MetaChip({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: RetrometerColors.textTertiary, size: 15),
        const SizedBox(width: 4),
        Text(text, style: RetrometerTextStyles.metaStrong),
      ],
    );
  }
}

/// An icon + text line used in stage tiles (schedule, location, finish). The
/// text is `Expanded` and ellipsises so long coordinates don't overflow.
class InfoLine extends StatelessWidget {
  const InfoLine({
    super.key,
    required this.icon,
    required this.text,
    this.textStyle,
    this.iconColor,
    this.iconSize = 16,
  });

  final IconData icon;
  final String text;
  final TextStyle? textStyle;
  final Color? iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor ?? RetrometerColors.textTertiary, size: iconSize),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle ?? RetrometerTextStyles.meta,
          ),
        ),
      ],
    );
  }
}

/// A label/value row for the competition header: `icon  label: value`. When
/// [highlight] is true the row renders in the brand accent (used for standings).
class HeaderRow extends StatelessWidget {
  const HeaderRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color =
        highlight ? RetrometerColors.primary : RetrometerColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text('$label: ', style: RetrometerTextStyles.meta),
        Text(value,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// A small coloured pill with a text label (status badges, standings). Uses
/// [RetrometerColors.pillDecoration] so the background/border match the text
/// color.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: RetrometerColors.pillDecoration(color),
      child: Text(
        text,
        style: RetrometerTextStyles.badge.copyWith(color: color),
      ),
    );
  }
}

/// A centred empty-state placeholder: a faint icon above a short message.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.iconSize = 56,
    this.titleStyle,
  });

  final IconData icon;
  final String message;
  final double iconSize;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: RetrometerColors.textFaint, size: iconSize),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: titleStyle ?? RetrometerTextStyles.emptyTitleSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// A confirm dialog with Anulează / [confirmLabel] actions. The confirm button
/// renders in the danger colour by default (delete confirmations). Returns
/// `true` only if the crew taps the confirm action.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Șterge',
  String cancelLabel = 'Anulează',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel,
              style: const TextStyle(color: RetrometerColors.danger)),
        ),
      ],
    ),
  );
  return result ?? false;
}