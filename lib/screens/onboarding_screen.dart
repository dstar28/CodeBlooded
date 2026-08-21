import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../theme/app_colors.dart';

/// Static content for a single onboarding page.
class _OnboardingPageData {
  final IconData primaryIcon;
  final IconData badgeIcon;
  final String title;
  final String description;

  const _OnboardingPageData({
    required this.primaryIcon,
    required this.badgeIcon,
    required this.title,
    required this.description,
  });
}

const List<_OnboardingPageData> _kOnboardingPages = [
  _OnboardingPageData(
    primaryIcon: Icons.map_rounded,
    badgeIcon: Icons.verified_rounded,
    title: 'Travel With Confidence',
    description:
        'Plan your journey and stay aware of important safety conditions along the way.',
  ),
  _OnboardingPageData(
    primaryIcon: Icons.groups_rounded,
    badgeIcon: Icons.shield_rounded,
    title: 'Stay Connected',
    description:
        'Keep your trusted travel group and emergency contacts informed when it matters.',
  ),
  _OnboardingPageData(
    primaryIcon: Icons.sos_rounded,
    badgeIcon: Icons.bolt_rounded,
    title: 'Get Help When You Need It',
    description:
        'Access emergency assistance quickly and share important safety information when required.',
  ),
];

/// Onboarding flow shown after Splash and before Login.
///
/// Three swipeable pages introducing SafeGuard's future capabilities at a
/// concept level only — no real map, group, or SOS functionality here.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool get _isLastPage => _currentPage == _kOnboardingPages.length - 1;

  void _goToLogin() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  void _onPrimaryPressed() {
    if (_isLastPage) {
      _goToLogin();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 20, 0),
                child: TextButton(
                  onPressed: _goToLogin,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _kOnboardingPages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  return _OnboardingPage(data: _kOnboardingPages[index]);
                },
              ),
            ),
            _PageIndicator(
              currentPage: _currentPage,
              pageCount: _kOnboardingPages.length,
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _onPrimaryPressed,
                  child: Text(_isLastPage ? 'Get Started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;

  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double illustrationSize = (width * 0.55).clamp(180.0, 260.0).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Illustration(
                    primaryIcon: data.primaryIcon,
                    badgeIcon: data.badgeIcon,
                    size: illustrationSize,
                  ),
                  const SizedBox(height: 40),
                  Text(
                    data.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    data.description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A concept illustration: a soft radar-style circle with the page's
/// primary icon and a small accent badge. Built entirely from Flutter
/// primitives — no external image assets.
class _Illustration extends StatelessWidget {
  final IconData primaryIcon;
  final IconData badgeIcon;
  final double size;

  const _Illustration({
    required this.primaryIcon,
    required this.badgeIcon,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.border, width: 1),
            ),
          ),
          Container(
            width: size * 0.74,
            height: size * 0.74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accent.withOpacity(0.35),
                width: 1,
              ),
            ),
          ),
          Icon(primaryIcon, size: size * 0.32, color: AppColors.accent),
          Positioned(
            top: size * 0.08,
            right: size * 0.08,
            child: Container(
              width: size * 0.18,
              height: size * 0.18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.background,
                border: Border.all(color: AppColors.accent, width: 1.5),
              ),
              child: Icon(
                badgeIcon,
                size: size * 0.1,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact animated dot indicator using the SafeGuard accent color.
class _PageIndicator extends StatelessWidget {
  final int currentPage;
  final int pageCount;

  const _PageIndicator({required this.currentPage, required this.pageCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        final bool isActive = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive ? AppColors.accent : AppColors.surfaceVariant,
          ),
        );
      }),
    );
  }
}
