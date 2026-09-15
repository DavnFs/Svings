import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cause_money_record/config/app_color.dart';

/// Shared Liquid Glass blur: one function so the nav pill, app bars, and cards
/// all refract identically. Kept as a function (not inline blur calls) so a
/// future SDK saturation/compose upgrade lands in one place.
ImageFilter liquidGlassFilter({double blur = 24}) {
  return ImageFilter.blur(sigmaX: blur, sigmaY: blur);
}

/// The core Liquid Glass material: backdrop blur + low-alpha tint + specular
/// sheen + hairline edge, clipped to continuous-feel rounded corners.
///
/// What makes this read as glass instead of frosted plastic:
/// - the blur stays strong (24+) while the tint alpha stays low (~0.35), so
///   the aurora behind shows through instead of washing out;
/// - the sheen gradient is light catching the surface (skill §12).
///
/// With `MediaQuery.highContrast` the filter is skipped for a solid tile
/// (reduced-transparency fallback, skill §14).
class LiquidGlass extends StatelessWidget {
  final Widget child;
  final double radius;
  final double blur;
  final Color? tint;
  final double alpha;
  final EdgeInsetsGeometry? padding;
  final bool sheen;
  final List<BoxShadow>? shadows;

  const LiquidGlass({
    super.key,
    required this.child,
    this.radius = 28,
    this.blur = 24,
    this.tint,
    this.alpha = 0.35,
    this.padding,
    this.sheen = true,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    final base = tint ?? AppColor.surface;

    final tile = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: highContrast ? base : base.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(radius),
        // Uniform hairline — per-side Border colors throw with borderRadius.
        border: Border.all(
          color: highContrast ? AppColor.border : Colors.white.withValues(alpha: 0.28),
        ),
        boxShadow: shadows ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
      ),
      child: sheen && !highContrast
          ? Stack(children: [
              _Sheen(radius: radius),
              child,
            ])
          : child,
    );

    if (highContrast) return tile;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: liquidGlassFilter(blur: blur),
        child: tile,
      ),
    );
  }
}

/// Card-sized glass: the grouped-list and section tiles across every screen.
/// Replaces the opaque `Container(card + border)` tiles so the aurora refracts
/// through them instead of stopping at flat white.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  const GlassCard({super.key, required this.child, this.padding, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: radius,
      blur: 16,
      tint: AppColor.card,
      alpha: 0.62,
      padding: padding,
      shadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
      child: child,
    );
  }
}

/// Light catching the surface: a soft white wash from the top-left fading by
/// mid-tile, plus a brighter 1px top edge. Painted *inside* the tile so it
/// never stacks translucency on translucency (skill §12).
class _Sheen extends StatelessWidget {
  final double radius;

  const _Sheen({required this.radius});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.45, 0.451, 1.0],
              colors: [
                Colors.white.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0.0),
                Colors.transparent,
                Colors.transparent,
              ],
            ),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.35), width: 1),
            ),
          ),
        ),
      ),
    );
  }
}
