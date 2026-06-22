import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/retrometer_theme.dart';
import '../utils/formatting.dart';

/// Dark picker theme (date/time pickers) tinted with the brand accent. The
/// pickers don't inherit the app theme, so we wrap them explicitly. Reused by
/// [DateTimeField] and [DateRangeField].
Widget pickerTheme(BuildContext context, Widget? child) => Theme(
      data: ThemeData.dark().copyWith(
        colorScheme:
            ColorScheme.dark(primary: context.colors.primary),
      ),
      child: child!,
    );

// ---------------------------------------------------------------------------
// Date formatting helpers.
// ---------------------------------------------------------------------------

String _formatDate(DateTime dt) {
  return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
}

/// `yyyy-MM-dd HH:mm`, or `—` when [dt] is null.
String formatDateTime(DateTime? dt) {
  if (dt == null) return '—';
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
      '${two(dt.hour)}:${two(dt.minute)}';
}

/// Display a date range. Single date when [end] is null or on the same calendar
/// day as [start]; otherwise `start → end`.
String formatDateRange(DateTime? start, DateTime? end) {
  if (start == null) return '—';
  final sameDay = end != null &&
      end.year == start.year &&
      end.month == start.month &&
      end.day == start.day;
  if (end == null || sameDay) return _formatDate(start);
  return '${_formatDate(start)} → ${_formatDate(end)}';
}

// ---------------------------------------------------------------------------
// Form fields.
// ---------------------------------------------------------------------------

/// A label + numeric text field row. Whole-number fields accept digits only;
/// decimal fields accept one decimal point. Reports parsed values via
/// [onChanged] (ignored while the input doesn't parse).
///
/// When [controller] is supplied it's used as-is (and not disposed here); when
/// omitted the field creates one from [value]. Shared between the stage config
/// sheet and the competition/stage editors.
class NumberField extends StatefulWidget {
  const NumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.controller,
    this.decimals = 0,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final TextEditingController? controller;
  final int decimals;

