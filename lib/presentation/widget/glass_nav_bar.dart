import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/presentation/widget/liquid_glass.dart';
import 'package:cause_money_record/presentation/widget/pressable.dart';

/// The floating nav pill: real Liquid Glass ([LiquidGlass]) over the aurora,
/// with a sliding selector that glides between tabs on a spring.
///
/// The selector is the iOS-27 tell: it tracks the selected tab's center with an
/// interruptible animation, so rapid taps reverse mid-flight instead of
/// jumping (skill §3). Icons sit above it in a row; labels ride with them.
class GlassNavBar extends StatefulWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const GlassNavBar({super.key, required this.index, required this.onChanged});

  static const tabs = [
    _TabSpec('Home', Icons.home_outlined, Icons.home, 'Home'),
    _TabSpec('Income', Icons.arrow_downward_rounded, Icons.south_rounded, 'Income records'),
    _TabSpec('Expense', Icons.arrow_upward_rounded, Icons.north_rounded, 'Expense records'),
    _TabSpec('History', Icons.receipt_long_outlined, Icons.receipt_long, 'Transaction history'),
  ];

  @override
  State<GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<GlassNavBar> with SingleTickerProviderStateMixin {
  late final AnimationController _slide;

  @override
  void initState() {
    super.initState();
    // Damping 1.0 / response ~0.35: critically damped, no overshoot (skill §4).
    _slide = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slide.value = widget.index / (GlassNavBar.tabs.length - 1);
  }

  @override
  void didUpdateWidget(covariant GlassNavBar old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _slide.animateTo(
        widget.index / (GlassNavBar.tabs.length - 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: LiquidGlass(
        radius: 28,
        blur: 26,
        alpha: 0.38,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColor.accent.withValues(alpha: 0.10),
            blurRadius: 32,
            offset: const Offset(0, 4),
          ),
        ],
        child: LayoutBuilder(builder: (context, constraints) {
          final count = GlassNavBar.tabs.length;
          final cell = constraints.maxWidth / count;
          return Stack(children: [
            AnimatedBuilder(
              animation: _slide,
              builder: (context, _) => Positioned(
                left: _slide.value * cell,
                top: 0,
                bottom: 0,
                width: cell,
                child: Center(
                  child: Container(
                    width: cell * 0.78,
                    decoration: BoxDecoration(
                      color: AppColor.accent.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: List.generate(count, (i) {
                final spec = GlassNavBar.tabs[i];
                final selected = i == widget.index;
                return SizedBox(
                  width: cell,
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: spec.tooltip,
                    child: Tooltip(
                      message: spec.tooltip,
                      child: Pressable(
                        onTap: () {
                          if (i == widget.index) return;
                          HapticFeedback.selectionClick();
                          widget.onChanged(i);
                        },
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 150),
                            child: Icon(
                              selected ? spec.selectedIcon : spec.icon,
                              key: ValueKey(selected),
                              size: 22,
                              color: selected ? AppColor.textPrimary : AppColor.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            spec.label,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: selected ? AppColor.textPrimary : AppColor.textSecondary,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                                ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ]);
        }),
      ),
    );
  }
}

class _TabSpec {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String tooltip;

  const _TabSpec(this.label, this.icon, this.selectedIcon, this.tooltip);
}
