import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'routes/app_routes.dart';
import 'services/supabase/supabase_service.dart';

Future<void> main() async {
  // Required because we await Supabase initialization before runApp().
  WidgetsFlutterBinding.ensureInitialized();

  // Never crashes: if credentials are missing or initialization fails,
  // SafeGuard proceeds in Offline/Demo Mode (see SupabaseService).
  await SupabaseService.initialize();

  runApp(const SafeGuardApp());
}

class SafeGuardApp extends StatelessWidget {
  const SafeGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeGuard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.initialRoute,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}