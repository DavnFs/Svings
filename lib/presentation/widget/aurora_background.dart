import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cause_money_record/config/app_color.dart';

/// The living backdrop the glass refracts. Real Liquid Glass needs something to
/// bend — on a flat `surface` background the pill was just a translucent tint,
/// which is why it never read as glass.
///
/// Two slow-drifting accent orbs + film grain over the surface color, shared by
/// every screen (shell, pushed pages, auth). One aurora for the whole app —
/// entering a page keeps the same light (skill §7 spatial consistency).
///
/// Cost note: two large blurred circles repaint every frame while drifting.
/// The orbs render once into a [RepaintBoundary] and only their offsets
/// animate; still, on very low-end devices drop [AuroraBackground] for a static
/// gradient. Reduced motion (skill §14) freezes the drift.
class AuroraBackground extends StatefulWidget {
  final Widget child;

  const AuroraBackground({super.key, required this.child});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(vsync: this, duration: const Duration(seconds: 22))..repeat();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Stack(children: [
      Positioned.fill(child: ColoredBox(color: AppColor.surface)),
      Positioned.fill(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: reduce ? kAlwaysCompleteAnimation : _drift,
            builder: (context, _) {
              final t = reduce ? 0.0 : _drift.value * 2 * math.pi;
              final size = MediaQuery.sizeOf(context);
              return CustomPaint(
                painter: _AuroraPainter(
                  accent: AppColor.accent,
                  income: AppColor.income,
                  phase: t,
                  size: size,
                ),
              );
            },
          ),
        ),
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(painter: _GrainPainter()),
        ),
      ),
      widget.child,
    ]);
  }
}

class _AuroraPainter extends CustomPainter {
  final Color accent;
  final Color income;
  final double phase;
  final Size size;

  _AuroraPainter({required this.accent, required this.income, required this.phase, required this.size});

  @override
  void paint(Canvas canvas, Size _) {
    final w = size.width;
    final h = size.height;

    void orb(Offset c, double r, Color color) {
      final rect = Rect.fromCircle(center: c, radius: r);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.34), color.withValues(alpha: 0.0)],
        ).createShader(rect);
      canvas.drawRect(rect, paint);
    }

    // Accent orb drifting across the top third, income orb across the bottom.
    orb(
      Offset(w * (0.5 + 0.32 * math.sin(phase)), h * (0.10 + 0.05 * math.cos(phase * 0.7))),
      math.max(w, h) * 0.55,
      accent,
    );
    orb(
      Offset(w * (0.5 + 0.36 * math.cos(phase * 0.8 + 1.3)), h * (0.78 + 0.06 * math.sin(phase * 0.6 + 0.5))),
      math.max(w, h) * 0.48,
      income,
    );
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) =>
      old.phase != phase || old.size != size || old.accent != accent || old.income != income;
}

/// Sparse film grain so large blurred areas don't band. 400 specks at 3%
/// alpha — visible only as texture, never as noise.
class _GrainPainter extends CustomPainter {
  static final _rng = math.Random(7);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.03);
    for (var i = 0; i < 400; i++) {
      canvas.drawCircle(
        Offset(_rng.nextDouble() * size.width, _rng.nextDouble() * size.height),
        0.7,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
