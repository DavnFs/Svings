import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/presentation/widget/pressable.dart';

/// A floating glass pill over the content — the BitChord / iOS 27 Liquid Glass
/// idiom: detached with side + bottom margins, content scrolling underneath,
/// strong blur + low-alpha tint + bright top edge approximating the material.
///
/// Compared to the old docked `NavigationBar`: a custom row gives per-item
/// pointer-down scale (via [Pressable]) plus `HapticFeedback.selectionClick` on
/// commit (skill §13, causality + utility — reserved for the snap moment).
///
/// Accessibility: `MediaQuery.highContrast` drops the blur for a solid bar;
/// `MediaQuery.disableAnimations` skips scale and content transitions.
class GlassNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const GlassNavBar({super.key, required this.index, required this.onChanged});

  static const _tabs = [
    _TabSpec('Home', Icons.home_outlined, Icons.home),
    _TabSpec('Income', Icons.arrow_downward_rounded, Icons.south_rounded),
    _TabSpec('Expense', Icons.arrow_upward_rounded, Icons.north_rounded),
    _TabSpec('History', Icons.receipt_long_outlined, Icons.receipt_long),
  ];

  static const _tooltips = [
    'Home',
    'Income records',
    'Expense records',
    'Transaction history',
  ];

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    final bar = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: highContrast ? AppColor.surface : AppColor.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(28),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: highContrast ? 0.0 : 0.4)),
          left: BorderSide(color: AppColor.border.withValues(alpha: 0.5)),
          right: BorderSide(color: AppColor.border.withValues(alpha: 0.5)),
          bottom: BorderSide(color: AppColor.border.withValues(alpha: 0.5)),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          return Expanded(
            child: _GlassTab(
              spec: _tabs[i],
              tooltip: _tooltips[i],
              selected: i == index,
              onTap: () {
                if (i == index) return;
                HapticFeedback.selectionClick();
                onChanged(i);
              },
            ),
          );
        }),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: highContrast
          ? bar
          : ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25), child: bar),
            ),
    );
  }
}

class _TabSpec {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _TabSpec(this.label, this.icon, this.selectedIcon);
}

class _GlassTab extends StatelessWidget {
  final _TabSpec spec;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _GlassTab({required this.spec, required this.tooltip, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Pressable(
          onTap: onTap,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColor.accent.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  selected ? spec.selectedIcon : spec.icon,
                  key: ValueKey(selected),
                  size: 22,
                  color: selected ? scheme.primary : AppColor.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                spec.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected ? scheme.primary : AppColor.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
