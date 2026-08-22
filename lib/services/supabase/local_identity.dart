/// Temporary local/demo identity used until real Supabase Auth is
/// connected. Real authentication is explicitly out of scope for
/// Prompt #12.
///
/// IMPORTANT: this is NOT an authenticated user and must never be
/// presented to the traveler as a signed-in account. It exists only so
/// rows written by this prototype can be scoped to "a" user id while the
/// repository/RLS foundation is being built. Row Level Security is
/// written against `auth.uid()`, so writes made under this demo id will
/// be rejected by Postgres once RLS is enabled until a real Supabase
/// Auth session replaces it — SafeGuard treats that rejection as a
/// normal "Unable to sync" backend error, not a crash.
class LocalIdentity {
  LocalIdentity._();

  /// Fixed demo/local user id, clearly namespaced so it's unmistakable
  /// in the database that this did not come from real authentication.
  static const String demoUserId = 'demo-local-user-safeguard';
}