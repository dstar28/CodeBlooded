import 'package:flutter/material.dart';

/// Local/mock incident lifecycle states for the Incident Engine foundation
/// (Prompt #11).
///
/// Status changes represented by this enum are simulated/local only for
/// now — there is no real admin verification, responder dispatch, or
/// backend behind any value beyond [reported] yet. Nothing in this app
/// currently claims a real person has verified or acted on an incident.
enum IncidentStatus {
  reported,
  underReview,
  verified,
  responderAssigned,
  inProgress,
  resolved,
  cancelled,
}

extension IncidentStatusPresentation on IncidentStatus {
  String get label {
    switch (this) {
      case IncidentStatus.reported:
        return 'Reported';
      case IncidentStatus.underReview:
        return 'Under Review';
      case IncidentStatus.verified:
        return 'Verified';
      case IncidentStatus.responderAssigned:
        return 'Responder Assigned';
      case IncidentStatus.inProgress:
        return 'In Progress';
      case IncidentStatus.resolved:
        return 'Resolved';
      case IncidentStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Types of safety incident a traveler can report.
///
/// [emergencySos] is intentionally not offered in the manual type picker —
/// it is only ever set automatically when an incident is created from an
/// active SOS session (Prompt #7's Emergency Assistance flow). See
/// [selectableIncidentTypes].
enum IncidentType {
  accident,
  medicalEmergency,
  theft,
  harassment,
  lostTourist,
  unsafeArea,
  naturalDisaster,
  emergencySos,
  other,
}

extension IncidentTypePresentation on IncidentType {
  String get label {
    switch (this) {
      case IncidentType.accident:
        return 'Accident';
      case IncidentType.medicalEmergency:
        return 'Medical Emergency';
      case IncidentType.theft:
        return 'Theft';
      case IncidentType.harassment:
        return 'Harassment';
      case IncidentType.lostTourist:
        return 'Lost Tourist';
      case IncidentType.unsafeArea:
        return 'Unsafe Area';
      case IncidentType.naturalDisaster:
        return 'Natural Disaster';
      case IncidentType.emergencySos:
        return 'Emergency / SOS';
      case IncidentType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case IncidentType.accident:
        return Icons.car_crash_outlined;
      case IncidentType.medicalEmergency:
        return Icons.medical_services_outlined;
      case IncidentType.theft:
        return Icons.inventory_2_outlined;
      case IncidentType.harassment:
        return Icons.report_gmailerrorred_outlined;
      case IncidentType.lostTourist:
        return Icons.person_search_outlined;
      case IncidentType.unsafeArea:
        return Icons.warning_amber_outlined;
      case IncidentType.naturalDisaster:
        return Icons.cyclone_outlined;
      case IncidentType.emergencySos:
        return Icons.emergency_outlined;
      case IncidentType.other:
        return Icons.more_horiz_outlined;
    }
  }
}

/// The types actually presented by the Incident Type picker.
///
/// [IncidentType.emergencySos] is excluded — see its doc comment above.
const List<IncidentType> selectableIncidentTypes = [
  IncidentType.accident,
  IncidentType.medicalEmergency,
  IncidentType.theft,
  IncidentType.harassment,
  IncidentType.lostTourist,
  IncidentType.unsafeArea,
  IncidentType.naturalDisaster,
  IncidentType.other,
];

/// Where an incident originated.
///
/// Only [userReport] and [sos] are ever actually produced by the app
/// today. The remaining values exist so this model doesn't need to change
/// shape when AI detection, geo-fencing, and group alerts are connected in
/// later prompts — no fake results are generated for them now.
enum IncidentSource { userReport, sos, aiDetection, geoFence, groupAlert }

extension IncidentSourcePresentation on IncidentSource {
  String get label {
    switch (this) {
      case IncidentSource.userReport:
        return 'User Report';
      case IncidentSource.sos:
        return 'SOS';
      case IncidentSource.aiDetection:
        return 'AI Detection';
      case IncidentSource.geoFence:
        return 'Geo-fence';
      case IncidentSource.groupAlert:
        return 'Group Alert';
    }
  }
}

/// Local evidence attachment kinds a traveler can represent on an
/// incident.
enum EvidenceType { photo, video, document }

extension EvidenceTypePresentation on EvidenceType {
  String get label {
    switch (this) {
      case EvidenceType.photo:
        return 'Photo';
      case EvidenceType.video:
        return 'Video';
      case EvidenceType.document:
        return 'Document';
    }
  }

  IconData get icon {
    switch (this) {
      case EvidenceType.photo:
        return Icons.photo_camera_outlined;
      case EvidenceType.video:
        return Icons.videocam_outlined;
      case EvidenceType.document:
        return Icons.description_outlined;
    }
  }
}

/// A single locally-selected evidence attachment.
///
/// This only represents the traveler's local selection for Prompt #11 —
/// nothing here is uploaded to Supabase, hashed, or anchored anywhere.
/// [isUploaded] and [isVerified] stay false until a future prompt adds
/// real file upload and blockchain evidence registration; the UI must use
/// them to visually separate local-only evidence from anything trusted.
class IncidentEvidenceItem {
  IncidentEvidenceItem({
    required this.id,
    required this.type,
    required this.label,
    required this.addedAt,
    this.isUploaded = false,
    this.isVerified = false,
  });

  final String id;
  final EvidenceType type;
  final String label;
  final DateTime addedAt;
  final bool isUploaded;
  final bool isVerified;
}

/// A single entry in an incident's lifecycle timeline.
///
/// Only entries for things that actually happened are ever created — see
/// [Incident] doc comment.
class IncidentTimelineEvent {
  IncidentTimelineEvent({required this.timestamp, required this.label});

  final DateTime timestamp;
  final String label;
}

/// A traveler-reported (or SOS-originated) safety incident.
///
/// This is the local application foundation for the Incident Engine
/// (Prompt #11). It intentionally models the fields future prompts will
/// need — Supabase persistence, real evidence upload, admin verification,
/// responder dispatch, and blockchain evidence anchoring — without
/// implementing any of that yet. Incidents live only in `IncidentStore`
/// for the current app session; nothing here is sent to a backend.
///
/// A reported incident is NOT automatically a verified or trusted record.
/// [status] starts at [IncidentStatus.reported] and only [source],
/// [timestamp], and the initial "Incident reported" [timeline] entry are
/// ever set automatically — no admin/responder/AI outcome is fabricated.
class Incident {
  Incident({
    required this.incidentId,
    required this.type,
    required this.description,
    required this.timestamp,
    required this.source,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.userId,
    this.tripId,
    this.latitude,
    this.longitude,
    this.locationCaptured = false,
    List<IncidentEvidenceItem>? evidence,
    List<IncidentTimelineEvent>? timeline,
  }) : evidence = evidence ?? const [],
       timeline = timeline ?? const [];

  final String incidentId;

  /// Reference only — this app has no real auth/user backend yet, so this
  /// stays null until Supabase auth is wired up.
  final String? userId;

  /// Reference to a [Trip] from [TripStore], if the traveler had one
  /// active when the incident was created.
  final String? tripId;

  final IncidentType type;
  final String description;

  final double? latitude;
  final double? longitude;

  /// Whether device location was actually captured for this incident.
  /// When false, [latitude]/[longitude] are null and the UI must say so
  /// rather than showing blank/fake coordinates.
  final bool locationCaptured;

  /// Device time when the incident was created. Not user-editable.
  final DateTime timestamp;

  final IncidentSource source;
  final IncidentStatus status;

  final List<IncidentEvidenceItem> evidence;
  final List<IncidentTimelineEvent> timeline;

  final DateTime createdAt;
  final DateTime updatedAt;

  Incident copyWith({
    IncidentStatus? status,
    List<IncidentEvidenceItem>? evidence,
    List<IncidentTimelineEvent>? timeline,
    DateTime? updatedAt,
  }) {
    return Incident(
      incidentId: incidentId,
      userId: userId,
      tripId: tripId,
      type: type,
      description: description,
      latitude: latitude,
      longitude: longitude,
      locationCaptured: locationCaptured,
      timestamp: timestamp,
      source: source,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      evidence: evidence ?? this.evidence,
      timeline: timeline ?? this.timeline,
    );
  }
}

// ---------------------------------------------------------------------------
// Lightweight local time formatting (no `intl` dependency), mirroring the
// approach already used by utils/date_format.dart for trips.
// ---------------------------------------------------------------------------

const List<String> _incidentMonthAbbreviations = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatIncidentClock(DateTime dt) {
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatIncidentDateTime(DateTime dt) {
  final month = _incidentMonthAbbreviations[dt.month - 1];
  return '$month ${dt.day}, ${dt.year} · ${formatIncidentClock(dt)}';
}