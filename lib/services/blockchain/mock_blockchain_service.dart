import 'blockchain_trust_service.dart';
import '../../models/tourist_credential.dart';

/// Prototype Trust Registry (a.k.a. "Blockchain Demo Registry").
///
/// IMPORTANT — this is NOT a real blockchain. It is a local, in-memory
/// stand-in for the conceptual `TouristCredentialRegistry` chaincode
/// described in the SIH prompt:
///
/// ```
/// registerCredential()
/// verifyCredential()
/// revokeCredential()
/// getCredentialStatus()
/// ```
///
/// No transaction is broadcast anywhere, there is no consensus, and there
/// is no wallet or private key involved. The UI must always present this
/// as a "Prototype Trust Registry" / "Blockchain Demo Registry" and must
/// never claim a real distributed ledger was used.
///
/// The architecture is written so this class can later be swapped for a
/// real adapter (e.g. `FabricBlockchainService`) purely by providing a
/// different [BlockchainTrustService] implementation — no UI or
/// [CredentialService] changes required. When that happens, transactions
/// must be signed/submitted by a secure backend; a Flutter client should
/// never hold blockchain private keys or admin credentials.
class MockBlockchainService implements BlockchainTrustService {
  final Map<String, CredentialRegistryRecord> _registry = {};

  /// Simulated network/consensus latency so the UI can show a realistic
  /// "checking..." state. Not representative of any real chain's timing.
  static const _simulatedLatency = Duration(milliseconds: 550);

  @override
  Future<CredentialRegistryRecord> registerCredential({
    required String credentialId,
    required String credentialHash,
    required String issuerId,
  }) async {
    await Future.delayed(_simulatedLatency);

    final record = CredentialRegistryRecord(
      credentialId: credentialId,
      credentialHash: credentialHash,
      issuerId: issuerId,
      status: CredentialStatus.active,
      createdAt: DateTime.now(),
    );
    _registry[credentialId] = record;
    return record;
  }

  @override
  Future<CredentialVerificationResult> verifyCredential({
    required String credentialId,
    required String credentialHash,
  }) async {
    await Future.delayed(_simulatedLatency);

    final record = _registry[credentialId];
    final now = DateTime.now();

    if (record == null) {
      return CredentialVerificationResult(
        credentialId: credentialId,
        registryMatched: false,
        integrityValid: false,
        status: CredentialStatus.revoked,
        checkedAt: now,
      );
    }

    final integrityValid = record.credentialHash == credentialHash;

    return CredentialVerificationResult(
      credentialId: credentialId,
      registryMatched: true,
      integrityValid: integrityValid,
      status: record.status,
      checkedAt: now,
    );
  }

  @override
  Future<CredentialRegistryRecord> revokeCredential(
    String credentialId,
  ) async {
    await Future.delayed(_simulatedLatency);

    final existing = _registry[credentialId];
    if (existing == null) {
      throw StateError(
        'Cannot revoke unknown credential: $credentialId',
      );
    }

    final revoked = existing.copyWith(
      status: CredentialStatus.revoked,
      revokedAt: DateTime.now(),
    );
    _registry[credentialId] = revoked;
    return revoked;
  }

  @override
  Future<CredentialRegistryRecord> reactivateCredential(
    String credentialId,
  ) async {
    await Future.delayed(_simulatedLatency);

    final existing = _registry[credentialId];
    if (existing == null) {
      throw StateError(
        'Cannot reactivate unknown credential: $credentialId',
      );
    }

    final reactivated = existing.copyWith(
      status: CredentialStatus.active,
      clearRevokedAt: true,
    );
    _registry[credentialId] = reactivated;
    return reactivated;
  }

  @override
  Future<CredentialRegistryRecord?> getCredentialStatus(
    String credentialId,
  ) async {
    await Future.delayed(_simulatedLatency);
    return _registry[credentialId];
  }
}
