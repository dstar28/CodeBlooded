/// Local/mock member safety status for the Safety Circle feature
/// (Prompt #9).
///
/// This is a plain-language status only. There is no numerical risk
/// score anywhere in this model — that is deliberately an admin-only
/// concept and must never surface to a regular traveler.
enum MemberSafetyStatus { safe, caution, danger, offline }

extension MemberSafetyStatusLabel on MemberSafetyStatus {
  String get label {
    switch (this) {
      case MemberSafetyStatus.safe:
        return 'Safe';
      case MemberSafetyStatus.caution:
        return 'Caution';
      case MemberSafetyStatus.danger:
        return 'Danger';
      case MemberSafetyStatus.offline:
        return 'Offline';
    }
  }

  /// Short, plain-language description shown on member cards and alerts.
  /// Deliberately avoids anything resembling a risk score.
  String descriptionFor(String memberName) {
    switch (this) {
      case MemberSafetyStatus.safe:
        return '$memberName is safe.';
      case MemberSafetyStatus.caution:
        return '$memberName may need attention.';
      case MemberSafetyStatus.danger:
        return '$memberName may be in danger.';
      case MemberSafetyStatus.offline:
        return '$memberName is currently offline.';
    }
  }
}

/// A single member of a Safety Circle group.
///
/// This is in-memory/mock data only for Prompt #9 — there is no real
/// location sharing, and no private profile data (phone number, exact
/// location history, documents, etc.) is modeled here on purpose.
class SafetyCircleMember {
  SafetyCircleMember({
    required this.id,
    required this.name,
    required this.status,
    this.isCurrentUser = false,
    this.lastUpdatedLabel = 'Just now',
    this.distanceKm,
  });

  final String id;
  final String name;
  final MemberSafetyStatus status;
  final bool isCurrentUser;

  /// Plain-language freshness label (e.g. "Just now", "5 min ago").
  /// Intentionally not a precise timestamp/location trail.
  final String lastUpdatedLabel;

  /// Approximate distance from the current user, in kilometers, for
  /// display purposes only (e.g. "0.6 km from you"). This is demo/mock
  /// data — there is no live GPS distance calculation behind it. Null
  /// for the current user (whose card shows "Current location" instead)
  /// and for members whose distance is unknown (e.g. offline).
  final double? distanceKm;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  SafetyCircleMember copyWith({MemberSafetyStatus? status}) {
    return SafetyCircleMember(
      id: id,
      name: name,
      status: status ?? this.status,
      isCurrentUser: isCurrentUser,
      lastUpdatedLabel: lastUpdatedLabel,
      distanceKm: distanceKm,
    );
  }
}

/// A Safety Circle / group travel session.
///
/// Membership and status here are local/mock only for Prompt #9 — there
/// is no Supabase Realtime sync and no backend group service yet.
class SafetyCircleGroup {
  SafetyCircleGroup({
    required this.id,
    required this.name,
    required this.code,
    required this.members,
    this.tripName,
  });

  final String id;
  final String name;
  final String code;
  final String? tripName;
  final List<SafetyCircleMember> members;
}