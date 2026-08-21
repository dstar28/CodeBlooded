/// Placeholder configuration for future Supabase integration.
///
/// This class intentionally does NOT depend on the `supabase_flutter`
/// package yet — that dependency, along with real initialization and
/// auth logic, will be added in the prompt that actually implements
/// authentication.
///
/// Values must come from environment/build-time configuration
/// (e.g. `--dart-define=SUPABASE_URL=...`), never hard-coded secrets.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}