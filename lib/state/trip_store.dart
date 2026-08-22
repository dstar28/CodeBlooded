import 'package:flutter/foundation.dart';
import '../models/trip.dart';
import '../services/supabase/sync_state.dart';
import '../services/supabase/trip_repository.dart';

/// In-memory trip store for local/mock trip state.
///
/// This is intentionally a lightweight singleton `ChangeNotifier` rather
/// than a full state-management package, per Prompt #5 scope ("use a
/// simple local state solution"). [TripStore] itself is still the source
/// of truth for the running app session — as of Prompt #12, newly
/// created trips are also persisted to Supabase in the background via
/// [TripRepository]. When Supabase is unavailable (or a real user isn't
/// signed in yet), SafeGuard stays fully usable; [syncState] simply
/// reflects that instead of the app silently pretending the save
/// succeeded.
class TripStore extends ChangeNotifier {
  TripStore._internal() {
    // Seeded mock trip only, as specified in Prompt #5.
    _trips.add(
      Trip(
        id: 'mock-goa-trip',
        name: 'Goa Trip',
        destination: 'Goa',
        origin: 'Mumbai',
        startDate: DateTime(2026, 8, 21),
        endDate: DateTime(2026, 8, 25),
        status: TripStatus.active,
      ),
    );
  }

  static final TripStore instance = TripStore._internal();

  final List<Trip> _trips = [];

  List<Trip> get trips => List.unmodifiable(_trips);

  SyncState _syncState = SyncState.idle;

  /// Status of the most recent Supabase sync attempt, for a small
  /// "Synced" / "Offline Mode" / "Unable to sync" indicator in the UI.
  SyncState get syncState => _syncState;

  void addTrip(Trip trip) {
    _trips.insert(0, trip);
    notifyListeners();
    _syncTrip(trip);
  }

  Future<void> _syncTrip(Trip trip) async {
    _syncState = SyncState.syncing;
    notifyListeners();

    final result = await TripRepository.instance.saveTrip(trip);
    if (result.isSuccess) {
      _syncState = SyncState.synced;
    } else if (result.isOffline) {
      _syncState = SyncState.offline;
    } else {
      _syncState = SyncState.error;
    }
    notifyListeners();
  }
}