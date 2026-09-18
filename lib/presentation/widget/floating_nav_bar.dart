import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// The three tabs, in display order. Single source of truth: MainShell builds
/// its IndexedStack pages in [MainTab.values] order and passes the selected
/// tab's index to the nav bar, so render order and highlight can never drift
/// apart. (Income/Expense used to be tabs; they are now filters inside the
/// Transactions screen — see HistoryBody. Wallet was split out of Home's
/// account row so management lives in one place.)
enum MainTab {
  home('Home', Icons.home_outlined, Icons.home, 'Home'),
  wallet('Wallet', Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet, 'Accounts'),
  transactions('Transactions', Icons.receipt_long_outlined, Icons.receipt_long,
      'Transaction history');

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String tooltip;

  const MainTab(this.label, this.icon, this.selectedIcon, this.tooltip);
}

// Geometry, all in one place: the pill's width, the highlight capsule and the
// add button have to agree on these numbers or they drift apart.
const double _marginX = 16;
const double _marginBottom = 16;
const double _pillPad = 4;
const double _tabPadX = 14;
const double _tabHeight = 48; // 48dp tap target inside the 56dp pill.
const double _iconSize = 22;
const double _iconGap = 6;
const double _labelSize = 12;
const double _fabGap = 12;

/// Lightly underdamped: about a quarter second to settle with roughly 2%
/// overshoot, which reads as a deliberate stop rather than a wobble.
const SpringDescription _spring =
    SpringDescription(mass: 1, stiffness: 500, damping: 34);

