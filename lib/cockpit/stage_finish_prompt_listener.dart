import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigator_key.dart';
import '../state_providers.dart';
import '../theme/retrometer_theme.dart';
import '../widgets/retrometer_alert_dialog.dart';

/// Surfaces the stage-finish prompt as a confirmation dialog, replacing the
/// old silent auto-stop.
///
/// Renders nothing (`SizedBox.shrink`); hosted at the app root (via
/// `MaterialApp.builder`, alongside [AutoStartPromptListener]) so the prompt
/// fires from any pushed route, not just the cockpit. Because the widget lives
/// *outside* the navigator subtree (a sibling in the builder's `Stack`), it
/// can't use `showDialog(context: ...)` — its [BuildContext] has no `Navigator`
/// ancestor — so it pushes the [DialogRoute] directly onto [rootNavigatorKey]'s
/// state. Listens to [stageFinishProvider]'s pending reason via
/// [ref.listenManual] in [initState] — the callback fires only on change, so
/// this widget never rebuilds. A `_dialogShown` guard prevents a second dialog
/// while one is on screen. **Da** stops the stage; **Nu** dismisses (the
/// notifier's once-per-stage guard keeps it from reappearing at every fix).
class StageFinishPromptListener extends ConsumerStatefulWidget {
  const StageFinishPromptListener({super.key});

  @override
  ConsumerState<StageFinishPromptListener> createState() =>
      _StageFinishPromptListenerState();
}

class _StageFinishPromptListenerState
    extends ConsumerState<StageFinishPromptListener> {
  bool _dialogShown = false;
  // The manual subscription owns its lifecycle; cancelled in [dispose].
  ProviderSubscription<StageFinishReason?>? _subscription;

  @override
  void initState() {
    super.initState();
    // listenManual (not ref.listen) because this runs in initState, outside
    // build(). A narrow `.select` (just the pending reason) keeps unrelated
    // stage changes from waking the callback.
    _subscription = ref.listenManual<StageFinishReason?>(
      stageFinishProvider,
      (prev, next) => _onPromptChanged(next),
    );
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  void _onPromptChanged(StageFinishReason? next) {
    if (next == null) {
      // Prompt cleared (confirmed/dismissed, or a rebuild).
      _dialogShown = false;
      return;
    }
    if (_dialogShown) return;
    if (!mounted) return;
    _dialogShown = true;
    final nav = rootNavigatorKey.currentState;
    if (nav == null) {
      _dialogShown = false;
      return;
    }
    nav.push<bool>(
      DialogRoute<bool>(
        context: nav.context,
        barrierDismissible: false,
        builder: (dialogContext) => RetrometerAlertDialog(
          title: 'Final de stagiu',
          content: Text(_message(next)),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: dialogContext.colors.textSecondary,
              ),
              onPressed: () {
                ref.read(stageFinishProvider.notifier).dismiss();
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Nu'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: dialogContext.colors.danger,
              ),
              onPressed: () async {
                await ref.read(stageFinishProvider.notifier).confirm();
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Da, oprește'),
            ),
          ],
        ),
      ),
    ).then((_) {
      if (mounted) _dialogShown = false;
    });
  }

  String _message(StageFinishReason reason) {
    switch (reason) {
      case StageFinishReason.location:
        return 'Ați ajuns la finalul stagiului (locație). Opreți?';
      case StageFinishReason.time:
        return 'Ați ajuns la finalul stagiului (timp alocat). Opreți?';
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}