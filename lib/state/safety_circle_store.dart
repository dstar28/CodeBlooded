import 'dart:math';

import 'package:flutter/foundation.dart';
import '../models/safety_circle_group.dart';

/// In-memory Safety Circle store for local/mock group state (Prompt #9).
///
/// This is intentionally a lightweight singleton `ChangeNotifier`, matching
/// [TripStore] and [SosStore] — no new state-management package, no
/// Supabase Realtime, no real backend group service. Group membership
/// only persists for the lifetime of the running app.
///
/// Joining is simulated against a small set of mock codes so the "Join
/// Safety Circle" flow can be demonstrated without a backend. Creating a
/// group generates a fresh mock code locally.
class SafetyCircleStore extends ChangeNotifier {
  SafetyCircleStore._internal();

  static final SafetyCircleStore instance = SafetyCircleStore._internal();

  /// Codes a user is allowed to "join" in this mock implementation, as if
  /// another traveler had already created these circles.
  static const List<String> _mockJoinableCodes = ['SG-2025', 'SG-7143'];

  final Random _random = Random();

  SafetyCircleGroup? _group;

  /// The current user's active Safety Circle, or null if not in one.
  SafetyCircleGroup? get group => _group;

  bool get hasGroup => _group != null;

  /// Id of the member currently flagged as being in danger, used to drive
  /// the Safety Alert banner. Null when there is no active alert.
  String? _alertMemberId;
  String? get alertMemberId => _alertMemberId;

  List<SafetyCircleMember> _mockMembers() => [
        SafetyCircleMember(
          id: 'you',
          name: 'You',
          status: MemberSafetyStatus.safe,
          isCurrentUser: true,
        ),
        SafetyCircleMember(
          id: 'aarav',
          name: 'Aarav',
          status: MemberSafetyStatus.safe,
        ),
        SafetyCircleMember(
          id: 'priya',
          name: 'Priya',
          status: MemberSafetyStatus.safe,
        ),
        SafetyCircleMember(
          id: 'rahul',
          name: 'Rahul',
          status: MemberSafetyStatus.safe,
        ),
      ];

  String _generateCode() {
    final number = 1000 + _random.nextInt(9000);
    return 'SG-$number';
  }

  /// Creates a new Safety Circle locally and makes it the current group.
  SafetyCircleGroup createGroup({required String name, String? tripName}) {
    final newGroup = SafetyCircleGroup(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      code: _generateCode(),
      members: _mockMembers(),
      tripName: tripName,
    );

    _group = newGroup;
    _alertMemberId = null;
    notifyListeners();
    return newGroup;
  }

  /// Attempts to join a mock Safety Circle by code.
  ///
  /// Returns true on success. This never talks to a real backend — it
  /// only checks against a small local list of demo codes.
  bool joinGroup(String code) {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty || !_mockJoinableCodes.contains(normalized)) {
      return false;
    }

    _group = SafetyCircleGroup(
      id: 'joined-$normalized',
      name: 'Goa Trip',
      code: normalized,
      members: _mockMembers(),
    );
    _alertMemberId = null;
    notifyListeners();
    return true;
  }

  /// Removes the current user from their Safety Circle.
  void leaveGroup() {
    _group = null;
    _alertMemberId = null;
    notifyListeners();
  }

  SafetyCircleMember? memberById(String id) {
    final currentGroup = _group;
    if (currentGroup == null) return null;
    for (final member in currentGroup.members) {
      if (member.id == id) return member;
    }
    return null;
  }

  /// Demo-only control: flips a non-current-user member to Danger and
  /// raises a local Safety Alert. Does not send any real notification.
  void simulateDanger({String? memberId}) {
    final currentGroup = _group;
    if (currentGroup == null) return;

    final targetId = memberId ??
        currentGroup.members
            .firstWhere((m) => !m.isCurrentUser, orElse: () => currentGroup.members.first)
            .id;

    final updatedMembers = currentGroup.members
        .map(
          (m) => m.id == targetId
              ? m.copyWith(status: MemberSafetyStatus.danger)
              : m,
        )
        .toList();

    _group = SafetyCircleGroup(
      id: currentGroup.id,
      name: currentGroup.name,
      code: currentGroup.code,
      members: updatedMembers,
      tripName: currentGroup.tripName,
    );
    _alertMemberId = targetId;
    notifyListeners();
  }

  /// Demo-only control: clears any simulated Danger status back to Safe.
  void resetDemoStatuses() {
    final currentGroup = _group;
    if (currentGroup == null) return;

    final resetMembers = currentGroup.members
        .map((m) => m.copyWith(status: MemberSafetyStatus.safe))
        .toList();

    _group = SafetyCircleGroup(
      id: currentGroup.id,
      name: currentGroup.name,
      code: currentGroup.code,
      members: resetMembers,
      tripName: currentGroup.tripName,
    );
    _alertMemberId = null;
    notifyListeners();
  }

  /// Dismisses the current Safety Alert banner without changing status.
  void dismissAlert() {
    _alertMemberId = null;
    notifyListeners();
  }
}
