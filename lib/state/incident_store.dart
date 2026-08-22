import 'package:flutter/foundation.dart';

import '../models/incident.dart';
import '../services/supabase/incident_repository.dart';
import '../services/supabase/sync_state.dart';

/// In-memory incident store for local/mock incident state.
///
/// Mirrors [TripStore] and [SosStore]'s lightweight singleton
/// `ChangeNotifier` approach rather than introducing a new
/// state-management package or a real backend. This store remains the
/// source of truth for the current app session; as of Prompt #12, every
/// created incident is also persisted to Supabase in the background via
/// [IncidentRepository] — the incident's own location snapshot only,
/// never continuous GPS history, and never auto-published to blockchain.
///
/// A traveler only ever sees their own incidents here — there is no
/// multi-user data in this store, and nothing in it is exposed to other
/// travelers or Safety Circle members.
class IncidentStore extends ChangeNotifier {
  IncidentStore._internal();

  static final IncidentStore instance = IncidentStore._internal();

  final List<Incident> _incidents = [];

  // Simple local unique-ID strategy for this prompt — a running counter
  // seeded away from 1 so generated IDs read like "INC-1029" rather than
  // "INC-1". This is unique for the current app session only; a real
  // backend-issued ID will replace it once Supabase persistence is fully
  // load-backed.
  int _nextIdSuffix = 1029;

  /// Most recently reported incident first.
  List<Incident> get incidents => List.unmodifiable(_incidents.reversed);

  bool get hasIncidents => _incidents.isNotEmpty;

  SyncState _syncState = SyncState.idle;

  /// Status of the most recent Supabase sync attempt, for a small
  /// "Synced" / "Offline Mode" / "Unable to sync" indicator in the UI.
  SyncState get syncState => _syncState;

  String _generateIncidentId() {
    final id = 'INC-$_nextIdSuffix';
    _nextIdSuffix += 1;
    return id;
  }

  /// Creates and stores a new incident reported directly by the traveler
  /// from the Report Incident screen. Source is always
  /// [IncidentSource.userReport] — see [createFromSos] for the other
  /// currently-real source.
  Incident createIncident({
    required IncidentType type,
    required String description,
    double? latitude,
    double? longitude,
    bool locationCaptured = false,
    String? tripId,
    List<IncidentEvidenceItem> evidence = const [],
  }) {
    final now = DateTime.now();
    final incident = Incident(
      incidentId: _generateIncidentId(),
      type: type,
      description: description,
      latitude: latitude,
      longitude: longitude,
      locationCaptured: locationCaptured,
      tripId: tripId,
      timestamp: now,
      source: IncidentSource.userReport,
      status: IncidentStatus.reported,
      createdAt: now,
      updatedAt: now,
      evidence: evidence,
      timeline: [
        IncidentTimelineEvent(timestamp: now, label: 'Incident reported'),
      ],
    );

    _incidents.add(incident);
    notifyListeners();
    _syncIncident(incident);
    return incident;
  }

  /// Creates a local incident when an SOS session becomes active
  /// (Prompt #7's Emergency Assistance flow), so the Incident Engine has
  /// a record ready without rewriting the SOS system itself. Called from
  /// [SosStore.activate].
  Incident createFromSos({String? tripId}) {
    final now = DateTime.now();
    final incident = Incident(
      incidentId: _generateIncidentId(),
      type: IncidentType.emergencySos,
      description: 'Emergency SOS alert activated by the traveler.',
      locationCaptured: false,
      tripId: tripId,
      timestamp: now,
      source: IncidentSource.sos,
      status: IncidentStatus.reported,
      createdAt: now,
      updatedAt: now,
      timeline: [
        IncidentTimelineEvent(
          timestamp: now,
          label: 'Incident reported (SOS)',
        ),
      ],
    );

    _incidents.add(incident);
    notifyListeners();
    _syncIncident(incident);
    return incident;
  }

  Future<void> _syncIncident(Incident incident) async {
    _syncState = SyncState.syncing;
    notifyListeners();

    final result = await IncidentRepository.instance.saveIncident(incident);
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