import '../../models/incident.dart';
import 'backend_result.dart';
import 'local_identity.dart';
import 'supabase_service.dart';

/// Persistence for [Incident] records.
///
/// Only the incident's own location snapshot (captured once, at report
/// time) is ever stored — never continuous GPS history — and nothing
/// here automatically publishes an incident to the blockchain trust
/// layer. A traveler can only ever read their own incidents, enforced by
/// Row Level Security (see supabase/schema.sql).
class IncidentRepository {
  IncidentRepository._();
  static final IncidentRepository instance = IncidentRepository._();

  static const String _table = 'incidents';

  Map<String, dynamic> _toRow(Incident incident, {String? userId}) => {
        'incident_id': incident.incidentId,
        'user_id': userId ?? LocalIdentity.demoUserId,
        'trip_id': incident.tripId,
        'type': incident.type.name,
        'description': incident.description,
        'latitude': incident.locationCaptured ? incident.latitude : null,
        'longitude': incident.locationCaptured ? incident.longitude : null,
        'incident_time': incident.timestamp.toIso8601String(),
        'source': incident.source.name,
        'status': incident.status.name,
        'updated_at': DateTime.now().toIso8601String(),
      };

  Future<BackendResult<void>> saveIncident(
    Incident incident, {
    String? userId,
  }) async {
    final client = SupabaseService.client;
    if (client == null) return BackendResult.offline();

    try {
      await client.from(_table).upsert(
            _toRow(incident, userId: userId),
            onConflict: 'incident_id',
          );
      return BackendResult.success();
    } catch (error) {
      return BackendResult.failure(error.toString());
    }
  }

  Future<BackendResult<List<Map<String, dynamic>>>> fetchIncidents({
    String? userId,
  }) async {
    final client = SupabaseService.client;
    if (client == null) return BackendResult.offline();

    try {
      final rows = await client
          .from(_table)
          .select()
          .eq('user_id', userId ?? LocalIdentity.demoUserId)
          .order('incident_time', ascending: false);
      return BackendResult.success(List<Map<String, dynamic>>.from(rows));
    } catch (error) {
      return BackendResult.failure(error.toString());
    }
  }
}