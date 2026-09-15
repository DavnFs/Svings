import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/presentation/controller/c_settings.dart';

/// Scoped "liquid glass lite": frosted blur only, no refraction shader.
///
/// Allowed surfaces ONLY: top app bar, bottom nav pill, bottom sheets and
/// modal dialogs. NEVER behind currency values, chart bars, chart value
/// labels, or transaction rows — those stay on solid matte for readability.
///
/// - Blur sigma 18 over surface @ 0.80 (inside the 75–85% band).
/// - 1px hairline: white @ 28% in dark mode; in light mode a white sheen is
///   near-invisible on a light surface, so the *border* does the edge work
///   (DESIGN.md hairline) while the highlight stays subtle.
/// - Specular: white→transparent gradient over the top 30%, capped at 10%
///   dark / 6% light (light gets the weaker wash + stronger edge instead).
/// - Reduce-transparency: when [reduceTransparency] is true the BackdropFilter
///   is SKIPPED entirely (not sigma 0 — no blur layer, no GPU cost) and the
///   surface renders solid at the same corner radius.
class GlassLite extends StatelessWidget {
  final Widget child;
  final double radius;
  final bool reduceTransparency;
  final EdgeInsetsGeometry? padding;

  const GlassLite({
    super.key,
    required this.child,
    this.radius = 18,
    this.reduceTransparency = false,
    this.padding,
  });

  /// Reads the platform reduce-transparency setting where exposed. Today that
  /// is iOS (`UIAccessibility.isReduceTransparencyEnabled` via
  /// MediaQuery.highContrast) — Android has no direct equivalent, so the
  /// app-level "Reduce glass effect" toggle in Settings feeds in here too.
  static bool of(BuildContext context) {
    if (MediaQuery.highContrastOf(context)) return true;
    if (Get.isRegistered<CSettings>()) {
      try {
        return Get.find<CSettings>().reduceGlass;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Read the toggle reactively: flipping "Reduce glass effect" in Settings
    // rebuilds every glass surface app-wide with no per-screen state.
    final contrast = MediaQuery.highContrastOf(context);
    if (!Get.isRegistered<CSettings>()) {
      return _Tile(
          radius: radius, padding: padding, reduce: reduceTransparency || contrast, child: child);
    }
    final settings = Get.find<CSettings>();
    return Obx(() => _Tile(
          radius: radius,
          padding: padding,
          reduce: reduceTransparency || contrast || settings.reduceGlass,
          child: child,
        ));
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('radius', radius));
    properties.add(FlagProperty('reduceTransparency',
        value: reduceTransparency, ifFalse: 'system'));
  }
}

/// The actual tile: solid when [reduce], blurred glass otherwise. Split out so
/// the reactive wrapper above stays trivial.
class _Tile extends StatelessWidget {
  final double radius;
  final EdgeInsetsGeometry? padding;
  final bool reduce;
  final Widget child;

  const _Tile({required this.radius, required this.padding, required this.reduce, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    final tile = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: reduce ? AppColor.surface : AppColor.surface.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: dark ? Colors.white.withValues(alpha: 0.28) : AppColor.border,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(children: [
          child,
          if (!reduce)
            const Positioned.fill(
              child: IgnorePointer(child: _Specular()),
            ),
        ]),
      ),
    );

    if (reduce) return tile;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: tile,
      ),
    );
  }
}

/// Specular wash over the top 30%: white fading to transparent. Strength is
/// theme-tuned in [_Specular.build] — see class doc.
class _Specular extends StatelessWidget {
  const _Specular();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return FractionallySizedBox(
      alignment: Alignment.topCenter,
      heightFactor: 0.3,
      widthFactor: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: dark ? 0.10 : 0.06),
              Colors.white.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sheet/dialog glass: same material at sheet radius, with content padding.
/// Use as the root surface of bottom sheets and modal dialogs.
class GlassSheet extends StatelessWidget {
  final Widget child;
  final bool reduceTransparency;

  const GlassSheet({super.key, required this.child, this.reduceTransparency = false});

  @override
  Widget build(BuildContext context) {
    return GlassLite(
      radius: 24,
      reduceTransparency: reduceTransparency,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: child,
    );
  }
}
