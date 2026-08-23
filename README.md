# SafeGuard — "Remember Me" / Persistent Session

## Inspection findings (before implementing)
- **`lib/main.dart`** — already awaits `SupabaseService.initialize()` before `runApp()`. Untouched; this is exactly where session recovery needs to happen, and it already does.
- **`lib/screens/login_screen.dart`** — the real, routed login screen (there's also an orphaned, unused duplicate at `lib/routes/login_screen.dart` — not touched, it's dead code, nothing imports it). Login was **mock-only**: any non-empty input navigated straight to Home, no real Supabase Auth call. Register only wrote a profile row, never created a real Supabase Auth user. So there was no real session to "remember" yet.
- **`lib/routes/app_routes.dart`** — `initialRoute` was hardcoded to `login`, with a comment explicitly forbidding auto-navigation to any other screen. `SplashScreen` and `OnboardingScreen` existed as files but were **never wired into `onGenerateRoute`** — dead code.
- **Existing Supabase service** — `SupabaseService` (single client, `SupabaseService.client`) and `AuthRepository` (already existed, password-reset only). `supabase_flutter` (`^2.6.0`) was already a dependency and, by default, persists the Supabase session (access + refresh token) to the device's local storage automatically and restores it during `Supabase.initialize()`.
- **Existing auth/session handling** — none beyond password-reset. No sign-in, no sign-up, no logout anywhere in the app (the only `Icons.logout` usage found was unrelated — "Leave Safety Circle").
- Requirement 6 (no Google/Apple/Phone/Remember-Me toggle) was **already true** — the login screen only ever had Login / Register / Forgot Password. Nothing needed removing there.

## What "session storage" means here
I did **not** build a custom secure-storage layer. `supabase_flutter` already is SafeGuard's session persistence mechanism — every `signInWithPassword`/`signUp` call writes the resulting session to local storage on its own, and `Supabase.initialize()` restores it on next launch. Building a second storage mechanism (e.g. `flutter_secure_storage`) would violate "don't create a second Supabase client / second system." I only added code that *reads* that existing state (`currentSession`, `hasValidSession`, `ensureFreshSession`) and *triggers* it (`signIn`, `signUp`, `signOut`).

## Implementation

### 1 & 2 — Persist session after login, never store the password
`AuthRepository.signIn()` / `.signUp()` call Supabase Auth's `signInWithPassword` / `signUp`. The password is sent once over the network for that call and never written to disk anywhere in this code — only the resulting session token is persisted, by `supabase_flutter` itself.

### 3 — Startup session check
`SplashScreen` (previously dead code, unconditionally routing to a non-existent Onboarding case) now calls `AuthRepository.ensureFreshSession()`:
- valid session → `pushReplacementNamed(AppRoutes.home)`
- none / expired / refresh failed → `pushReplacementNamed(AppRoutes.login)`

`AppRoutes.initialRoute` now points at `splash` instead of `login` directly, and a `splash` case was added to `onGenerateRoute` (it didn't exist before).

### 4 — Logout
No logout entry point existed anywhere in the app, so I added one: a logout icon in the Home screen's existing header icon row (next to the existing notification/profile icons — same pattern, no redesign). It confirms, then:
```dart
await AuthRepository.instance.signOut();   // Supabase signOut() also clears local storage
Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
```

### 5 — Expired/invalid session
Handled inside `ensureFreshSession()`: if the persisted access token is expired, it tries one silent `refreshSession()`. If that fails (refresh token dead/revoked, offline), it calls `signOut()` to clear the invalid local session, then Splash routes to Login.

### 6 — Login screen options
No changes needed — confirmed only Login / Register / Forgot Password exist, and no "Remember Me" checkbox was added (persistence is automatic and silent, per the requirement).

## Files modified
| File | Change |
|---|---|
| `lib/services/supabase/auth_repository.dart` | Added `signIn`, `signUp`, `signOut`, `currentSession`, `hasValidSession`, `ensureFreshSession`. Existing `sendPasswordResetEmail` untouched. |
| `lib/screens/login_screen.dart` | `_handleLogin`/`_handleCreateAccount` now call real Supabase Auth when available, with the previous mock behavior preserved as an Offline/Demo-Mode fallback (unchanged when Supabase isn't configured). Added inline error text + loading state to both buttons. No UI options added or removed. |
| `lib/screens/splash_screen.dart` | Repurposed from "always navigate to Onboarding after 2.2s" (unreachable dead code) into the session-check gate described above. |
| `lib/routes/app_routes.dart` | `initialRoute` → `splash`; added the missing `splash` route case. |
| `lib/screens/home_screen.dart` | Added one logout icon button + confirmation dialog + sign-out-and-navigate handler. Nothing else on this screen changed. |

**Not modified:** `lib/main.dart` (already correct — awaits Supabase init before `runApp`), `lib/routes/login_screen.dart` (unused duplicate, left alone), `lib/services/supabase/supabase_service.dart` (single client, reused as-is), `lib/services/supabase/profile_repository.dart` (reused its existing optional `userId` param, not edited), any other screen.

## Session storage mechanism used
`supabase_flutter`'s built-in local-storage-backed session persistence (part of the Supabase client already initialized once in `main.dart`) — not a second/custom storage layer.

## Startup session check location
`lib/screens/splash_screen.dart`, via `AuthRepository.ensureFreshSession()`, reached as `AppRoutes.initialRoute`.

## Logout behavior
Home screen → logout icon → confirm dialog → `AuthRepository.signOut()` (Supabase sign-out + local session clear in one call) → `pushNamedAndRemoveUntil(AppRoutes.login, ...)` clears the entire authenticated back stack so the back button can't return to Home.

## Commands to test
```bash
flutter pub get      # supabase_flutter was already a dependency — no new packages added
flutter analyze       # verify no lint/type errors after merging these files in
flutter run --dart-define=SAFEGUARD_SUPABASE_URL=... --dart-define=SAFEGUARD_SUPABASE_ANON_KEY=...
```
Manual test matrix:
1. Register a new account (online) → confirm success dialog → switch to Login → sign in → lands on Home.
2. Fully close and relaunch the app → should skip Login and land directly on Home (session restored).
3. Tap the logout icon on Home → confirm → should land on Login; relaunching the app should now show Login, not Home.
4. To test expiry handling: manually revoke/expire the session from the Supabase dashboard (or wait out the access-token TTL with the refresh token also invalidated), then relaunch — should clear local state and show Login.

I could not run `flutter analyze`/`flutter run` myself in this sandbox (no Flutter SDK / network here), so this was verified by careful manual review and brace/paren balance checks on every edited file — please run the commands above before shipping.
