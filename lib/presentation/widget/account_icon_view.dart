import 'package:flutter/material.dart';

import 'package:cause_money_record/config/app_account_icon.dart';
import 'package:cause_money_record/presentation/controller/c_accounts.dart';

/// An account's mark: its icon drawn in its own colour inside a tinted circle.
///
/// One widget for the picker, the filter pill and the account cards, so an
/// account looks the same everywhere and the tinting rule lives in one place.
class AccountIconView extends StatelessWidget {
  final AccountIcon icon;
  final String colorHex;
  final double size;

  const AccountIconView({
    super.key,
    required this.icon,
    required this.colorHex,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final color = CAccounts.parseColor(colorHex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon.data, size: size * 0.55, color: color),
    );
  }
}
