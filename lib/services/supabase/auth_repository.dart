import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_result.dart';
import 'supabase_service.dart';

/// Thin wrapper around Supabase Auth for SafeGuard.
///
/// Reuses the single Supabase client exposed by [SupabaseService] — this
/// does not create a new Supabase client or introduce a different
/// authentication provider.
///
/// Session persistence ("Remember Me") is handled entirely by
/// `supabase_flutter` itself: every successful [signIn]/[signUp] writes
/// the resulting session (access + refresh token, never the password)
/// to the device's local storage automatically, and [Supabase.initialize]
/// (see SupabaseService.initialize, called once in main()) restores it
/// on the next app launch. Nothing here introduces a second persistence
/// mechanism — [hasValidSession]/[ensureFreshSession] only *read* that
/// existing session state.
class AuthRepository {
  AuthRepository._();
  static final AuthRepository instance = AuthRepository._();

  /// The session `supabase_flutter` already restored from local storage
  /// for this device, if any. Null when signed out or Supabase is
  /// unavailable.
  Session? get currentSession => SupabaseService.client?.auth.currentSession;

  /// True if a locally-persisted session exists and its access token has
  /// not expired. Does NOT attempt a network refresh — use
  /// [ensureFreshSession] at app startup for that.
  bool get hasValidSession {
    final session = currentSession;
    return session != null && !session.isExpired;
  }

  /// Call once at app startup (see SplashScreen) to decide whether to
  /// land on Home or Login.
  ///
  /// If a persisted session exists but its access token has expired,
  /// this attempts one silent refresh using the stored refresh token
  /// (still no password involved). If that also fails — refresh token
  /// expired/revoked, or Supabase unreachable — the invalid local
  /// session is cleared via [signOut] so the app doesn't keep retrying
  /// a dead session, and this returns false.
  Future<bool> ensureFreshSession() async {
    final client = SupabaseService.client;
    if (client == null) return false;

    final session = client.auth.currentSession;
    if (session == null) return false;
    if (!session.isExpired) return true;

    try {
      await client.auth.refreshSession();
      return client.auth.currentSession != null &&
          !client.auth.currentSession!.isExpired;
    } catch (_) {
      await signOut();
      return false;
    }
  }

  /// Signs in with email + password via Supabase Auth
  /// (`GoTrueClient.signInWithPassword`). On success, `supabase_flutter`
  /// persists the session locally on its own — no separate "remember me"
  /// storage is written here, and the password itself is never stored,
  /// only ever sent over the network for this one request.
  Future<BackendResult<Session>> signIn({
    required String email,
    required String password,
  }) async {
    final client = SupabaseService.client;
    if (client == null) return BackendResult.offline();

    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final session = response.session;
      if (session == null) {
        return BackendResult.failure(
          'We couldn\'t sign you in. Please check your email and '
          'password and try again.',
        );
      }
      return BackendResult.success(session);
    } on AuthException catch (_) {
      return BackendResult.failure(
        'Incorrect email or password. Please try again.',
      );
    } catch (_) {
      return BackendResult.failure(
        'Something went wrong. Please try again in a moment.',
      );
    }
  }

  /// Creates a real Supabase Auth account via
  /// `GoTrueClient.signUp`. Used alongside the existing
  /// [ProfileRepository.ensureProfile] call in Register — this only adds
  /// the auth identity itself, it does not change how the profile row is
  /// written.
  Future<BackendResult<Session>> signUp({
    required String email,
    required String password,
  }) async {
    final client = SupabaseService.client;
    if (client == null) return BackendResult.offline();

    try {
      final response = await client.auth.signUp(
        email: email,
        password: password,
      );
      final session = response.session;
      if (session == null) {
        // Email confirmation required before a session exists — this is
        // a normal Supabase Auth outcome, not an error.
        return BackendResult.failure(
          'Account created. Please check your email to confirm before '
          'logging in.',
        );
      }
      return BackendResult.success(session);
    } on AuthException catch (error) {
      return BackendResult.failure(
        error.message.isNotEmpty
            ? error.message
            : 'We couldn\'t create your account. Please try again.',
      );
    } catch (_) {
      return BackendResult.failure(
        'Something went wrong. Please try again in a moment.',
      );
    }
  }

  /// Signs out of Supabase AND clears the locally persisted session —
  /// `GoTrueClient.signOut()` does both in one call, so there is no
  /// separate local-storage-clearing step to remember to keep in sync.
  Future<void> signOut() async {
    final client = SupabaseService.client;
    if (client == null) return;
    try {
      await client.auth.signOut();
    } catch (_) {
      // Best-effort — if this fails (e.g. already signed out, offline),
      // there is no meaningful recovery action for the caller to take.
    }
  }

  /// Sends a password-reset email via Supabase Auth
  /// (`GoTrueClient.resetPasswordForEmail`).
  ///
  /// Never throws: returns [BackendResult.offline] when Supabase isn't
  /// configured/reachable (matching SafeGuard's existing "offline never
  /// crashes" rule), and [BackendResult.failure] with a user-friendly
  /// message on any Supabase/network error — technical exception detail
  /// is never surfaced to the UI.
  Future<BackendResult<void>> sendPasswordResetEmail(String email) async {
    final client = SupabaseService.client;
    if (client == null) return BackendResult.offline();

    try {
      await client.auth.resetPasswordForEmail(email);
      return BackendResult.success();
    } on AuthException catch (_) {
      return BackendResult.failure(
        'We couldn\'t send the reset link. Please check the email '
        'address and try again.',
      );
    } catch (_) {
      return BackendResult.failure(
        'Something went wrong. Please try again in a moment.',
      );
    }
  }
}
