/// Centralized Supabase configuration for SafeGuard.
///
/// The Supabase project URL and anon/publishable key are not private
/// server secrets, but they are still kept in exactly one place rather
/// than scattered through the app. Provide them at build/run time with:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=your-anon-or-publishable-key
///
/// IMPORTANT: NEVER put the service_role key, database password,
/// blockchain private key, or any other private secret here or anywhere
/// else in the Flutter source code. The service_role key must never ship
/// inside a mobile app.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// True only when both a URL and anon key have been supplied at
  /// build/run time. When false, SafeGuard runs in Offline/Demo Mode
  /// instead of crashing — see [SupabaseService].
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}