  @override
  State<NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<NumberField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        TextEditingController(
            text: widget.value.toStringAsFixed(widget.decimals));
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatter = widget.decimals > 0
        ? FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))
        : FilteringTextInputFormatter.digitsOnly;
    return Row(
      children: [
        Expanded(
          child: Text(widget.label, style: context.text.fieldLabel),
        ),
        SizedBox(
          width: 100,
          child: TextField(
            controller: _controller,
            keyboardType: widget.decimals > 0
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.number,
            textAlign: TextAlign.center,
            style: context.text.fieldInput,
            inputFormatters: [formatter],
            onChanged: (s) {
              final v = double.tryParse(s);
              if (v != null) widget.onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}

/// Compact integer field (digits only, small styles). Reports parsed values via
/// [onChanged]. The caller owns [controller].
class IntField extends StatefulWidget {
  const IntField({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<int> onChanged;

  @override
  State<IntField> createState() => _IntFieldState();
}

class _IntFieldState extends State<IntField> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(widget.label, style: context.text.fieldLabelSmall),
        ),
        SizedBox(
          width: 90,
          child: TextField(
            controller: widget.controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: context.text.fieldInputSmall,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (s) {
              final v = int.tryParse(s);
              if (v != null) widget.onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}

/// Compact decimal field (one decimal point, small styles). Reports parsed
/// values via [onChanged]. The caller owns [controller].
class DecimalField extends StatefulWidget {
  const DecimalField({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  State<DecimalField> createState() => _DecimalFieldState();
}

class _DecimalFieldState extends State<DecimalField> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(widget.label, style: context.text.fieldLabelSmall),
        ),
        SizedBox(
          width: 110,
          child: TextField(
            controller: widget.controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: context.text.fieldInputSmall,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
            ],
            onChanged: (s) {
              final v = double.tryParse(s);
              if (v != null) widget.onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}

/// A plain labeled text field. The caller owns [controller].
class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: context.colors.textPrimary),
      decoration: InputDecoration(labelText: label),
    );
  }
}

/// A signed-decimal coordinate field (latitude/longitude). The caller owns
/// [controller]; parsed values are reported via [onChanged].
class CoordField extends StatefulWidget {
  const CoordField({
    super.key,
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<double> onChanged;

  @override
  State<CoordField> createState() => _CoordFieldState();
}

class _CoordFieldState extends State<CoordField> {
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: true),
      style: TextStyle(color: context.colors.textPrimary),
      decoration: InputDecoration(
        labelText: widget.label,
        isDense: true,
      ),
      onChanged: (s) {
        final v = double.tryParse(s);
        if (v != null) widget.onChanged(v);
      },
    );
  }
}

/// A date + time picker row showing the current [value] and a button that opens
/// a date picker then a time picker. Reports the combined [DateTime] via
/// [onChanged]. A clear button lets the crew unset the start (for a
/// location-only stage). [value]/[onChanged] are nullable.
class DateTimeField extends StatelessWidget {
  const DateTimeField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return Row(
      children: [
        Expanded(
          child: Text('Start: ${formatDateTime(value)}',
              style: context.text.fieldLabel),
        ),
        TextButton(
          onPressed: () async {
            final now = DateTime.now();
            final d = await showDatePicker(
              context: context,
              initialDate: value ?? now,
              firstDate: now.subtract(const Duration(days: 1)),
              lastDate: now.add(const Duration(days: 365)),
              builder: pickerTheme,
            );
            if (d == null) return;
            if (!context.mounted) return;
            final t = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(value ?? now),
              builder: pickerTheme,
            );
            if (t == null) return;
            onChanged(DateTime(d.year, d.month, d.day, t.hour, t.minute));
          },
          child: Text(
            hasValue ? 'Schimbă' : 'Alege data/ora',
            style: TextStyle(color: context.colors.primary),
          ),
        ),
        if (hasValue)
          IconButton(
            icon: Icon(Icons.clear,
                color: context.colors.textTertiary, size: 18),
            tooltip: 'Șterge ora de start',
            onPressed: () => onChanged(null),
          ),
      ],
    );
  }
}

/// A date-range picker (event start + optional end). [endDate] null or on the
/// same day as [startDate] means a single-day event. The end picker is disabled
/// until a start is set and never accepts a date before the start; editing the
/// start to fall after the existing end drops the end so the range stays valid.
class DateRangeField extends StatelessWidget {
  const DateRangeField({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onChanged,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final void Function(DateTime? start, DateTime? end) onChanged;

  Future<DateTime?> _pick(
    BuildContext context, {
    required DateTime? current,
    required DateTime? lowerBound,
  }) async {
    final d = await showDatePicker(
      context: context,
      initialDate: current ?? lowerBound ?? DateTime.now(),
      firstDate: lowerBound ??
          DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: pickerTheme,
    );
    return d;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Start date.
        Row(
          children: [
            Expanded(
              child: Text(
                startDate == null
                    ? 'Data start: —'
                    : 'Data start: ${_formatDate(startDate!)}',
                style: context.text.fieldLabel,
              ),
            ),
            TextButton(
              onPressed: () async {
                final d = await _pick(context, current: startDate, lowerBound: null);
                if (d == null) return;
                // If the new start is after the existing end, drop the end so
                // the range stays valid (single-day until the crew sets a new end).
                final end = (endDate != null && endDate!.isBefore(d)) ? null : endDate;
                onChanged(d, end);
              },
              child: Text(
                startDate == null ? 'Alege data' : 'Schimbă',
                style: TextStyle(color: context.colors.primary),
              ),
            ),
            if (startDate != null)
              IconButton(
                icon: Icon(Icons.clear,
                    color: context.colors.textTertiary, size: 18),
                tooltip: 'Șterge data start',
                onPressed: () => onChanged(null, endDate),
              ),
          ],
        ),
        const SizedBox(height: 4),
        // End date (optional; single-day when null or equal to start).
        Row(
          children: [
            Expanded(
              child: Text(
                endDate == null
                    ? 'Data sfârșit: — (o singură zi)'
                    : 'Data sfârșit: ${_formatDate(endDate!)}',
                style: context.text.fieldLabel,
              ),
            ),
            TextButton(
              onPressed: startDate == null
                  ? null
                  : () async {
                      final d = await _pick(
                        context,
                        current: endDate,
                        lowerBound: startDate,
                      );
                      if (d == null) return;
                      onChanged(startDate, d);
                    },
              child: Text(
                endDate == null ? 'Alege data' : 'Schimbă',
                style: TextStyle(color: context.colors.primary),
              ),
            ),
            if (endDate != null)
              IconButton(
                icon: Icon(Icons.clear,
                    color: context.colors.textTertiary, size: 18),
                tooltip: 'Șterge data sfârșit',
                onPressed: () => onChanged(startDate, null),
              ),
          ],
        ),
      ],
    );
  }
}