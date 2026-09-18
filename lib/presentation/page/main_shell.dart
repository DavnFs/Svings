import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/sessions.dart';
import 'package:cause_money_record/data/source/source_user.dart';
import 'package:cause_money_record/presentation/controller/c_accounts.dart';
import 'package:cause_money_record/presentation/controller/c_home.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/page/auth/login_page.dart';
import 'package:cause_money_record/presentation/page/history/history_form_page.dart';
import 'package:cause_money_record/presentation/page/history/history_page.dart';
import 'package:cause_money_record/presentation/page/home/home_body.dart';
import 'package:cause_money_record/presentation/page/settings_page.dart';
import 'package:cause_money_record/presentation/page/wallet/wallet_body.dart';
import 'package:cause_money_record/presentation/widget/floating_nav_bar.dart';

/// Primary navigation shell: Home + Wallet + Transactions in an IndexedStack
/// under a floating MD3 nav pill, with the "new entry" FAB sitting on the
/// pill's own row, just to its right.
///
/// The FAB is deliberately NOT contextual: it always means "add transaction"
/// on every tab, so the action stays predictable wherever you are. It lives
/// inside [FloatingNavBar] rather than in Scaffold.floatingActionButton so the
/// two can share one row and one vertical center by construction, instead of
/// being aligned by a hardcoded bottom offset that has to be re-tuned whenever
/// the pill changes height.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  MainTab _tab = MainTab.home;

  late final CUser cUser;
  late final CHome cHome;
  late final CAccounts cAccounts;

  @override
  void initState() {
    super.initState();
    cUser = Get.find<CUser>();
    cHome = Get.find<CHome>();
    cAccounts = Get.find<CAccounts>();
    _refresh();
  }

  Future<void> _refresh() async {
    final id = cUser.id;
    if (id.isEmpty) return;
    await cHome.getAnalysis(id);
    // Balances feed the hero card via the same pass — stale totals after a
    // save are the bug this second call prevents.
    await cAccounts.getAccounts(id);
    cHome.totalBalance = cAccounts.total;
  }

  void _selectTab(int i) => setState(() => _tab = MainTab.values[i]);

  /// Tab switch from content (Home's "See all" link into Wallet).
  void goTo(MainTab tab) => setState(() => _tab = tab);

  /// Opens the New Entry form. The FAB calls it bare; Home's quick actions pass
  /// the type they stand for and the account card that was on screen, so both
  /// entry points land on the same form with the same fields.
  Future<void> _newEntry({String? type, String? accountId}) async {
    HapticFeedback.lightImpact();
    final result = await Get.to(() => HistoryFormPage(
          initialType: type,
          initialAccountId: accountId,
        ));
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
            // Home's "See all" jumps here via callback, not via the shell
            // type — keeps Home importable without a cycle.
            child: IndexedStack(
              index: _tab.index,
              children: [
                _TabPage(
                    child: HomeBody(
                        onOpenTransactions: () => goTo(MainTab.transactions),
                        onQuickAction: (type, accountId) =>
                            _newEntry(type: type, accountId: accountId))),
                const _TabPage(child: WalletBody()),
                const _TabPage(child: HistoryBody()),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingNavBar(
              index: _tab.index,
              onChanged: _selectTab,
              onAddPressed: _newEntry,
            ),
          ),
        ]),
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

/// MD3 center-aligned top bar: greeting + settings + sign out on the scheme
/// surface. No blur — tonal surface only.
///
/// No avatar: the greeting is the identity here, and dropping the photo gives
/// the name the whole leading width instead of the ~52dp the image and its gap
/// used to take.
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
            Expanded(
                child: GetX<CUser>(
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
