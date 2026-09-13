import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_asset.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/data/source/source_user.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

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
      Get.snackbar(
        'Berhasil',
        'Akun berhasil dibuat, silakan login',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColor.income,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    } else {
      setState(() => _error.value = result.error ?? 'Registrasi gagal');
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
    return Scaffold(
      backgroundColor: AppColor.surface,
      appBar: AppBar(
        backgroundColor: AppColor.surface,
        foregroundColor: AppColor.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppColor.card,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: AppColor.accent.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 8))],
                    ),
                    child: Center(child: Image.asset(AppAsset.logo, width: 48, height: 48)),
                  ),
                  const SizedBox(height: 32),
                  Text('Create Account',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColor.textPrimary)),
                  const SizedBox(height: 8),
                  Text('Start managing your finances', style: TextStyle(color: AppColor.textSecondary, fontSize: 15)),
                  const SizedBox(height: 40),
                  _buildField(controller: _nameController, hint: 'Full Name', icon: Icons.person_outline,
                    validator: (v) => (v == null || v.isEmpty) ? 'Name is required' : null),
                  const SizedBox(height: 16),
                  _buildField(controller: _emailController, hint: 'Email', icon: Icons.email_outlined, type: TextInputType.emailAddress,
                    validator: (v) => (v == null || v.isEmpty) ? 'Email is required' : null),
                  const SizedBox(height: 16),
                  _buildField(controller: _passwordController, hint: 'Password', icon: Icons.lock_outlined, obscure: true,
                    validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null),
                  const SizedBox(height: 16),
                  Obx(() {
                    final err = _error.value;
                    if (err == null) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColor.danger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColor.danger.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: AppColor.danger, size: 18),
                          const SizedBox(width: 8),
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
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: Obx(() => ElevatedButton(
                      onPressed: _loading.value ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColor.primary, foregroundColor: Colors.white, elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                      ),
                      child: _loading.value
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('Create Account'),
                    )),
                  ),
                  const SizedBox(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('Already have an account? ', style: TextStyle(color: AppColor.textSecondary, fontSize: 14)),
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: Text('Sign In', style: TextStyle(color: AppColor.accent, fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ]),
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
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? type,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: type,
      validator: validator,
      style: TextStyle(color: AppColor.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: AppColor.textSecondary),
        prefixIcon: Icon(icon, color: AppColor.textSecondary, size: 20),
        filled: true, fillColor: AppColor.card,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColor.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColor.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColor.accent, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColor.danger)),
      ),
    );
  }
}
