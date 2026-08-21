/// A single trusted emergency contact (Prompt #8).
///
/// This is local/mock in-memory data only — nothing here is persisted to
/// Supabase yet, and adding a contact never sends a real SMS, call, or
/// notification of any kind.
class EmergencyContact {
  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
    this.email = '',
    this.isPrimary = false,
  });

  final String id;
  final String name;
  final String phone;
  final String relationship;
  final String email;
  final bool isPrimary;

  EmergencyContact copyWith({
    String? name,
    String? phone,
    String? relationship,
    String? email,
    bool? isPrimary,
  }) {
    return EmergencyContact(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
      email: email ?? this.email,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}
