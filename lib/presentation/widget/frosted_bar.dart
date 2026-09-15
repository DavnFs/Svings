import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/presentation/controller/c_settings.dart';
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
    final contrast = MediaQuery.highContrastOf(context);
    if (!Get.isRegistered<CSettings>()) {
      return _BarTile(contrast: reduceTransparency || contrast, child: child);
    }
    final settings = Get.find<CSettings>();
    return Obx(() => _BarTile(
          contrast: reduceTransparency || contrast || settings.reduceGlass,
          child: child,
        ));
  }
}

/// Solid-vs-blurred bar tile. Split out so the reactive wrapper stays trivial.
class _BarTile extends StatelessWidget {
  final bool contrast;
  final Widget child;

  const _BarTile({required this.contrast, required this.child});

  @override
  Widget build(BuildContext context) {
    if (contrast) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: AppColor.surface,
          border: Border(bottom: BorderSide(color: AppColor.border, width: 0.5)),
        ),
        child: child,
      );
    }
    // Frosted strip shared with the pill: delegate to the same material so
    // the toggle, specular, and radius logic live in exactly one place.
    return GlassLite(
      radius: 0,
      padding: null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // GlassLite already tints @ 0.80; this overlay is only the hairline.
          border: Border(bottom: BorderSide(color: AppColor.border, width: 0.5)),
        ),
        child: child,
      ),
    );
  }
}
