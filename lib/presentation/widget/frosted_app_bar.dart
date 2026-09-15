import 'package:flutter/material.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/presentation/widget/frosted_bar.dart';

/// DESIGN.md Top Bar: frosted strip (the dose-cap's first element) with a
/// centered 17sp w700 title. Replaces the five copy-pasted blur blocks.
class FrostedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const FrostedAppBar({super.key, required this.title});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return FrostedBar(
      child: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColor.textPrimary,
        elevation: 0,
        centerTitle: true,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      ),
    );
  }
}
