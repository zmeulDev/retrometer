import 'package:flutter/material.dart';

import 'cockpit/auto_start_prompt_listener.dart';
import 'cockpit/cockpit_delta_indicator.dart';
import 'cockpit/cockpit_top_bar.dart';
import 'cockpit/cockpit_tripmeter.dart';
import 'guide_view.dart';

/// Main cockpit screen: a 3-zone column (info / Δ indicator / trip-meter +
/// blind-touch gestures). Each zone is an independent widget (see the
/// `cockpit/` directory) that watches only the slice of state it needs, and
/// the hot zones are wrapped in `RepaintBoundary` so frequent changes don't
/// repaint the rest of the screen.
class CockpitView extends StatefulWidget {
  const CockpitView({super.key});

  @override
  State<CockpitView> createState() => _CockpitViewState();
}

class _CockpitViewState extends State<CockpitView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => maybeShowOnboarding(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        // Stack so the prompt listener (a SizedBox.shrink overlay) can host a
        // BuildContext for the auto-start dialog without taking layout space.
        // StackFit.expand gives the Column tight constraints so its Expanded
        // children can flex (a default Stack passes loose constraints, which
        // breaks the flex layout).
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                Expanded(flex: 20, child: CockpitTopBar()),
                Expanded(flex: 40, child: DeltaIndicator()),
                Expanded(flex: 20, child: TripmeterBar()),
              ],
            ),
            AutoStartPromptListener(),
          ],
        ),
      ),
    );
  }
}