import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Generic placeholder screen for destinations that are not yet built.
///
/// Used by the Home dashboard's bottom navigation and quick actions so
/// navigation feels complete without faking real features ahead of their
/// dedicated prompts. Each usage only supplies a title/subtitle/icon —
/// there is no screen-specific logic here.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    this.subtitle = 'This section will be available in a later step.',
    this.icon = Icons.construction_outlined,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(icon, color: AppColors.accent, size: 32),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
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
