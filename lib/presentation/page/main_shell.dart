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
import 'package:cause_money_record/presentation/widget/app_nav_bar.dart';

/// Primary navigation shell per DESIGN.md: flat frosted nav strip on the
/// bottom edge (NOT a floating capsule), four tabs in an IndexedStack, and a
/// standard FAB for the primary "new entry" action.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  late final CUser cUser;
  late final CHome cHome;

  @override
  void initState() {
    super.initState();
    cUser = Get.find<CUser>();
    cHome = Get.find<CHome>();
    if (cUser.id.isNotEmpty) cHome.getAnalysis(cUser.id);
  }

  Future<void> _refresh() async {
    final id = cUser.id;
    if (id.isEmpty) return;
    await cHome.getAnalysis(id);
  }

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
    return Scaffold(
      backgroundColor: AppColor.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: _Header(onSignOut: _signOut),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColor.accent,
          onRefresh: _refresh,
          // Plain setState tab switch — no Rx read here, so no Obx.
          child: IndexedStack(
            index: _index,
            children: const [
              HomeBody(),
              IncomeOutcomeBody(type: 'Pemasukan'),
              IncomeOutcomeBody(type: 'Pengeluaran'),
              HistoryBody(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('main_new_entry_fab'),
        onPressed: _newEntry,
        tooltip: 'Record new entry',
        backgroundColor: AppColor.accent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: AppNavBar(index: _index, onChanged: _selectTab),
    );
  }
}

/// Solid header: avatar + greeting + sign out. Matte surface, no glass — the
/// dose cap reserves frost for the Top Bar and Bottom Nav only.
class _Header extends StatelessWidget {
  final VoidCallback onSignOut;

  const _Header({required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColor.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(AppAsset.profile, width: 44, height: 44),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hi,', style: TextStyle(fontSize: 14, color: AppColor.textSecondary)),
              GetX<CUser>(
                builder: (c) => Text(
                  c.name,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColor.textPrimary),
                ),
              ),
            ])),
            Semantics(
              label: 'Sign out',
              button: true,
              child: IconButton(
                tooltip: 'Sign out',
                icon: Icon(Icons.logout, color: AppColor.danger, size: 20),
                onPressed: onSignOut,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
