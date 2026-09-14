import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_asset.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/config/sessions.dart';
import 'package:cause_money_record/data/source/source_user.dart';
import 'package:cause_money_record/presentation/controller/c_home.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/page/auth/login_page.dart';
import 'package:cause_money_record/presentation/page/history/history_form_page.dart';
import 'package:cause_money_record/presentation/page/history/history_page.dart';
import 'package:cause_money_record/presentation/page/history/income_outcome_page.dart';
import 'package:cause_money_record/presentation/page/home/home_body.dart';
import 'package:cause_money_record/presentation/widget/glass_nav_bar.dart';
import 'package:cause_money_record/presentation/widget/pressable.dart';

/// Primary navigation shell: a floating glass pill ([GlassNavBar]) over an
/// [IndexedStack] of the four top-level destinations, plus a compact action
/// button for the one primary action (recording a new entry).
///
/// The body extends under the pill (`extendBody`) so content scrolls behind
/// the glass — glass with nothing behind it is just a tint (skill §12).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final cUser = Get.put(CUser());
  late final cHome = Get.put(CHome());

  @override
  void initState() {
    super.initState();
    if (cUser.id.isNotEmpty) cHome.getAnalysis(cUser.id);
  }

  Future<void> _refresh() => cHome.getAnalysis(cUser.id);

  void _selectTab(int i) => setState(() => _index = i);

  Future<void> _newEntry() async {
    HapticFeedback.lightImpact();
    final result = await Get.to(() => const HistoryFormPage());
    if (result == true) _refresh();
  }

  Future<void> _signOut() async {
    await SourceUser.logout();
    await Session.clearUser();
    Get.offAll(() => const LoginPage());
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final stack = IndexedStack(
      key: ValueKey(_index),
      index: _index,
      children: const [
        HomeBody(),
        IncomeOutcomeBody(type: 'Pemasukan'),
        IncomeOutcomeBody(type: 'Pengeluaran'),
        HistoryBody(),
      ],
    );

    return Scaffold(
      backgroundColor: AppColor.surface,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Stack(children: [
          Column(children: [
            _header(context),
            Expanded(
              child: RefreshIndicator(
                color: AppColor.accent,
                onRefresh: _refresh,
                child: Obx(
                  () => reduce
                      ? IndexedStack(
                          index: _index,
                          children: const [
                            HomeBody(),
                            IncomeOutcomeBody(type: 'Pemasukan'),
                            IncomeOutcomeBody(type: 'Pengeluaran'),
                            HistoryBody(),
                          ],
                        )
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeOutCubic,
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(scale: Tween(begin: 0.98, end: 1.0).animate(animation), child: child),
                          ),
                          child: stack,
                        ),
                ),
              ),
            ),
          ]),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GlassNavBar(index: _index, onChanged: _selectTab),
          ),
          Positioned(
            right: 20,
            bottom: 104,
            child: FloatingActionButton.small(
              onPressed: _newEntry,
              tooltip: 'Record new entry',
              backgroundColor: AppColor.primary,
              foregroundColor: AppColor.onPrimary,
              child: const Icon(Icons.add),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(AppAsset.profile, width: 44, height: 44),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hi,', style: TextStyle(fontSize: 14, color: AppColor.textSecondary)),
          Obx(() => Text(
                cUser.name,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColor.textPrimary),
              )),
        ])),
        Semantics(
          label: 'Sign out',
          button: true,
          child: Pressable(
            onTap: _signOut,
            child: Material(
              color: AppColor.card.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColor.border.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.logout, color: AppColor.danger, size: 20),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
