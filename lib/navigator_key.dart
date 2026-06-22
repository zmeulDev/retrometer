import 'package:flutter/material.dart';

/// Global key for the app's root navigator.
///
/// Widgets hosted *outside* the navigator subtree — e.g. `AutoStartPromptListener`
/// mounted in `MaterialApp.builder`'s `Stack` as a sibling of the navigator —
/// have no `Navigator` ancestor in their own [BuildContext], so
/// `Navigator.of(context)` / `showDialog(context: ...)` would throw. They push
/// dialogs directly onto this navigator state instead:
///
/// ```dart
/// final nav = rootNavigatorKey.currentState;
/// nav?.push(DialogRoute(context: nav.context, builder: ...));
/// ```
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();