import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../routes/app_routes.dart';
import '../services/supabase/auth_repository.dart';
import '../services/supabase/profile_repository.dart';
import '../services/supabase/supabase_service.dart';

/// Combined authentication screen for SafeGuard: Login + Register behind a
/// single segmented toggle, matching the simplified SAFEGUARD auth design.
///
/// Login/Register now go through real Supabase Auth
/// (`AuthRepository.signIn` / `AuthRepository.signUp`) whenever Supabase
/// is configured and reachable — this is what makes "Remember Me" (see
/// SplashScreen) meaningful: `supabase_flutter` persists the resulting
/// session to local storage on its own, and the password itself is never
/// stored, only sent for that one sign-in/sign-up request. When Supabase
/// is unavailable (Offline/Demo Mode, matching the rest of the app), both
/// forms fall back to the previous mock behavior — no session is
/// persisted in that case, since there is nothing real to remember.
/// Registration's existing best-effort Supabase profile persistence
/// (ProfileRepository.ensureProfile) is preserved unchanged, now passed
/// the real auth user id when one exists.
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

  bool _isLoggingIn = false;
  bool _isRegistering = false;
  String? _loginError;
  String? _registerError;

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

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    final identifier = _loginIdController.text.trim();
    final password = _loginPasswordController.text;

    // Offline/Demo Mode: no Supabase to authenticate against, so there is
    // no real session to persist. Preserve the previous mock behavior
    // rather than blocking the demo.
    if (!SupabaseService.isAvailable) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      return;
    }

    if (!_emailPattern.hasMatch(identifier)) {
      setState(() {
        _loginError = 'Enter a valid email address to sign in.';
      });
      return;
    }

    setState(() {
      _isLoggingIn = true;
      _loginError = null;
    });

    final result = await AuthRepository.instance.signIn(
      email: identifier,
      password: password,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      // Session is already persisted locally by supabase_flutter at this
      // point — nothing further to do here for "Remember Me".
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      return;
    }

    setState(() {
      _isLoggingIn = false;
      _loginError = result.message ??
          'Something went wrong. Please try again in a moment.';
    });
  }

  Future<void> _handleCreateAccount() async {
    if (!_registerFormKey.currentState!.validate()) return;

    final fullName = _fullNameController.text.trim();
    final email = _registerEmailController.text.trim();
    final password = _registerPasswordController.text;

    if (!SupabaseService.isAvailable) {
      // Offline/Demo Mode: preserve the previous mock behavior.
      unawaited(ProfileRepository.instance.ensureProfile(fullName: fullName));
      _showSuccessDialog();
      return;
    }

    setState(() {
      _isRegistering = true;
      _registerError = null;
    });

    final result = await AuthRepository.instance.signUp(
      email: email,
      password: password,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _isRegistering = false;
        _registerError = result.message ??
            'Something went wrong. Please try again in a moment.';
      });
      return;
    }

    // Best-effort profile persistence, now scoped to the real auth user
    // id when we have one — fire-and-forget, never blocks the UI.
    unawaited(
      ProfileRepository.instance.ensureProfile(
        fullName: fullName,
        userId: result.data?.user.id,
      ),
    );

    setState(() => _isRegistering = false);
    _showSuccessDialog();
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
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _ForgotPasswordSheet(),
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
          if (_loginError != null) ...[
            const SizedBox(height: 4),
            Text(
              _loginError!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isLoggingIn ? null : _handleLogin,
            child: _isLoggingIn
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Login'),
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
          if (_registerError != null) ...[
            Text(
              _registerError!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.danger),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton(
            onPressed: _isRegistering ? null : _handleCreateAccount,
            child: _isRegistering
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Create Account'),
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

/// Functional "Forgot Password" bottom sheet.
///
/// Collects an email address and sends a real Supabase password-reset
/// email via [AuthRepository.sendPasswordResetEmail] — the same Supabase
/// client already used across SafeGuard (see SupabaseService). Never
/// shows raw exception text; only the user-friendly messages produced by
/// [AuthRepository].
class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet();

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  static final RegExp _emailPattern =
      RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  bool _isSending = false;
  bool _sent = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
      _errorText = null;
    });

    final result = await AuthRepository.instance
        .sendPasswordResetEmail(_emailController.text.trim());

    if (!mounted) return;

    setState(() {
      _isSending = false;
      if (result.isSuccess) {
        _sent = true;
      } else {
        // BackendResult already carries a user-friendly message for both
        // failure and offline cases — never show the raw exception.
        _errorText = result.message ??
            'Something went wrong. Please try again in a moment.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
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
            if (!_sent) ...[
              Text(
                'Forgot Password?',
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the email address linked to your account and '
                'we\'ll send you a link to reset your password.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  enabled: !_isSending,
                  onFieldSubmitted: (_) => _handleSendResetLink(),
                  decoration: InputDecoration(
                    hintText: 'Enter your email address',
                    prefixIcon: const Icon(Icons.mail_outline),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.accent),
                    ),
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
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSending ? null : _handleSendResetLink,
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Send Reset Link'),
              ),
            ] else ...[
              Icon(
                Icons.mark_email_read_outlined,
                color: AppColors.accent,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                'Check Your Email',
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'If an account exists for ${_emailController.text.trim()}, '
                'a password reset link has been sent.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
