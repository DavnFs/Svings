import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/presentation/widget/pressable.dart';

/// Floating glass pill modeled on BitChord's `FloatingTabBar` expanded state:
/// a detached `RoundedCornerShape(100)` tab cluster, centered with 16dp side
/// margins, content scrolling underneath.
///
/// BitChord behaviors ported, Flutter-idiomatic:
/// - sliding selection pill that follows taps (its spring) — the shared
///   `ExpandedTabs` indicator, without the drag/squash physics (no velocity
///   tracker on this side; a tap has no fling to hand off);
/// - tick haptic across tab boundaries on every committed switch;
/// - scroll-collapse (`inline` mini bar) deliberately NOT ported: BitChord
///   needs it for a media accessory, this app has none — a bar that hides on
///   scroll would just bury primary navigation (ponytail).
///
/// Frosted-glass material per DESIGN.md dose cap (the bar is frosted element
/// #2 alongside the top bar): blur 18 over surface @ 0.75 + hairline edge.
class FloatingTabBar extends StatefulWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const FloatingTabBar({super.key, required this.index, required this.onChanged});

  @override
  State<FloatingTabBar> createState() => _FloatingTabBarState();
}

/// The four tabs, in display order. Single source of truth: MainShell builds
/// its IndexedStack pages in [MainTab.values] order and passes the selected
/// tab's index here, so render order and highlight can never drift apart.
enum MainTab {
  home('Home', Icons.home_outlined, Icons.home, 'Home'),
  income('Income', Icons.arrow_downward_rounded, Icons.south_rounded, 'Income records'),
  expense('Expense', Icons.arrow_upward_rounded, Icons.north_rounded, 'Expense records'),
  history('History', Icons.receipt_long_outlined, Icons.receipt_long, 'Transaction history');

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String tooltip;

  const MainTab(this.label, this.icon, this.selectedIcon, this.tooltip);
}

class _FloatingTabBarState extends State<FloatingTabBar> with SingleTickerProviderStateMixin {
  late final AnimationController _slide;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slide.value = _fraction(widget.index);
  }

  @override
  void didUpdateWidget(covariant FloatingTabBar old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _slide.animateTo(
        _fraction(widget.index),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Selected tab as 0..1 across the row. One helper for init + retarget so
  /// the two can never disagree on the divisor.
  static double _fraction(int index) => index / (MainTab.values.length - 1);

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, 16 + bottom),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: BackdropFilter(
            filter: highContrast ? ImageFilter.blur() : ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: highContrast ? AppColor.surface : AppColor.surface.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppColor.border, width: 0.5),
              ),
              child: LayoutBuilder(builder: (context, constraints) {
                final count = MainTab.values.length;
                final cell = constraints.maxWidth / count;
                return Stack(children: [
                  AnimatedBuilder(
                    animation: _slide,
                    builder: (context, _) => Positioned(
                      // Indicator center tracks the selected CELL's center, not
                      // N/cell-widths from the left: padding + pill insets mean
                      // "index * cell" drifts (the old bug — Expense landed
                      // between Home and Income, History on Income).
                      left: (_slide.value * (count - 1) + 0.5) * cell - (cell * 0.86) / 2,
                      top: 0,
                      bottom: 0,
                      width: cell * 0.86,
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColor.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(count, (i) {
                      final spec = MainTab.values[i];
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
                              child: Padding(
                                // No horizontal padding: the cell is already
                                // narrow (~1/4 of the pill). Padding here stole
                                // ~40dp per tab and clipped "History" on small
                                // screens; the cell itself is the tap target.
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(
                                    selected ? spec.selectedIcon : spec.icon,
                                    size: 22,
                                    color: selected ? AppColor.accent : AppColor.textSecondary,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    spec.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                      color: selected ? AppColor.accent : AppColor.textSecondary,
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }
}
