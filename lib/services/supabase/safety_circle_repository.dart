import 'backend_result.dart';
import 'local_identity.dart';
import 'supabase_service.dart';

/// Persistence FOUNDATION for Safety Circles (Prompt #12 scope).
///
/// This only records that a circle exists and who belongs to it — it
/// does not implement real-time location sync, push notifications, or
/// any continuous GPS storage. [SafetyCircleStore] remains the local
/// source of truth for the current session; this repository just gives a
/// later prompt something real to build group sync on top of.
class SafetyCircleRepository {
  SafetyCircleRepository._();
  static final SafetyCircleRepository instance = SafetyCircleRepository._();

  static const String _circlesTable = 'safety_circles';
  static const String _membersTable = 'safety_circle_members';

  Future<BackendResult<void>> saveCircle({
    required String id,
    required String name,
    required String inviteCode,
    String? createdBy,
  }) async {
    final client = SupabaseService.client;
    if (client == null) return BackendResult.offline();

    try {
      await client.from(_circlesTable).upsert({
        'id': id,
        'name': name,
        'invite_code': inviteCode,
        'created_by': createdBy ?? LocalIdentity.demoUserId,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return BackendResult.success();
    } catch (error) {
      return BackendResult.failure(error.toString());
    }
  }

  Future<BackendResult<void>> addMember({
    required String circleId,
    String? userId,
    String role = 'member',
    String status = 'active',
  }) async {
    final client = SupabaseService.client;
    if (client == null) return BackendResult.offline();

    try {
      await client.from(_membersTable).upsert({
        'circle_id': circleId,
        'user_id': userId ?? LocalIdentity.demoUserId,
        'role': role,
        'status': status,
      });
      return BackendResult.success();
    } catch (error) {
      return BackendResult.failure(error.toString());
    }
  }
}