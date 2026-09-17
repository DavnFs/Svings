import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_asset.dart';
import 'package:cause_money_record/data/source/source_user.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _loading = false.obs;
  final _error = RxnString();
  var _obscurePassword = true;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    _loading.value = true;
    _error.value = null;
    final result = await SourceUser.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    _loading.value = false;
    if (!mounted) return;

    if (result.success) {
      Get.back();
      final scheme = Theme.of(context).colorScheme;
      Get.snackbar(
        'Account Created',
        'Your account is ready. Please sign in.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: scheme.tertiary,
        colorText: scheme.onTertiary,
        margin: const EdgeInsets.all(16),
        borderRadius: 14,
      );
    } else {
      setState(() => _error.value = result.error ?? 'Registration failed');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Image.asset(AppAsset.logo, width: 44, height: 44),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Create Account',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                          fontSize: 26,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start tracking your finances with clarity',
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
                          _RegisterField(
                            controller: _nameController,
                            label: 'Full Name',
                            hint: 'Your Name',
                            icon: Icons.person_outline_rounded,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                          ),
                          const SizedBox(height: 16),
                          _RegisterField(
                            controller: _emailController,
                            label: 'Email',
                            hint: 'name@example.com',
                            icon: Icons.email_outlined,
                            type: TextInputType.emailAddress,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Email is required' : null,
                          ),
                          const SizedBox(height: 16),
                          _RegisterField(
                            controller: _passwordController,
                            label: 'Password',
                            hint: 'Create a password',
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
                                (v == null || v.length < 6) ? 'At least 6 characters required' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Obx(() {
                    final err = _error.value;
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
                  }),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Obx(
                      () => FilledButton(
                        onPressed: _loading.value ? null : _register,
                        child: _loading.value
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : const Text('Create Account'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: () => Get.back(),
                        child: Text(
                          'Sign In',
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

/// MD3 register input: scheme outline, primary focus ring.
class _RegisterField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType? type;
  final String? Function(String?)? validator;

  const _RegisterField({
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
