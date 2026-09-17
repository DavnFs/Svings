import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_asset.dart';
import 'package:cause_money_record/config/sessions.dart';
import 'package:cause_money_record/data/source/source_user.dart';
import 'package:cause_money_record/presentation/page/auth/register_page.dart';
import 'package:cause_money_record/presentation/page/main_shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _loading = false.obs;
  final _error = RxnString();
  var _obscurePassword = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    _loading.value = true;
    _error.value = null;
    final result = await SourceUser.login(
      _emailController.text.trim(),
      _passwordController.text,
    );
    _loading.value = false;
    if (!mounted) return;

    if (result.success && result.user != null) {
      await Session.saveUser(result.user!);
      Get.off(() => const MainShell());
    } else {
      setState(() => _error.value = result.error ?? 'Login failed. Please check your credentials.');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _LogoBadge(),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to svings',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                          fontSize: 26,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to manage your income & expenses',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Card.outlined(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    color: scheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _AuthField(
                            controller: _emailController,
                            label: 'Email',
                            hint: 'name@example.com',
                            icon: Icons.email_outlined,
                            type: TextInputType.emailAddress,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Email is required' : null,
                          ),
                          const SizedBox(height: 16),
                          _AuthField(
                            controller: _passwordController,
                            label: 'Password',
                            hint: 'Enter your password',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Password is required' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ErrorBanner(error: _error),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Obx(
                      () => FilledButton(
                        onPressed: _loading.value ? null : _login,
                        child: _loading.value
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : const Text('Sign In'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: () => Get.to(() => const RegisterPage()),
                        child: Text(
                          'Register',
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo badge: tonal tile.
class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Image.asset(AppAsset.logo, width: 44, height: 44),
      ),
    );
  }
}

/// Inline auth error: reserves no space when null to avoid layout jump.
class _ErrorBanner extends StatelessWidget {
  final RxnString error;

  const _ErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final err = error.value;
      if (err == null) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                err,
                style: TextStyle(
                  color: scheme.onErrorContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// MD3 auth input: scheme outline, primary focus ring.
class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType? type;
  final String? Function(String?)? validator;

  const _AuthField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffixIcon,
    this.type,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: type,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: suffixIcon,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
