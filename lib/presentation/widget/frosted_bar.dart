import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/presentation/widget/glass_lite.dart';

/// DESIGN.md dose cap: frosted glass lives on the Top Bar and Bottom Nav ONLY.
/// Everything else is solid matte. One shared material so both bars refract
/// identically: blur 18 over surface @ 0.80 + hairline + top specular.
///
/// [reduceTransparency] bypasses the blur layer entirely (see [GlassLite]).
class FrostedBar extends StatelessWidget {
  final Widget child;
  final bool reduceTransparency;

  const FrostedBar({super.key, required this.child, this.reduceTransparency = false});

  @override
  Widget build(BuildContext context) {
    final reduce = reduceTransparency || GlassLite.of(context);
    if (reduce) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: AppColor.surface,
          border: Border(bottom: BorderSide(color: AppColor.border, width: 0.5)),
        ),
        child: child,
      );
    }
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: GlassLite(
          radius: 0,
          padding: null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColor.surface.withValues(alpha: 0.80),
              border: Border(bottom: BorderSide(color: AppColor.border, width: 0.5)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
