import 'dart:async';

import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../services/supabase/auth_repository.dart';
import '../theme/app_colors.dart';

/// Splash / session-gate screen shown on app launch.
///
/// Displays the SafeGuard brand mark with a short fade + scale entrance
/// animation, then checks for a valid, locally-persisted Supabase Auth
/// session ("Remember Me") via [AuthRepository.ensureFreshSession] and
/// routes accordingly:
///   - valid session found  -> Home (no login prompt)
///   - none/expired/invalid -> Login (any invalid local session is
///     cleared as part of that check, see AuthRepository)
///
/// This replaces the previous unconditional "always go to Onboarding"
/// behavior — Onboarding was never actually reachable before (this
/// screen wasn't wired into initialRoute), so no existing navigation
/// path is being broken.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  // Minimum time the brand mark stays on screen, so the session check
  // (which is often near-instant) never reads as a flicker.
  static const Duration _minimumDisplay = Duration(milliseconds: 900);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();

    unawaited(_checkSessionAndNavigate());
  }

  Future<void> _checkSessionAndNavigate() async {
    final stopwatch = Stopwatch()..start();

    final hasValidSession = await AuthRepository.instance.ensureFreshSession();

    final remaining = _minimumDisplay - stopwatch.elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      hasValidSession ? AppRoutes.home : AppRoutes.login,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double markSize = (width * 0.32).clamp(96.0, 160.0).toDouble();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ShieldMark(size: markSize),
                    const SizedBox(height: 28),
                    Text(
                      'SafeGuard',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            letterSpacing: 0.5,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your Travel Guardian',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A simple shield mark built purely from Flutter primitives — no external
/// image assets required.
class _ShieldMark extends StatelessWidget {
  final double size;

  const _ShieldMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.35),
            blurRadius: 32,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.shield_rounded,
          size: size * 0.52,
          color: AppColors.accent,
        ),
      ),
    );
  }
}
