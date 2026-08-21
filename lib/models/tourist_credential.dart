/// Digital Tourist ID credential model (Prompt #10).
///
/// This model intentionally holds only what the app needs to *display* a
/// tourist's credential and what a verifier needs to check its trust
/// status. It never stores real government identifiers:
///
/// * No passport number, passport image, or Aadhaar number.
/// * No phone number, home address, or medical information.
/// * No live GPS or GPS history.
///
/// [credentialHash] is a privacy-preserving proof reference (a generated
/// commitment string), not a hash of predictable personal data such as a
/// passport or Aadhaar number. The blockchain trust layer only ever sees
/// [credentialId], [credentialHash], [issuerId], [status], and timestamps
/// — never the tourist's name or any other personal detail.
library;

/// Whether the traveler holding this credential is a domestic or foreign
/// tourist. Foreign tourist support here is just a type indicator — no
/// passport collection/upload flow exists yet.
enum TouristType {
  domestic,
  foreign;

  String get label {
    switch (this) {
      case TouristType.domestic:
        return 'Domestic Tourist';
      case TouristType.foreign:
        return 'Foreign Tourist';
    }
  }
}

/// Credential lifecycle status.
///
/// Revocation is a demo-only concept for this prototype: revoking a
/// credential never deletes its record, it only flips [status] and stamps
/// [TouristCredential.revokedAt] — mirroring how a real trust registry
/// keeps revocation auditable rather than destroying history.
enum CredentialStatus {
  active,
  revoked;

  String get label {
    switch (this) {
      case CredentialStatus.active:
        return 'Active';
      case CredentialStatus.revoked:
        return 'Revoked';
    }
  }
}

class TouristCredential {
  const TouristCredential({
    required this.touristName,
    required this.touristType,
    required this.credentialId,
    required this.credentialHash,
    required this.issuerId,
    required this.issuerName,
    required this.status,
    required this.createdAt,
    this.revokedAt,
  });

  /// Display-only name. Kept locally on-device for this prototype; never
  /// sent to the blockchain trust layer.
  final String touristName;

  final TouristType touristType;

  /// Public-safe reference shown on the card and encoded in the QR
  /// representation, e.g. "SG-CRED-7F3K9A".
  final String credentialId;

  /// Generated credential/proof commitment. This is NOT a simple hash of
  /// a passport/Aadhaar number — see [MockBlockchainService] and
  /// [CredentialService] for how it's produced.
  final String credentialHash;

  final String issuerId;
  final String issuerName;

  final CredentialStatus status;
  final DateTime createdAt;
  final DateTime? revokedAt;

  TouristCredential copyWith({
    CredentialStatus? status,
    DateTime? revokedAt,
    bool clearRevokedAt = false,
  }) {
    return TouristCredential(
      touristName: touristName,
      touristType: touristType,
      credentialId: credentialId,
      credentialHash: credentialHash,
      issuerId: issuerId,
      issuerName: issuerName,
      status: status ?? this.status,
      createdAt: createdAt,
      revokedAt: clearRevokedAt ? null : (revokedAt ?? this.revokedAt),
    );
  }
}
