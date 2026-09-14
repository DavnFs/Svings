import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cause_money_record/config/app_color.dart';

/// Shared frosted-glass app bar (skill §12): translucent layer with content
/// scrolling underneath, not an opaque strip.
///
/// Replaces four copy-pasted `PreferredSize + ClipRect + BackdropFilter` blocks
/// (form, detail, income/expense standalone, history standalone). One place to
/// change blur, tint, and title type — previously four.
///
/// With `MediaQuery.highContrast` the blur is skipped for a solid bar
/// (reduced-transparency fallback, skill §14).
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const GlassAppBar({super.key, required this.title});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    final bar = AppBar(
      backgroundColor: highContrast ? AppColor.surface : AppColor.surface.withValues(alpha: 0.75),
      foregroundColor: AppColor.textPrimary,
      elevation: 0,
      centerTitle: true,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
    );
    if (highContrast) return bar;
    return ClipRect(
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: bar),
    );
  }
}
