import 'package:flutter/foundation.dart';
import '../models/trip.dart';

/// In-memory trip store for local/mock trip state.
///
/// This is intentionally a lightweight singleton `ChangeNotifier` rather
/// than a full state-management package, per Prompt #5 scope ("use a
/// simple local state solution"). Trip data only persists for the
/// lifetime of the running app — Supabase persistence will replace this
/// in a later prompt. Do NOT treat this as a real backend service.
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

  void addTrip(Trip trip) {
    _trips.insert(0, trip);
    notifyListeners();
  }
}