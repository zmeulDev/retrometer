import 'package:flutter/material.dart';

/// Shared `AlertDialog` shell for the app's dialog sites.
///
/// Wraps Material's [AlertDialog] with the app's common dialog chrome: a
/// [Text] title, a content widget, and a caller-supplied list of action
/// buttons. Callers own their buttons (including button type and colors), so
/// per-call differences in confirm/cancel styling stay at the call site.
/// The optional [icon] is exposed for disclosure-style dialogs that show a
/// leading icon.
///
/// This widget only renders the dialog body. How it is surfaced (via
/// [showDialog] or pushed as a [DialogRoute] onto a specific navigator) is
/// the caller's responsibility — see `confirmDialog` in `info_widgets.dart`
/// and the auto-start prompt in `cockpit/auto_start_prompt_listener.dart`.
class RetrometerAlertDialog extends StatelessWidget {
  const RetrometerAlertDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.icon,
  });

  /// Dialog title text.
  final String title;

  /// Dialog body.
  final Widget content;

  /// Action buttons (typically cancel + confirm).
  final List<Widget> actions;

  /// Optional leading icon (shown above the title).
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: icon,
      title: Text(title),
      content: content,
      actions: actions,
    );
  }
}