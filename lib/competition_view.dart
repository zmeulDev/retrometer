// Barrel for the competition feature. The two screens live in
// `lib/competition/`; this file re-exports them so existing imports
// (`import 'competition_view.dart';`) keep working.
export 'competition/competition_list_view.dart' show CompetitionsScreen;
export 'competition/competition_detail_view.dart' show CompetitionDetailScreen;