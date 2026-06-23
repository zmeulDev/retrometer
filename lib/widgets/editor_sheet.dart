import 'package:flutter/material.dart';

import '../theme/retrometer_theme.dart';
import 'cards.dart';

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
      padding: EdgeInsets.fromLTRB(20, RetrometerSpacing.s8, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: context.text.sheetTitle),
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

/// A full-screen editor page: an app bar with the [title] and a close button,
/// a scrollable body of grouped sections, and a sticky "Salvează" bar pinned
/// above the keyboard. Used by the competition and stage editors — a full
/// screen gives the long forms room to breathe and keeps Save always reachable
/// (unlike the old bottom sheet, where Save scrolled off the bottom).
///
/// The [children] are laid out in a stretched column with `RetrometerSpacing.s16`
/// between them — typically [EditorSectionCard]s. [onSave] is called when the
/// save bar is tapped; the page does not pop itself (the caller's `_save`
/// decides whether to pop, e.g. after passing validation).
class EditorPageScaffold extends StatelessWidget {
  const EditorPageScaffold({
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
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Anulează',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            RetrometerSpacing.s16,
            RetrometerSpacing.s12,
            RetrometerSpacing.s16,
            RetrometerSpacing.s24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  const SizedBox(height: RetrometerSpacing.s16),
              ],
            ],
          ),
        ),
      ),
      // Sticky save bar — the Scaffold raises it above the keyboard
      // (resizeToAvoidBottomInset), so Save stays reachable on long forms.
      bottomNavigationBar: onSave == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  RetrometerSpacing.s16,
                  RetrometerSpacing.s8,
                  RetrometerSpacing.s16,
                  RetrometerSpacing.s8,
                ),
                child: FilledButton(
                  onPressed: onSave,
                  child: Text(saveLabel),
                ),
              ),
            ),
    );
  }
}

/// A grouped section card for an [EditorPageScaffold]: a [SurfaceCard] with a
/// stencil section title and the section's fields stacked inside, separated by
/// [RetrometerSpacing.s12]. Gives the long editors visual structure (identity /
/// crew / contact / standing) instead of a flat underline-only field list.
class EditorSectionCard extends StatelessWidget {
  const EditorSectionCard({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(
        RetrometerSpacing.s16,
        RetrometerSpacing.s12,
        RetrometerSpacing.s16,
        RetrometerSpacing.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(title, bottomPadding: RetrometerSpacing.s4),
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const SizedBox(height: RetrometerSpacing.s12),
          ],
        ],
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
    this.bottomPadding = RetrometerSpacing.s8,
  });

  final String text;
  final TextStyle? style;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Text(text, style: style ?? context.text.sectionLabel),
    );
  }
}