import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/presentation/widget/frosted_bar.dart';
import 'package:cause_money_record/presentation/widget/pressable.dart';

/// Bottom nav per DESIGN.md: a flat frosted strip (the dose-cap's second
/// element), NOT a floating capsule. Frosted Bar material + hairline top edge,
/// four destinations, active tab in accent.
class AppNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const AppNavBar({super.key, required this.index, required this.onChanged});

  static const _tabs = [
    _TabSpec('Home', Icons.home_outlined, Icons.home_filled, 'Home'),
    _TabSpec('Income', Icons.arrow_downward_rounded, Icons.south_rounded, 'Income records'),
    _TabSpec('Expense', Icons.arrow_upward_rounded, Icons.north_rounded, 'Expense records'),
    _TabSpec('History', Icons.receipt_long_outlined, Icons.receipt_long, 'Transaction history'),
  ];

  @override
  Widget build(BuildContext context) {
    return FrostedBar(
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final spec = _tabs[i];
              final selected = i == index;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: spec.tooltip,
                  child: Pressable(
                    onTap: () {
                      if (i == index) return;
                      HapticFeedback.selectionClick();
                      onChanged(i);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? spec.selectedIcon : spec.icon,
                          size: 24,
                          color: selected ? AppColor.accent : AppColor.textSecondary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          spec.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? AppColor.accent : AppColor.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
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