/// Google Photos-style floating nav: a pill that hugs its content, plus a
/// detached round add button sharing the same row on its right.
///
/// Why the pill shrink-wraps: the reference reads as a small floating object,
/// not as a bar spanning the screen. Width therefore comes from the tabs
/// themselves (icon slot + label + padding, per tab), never from dividing the
/// available space by the tab count, which cannot work once the three tab
/// widths differ.
///
/// Why only the selected tab carries an icon: the other two are their label
/// alone, so they are genuinely narrower. No slot is reserved for an icon a tab
/// is not showing.
///
/// Why one spring drives everything: the capsule's left edge, the capsule's
/// width and the icon slots all read from a single position value, so a switch
/// is one gesture instead of three animations that can drift apart. A
/// fixed-duration curve cannot express that.
class FloatingNavBar extends StatefulWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback onAddPressed;

  const FloatingNavBar({
    super.key,
    required this.index,
    required this.onChanged,
    required this.onAddPressed,
  });

  @override
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar>
    with SingleTickerProviderStateMixin {
  /// Selected tab as a continuous position across the row (0..tabCount-1).
  /// Unbounded so a spring overshoot past either end is not clipped away.
  late final AnimationController _capsule;

  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _capsule = AnimationController.unbounded(
      vsync: this,
      value: widget.index.toDouble(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read here, not in build: this is the dependency hook, and didUpdateWidget
    // runs against a tree that is already rebuilding.
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(covariant FloatingNavBar old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    final target = widget.index.toDouble();
    if (_reduceMotion) {
      _capsule.value = target;
      return;
    }
    // Carrying the live velocity means a second tap mid-flight bends the curve
    // instead of restarting it from a standstill.
    _capsule.animateWith(
      SpringSimulation(_spring, _capsule.value, target, _capsule.velocity),
    );
  }

  @override
  void dispose() {
    _capsule.dispose();
    super.dispose();
  }

  /// Width of one label, measured with the very style the [Text] widget will
  /// use. Rounded up so a label can never be a subpixel wider than its box.
  static double _labelWidth(
    String label,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: direction,
      maxLines: 1,
      textScaler: scaler,
    )..layout();
    return painter.width.ceilToDouble();
  }

  /// The label style, built in one place so the painter and the [Text] can
  /// never disagree: a mismatch would size the capsule for text that is not
  /// what gets painted.
  static TextStyle _labelStyle(
    BuildContext context,
    double slot,
    Color color,
  ) {
    return DefaultTextStyle.of(context).style.copyWith(
          fontSize: _labelSize,
          // Selection is the only thing that changes the weight, so the bold
          // label and the open icon slot land together.
          fontWeight: FontWeight.lerp(FontWeight.w500, FontWeight.w700, slot),
          color: color,
        );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final scaler = MediaQuery.textScalerOf(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(_marginX, 0, _marginX, _marginBottom + bottom),
      // RepaintBoundary keeps the capsule animation off the scrolling lists'
      // repaint path.
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _capsule,
          builder: (context, _) {
            final scheme = Theme.of(context).colorScheme;
            final tabs = _measure(context, scaler);
            return FittedBox(
              // Shrink-only safety net for a very large text scale, which would
              // otherwise push the add button off-screen. Never scales up, so a
              // normal size renders untouched.
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _pill(context, scheme, tabs),
                  const SizedBox(width: _fabGap),
                  _addButton(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Tab geometry for the current spring position: width, offset and icon slot
  /// progress for each tab.
  List<_TabMetrics> _measure(BuildContext context, TextScaler scaler) {
    final direction = Directionality.of(context);
    final scheme = Theme.of(context).colorScheme;
    // Clamped because a settled spring may sit a hair past either end.
    final p =
        _capsule.value.clamp(0.0, (MainTab.values.length - 1).toDouble());
    final tabs = <_TabMetrics>[];
    var left = 0.0;
    for (var i = 0; i < MainTab.values.length; i++) {
      // 1 on the selected tab, 0 on both neighbours: the icon slot opens and
      // closes on the same curve as the capsule instead of on its own timer.
      final slot =
          Curves.easeOutCubic.transform((1 - (p - i).abs()).clamp(0.0, 1.0));
      final width = _tabPadX * 2 +
          _labelWidth(
            MainTab.values[i].label,
            _labelStyle(context, slot, scheme.onSurface),
            scaler,
            direction,
          ) +
          slot * (_iconSize + _iconGap);
      tabs.add(_TabMetrics(
        spec: MainTab.values[i],
        index: i,
        left: left,
        width: width,
        slot: slot,
      ));
      left += width;
    }
    return tabs;
  }

  /// The capsule sits on the selected tab's own rect, blended toward the tab it
  /// is travelling to so the hand-off stays continuous. At rest it matches that
  /// tab exactly, which is what makes unequal tab widths work.
  Rect _capsuleRect(List<_TabMetrics> tabs) {
    final p = _capsule.value.clamp(0.0, (tabs.length - 1).toDouble());
    final from = p.floor().clamp(0, tabs.length - 1);
    final to = (from + 1).clamp(0, tabs.length - 1);
    return Rect.lerp(tabs[from].rect, tabs[to].rect, p - from)!;
  }

  Widget _pill(
    BuildContext context,
    ColorScheme scheme,
    List<_TabMetrics> tabs,
  ) {
    final capsule = _capsuleRect(tabs);
    return Material(
      key: const Key('nav_pill'),
      elevation: 3,
      // surfaceContainer + level-3 shadow: the MD3 answer to a bar that floats
      // over busy scrolling content.
      color: scheme.surfaceContainer,
      shape: const StadiumBorder(),
      child: Padding(
        // The pill adds nothing but its own padding to the row it wraps, so its
        // width is the tabs' width and never the screen's.
        padding: const EdgeInsets.all(_pillPad),
        child: SizedBox(
          height: _tabHeight,
          child: Stack(
            children: [
              Positioned(
                left: capsule.left,
                top: 0,
                bottom: 0,
                width: capsule.width,
                child: DecoratedBox(
                  key: const Key('nav_capsule'),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(_tabHeight / 2),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [for (final tab in tabs) _tab(context, scheme, tab)],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, ColorScheme scheme, _TabMetrics tab) {
    final selected = tab.index == widget.index;
    final color =
        selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
    return SizedBox(
      key: Key('nav_tab_${tab.spec.name}'),
      width: tab.width,
      child: Semantics(
        button: true,
        selected: selected,
        label: tab.spec.tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(_tabHeight / 2),
          onTap: () {
            if (selected) return;
            HapticFeedback.selectionClick();
            widget.onChanged(tab.index);
          },
          child: Center(
            child: SizedBox(
              key: Key('nav_content_${tab.spec.name}'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nothing is built for a closed slot: an unselected tab holds
                  // no icon and no empty space shaped like one.
                  if (tab.slot > 0)
                    SizedBox(
                      width: tab.slot * (_iconSize + _iconGap),
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.centerLeft,
                          minWidth: 0,
                          maxWidth: _iconSize,
                          child: Opacity(
                            opacity: tab.slot,
                            child: Transform.scale(
                              scale: 0.6 + 0.4 * tab.slot,
                              child: Icon(
                                selected
                                    ? tab.spec.selectedIcon
                                    : tab.spec.icon,
                                size: _iconSize,
                                color: color,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Text(
                    tab.spec.label,
                    maxLines: 1,
                    softWrap: false,
                    style: _labelStyle(context, tab.slot, color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Detached add button: a circle the exact height of the pill, sharing the
  /// pill's row so the two are centered on one axis by construction.
  Widget _addButton() {
    return FloatingActionButton(
      key: const Key('main_new_entry_fab'),
      onPressed: widget.onAddPressed,
      tooltip: 'Record new entry',
      shape: const CircleBorder(),
      // Same level as the pill: the two float on one plane, not two.
      elevation: 3,
      child: const Icon(Icons.add),
    );
  }
}

/// One tab's geometry for the current frame.
class _TabMetrics {
  final MainTab spec;
  final int index;
  final double left;
  final double width;

  /// Icon slot progress: 1 when this tab owns the selection, 0 when it is
  /// fully collapsed.
  final double slot;

  const _TabMetrics({
    required this.spec,
    required this.index,
    required this.left,
    required this.width,
    required this.slot,
  });

  Rect get rect => Rect.fromLTWH(left, 0, width, _tabHeight);
}
