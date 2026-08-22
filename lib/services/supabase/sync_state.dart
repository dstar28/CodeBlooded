/// Small, UI-facing summary of the most recent Supabase sync attempt for
/// a given feature (Trips, Emergency Contacts, Incidents, Safety Circle,
/// Digital Tourist ID).
///
/// Deliberately coarse — this is not a queue or retry system, just enough
/// state to show a "Synced" / "Offline Mode" / "Unable to sync" badge
/// without ever lying about whether a save succeeded.
enum SyncState { idle, syncing, synced, offline, error }