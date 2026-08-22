import '../../models/tourist_credential.dart';
import 'backend_result.dart';
import 'local_identity.dart';
import 'supabase_service.dart';

/// Persistence for the application-side Digital Tourist ID record.
///
/// Only the non-sensitive subset already shared with the blockchain
/// trust layer is stored here — [TouristCredential.touristName] and
/// [TouristCredential.touristType] intentionally stay off this table.
/// This mirrors the existing separation between [CredentialService] and
/// `BlockchainTrustService`: Supabase is the application database, the
/// blockchain stays a separate (still-unimplemented-in-this-prompt)
/// trust layer, and this repository never talks to the blockchain
/// adapter directly.
class TouristCredentialRepository {
  TouristCredentialRepository._();
  static final TouristCredentialRepository instance =
      TouristCredentialRepository._();

  static const String _table = 'tourist_credentials';

  Future<BackendResult<void>> saveCredential(
    TouristCredential credential, {
    String? userId,
  }) async {
    final client = SupabaseService.client;
    if (client == null) return BackendResult.offline();

    try {
      await client.from(_table).upsert(
        {
          'user_id': userId ?? LocalIdentity.demoUserId,
          'credential_id': credential.credentialId,
          'credential_hash': credential.credentialHash,
          'issuer_id': credential.issuerId,
          'status': credential.status.name,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'credential_id',
      );
      return BackendResult.success();
    } catch (error) {
      return BackendResult.failure(error.toString());
    }
  }
}