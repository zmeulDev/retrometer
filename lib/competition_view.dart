import 'package:flutter/material.dart';

import 'competition/competition_detail_view.dart';
import 'competition/competition_list_view.dart';

/// Competition feature entry point. Hosts the list and detail screens in a
/// single route: tapping a competition switches to its detail in place (no
/// Navigator push); the system/gesture back returns to the list, and a further
/// back leaves the feature. Mirrors `CockpitView`'s composition-root shape — a
/// StatefulWidget that composes child widgets rather than pushing them as
/// separate routes.
class CompetitionView extends StatefulWidget {
  const CompetitionView({super.key});

  @override
  State<CompetitionView> createState() => _CompetitionViewState();
}

class _CompetitionViewState extends State<CompetitionView> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final id = _selectedId;
    return PopScope(
      canPop: id == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && id != null) setState(() => _selectedId = null);
      },
      child: id == null
          ? CompetitionsScreen(
              onOpen: (cid) => setState(() => _selectedId = cid),
            )
          : CompetitionDetailScreen(
              id: id,
              onBack: () => setState(() => _selectedId = null),
            ),
    );
  }
}