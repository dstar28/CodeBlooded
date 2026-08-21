# SafeGuard — Your Travel Guardian

Flutter mobile app foundation (Prompt #1 only). No auth, GPS, SOS, groups,
insurance, admin, or AI features are implemented yet — this is theme +
entry point + a temporary starting screen.

## Setup

This bundle contains only `lib/`, `pubspec.yaml`, `analysis_options.yaml`,
and `.gitignore` — the Dart/config source, not the native Android/iOS/web
scaffolding. To run it:

```bash
flutter create --org com.safeguard --project-name safeguard safeguard_app
cd safeguard_app
# replace the generated lib/, pubspec.yaml, analysis_options.yaml with the ones in this bundle
flutter pub get
flutter analyze
flutter run
```

## Structure

```
lib/
  main.dart              # entry point, MaterialApp, temporary home
  theme/
    app_colors.dart       # centralized color palette
    app_theme.dart         # centralized Material 3 ThemeData
  screens/
    splash_screen.dart     # temporary "foundation ready" screen
  services/
    supabase_config.dart   # placeholder config, no real init yet
  widgets/                 # empty — reusable widgets land here later
  models/                  # empty — data models land here later
```

## Notes

- No secret keys are hard-coded. `SupabaseConfig` reads from
  `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
  at build time, and is unused until a later prompt wires up real auth.
- The `supabase_flutter` package was deliberately **not** added yet —
  it isn't used by anything in this prompt, so adding it now would
  violate the "no unnecessary dependencies" rule. Add it when the
  Supabase auth/database prompt is implemented.
- Dark navy background, deep blue cards, cyan/blue primary accent,
  red/pink reserved for emergency/danger states — all centralized in
  `theme/`, not scattered across widgets.
