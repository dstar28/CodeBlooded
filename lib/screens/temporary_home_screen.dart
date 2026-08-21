import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Temporary starting screen for the SafeGuard project foundation.
///
/// This screen is only a placeholder confirming the app, theme, and
/// navigation structure are wired up correctly. It will be replaced by
/// the real Splash/Onboarding/Home flow in later prompts.
class TemporaryHomeScreen extends StatelessWidget {
  const TemporaryHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppColors.accent,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                Text('SafeGuard', style: textTheme.displayLarge),
                const SizedBox(height: 8),
                Text('Your Travel Guardian', style: textTheme.bodyLarge),
                const SizedBox(height: 32),
                Text(
                  'Project foundation ready',
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}