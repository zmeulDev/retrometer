import 'package:flutter/material.dart';

import '../theme/retrometer_theme.dart';

/// The shared scaffold for a modal bottom-sheet editor: padded for the
/// keyboard inset, scrollable, with a stretch column titled [title] and an
/// optional trailing "Salvează" button. Used by the competition editor, the
/// stage editor and the cockpit stage-config sheet — previously each re-rolled
/// the same `Padding` + `SingleChildScrollView` + `Column` + `FilledButton`
/// boilerplate.
class EditorSheetScaffold extends StatelessWidget {
  const EditorSheetScaffold({
    super.key,
    required this.title,
    required this.children,
    this.onSave,
    this.saveLabel = 'Salvează',
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onSave;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: RetrometerTextStyles.sheetTitle),
            const SizedBox(height: 16),
            ...children,
            if (onSave != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onSave,
                child: Text(saveLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A bold section title inside a sheet/screen — the `Text(sectionLabel)` +
/// `SizedBox(8)` pair repeated across the editors, and the guide's
/// `_SectionTitle`. Pass [style] to use a different title style (e.g. the
/// guide's larger `guideSection`).
class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.text, {
    super.key,
    this.style,
    this.bottomPadding = 8,
  });

  final String text;
  final TextStyle? style;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Text(text, style: style ?? RetrometerTextStyles.sectionLabel),
    );
  }
}