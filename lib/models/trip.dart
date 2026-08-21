/// Local/mock trip status states supported by Trip Planning (Prompt #5).
///
/// Status changes here are local-only for now — there is no real tracking
/// engine, geo-fencing, or backend sync behind these values yet.
enum TripStatus { upcoming, active, completed }

extension TripStatusLabel on TripStatus {
  String get label {
    switch (this) {
      case TripStatus.upcoming:
        return 'Upcoming';
      case TripStatus.active:
        return 'Active';
      case TripStatus.completed:
        return 'Completed';
    }
  }
}

/// A single planned/active/completed trip.
///
/// This is in-memory/mock data only for Prompt #5 — nothing here is
/// persisted to Supabase yet. [origin] is not currently a user-entered
/// field (Create Trip only collects a destination), so it defaults to a
/// generic label for user-created trips; the seeded mock trip sets it
/// explicitly.
class Trip {
  Trip({
    required this.id,
    required this.name,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.origin = 'Current Location',
    this.notes = '',
  });

  final String id;
  final String name;
  final String destination;
  final String origin;
  final DateTime startDate;
  final DateTime endDate;
  final TripStatus status;
  final String notes;

  String get route => '$origin → $destination';
}