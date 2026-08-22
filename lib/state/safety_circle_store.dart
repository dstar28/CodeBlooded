import 'dart:math';

import 'package:flutter/foundation.dart';
import '../models/safety_circle_group.dart';
import '../services/supabase/safety_circle_repository.dart';
import '../services/supabase/sync_state.dart';

/// In-memory Safety Circle store for local/mock group state (Prompt #9).
///
/// This is intentionally a lightweight singleton `ChangeNotifier`,
/// matching [TripStore] and [SosStore] — no new state-management
/// package, no Supabase Realtime, no real backend group service. Group
/// membership/status remains local/mock for the lifetime of the running
/// app. As of Prompt #12, creating or joining a circle also persists a
/// FOUNDATION record (circle + membership row) to Supabase in the
/// background via [SafetyCircleRepository] — no continuous GPS, no
/// real-time tracking, and no push notifications are added by this.
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

  SyncState _syncState = SyncState.idle;

  /// Status of the most recent Supabase sync attempt for this circle's
  /// persistence-foundation record.
  SyncState get syncState => _syncState;

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
          lastUpdatedLabel: '1 min ago',
          distanceKm: 0.6,
        ),
        SafetyCircleMember(
          id: 'priya',
          name: 'Priya',
          status: MemberSafetyStatus.safe,
          lastUpdatedLabel: '1 min ago',
          distanceKm: 0.8,
        ),
        SafetyCircleMember(
          id: 'rahul',
          name: 'Rahul',
          status: MemberSafetyStatus.safe,
          lastUpdatedLabel: '2 min ago',
          distanceKm: 1.1,
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
    _syncCircle(newGroup, addSelfAsMember: true);
    return newGroup;
  }

  /// Attempts to join a mock Safety Circle by code.
  ///
  /// Returns true on success. This never talks to a real backend for the
  /// *join validation* itself — it only checks against a small local
  /// list of demo codes — but a successful join is still recorded via
  /// [SafetyCircleRepository] in the background.
  bool joinGroup(String code) {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty || !_mockJoinableCodes.contains(normalized)) {
      return false;
    }

    final joined = SafetyCircleGroup(
      id: 'joined-$normalized',
      name: 'Goa Trip',
      code: normalized,
      members: _mockMembers(),
    );
    _group = joined;
    _alertMemberId = null;
    notifyListeners();
    _syncCircle(joined, addSelfAsMember: true);
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
            .firstWhere(
              (m) => !m.isCurrentUser,
              orElse: () => currentGroup.members.first,
            )
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

  Future<void> _syncCircle(
    SafetyCircleGroup group, {
    bool addSelfAsMember = false,
  }) async {
    _syncState = SyncState.syncing;
    notifyListeners();

    final circleResult = await SafetyCircleRepository.instance.saveCircle(
      id: group.id,
      name: group.name,
      inviteCode: group.code,
    );

    if (circleResult.isSuccess && addSelfAsMember) {
      await SafetyCircleRepository.instance.addMember(circleId: group.id);
    }

    if (circleResult.isSuccess) {
      _syncState = SyncState.synced;
    } else if (circleResult.isOffline) {
      _syncState = SyncState.offline;
    } else {
      _syncState = SyncState.error;
    }
    notifyListeners();
  }
}