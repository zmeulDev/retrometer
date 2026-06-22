import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../competition_providers.dart';
import '../location_disclosure.dart';
import '../navigator_key.dart';
import '../theme/retrometer_theme.dart';
import '../widgets/retrometer_alert_dialog.dart';

/// Surfaces the auto-start monitor's pending prompt as a confirmation dialog.
///
/// Renders nothing (`SizedBox.shrink`); hosted at the app root (via
/// `MaterialApp.builder`) so the prompt fires from any pushed route
/// (Competitions/About/Guide), not just the cockpit. Because the widget lives
/// *outside* the navigator subtree (a sibling in the builder's `Stack`), it
/// can't use `showDialog(context: ...)` — its [BuildContext] has no `Navigator`
/// ancestor — so it pushes the [DialogRoute] directly onto
/// [rootNavigatorKey]'s state instead. Listens to
/// `autoStartMonitorProvider`'s `pendingPrompt` slice via
/// [ref.listenManual] in [initState] — the callback fires only on change, so
/// this widget never rebuilds. A `_dialogShown` guard prevents a second dialog
/// from opening while one is already on screen (the monitor suppresses
/// re-prompts too, but this is belt-and-braces against rebuilds). Confirming
/// pops back to the cockpit (`popUntil(isFirst)`), so the crew lands on the
/// running stage regardless of which screen they were on.
class AutoStartPromptListener extends ConsumerStatefulWidget {
  const AutoStartPromptListener({super.key});

  @override
  ConsumerState<AutoStartPromptListener> createState() =>
      _AutoStartPromptListenerState();
}

class _AutoStartPromptListenerState
    extends ConsumerState<AutoStartPromptListener> {
  bool _dialogShown = false;
  // The manual subscription owns its lifecycle; cancelled in [dispose].
  ProviderSubscription<ScheduledStage?>? _subscription;

  @override
  void initState() {
    super.initState();
    // listenManual (not ref.listen) because this runs in initState, outside
    // build(). Listening to a narrow `.select` slice (just pendingPrompt)
    // means unrelated diagnostics updates (message, lastFixAccuracyM, ...)
    // don't wake the callback.
    _subscription = ref.listenManual<ScheduledStage?>(
      autoStartMonitorProvider.select((s) => s.pendingPrompt),
      (prev, next) => _onPromptChanged(next),
    );
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  void _onPromptChanged(ScheduledStage? next) {
    if (next == null) {
      // Prompt cleared externally (monitor confirmed/dismissed, or a rebuild).
      _dialogShown = false;
      return;
    }
    if (_dialogShown) return;
    if (!mounted) return;
    _dialogShown = true;
    // The listener is hosted in `MaterialApp.builder` as a sibling of the
    // navigator, so its own `context` has no Navigator ancestor — `showDialog`
    // would throw. Push directly onto the root navigator via its key instead.
    final nav = rootNavigatorKey.currentState;
    if (nav == null) {
      // Navigator not mounted yet; drop the prompt and re-arm so the next tick
      // (with the navigator up) can re-surface it.
      _dialogShown = false;
      return;
    }
    nav.push<bool>(
      DialogRoute<bool>(
        context: nav.context,
        barrierDismissible: false,
        builder: (dialogContext) => RetrometerAlertDialog(
        title: 'Pornire stage',
        content: Text('Doriți să porniți "${next.stage.name}"?'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: RetrometerColors.danger),
            onPressed: () {
              ref.read(autoStartMonitorProvider.notifier).dismissPending();
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('Nu'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: RetrometerColors.primary),
            onPressed: () async {
              // Prominent location disclosure must precede the permission
              // request; if the crew declines, treat the prompt as declined.
              if (!dialogContext.mounted) return;
              final ok = await maybeShowLocationDisclosure(dialogContext);
              if (!ok) {
                ref.read(autoStartMonitorProvider.notifier).dismissPending();
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(false);
                return;
              }
              await ref.read(autoStartMonitorProvider.notifier).confirmPending();
              if (!dialogContext.mounted) return;
              // Close the dialog AND pop any pushed routes (Competitions/About/
              // Guide) back to `home` (cockpit), so the user lands in the
              // cockpit with the stage running. If already on the cockpit,
              // popUntil(isFirst) just closes the dialog route.
              Navigator.of(dialogContext).popUntil((r) => r.isFirst);
            },
            child: const Text('Da'),
          ),
        ],
        ),
      ),
    ).then((_) {
      // Dialog closed (either button, or a route pop). Re-arm so a future
      // prompt can show again.
      if (mounted) _dialogShown = false;
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}