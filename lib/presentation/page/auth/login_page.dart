import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_asset.dart';
import 'package:cause_money_record/config/app_color.dart';
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
    return Scaffold(
      backgroundColor: AppColor.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColor.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColor.border),
                    ),
                    child: Center(
                      child: Image.asset(AppAsset.logo, width: 44, height: 44),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to Uangku',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColor.textPrimary,
                          fontSize: 26,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to manage your income & expenses',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColor.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColor.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColor.border),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'name@example.com',
                          icon: Icons.email_outlined,
                          type: TextInputType.emailAddress,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Email is required' : null,
                        ),
                        const SizedBox(height: 18),
                        _buildField(
                          controller: _passwordController,
                          label: 'Password',
                          hint: 'Enter your password',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: AppColor.textSecondary,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
                        ),
                      ],
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
                        color: AppColor.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColor.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: AppColor.danger, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              err,
                              style: TextStyle(
                                color: AppColor.danger,
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
                      () => ElevatedButton(
                        onPressed: _loading.value ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColor.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: _loading.value
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
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
                        style: TextStyle(color: AppColor.textSecondary, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: () => Get.to(() => const RegisterPage()),
                        child: Text(
                          'Register',
                          style: TextStyle(
                            color: AppColor.accent,
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? type,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColor.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: type,
          validator: validator,
          style: TextStyle(color: AppColor.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColor.textSecondary.withValues(alpha: 0.7), fontSize: 14),
            prefixIcon: Icon(icon, color: AppColor.textSecondary, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColor.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColor.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColor.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColor.accent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColor.danger),
            ),
          ),
        ),
      ],
    );
  }
}
