import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_surface.dart';
import '../../../routing/routes.dart';
import '../controllers/login_controller.dart';

final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Email + password sign-in (spec §11.1, T-3.3), plus a link to `/signup`
/// (spec D2/F-15, T-M2.4 — v1.0's instruction to omit a sign-up link is
/// superseded in v2.0).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(loginControllerProvider.notifier)
        .signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    // On success the auth state change drives the router redirect (T-3.4) —
    // nothing to navigate to here. On failure the error renders below.
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email above first.')),
      );
      return;
    }
    final result = await ref
        .read(loginControllerProvider.notifier)
        .sendPasswordReset(email);
    if (!mounted) return;
    result.fold(
      (_) =>
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Check your email'))),
      (failure) =>
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final isLoading = state.isLoading;
    final error = state.hasError ? state.error as Failure : null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A1220),
              AppColors.ink,
              AppColors.ink,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      const AppBrandMark(),
                      const SizedBox(height: 20),
                      Text(
                        'Kharcha',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A calmer way to keep household\nspending clear.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                        ),
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) return 'Enter your email.';
                          if (!_emailRegex.hasMatch(trimmed)) {
                            return 'Enter a valid email.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon:
                              const Icon(Icons.lock_outline_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'Enter your password.'
                            : null,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.danger,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  error.message,
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      _GlowButton(
                        onPressed: isLoading ? null : _submit,
                        isLoading: isLoading,
                        label: 'Sign in',
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: isLoading ? null : _forgotPassword,
                        child: const Text('Forgot password?'),
                      ),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () => context.push(AppRoutes.signup),
                        child: Text.rich(
                          TextSpan(
                            text: 'New here? ',
                            style: TextStyle(color: AppColors.textMuted),
                            children: [
                              TextSpan(
                                text: 'Create an account',
                                style: TextStyle(
                                  color: AppColors.neonCyan,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CTA button with neon glow
class _GlowButton extends StatelessWidget {
  const _GlowButton({
    required this.onPressed,
    required this.isLoading,
    required this.label,
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: AppColors.neonMint.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: FilledButton(
        onPressed: onPressed,
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.ink,
                ),
              )
            : Text(label),
      ),
    );
  }
}
