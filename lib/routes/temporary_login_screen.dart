import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Minimal placeholder Login screen.
///
/// Exists only so Onboarding → Login navigation can be verified in this
/// prompt. Real authentication (Supabase, fields, validation) will replace
/// this in a later prompt.
class TemporaryLoginScreen extends StatelessWidget {
  const TemporaryLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 48,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 20),
                Text(
                  'Login',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'SafeGuard authentication will be added in a later prompt.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
