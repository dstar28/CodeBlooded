import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/safety_circle_group.dart';
import '../services/api/safeguard_api_client.dart';
import '../services/supabase/local_identity.dart';
import '../services/supabase/safety_circle_repository.dart';
import '../services/supabase/sync_state.dart';

/// Outcome of a create/join action, so screens can show their own
/// error text (matching their existing UI) without the store throwing.
class SafetyCircleActionResult {
  const SafetyCircleActionResult._(this.success, this.group, this.errorMessage);

  final bool success;
  final SafetyCircleGroup? group;
  final String? errorMessage;

  factory SafetyCircleActionResult.success(SafetyCircleGroup group) =>
      SafetyCircleActionResult._(true, group, null);

  factory SafetyCircleActionResult.failure(String message) =>
      SafetyCircleActionResult._(false, null, message);
}

/// Safety Circle store, backed by the SafeGuard FastAPI Group backend.
///
/// This is still a lightweight singleton `ChangeNotifier`, matching
/// [TripStore] and [SosStore] — no new state-management package. As of
/// this update, group creation/joining/loading, group-member status, and
/// location updates all go through [SafeguardApiClient] rather than
/// local mock data. The Supabase "foundation" sync via
/// [SafetyCircleRepository] is unrelated persistence and is left as-is.
///
/// The tourist-facing UI only ever sees plain-language status
/// (safe/caution/danger/offline) and distance — never a numerical risk
/// score. The admin AI risk endpoint is intentionally not called from
/// anywhere in this store.
class SafetyCircleStore extends ChangeNotifier {
  SafetyCircleStore._internal();

  static final SafetyCircleStore instance = SafetyCircleStore._internal();

  static const Duration _refreshInterval = Duration(seconds: 20);
  static const Duration _locationUpdateInterval = Duration(seconds: 15);

  SafetyCircleGroup? _group;

  /// The current user's active Safety Circle, or null if not in one.
  SafetyCircleGroup? get group => _group;

  bool get hasGroup => _group != null;

  /// True while a create/join/refresh call to the backend is in flight.
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// True when the most recent background refresh could not reach the
  /// backend. The last successfully loaded group data is kept on screen;
  /// this only drives an unobtrusive "offline" indicator.
  bool _isOffline = false;
  bool get isOffline => _isOffline;

  /// Id of the member currently flagged as being in danger, used to drive
  /// the Safety Alert banner. Null when there is no active alert. This
  /// remains a local/demo concept — the backend does not report a
  /// "danger" status, only SAFE/WARNING.
  String? _alertMemberId;
  String? get alertMemberId => _alertMemberId;

  SyncState _syncState = SyncState.idle;

  /// Status of the most recent Supabase sync attempt for this circle's
  /// persistence-foundation record.
  SyncState get syncState => _syncState;

  Timer? _refreshTimer;
  DateTime? _lastLocationSentAt;

  /// Creates a new Safety Circle via the backend and makes it the
  /// current group.
  Future<SafetyCircleActionResult> createGroup({
    required String name,
    String? tripName,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return SafetyCircleActionResult.failure('Group name is required');
    }

    _isLoading = true;
    notifyListeners();

    final userId = LocalIdentity.demoUserId;
    const userName = 'You';

    final result = await SafeguardApiClient.instance.createGroup(
      name: trimmedName,
      userId: userId,
      userName: userName,
    );

    if (!result.isSuccess) {
      _isLoading = false;
      notifyListeners();
      return SafetyCircleActionResult.failure(
        result.message ?? 'Could not create the Safety Circle. Please try again.',
      );
    }

    final data = result.data!;
    final groupId = data['group_id'] as String?;
    final inviteCode = data['invite_code'] as String?;

    if (groupId == null || inviteCode == null) {
      _isLoading = false;
      notifyListeners();
      return SafetyCircleActionResult.failure(
        'Unexpected response from the server. Please try again.',
      );
    }

    final newGroup = SafetyCircleGroup(
      id: groupId,
      name: data['name'] as String? ?? trimmedName,
      code: inviteCode,
      members: [
        SafetyCircleMember(
          id: userId,
          name: userName,
          status: MemberSafetyStatus.safe,
          isCurrentUser: true,
        ),
      ],
      tripName: tripName,
    );

    _group = newGroup;
    _alertMemberId = null;
    _isOffline = false;
    _isLoading = false;
    notifyListeners();

    _syncCircle(newGroup, addSelfAsMember: true);
    _startAutoRefresh();
    unawaited(_loadGroupDetails(groupId));

    return SafetyCircleActionResult.success(newGroup);
  }

  /// Joins an existing Safety Circle by invite code via the backend.
  Future<SafetyCircleActionResult> joinGroup(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      return SafetyCircleActionResult.failure(
        'Please enter a Safety Circle code',
      );
    }

    _isLoading = true;
    notifyListeners();

    final userId = LocalIdentity.demoUserId;
    const userName = 'You';

    final joinResult = await SafeguardApiClient.instance.joinGroup(
      inviteCode: normalized,
      userId: userId,
      userName: userName,
    );

    if (!joinResult.isSuccess) {
      _isLoading = false;
      notifyListeners();
      if (joinResult.status == ApiStatus.notFound) {
        return SafetyCircleActionResult.failure('Invalid Safety Circle Code');
      }
      return SafetyCircleActionResult.failure(
        joinResult.message ??
            'Could not join the Safety Circle. Please try again.',
      );
    }

    final groupId = joinResult.data!['group_id'] as String?;
    if (groupId == null) {
      _isLoading = false;
      notifyListeners();
      return SafetyCircleActionResult.failure(
        'Unexpected response from the server. Please try again.',
      );
    }

