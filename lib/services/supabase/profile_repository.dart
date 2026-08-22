import 'local_identity.dart';
import 'supabase_service.dart';

/// Persistence for the demo/local profile row.
///
/// As of Prompt #12, Signup performs a best-effort, non-blocking attempt
/// to persist a demo profile (full name only) to Supabase — see
/// lib/screens/signup_screen.dart, which calls [ensureProfile] via
/// `unawaited(...)`. This must never fail or delay the signup UI, so
/// [ensureProfile] swallows any Supabase error internally and simply
/// no-ops when Supabase is unavailable, matching SafeGuard's existing
/// "offline never crashes" rule.
class ProfileRepository {
  ProfileRepository._();
  static final ProfileRepository instance = ProfileRepository._();

  static const String _table = 'profiles';

  /// Best-effort upsert of a demo profile row (full name only).
  /// Fire-and-forget by design — never throws, and safely no-ops when
  /// Supabase is unavailable.
  Future<void> ensureProfile({
    required String fullName,
    String? userId,
  }) async {
    final client = SupabaseService.client;
    if (client == null) return;

    try {
      await client.from(_table).upsert({
        'id': userId ?? LocalIdentity.demoUserId,
        'full_name': fullName,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Best-effort only — Signup must never fail because of this.
    }
  }
}
