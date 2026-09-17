import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_asset.dart';
import 'package:cause_money_record/config/sessions.dart';
import 'package:cause_money_record/data/source/source_user.dart';
import 'package:cause_money_record/presentation/controller/c_home.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/page/auth/login_page.dart';
import 'package:cause_money_record/presentation/page/history/history_form_page.dart';
import 'package:cause_money_record/presentation/page/history/history_page.dart';
import 'package:cause_money_record/presentation/page/history/income_outcome_page.dart';
import 'package:cause_money_record/presentation/page/home/home_body.dart';
import 'package:cause_money_record/presentation/page/settings_page.dart';
import 'package:cause_money_record/presentation/widget/floating_nav_bar.dart';

/// Primary navigation shell: a Google Photos-style floating MD3 nav pill on
/// the bottom edge, four tabs in an IndexedStack, and a standard FAB for the
/// primary "new entry" action.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  MainTab _tab = MainTab.home;

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

  void _selectTab(int i) => setState(() => _tab = MainTab.values[i]);

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
      // extendBody lets the list scroll UNDER the floating pill; the bottom
      // padding on the lists keeps the last row clear of it.
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Stack(children: [
          RefreshIndicator(
            color: Theme.of(context).colorScheme.primary,
            onRefresh: _refresh,
            // Plain setState tab switch — no Rx read here, so no Obx.
            child: IndexedStack(
              index: _tab.index,
              children: const [
                _TabPage(child: HomeBody()),
                _TabPage(child: IncomeOutcomeBody(type: 'Pemasukan')),
                _TabPage(child: IncomeOutcomeBody(type: 'Pengeluaran')),
                _TabPage(child: HistoryBody()),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingNavBar(index: _tab.index, onChanged: _selectTab),
          ),
        ]),
      ),
      floatingActionButton: Padding(
        // Float above the pill — pill height + 16dp margin + safe area.
        padding: EdgeInsets.only(bottom: 82 + MediaQuery.paddingOf(context).bottom),
        child: FloatingActionButton(
          key: const Key('main_new_entry_fab'),
          onPressed: _newEntry,
          tooltip: 'Record new entry',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

/// One tab page: MD3 top bar + content.
class _TabPage extends StatelessWidget {
  final Widget child;

  const _TabPage({required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const _TopBar(),
      Expanded(child: child),
    ]);
  }
}

/// MD3 center-aligned top bar: avatar + greeting + settings + sign out on the
/// scheme surface. No blur — tonal surface only.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final shell = context.findAncestorStateOfType<_MainShellState>()!;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(AppAsset.profile, width: 40, height: 40),
            ),
            const SizedBox(width: 12),
            Expanded(child: GetX<CUser>(
              builder: (c) => Text(
                c.name.isEmpty ? 'Hi,' : 'Hi, ${c.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            )),
            Semantics(
              label: 'Settings',
              button: true,
              child: IconButton(
                key: const Key('topbar_settings'),
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined, size: 20),
                onPressed: () => Get.to(() => const SettingsPage()),
              ),
            ),
            Semantics(
              label: 'Sign out',
              button: true,
              child: IconButton(
                tooltip: 'Sign out',
                icon: Icon(Icons.logout, color: scheme.error, size: 20),
                onPressed: shell._signOut,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
