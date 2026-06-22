import 'package:flutter/material.dart';

import 'cockpit/cockpit_delta_indicator.dart';
import 'cockpit/cockpit_top_bar.dart';
import 'cockpit/cockpit_tripmeter.dart';
import 'cockpit/led_strip.dart';
import 'guide_view.dart';
import 'widgets/restomod_frame.dart';

/// Main cockpit screen: a 3-zone column (info / Δ indicator / trip-meter +
/// blind-touch gestures) framed by a restomod double-rule bezel and capped by a
/// flat LED status strip. Each zone is an independent widget (see the
/// `cockpit/` directory) that watches only the slice of state it needs, and the
/// hot zones are wrapped in `RepaintBoundary` so frequent changes don't
/// repaint the rest of the screen.
///
/// The auto-start prompt listener now lives at the app root (via
/// `MaterialApp.builder`) so its dialog can fire from any screen; this widget
/// no longer needs a Stack to host it.
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
    return Scaffold(
      body: SafeArea(
        // Scaffold body gives tight constraints so the Expanded children flex
        // correctly. The LED strip is a fixed-height row above the three zones;
        // the restomod double-rule bezel wraps the whole dash.
        child: RestomodFrame(
          child: const Column(
            children: [
              LedStrip(),
              Expanded(flex: 20, child: CockpitTopBar()),
              Expanded(flex: 40, child: DeltaIndicator()),
              Expanded(flex: 20, child: TripmeterBar()),
            ],
          ),
        ),
      ),
    );
  }
}