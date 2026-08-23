import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../routes/app_routes.dart';
import '../services/supabase/profile_repository.dart';

/// Combined authentication screen for SafeGuard: Login + Register behind a
/// single segmented toggle, matching the simplified SAFEGUARD auth design.
///
/// Login authentication here is MOCK ONLY: any non-empty, valid-looking
/// email/mobile and non-empty password proceeds to Home. No real auth
/// tokens are issued. Registration performs the same best-effort,
/// non-blocking Supabase profile persistence that previously lived in
/// SignupScreen (see ProfileRepository.ensureProfile) — that integration
/// is preserved unchanged.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;

  // Login form state.
  final _loginFormKey = GlobalKey<FormState>();
  final _loginIdController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _obscureLoginPassword = true;

  // Register form state.
  final _registerFormKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureRegisterPassword = true;
  bool _obscureConfirmPassword = true;

  static final RegExp _emailPattern =
      RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  /// Local field styling only (does not touch the app-wide theme), so
  /// unrelated screens using TextFormField are unaffected.
  InputDecoration _fieldDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color),
        );
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(icon, color: AppColors.textSecondary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.accent),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger),
    );
  }

  @override
  void dispose() {
    _loginIdController.dispose();
    _loginPasswordController.dispose();
    _fullNameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_loginFormKey.currentState!.validate()) {
      // Mock login only — no real authentication, no tokens.
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    }
  }

  void _handleCreateAccount() {
    if (_registerFormKey.currentState!.validate()) {
      // Best-effort profile persistence — fire-and-forget, never blocks
      // the UI, and safely no-ops when Supabase is unavailable.
      unawaited(
        ProfileRepository.instance.ensureProfile(
          fullName: _fullNameController.text.trim(),
        ),
      );
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Success'),
        content: const Text('Account setup complete.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              setState(() => _isLogin = true);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Forgot Password?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Password recovery will be available when authentication '
                'is connected.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBrandHeader(context),
              const SizedBox(height: 28),
              _buildToggle(context),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: _isLogin
                    ? _buildLoginForm(context)
                    : _buildRegisterForm(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          'SAFEGUARD',
          textAlign: TextAlign.center,
          style: textTheme.displayLarge?.copyWith(
            fontSize: 34,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Smart Tourism. Safer Journeys.',
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your trusted companion for real-time safety, group '
          'protection and emergency assistance.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildToggle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleTab(
              label: 'Login',
              icon: Icons.person_outline,
              selected: _isLogin,
              onTap: () => setState(() => _isLogin = true),
            ),
          ),
          Expanded(
            child: _ToggleTab(
              label: 'Register',
              icon: Icons.person_add_alt_outlined,
              selected: !_isLogin,
              onTap: () => setState(() => _isLogin = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Email or Mobile Number',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _loginIdController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: _fieldDecoration(
              hintText: 'Enter your email or mobile number',
              icon: Icons.mail_outline,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email or mobile number is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Password',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _loginPasswordController,
            obscureText: _obscureLoginPassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleLogin(),
            decoration: _fieldDecoration(
              hintText: 'Enter your password',
              icon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureLoginPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  setState(() {
                    _obscureLoginPassword = !_obscureLoginPassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPasswordSheet,
              child: const Text('Forgot Password?'),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _handleLogin,
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(BuildContext context) {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Full Name',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _fullNameController,
            textInputAction: TextInputAction.next,
            decoration: _fieldDecoration(
              hintText: 'Enter your full name',
              icon: Icons.person_outline,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Full name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Email',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _registerEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: _fieldDecoration(
              hintText: 'Enter your email',
              icon: Icons.mail_outline,
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) {
                return 'Email is required';
              }
              if (!_emailPattern.hasMatch(email)) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Password',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _registerPasswordController,
            obscureText: _obscureRegisterPassword,
            textInputAction: TextInputAction.next,
            decoration: _fieldDecoration(
              hintText: 'Enter your password',
              icon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureRegisterPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  setState(() {
                    _obscureRegisterPassword = !_obscureRegisterPassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Confirm Password',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleCreateAccount(),
            decoration: _fieldDecoration(
              hintText: 'Re-enter your password',
              icon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _registerPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _handleCreateAccount,
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
  }
}

/// Single tab within the Login / Register segmented toggle.
class _ToggleTab extends StatelessWidget {
  const _ToggleTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : AppColors.accent,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
