import 'package:flutter/material.dart';
import 'package:cause_money_record/config/app_color.dart';

class AppDialog {
  AppDialog._();

  static void success(BuildContext context, String message) {
    // The fill is the semantic money-in green, which the default snackbar text
    // colour does not know about: it is chosen against the inverse surface, so
    // over this green it lands at 3.4:1. onColor picks black or white per fill
    // and clears AA on both snackbars.
    _snack(context, message, AppColor.income);
  }

  static void error(BuildContext context, String message) {
    _snack(context, message, AppColor.outcome);
  }

  static void _snack(BuildContext context, String message, Color fill) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: AppColor.onColor(fill))),
        backgroundColor: fill,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static Future<bool> confirm(
    BuildContext context,
    String title,
    String message, {
    String confirmText = 'Ya',
    String cancelText = 'Batal',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 18)),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(cancelText, style: TextStyle(color: AppColor.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmText, style: TextStyle(color: AppColor.danger)),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
