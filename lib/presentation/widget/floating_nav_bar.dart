import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The two tabs, in display order. Single source of truth: MainShell builds
/// its IndexedStack pages in [MainTab.values] order and passes the selected
/// tab's index to the nav bar, so render order and highlight can never drift
/// apart. (Income/Expense used to be tabs; they are now filters inside the
/// Transactions screen — see HistoryBody.)
enum MainTab {
  home('Home', Icons.home_outlined, Icons.home, 'Home'),
  transactions('Transactions', Icons.receipt_long_outlined, Icons.receipt_long,
      'Transaction history');

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String tooltip;

  const MainTab(this.label, this.icon, this.selectedIcon, this.tooltip);
}

/// Google Photos-style floating nav: a detached pill with 16dp side margins,
/// content scrolling underneath. Pure MD3 — tonal indicator + scheme colors,
/// no blur, no shadow.
///
/// Kept behaviors from the old custom pill: sliding indicator that follows
/// taps on a spring, tick haptic on every committed switch.
class FloatingNavBar extends StatefulWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const FloatingNavBar({super.key, required this.index, required this.onChanged});

  @override
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar> with SingleTickerProviderStateMixin {
  late final AnimationController _slide;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slide.value = _fraction(widget.index);
  }

  @override
  void didUpdateWidget(covariant FloatingNavBar old) {
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
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      // RepaintBoundary keeps the indicator animation off the scrolling
      // lists' repaint path.
      child: RepaintBoundary(
        child: Material(
          elevation: 3,
          // surfaceContainer + level-3 shadow: the MD3 answer to a bar that
          // floats over busy scrolling content.
          color: scheme.surfaceContainer,
          shape: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: LayoutBuilder(builder: (context, constraints) {
              final count = MainTab.values.length;
              final cell = constraints.maxWidth / count;
              return Stack(children: [
                AnimatedBuilder(
                  animation: _slide,
                  builder: (context, _) => Positioned(
                    // Indicator center tracks the selected CELL's center, not
                    // N/cell-widths from the left: bar padding means
                    // "index * cell" drifts with the index.
                    left: (_slide.value * (count - 1) + 0.5) * cell - (cell * 0.86) / 2,
                    top: 0,
                    bottom: 0,
                    width: cell * 0.86,
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
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
                        child: InkWell(
                          borderRadius: BorderRadius.circular(100),
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
                                color: selected
                                    ? scheme.onSecondaryContainer
                                    : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                spec.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  color: selected
                                      ? scheme.onSecondaryContainer
                                      : scheme.onSurfaceVariant,
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
        ),
      ),
    );
  }
}
