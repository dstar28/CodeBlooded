import '../../models/tourist_credential.dart';

/// A conceptual on-chain (or trust-registry) record for a credential.
///
/// This is deliberately the ONLY shape of data that ever crosses into the
/// blockchain trust layer. It contains no tourist-identifying information
/// — no name, no passport/Aadhaar number, no contact details, no
/// location. Compare with [TouristCredential], which additionally carries
/// display-only fields that stay off-chain.
class CredentialRegistryRecord {
  const CredentialRegistryRecord({
    required this.credentialId,
    required this.credentialHash,
    required this.issuerId,
    required this.status,
    required this.createdAt,
    this.revokedAt,
  });

  final String credentialId;
  final String credentialHash;
  final String issuerId;
  final CredentialStatus status;
  final DateTime createdAt;
  final DateTime? revokedAt;

  CredentialRegistryRecord copyWith({
    CredentialStatus? status,
    DateTime? revokedAt,
    bool clearRevokedAt = false,
  }) {
    return CredentialRegistryRecord(
      credentialId: credentialId,
      credentialHash: credentialHash,
      issuerId: issuerId,
      status: status ?? this.status,
      createdAt: createdAt,
      revokedAt: clearRevokedAt ? null : (revokedAt ?? this.revokedAt),
    );
  }
}

/// Result of asking the trust layer to verify a credential.
///
/// Deliberately worded in technically-accurate terms: this confirms the
/// credential's registry entry is present, unmodified, and not revoked.
/// It does NOT confirm the tourist's real-world identity, since no
/// government issuer is integrated in this prototype.
class CredentialVerificationResult {
  const CredentialVerificationResult({
    required this.credentialId,
    required this.registryMatched,
    required this.integrityValid,
    required this.status,
    required this.checkedAt,
  });

  final String credentialId;

  /// Whether a registry entry with this credential ID was found at all.
  final bool registryMatched;

  /// Whether the stored hash matches what was presented — i.e. the
  /// credential has not been altered since registration.
  final bool integrityValid;

  final CredentialStatus status;
  final DateTime checkedAt;

  /// True only when the registry entry exists, its integrity checks out,
  /// and it has not been revoked.
  bool get isValid =>
      registryMatched && integrityValid && status == CredentialStatus.active;
}

/// Abstraction for the blockchain trust layer.
///
/// The Digital Tourist ID feature talks to this interface only — never to
/// a concrete blockchain SDK directly. That keeps the UI and
/// [CredentialService] layer decoupled from whichever registry
/// implementation is actually running underneath.
///
/// Today, [MockBlockchainService] is the only adapter and is clearly a
/// local prototype trust registry, not a real distributed ledger. A real
/// deployment would add another adapter (e.g. a Hyperledger Fabric
/// adapter talking to a secure backend) without changing this interface
/// or any UI code.
abstract class BlockchainTrustService {
  /// Registers a new credential's proof in the trust registry.
  ///
  /// Only [credentialId], [credentialHash], and [issuerId] are recorded —
  /// no personal tourist data is ever passed in here.
  Future<CredentialRegistryRecord> registerCredential({
    required String credentialId,
    required String credentialHash,
    required String issuerId,
  });

  /// Checks whether [credentialId]/[credentialHash] correspond to a
  /// registered, unaltered, non-revoked credential.
  Future<CredentialVerificationResult> verifyCredential({
    required String credentialId,
    required String credentialHash,
  });

  /// Marks a credential as revoked. The registry entry is kept (auditable
  /// history), only its status and revocation timestamp change.
  Future<CredentialRegistryRecord> revokeCredential(String credentialId);

  /// Demo-only counterpart to [revokeCredential], restoring a credential to
  /// active status. Included purely so this prototype's status can be
  /// exercised end-to-end without restarting the app; a production
  /// registry would not expose an unrestricted "un-revoke".
  Future<CredentialRegistryRecord> reactivateCredential(String credentialId);

  /// Looks up the current registry record for a credential, if any.
  Future<CredentialRegistryRecord?> getCredentialStatus(String credentialId);
}
