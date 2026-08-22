import '../../models/emergency_contact.dart';
import 'backend_result.dart';
import 'local_identity.dart';
import 'supabase_service.dart';

/// Persistence for [EmergencyContact] records.
///
/// A user can only ever read/write their own contacts — enforced at the
/// database level via Row Level Security (see supabase/schema.sql), not
/// just by this repository always scoping to [LocalIdentity.demoUserId]
/// or a real signed-in user id.
class EmergencyContactRepository {
  EmergencyContactRepository._();
  static final EmergencyContactRepository instance =
      EmergencyContactRepository._();

  static const String _table = 'emergency_contacts';

  Map<String, dynamic> _toRow(EmergencyContact contact, {String? userId}) => {
        'id': contact.id,
        'user_id': userId ?? LocalIdentity.demoUserId,
        'name': contact.name,
        'phone': contact.phone,
        'relationship': contact.relationship,
        'email': contact.email,
        'is_primary': contact.isPrimary,
        'updated_at': DateTime.now().toIso8601String(),
      };

  Future<BackendResult<void>> saveContact(
    EmergencyContact contact, {
    String? userId,
  }) async {
    final client = SupabaseService.client;
    if (client == null) return BackendResult.offline();

    try {
      await client.from(_table).upsert(_toRow(contact, userId: userId));
      return BackendResult.success();
    } catch (error) {
      return BackendResult.failure(error.toString());
    }
  }

  Future<BackendResult<void>> deleteContact(String id) async {
    final client = SupabaseService.client;
    if (client == null) return BackendResult.offline();

    try {
      await client.from(_table).delete().eq('id', id);
      return BackendResult.success();
    } catch (error) {
      return BackendResult.failure(error.toString());
    }
  }

  Future<BackendResult<List<Map<String, dynamic>>>> fetchContacts({
    String? userId,
  }) async {
    final client = SupabaseService.client;
    if (client == null) return BackendResult.offline();

    try {
      final rows = await client
          .from(_table)
          .select()
          .eq('user_id', userId ?? LocalIdentity.demoUserId)
          .order('created_at', ascending: true);
      return BackendResult.success(List<Map<String, dynamic>>.from(rows));
    } catch (error) {
      return BackendResult.failure(error.toString());
    }
  }
}