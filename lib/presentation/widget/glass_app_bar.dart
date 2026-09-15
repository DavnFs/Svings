import 'package:flutter/material.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/presentation/widget/liquid_glass.dart';

/// Shared Liquid Glass app bar: blurs + saturates the backdrop with content
/// scrolling underneath, not an opaque strip (skill §12).
///
/// Replaces five copy-pasted blur blocks (form, detail, income/expense
/// standalone, history standalone). One place to change the material.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const GlassAppBar({super.key, required this.title});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    return AppBar(
      backgroundColor:
          highContrast ? AppColor.surface : AppColor.surface.withValues(alpha: 0.45),
      flexibleSpace: highContrast
          ? null
          : ClipRect(
              child: BackdropFilter(
                filter: liquidGlassFilter(blur: 24),
                child: const SizedBox.expand(),
              ),
            ),
      foregroundColor: AppColor.textPrimary,
      elevation: 0,
      centerTitle: true,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
    );
  }
}
