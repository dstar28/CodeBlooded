import '../../models/trip.dart';
import 'backend_result.dart';
import 'local_identity.dart';
import 'supabase_service.dart';

/// Persistence for [Trip] records.
///
/// A user can only ever read/write their own trips — enforced at the
/// database level via Row Level Security (see supabase/schema.sql), not
/// just by this repository always scoping to [LocalIdentity.demoUserId]
/// or a real signed-in user id.
class TripRepository {
  TripRepository._();
  static final TripRepository instance = TripRepository._();

  static const String _table = 'trips';

  Map<String, dynamic> _toRow(Trip trip, {String? userId}) => {
        'id': trip.id,
        'user_id': userId ?? LocalIdentity.demoUserId,
        'title': trip.name,
        'destination': trip.destination,
        'origin': trip.origin,
        'start_date': trip.startDate.toIso8601String(),
        'end_date': trip.endDate.toIso8601String(),
        'status': trip.status.name,
        'notes': trip.notes,
        'updated_at': DateTime.now().toIso8601String(),
      };

  Future<BackendResult<void>> saveTrip(
    Trip trip, {
    String? userId,
  }) async {
    final client = SupabaseService.client;
    if (client == null) return BackendResult.offline();

    try {
      await client.from(_table).upsert(_toRow(trip, userId: userId));
      return BackendResult.success();
    } catch (error) {
      return BackendResult.failure(error.toString());
    }
  }
}
