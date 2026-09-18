import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:cause_money_record/config/app_account_icon.dart';
import 'package:cause_money_record/data/model/account.dart';
import 'package:cause_money_record/data/model/user.dart';
import 'package:cause_money_record/presentation/controller/c_accounts.dart';
import 'package:cause_money_record/presentation/controller/c_home.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/controller/history/c_history.dart';
import 'package:cause_money_record/presentation/controller/history/c_history_form.dart';
import 'package:cause_money_record/presentation/page/history/history_form_page.dart';
import 'package:cause_money_record/presentation/page/main_shell.dart';

/// Home quick-actions contract:
///
/// - the three buttons open the SAME New Entry form the FAB opens, pre-set to
///   their own transaction type;
/// - the account is pre-selected only when a specific account card is the one
///   the carousel is showing — the aggregate card means "no account chosen",
///   which is what the FAB does;
/// - the FAB is still there and still opens the form with nothing chosen.
///
/// Every getter override reads the base value first, which is the read that
/// keeps the dashboard's Obx widgets registered.
class _FakeHome extends CHome {
  @override
  Future<void> getAnalysis(String idUser) async {}

  @override
  double get totalBalance => super.totalBalance + 12000000;
  @override
  double get today => super.today + 50000;
  @override
  String get todayPercent => '${super.todayPercent}-12,4%';
  @override
  List<double> get week => [for (var i = 0; i < super.week.length; i++) 1000.0];
  @override
  double get monthIncome => super.monthIncome + 5000000;
  @override
  double get monthOutcome => super.monthOutcome + 1250000;
  @override
  double get differentMonth => super.differentMonth + 3750000;
  @override
  String get percentIncome => '${super.percentIncome}60.0';
  @override
  String get monthPercent => '${super.monthPercent}Pemasukan\nlebih besar';
}

class _OfflineAccounts extends CAccounts {
  @override
  Future<void> getAccounts(String idUser) async {}
}

class _OfflineHistory extends CHistory {
  @override
  Future<void> getList(String idUser) async {}
}

void main() {
  late CHistoryForm form;

  setUpAll(() => initializeDateFormatting('id_ID'));

  setUp(() {
    Get.testMode = true;
    Get.put(CUser()).setData(const User(idUser: 'u1', name: 'Davin'));
    Get.put<CHome>(_FakeHome());
    final accounts = Get.put<CAccounts>(_OfflineAccounts());
    accounts.accounts.addAll(const [
      Account(
          id: 'acc-cash',
          userId: 'u1',
          name: 'Cash',
          kind: 'cash',
          icon: AccountIcon.cash),
      Account(
          id: 'acc-gopay',
          userId: 'u1',
          name: 'GoPay',
          kind: 'e-wallet',
          icon: AccountIcon.gojek),
      Account(
          id: 'acc-bank',
          userId: 'u1',
          name: 'Bank BCA',
          kind: 'bank',
          icon: AccountIcon.bank),
    ]);
    accounts.balances['acc-cash'] = 425000;
    accounts.balances['acc-gopay'] = 250000;
    accounts.balances['acc-bank'] = 11800000;
    form = Get.put(CHistoryForm());
    Get.put<CHistory>(_OfflineHistory());
  });

  tearDown(Get.reset);

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GetMaterialApp(home: MainShell()));
    await tester.pumpAndSettle();
  }

  /// The type the form actually opened on, read from the segment itself.
  Set<String> openedType(WidgetTester tester) => tester
      .widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>))
      .selected;

  Future<void> swipeToAccount(WidgetTester tester, int times) async {
    for (var i = 0; i < times; i++) {
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('the row sits below the carousel and its dots', (tester) async {
    await pumpHome(tester);

    expect(find.byKey(const Key('quick_action_income')), findsOneWidget);
    expect(find.byKey(const Key('quick_action_expense')), findsOneWidget);
    expect(find.byKey(const Key('quick_action_transfer')), findsOneWidget);
    expect(find.text('Pemasukan'), findsOneWidget);
    expect(find.text('Pengeluaran'), findsOneWidget);

    // Below the dots, and above the charts.
    final dots = tester.getTopLeft(find.byKey(const Key('carousel_dot_0'))).dy;
    final row =
        tester.getTopLeft(find.byKey(const Key('quick_action_income'))).dy;
    expect(row, greaterThan(dots));
    expect(row, lessThan(tester.getTopLeft(find.text('This Week')).dy));

    // Evenly distributed across the row.
    final income = tester.getRect(find.byKey(const Key('quick_action_income')));
    final transfer =
        tester.getRect(find.byKey(const Key('quick_action_transfer')));
    expect(income.width, closeTo(transfer.width, 1));
  });

  testWidgets('each button opens the form on its own type', (tester) async {
    for (final entry in {
      'quick_action_income': 'Pemasukan',
      'quick_action_expense': 'Pengeluaran',
      'quick_action_transfer': 'Transfer',
    }.entries) {
      await pumpHome(tester);
      await tester.tap(find.byKey(Key(entry.key)));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryFormPage), findsOneWidget,
          reason: '${entry.value} should open the New Entry form');
      expect(openedType(tester), {entry.value});
      expect(form.type, entry.value);

      // Back out for the next one.
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('account pre-selection follows the carousel card',
      (tester) async {
    await pumpHome(tester);

    // Aggregate card showing: no account is chosen, exactly like the FAB.
    await tester.tap(find.byKey(const Key('quick_action_expense')));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryFormPage), findsOneWidget);
    // The pickers fall back to the first account when nothing was chosen, so a
    // different account here can only have come from the carousel.
    expect(form.accountId, 'acc-cash');
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Swipe to the second account (GoPay) and tap again.
    await swipeToAccount(tester, 2);
    await tester.tap(find.byKey(const Key('quick_action_expense')));
    await tester.pumpAndSettle();
    expect(form.accountId, 'acc-gopay');
    expect(openedType(tester), {'Pengeluaran'});
  });

  testWidgets('a transfer shortcut starts from the account in view',
      (tester) async {
    await pumpHome(tester);

    // Page 3 is the third account, Bank BCA.
    await swipeToAccount(tester, 3);
    await tester.tap(find.byKey(const Key('quick_action_transfer')));
    await tester.pumpAndSettle();

    expect(openedType(tester), {'Transfer'});
    // For a transfer the chosen account is the SOURCE, and the form fills the
    // destination itself.
    expect(form.accountId, 'acc-bank');
    expect(form.transferToAccountId, isNotNull);
    expect(form.transferToAccountId, isNot('acc-bank'));
  });

  testWidgets('the FAB is untouched and still opens the bare form',
      (tester) async {
    await pumpHome(tester);

    // Same form, no shortcut: the default type, and no account from a carousel.
    await swipeToAccount(tester, 2);
    await tester.tap(find.byKey(const Key('main_new_entry_fab')));
    await tester.pumpAndSettle();

    expect(find.byType(HistoryFormPage), findsOneWidget);
    expect(openedType(tester), {'Pemasukan'});
    expect(form.accountId, 'acc-cash');
  });
}
