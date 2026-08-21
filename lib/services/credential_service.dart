import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/tourist_credential.dart';
import 'blockchain/blockchain_trust_service.dart';
import 'blockchain/mock_blockchain_service.dart';

/// Credential Service — the single place the Digital Tourist ID UI talks
/// to for issuing, verifying, and revoking a credential.
///
/// Architecture (per Prompt #10):
///
/// ```
/// Digital Tourist ID (UI)
///        |
/// CredentialService              <- this file
///        |
/// BlockchainTrustService (interface)
///        |
/// MockBlockchainService          <- prototype trust registry
/// ```
///
/// [CredentialService] owns the tourist-facing [TouristCredential]
/// (including the display-only name/type), while only the non-sensitive
/// subset (credential ID, credential hash, issuer ID, status, timestamps)
/// is ever passed down to [BlockchainTrustService]. Mirrors the lightweight
/// singleton `ChangeNotifier` pattern already used by the other stores in
/// this app (see `EmergencyContactsStore`, `TripStore`) rather than
/// introducing a new state-management dependency.
///
/// This is mock/local data for now — there is no Supabase sync and no
/// real tourist profile collection here.
class CredentialService extends ChangeNotifier {
  CredentialService._internal({BlockchainTrustService? blockchainService})
      : _blockchain = blockchainService ?? MockBlockchainService();

  static final CredentialService instance = CredentialService._internal();

  final BlockchainTrustService _blockchain;

  static const String _issuerId = 'SAFEGUARD-CRED-SERVICE';
  static const String _issuerName = 'SafeGuard Credential Service';

  TouristCredential? _credential;
  bool _isIssuing = false;

  TouristCredential? get credential => _credential;
  bool get isIssuing => _isIssuing;

  /// Issues the demo credential the first time this is called, and
  /// registers its proof with the blockchain trust layer. Safe to call
  /// repeatedly — subsequent calls are a no-op once a credential exists.
  Future<void> ensureIssued() async {
    if (_credential != null || _isIssuing) return;

    _isIssuing = true;
    notifyListeners();

    final credentialId = _generateCredentialId();
    final credentialHash = _generateCredentialHash(credentialId);

    await _blockchain.registerCredential(
      credentialId: credentialId,
      credentialHash: credentialHash,
      issuerId: _issuerId,
    );

    _credential = TouristCredential(
      touristName: 'Aarav Sharma',
      touristType: TouristType.domestic,
      credentialId: credentialId,
      credentialHash: credentialHash,
      issuerId: _issuerId,
      issuerName: _issuerName,
      status: CredentialStatus.active,
      createdAt: DateTime.now(),
    );

    _isIssuing = false;
    notifyListeners();
  }

  /// Asks the trust registry to check this credential's current standing.
  /// Returns null if no credential has been issued yet.
  Future<CredentialVerificationResult?> verifyCredential() async {
    final current = _credential;
    if (current == null) return null;

    return _blockchain.verifyCredential(
      credentialId: current.credentialId,
      credentialHash: current.credentialHash,
    );
  }

  /// Demo Controls action: flips the credential to revoked, both locally
  /// and in the trust registry. Never deletes the credential record.
  Future<void> revokeCredential() async {
    final current = _credential;
    if (current == null) return;

    final record = await _blockchain.revokeCredential(current.credentialId);
    _credential = current.copyWith(
      status: record.status,
      revokedAt: record.revokedAt,
    );
    notifyListeners();
  }

  /// Demo Controls action: restores a revoked credential back to active,
  /// so the flow can be exercised repeatedly in this prototype.
  Future<void> reactivateCredential() async {
    final current = _credential;
    if (current == null) return;

    final record = await _blockchain.reactivateCredential(
      current.credentialId,
    );
    _credential = current.copyWith(
      status: record.status,
      clearRevokedAt: true,
    );
    notifyListeners();
  }

  String _generateCredentialId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final suffix =
        List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
    return 'SG-CRED-$suffix';
  }

  /// Generates a privacy-preserving credential proof/commitment.
  ///
  /// This is NOT a hash of the tourist's passport/Aadhaar number or any
  /// other predictable personal data — it never receives that data in the
  /// first place. It's a randomly generated commitment tied only to the
  /// credential ID, standing in for what a real issuance backend would
  /// produce as a signed credential hash. A production system would
  /// generate this server-side, from a salted credential payload, using a
  /// proper cryptographic hash — never on-device from raw identifiers.
  String _generateCredentialHash(String credentialId) {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
