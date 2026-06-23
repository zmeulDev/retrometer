/// SharedPreferences keys kept here so the repository (legacy migration) and
/// any other reader share the exact same constants.
const kCompetitionsKey = 'retrometer.competitions';

/// Legacy flat-schedule key (pre-competition versions). Used only for the
/// one-time migration into a default competition on first load.
const kLegacyScheduleKey = 'retrometer.schedule';