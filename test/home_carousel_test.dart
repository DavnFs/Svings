import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:cause_money_record/config/app_account_icon.dart';
import 'package:cause_money_record/data/model/account.dart';
import 'package:cause_money_record/presentation/controller/c_accounts.dart';
import 'package:cause_money_record/presentation/controller/c_home.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/controller/history/c_history.dart';
import 'package:cause_money_record/presentation/page/home/home_body.dart';
import 'package:cause_money_record/presentation/widget/account_widgets.dart';

/// Home balance carousel contract:
///
/// - page 0 is the aggregate, the rest are one card per account;
/// - an account card shows that account's own balance and its own today-spend,
///   not the global figure;
/// - the dots track the active card;
/// - account cards open that account's filtered list, the aggregate card opens
///   the unfiltered one;
/// - the horizontal swipe does not fight the page's vertical scroll.
///
/// Assertions are scoped to a card by key: the carousel peeks its neighbour into
/// view, so both cards are in the tree at once and a global text finder would
/// match either. Every getter override reads the base value first, which is the
/// read that keeps the screen's Obx widgets registered.
class _FakeHome extends CHome {
  @override
  Future<void> getAnalysis(String idUser) async {}

  @override
  double get totalBalance => super.totalBalance + 12000000;
  @override
  double get today => super.today + 50000;
  @override
  String get todayPercent => '${super.todayPercent}-12,4% dibanding kemarin';
  @override
  String? get todayId => super.todayId ?? 'tx-today';
  @override
  List<double> get week => [for (var i = 0; i < super.week.length; i++) 10000];
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

  /// Cash spent 21.500 today, GoPay nothing. Distinct from the aggregate's
  /// 50.000 so a value can only come from the card it belongs to.
  @override
  double todaySpendOf(String? accountId) {
    super.todaySpendOf(accountId);
    return accountId == 'acc-cash' ? 21500 : 0;
  }
}

class _OfflineAccounts extends CAccounts {
  @override
  Future<void> getAccounts(String idUser) async {}
}

class _OfflineHistory extends CHistory {
  @override
  Future<void> getList(String idUser) async {}
}

const _accounts = [
  Account(id: 'acc-cash', userId: 'u1', name: 'Cash', icon: AccountIcon.cash),
  Account(
      id: 'acc-gopay',
      userId: 'u1',
      name: 'GoPay',
      kind: 'e-wallet',
      icon: AccountIcon.gojek),
];

void main() {
  var openedTransactions = 0;

  setUp(() {
    Get.testMode = true;
    Get.put(CUser());
    Get.put<CHome>(_FakeHome());
    final accounts = Get.put<CAccounts>(_OfflineAccounts());
    accounts.accounts.addAll(_accounts);
    accounts.balances['acc-cash'] = 1250000;
    accounts.balances['acc-gopay'] = 250000;
    Get.put<CHistory>(_OfflineHistory());
    openedTransactions = 0;
  });

  tearDown(Get.reset);

  Future<void> pumpHome(WidgetTester tester,
      {Size size = const Size(600, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(
      home: Scaffold(
        body: HomeBody(onOpenTransactions: () => openedTransactions++),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Which card the carousel has settled on.
  double pageOf(WidgetTester tester) =>
      tester.widget<PageView>(find.byType(PageView)).controller!.page!;

  Finder inCard(String id, Finder matching) => find.descendant(
        of: find.byKey(Key('carousel_card_$id')),
        matching: matching,
      );

  Future<void> swipe(WidgetTester tester) async {
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
  }

  double dotWidth(WidgetTester tester, int i) =>
      tester.getSize(find.byKey(Key('carousel_dot_$i'))).width;

  testWidgets('page 0 is the aggregate, then one card per account',
      (tester) async {
    await pumpHome(tester);

    expect(pageOf(tester), 0);
    expect(inCard('aggregate', find.text('Total Balance')), findsOneWidget);
    expect(inCard('aggregate', find.text('Rp 12.000.000,00')), findsOneWidget);
    expect(inCard('aggregate', find.textContaining('Spent today: Rp 50.000')),
        findsOneWidget);

    await swipe(tester);

    expect(pageOf(tester), 1);
    expect(inCard('acc-cash', find.text('Cash')), findsOneWidget);
    expect(inCard('acc-cash', find.text('Rp 1.250.000,00')), findsOneWidget);
  });

  testWidgets('an account card shows that account\'s spend, not the total',
      (tester) async {
    await pumpHome(tester);

    await swipe(tester); // Cash
    expect(inCard('acc-cash', find.text('Spent today: Rp 21.500,00')),
        findsOneWidget);

    await swipe(tester); // GoPay
    expect(pageOf(tester), 2);
    expect(inCard('acc-gopay', find.text('GoPay')), findsOneWidget);
    expect(inCard('acc-gopay', find.text('Rp 250.000,00')), findsOneWidget);
    // GoPay spent nothing today: neither the aggregate's 50.000 nor Cash's
    // 21.500 may leak into this card.
    expect(
        inCard('acc-gopay', find.text('Spent today: Rp 0,00')), findsOneWidget);
  });

  testWidgets('the dots follow the active card', (tester) async {
    await pumpHome(tester);

    // One dot per card: aggregate + two accounts, the active one wider.
    expect(find.byKey(const Key('carousel_dot_0')), findsOneWidget);
    expect(find.byKey(const Key('carousel_dot_2')), findsOneWidget);
    expect(find.byKey(const Key('carousel_dot_3')), findsNothing);
    expect(dotWidth(tester, 0), greaterThan(dotWidth(tester, 1)));

    await swipe(tester);
    expect(dotWidth(tester, 1), greaterThan(dotWidth(tester, 0)));
    expect(dotWidth(tester, 1), greaterThan(dotWidth(tester, 2)));
  });

  testWidgets('tapping an account card opens its filtered list',
      (tester) async {
    await pumpHome(tester);

    await swipe(tester);
    await tester.tap(inCard('acc-cash', find.text('Cash')));
    await tester.pumpAndSettle();

    expect(find.byType(AccountTransactionsPage), findsOneWidget);
  });

  testWidgets('tapping the aggregate card opens all transactions',
      (tester) async {
    await pumpHome(tester);

    await tester.tap(inCard('aggregate', find.text('Total Balance')));
    await tester.pumpAndSettle();

    expect(openedTransactions, 1);
  });

  testWidgets('the swipe does not fight the page scroll', (tester) async {
    // Shorter than the content, so the page really is scrollable.
    await pumpHome(tester, size: const Size(600, 600));

    ScrollableState listState() =>
        tester.state<ScrollableState>(find.byType(Scrollable).first);

    expect(listState().position.pixels, 0);
    expect(pageOf(tester), 0);

    // A horizontal drag on the card belongs to the carousel, and must not
    // scroll the page vertically.
    await swipe(tester);
    expect(pageOf(tester), 1);
    expect(listState().position.pixels, 0);

    // A vertical drag on the card belongs to the list, and must not change the
    // card. Kept short so the carousel stays partly in view: a ListView unmounts
    // children that scroll out entirely, and then there is no page left to read.
    final pageBefore = pageOf(tester);
    await tester.drag(find.byType(PageView), const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(listState().position.pixels, greaterThan(0));
    expect(pageOf(tester), pageBefore);
  });
}
