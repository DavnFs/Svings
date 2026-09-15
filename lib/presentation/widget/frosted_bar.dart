import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cause_money_record/config/app_color.dart';

/// DESIGN.md dose cap: frosted glass lives on the Top Bar and Bottom Nav ONLY.
/// Everything else is solid matte. One shared material so both bars refract
/// identically: blur 18 over surface @ 0.75 + a hairline edge.
class FrostedBar extends StatelessWidget {
  final Widget child;

  const FrostedBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    return ClipRect(
      child: BackdropFilter(
        filter: highContrast ? ImageFilter.blur() : ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: highContrast ? AppColor.surface : AppColor.surface.withValues(alpha: 0.75),
            border: Border(
              bottom: BorderSide(color: AppColor.border, width: 0.5),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