    final loaded = await _loadGroupDetails(groupId, fallbackCode: normalized);
    _isLoading = false;

    if (loaded == null) {
      notifyListeners();
      return SafetyCircleActionResult.failure(
        'Joined the group, but could not load it. Pull down to try again.',
      );
    }

    _alertMemberId = null;
    notifyListeners();

    _syncCircle(loaded, addSelfAsMember: true);
    _startAutoRefresh();

    return SafetyCircleActionResult.success(loaded);
  }

  /// Re-fetches the current group's members and safety status from the
  /// backend. Safe to call repeatedly (used by the periodic refresh
  /// timer); keeps the last good data on screen if the backend can't be
  /// reached.
  Future<void> refreshGroupStatus() async {
    final current = _group;
    if (current == null) return;
    await _loadGroupDetails(current.id, fallbackCode: current.code);
  }

  /// Fetches group membership + safety status and merges them into the
  /// store's [SafetyCircleGroup]. Returns the new group, or null if the
  /// group could not be loaded at all (e.g. it no longer exists).
  Future<SafetyCircleGroup?> _loadGroupDetails(
    String groupId, {
    String? fallbackCode,
  }) async {
    final groupResult = await SafeguardApiClient.instance.getGroup(groupId);

    if (!groupResult.isSuccess) {
      // Keep whatever we already have on screen; just surface an
      // unobtrusive offline/error indicator for network failures.
      _isOffline = groupResult.isNetworkFailure;
      notifyListeners();
      return null;
    }

    final data = groupResult.data!;
    final rawMembers = (data['members'] as List<dynamic>?) ?? const [];
    final currentUserId = LocalIdentity.demoUserId;

    // Best-effort: safety status failing shouldn't block showing members.
    final statusResult = await SafeguardApiClient.instance.getSafetyStatus(
      groupId,
    );
    final statusByUser = <String, Map<String, dynamic>>{};
    if (statusResult.isSuccess) {
      final statusMembers =
          (statusResult.data!['members'] as List<dynamic>?) ?? const [];
      for (final entry in statusMembers) {
        final map = entry as Map<String, dynamic>;
        final userId = map['user_id'] as String?;
        if (userId != null) statusByUser[userId] = map;
      }
    }

    final members = rawMembers.map((entry) {
      final map = entry as Map<String, dynamic>;
      final userId = map['user_id'] as String? ?? '';
      final isCurrentUser = userId == currentUserId;
      final statusEntry = statusByUser[userId];

      MemberSafetyStatus status;
      double? distanceKm;
      String lastUpdatedLabel;

      if (statusEntry != null) {
        final backendStatus = statusEntry['status'] as String?;
        status = backendStatus == 'WARNING'
            ? MemberSafetyStatus.caution
            : MemberSafetyStatus.safe;
        final rawDistance = statusEntry['distance_km'];
        distanceKm = isCurrentUser
            ? null
            : (rawDistance is num ? rawDistance.toDouble() : null);
        lastUpdatedLabel = 'Just now';
      } else {
        // No location reported for this member yet — never fabricate a
        // distance or a dangerous-sounding status.
        status = MemberSafetyStatus.safe;
        distanceKm = null;
        lastUpdatedLabel = 'No location yet';
      }

      // A member flagged in a local demo alert stays visually "in
      // danger" until dismissed/reset, even though the backend has no
      // such concept.
      if (userId == _alertMemberId) {
        status = MemberSafetyStatus.danger;
      }

      return SafetyCircleMember(
        id: userId,
        name: map['name'] as String? ?? 'Member',
        status: status,
        isCurrentUser: isCurrentUser,
        lastUpdatedLabel: lastUpdatedLabel,
        distanceKm: distanceKm,
      );
    }).toList();

    final newGroup = SafetyCircleGroup(
      id: data['group_id'] as String? ?? groupId,
      name: data['name'] as String? ?? _group?.name ?? '',
      code: data['invite_code'] as String? ??
          fallbackCode ??
          _group?.code ??
          '',
      members: members,
      tripName: _group?.tripName,
    );

    _group = newGroup;
    _isOffline = false;
    notifyListeners();
    return newGroup;
  }

  /// Removes the current user from their Safety Circle (locally). Stops
  /// background refresh/location timers.
  void leaveGroup() {
    _stopAutoRefresh();
    _group = null;
    _alertMemberId = null;
    _isOffline = false;
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
  /// raises a local Safety Alert. Does not send any real notification and
  /// does not call the backend — this purely overlays the local group
  /// state shown on screen.
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
        .map(
          (m) => m.status == MemberSafetyStatus.danger
              ? m.copyWith(status: MemberSafetyStatus.safe)
              : m,
        )
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

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      unawaited(refreshGroupStatus());
      unawaited(_sendLocationIfDue());
    });
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Best-effort, throttled location send (respects the backend's
  /// `location_update_interval_seconds = 15`). Never prompts more than
  /// the standard system permission dialog, and silently does nothing if
  /// location isn't available — this runs in the background alongside
  /// the "Safety Monitoring: Active" info tile already shown on screen.
  Future<void> _sendLocationIfDue() async {
    final current = _group;
    if (current == null) return;

    final now = DateTime.now();
    if (_lastLocationSentAt != null &&
        now.difference(_lastLocationSentAt!) < _locationUpdateInterval) {
      return;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _lastLocationSentAt = now;

      await SafeguardApiClient.instance.updateLocation(
        userId: LocalIdentity.demoUserId,
        groupId: current.id,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
    } catch (_) {
      // Best-effort background update only — never surface this as a
      // screen-level error.
    }
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

  @override
  void dispose() {
    _stopAutoRefresh();
    super.dispose();
  }
}
