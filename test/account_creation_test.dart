import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:cause_money_record/config/app_account_icon.dart';
import 'package:cause_money_record/data/model/account.dart';
import 'package:cause_money_record/data/model/account_balance.dart';
import 'package:cause_money_record/data/model/history.dart';
import 'package:cause_money_record/data/model/user.dart';
import 'package:cause_money_record/data/source/source_account.dart';
import 'package:cause_money_record/presentation/controller/c_accounts.dart';
import 'package:cause_money_record/presentation/controller/c_home.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/controller/history/c_history.dart';
import 'package:cause_money_record/presentation/page/main_shell.dart';

/// Account creation contract:
///
/// - creating an account runs the real flow (sheet → controller → store) and
///   the new account shows up on Wallet and Home from the controller's own
///   refresh, with no restart and no manual re-navigation;
/// - a failed write keeps the sheet open and says so, instead of closing as if
///   it had worked;
/// - a starting balance writes ONE opening entry alongside the account, in one
///   store call, so the two cannot come apart;
/// - a blank or zero starting balance writes no entry at all;
/// - that opening entry counts toward the account balance and is absent from
///   every income/expense total.
class _FakeStore implements AccountsStore {
  final List<Account> rows = [];
  final Map<String, double> balanceMap = {};

  /// Set to make the next write fail, the way a duplicate name or a dropped
  /// connection does.
  bool failNextAdd = false;

  /// Recorded per create call, so a test can prove the account and its opening
  /// entry were one operation rather than two.
  final List<({String name, double opening})> creates = [];

  int _seq = 0;

  @override
  Future<List<Account>> list(String idUser) async => List.of(rows);

  @override
  Future<Account?> ensureDefault(String idUser) async => null;

  @override
  Future<Map<String, double>> balances(String idUser) async => balanceMap;

  @override
  Future<Account?> add({
    required String idUser,
    required String name,
    String kind = 'other',
    AccountIcon icon = AccountIcon.other,
    String color = '#7C5CFF',
    double openingBalance = 0,
  }) async {
    creates.add((name: name, opening: openingBalance));
    if (failNextAdd) {
      failNextAdd = false;
      return null;
    }
    final created = Account(
        id: 'acc-${_seq++}',
        userId: idUser,
        name: name,
        kind: kind,
        icon: icon,
        color: color);
    rows.add(created);
    // The opening entry lands in the same store call as the account, which is
    // what the real create_account_with_opening function does in one
    // transaction.
    if (openingBalance > 0) balanceMap[created.id] = openingBalance;
    return created;
  }

  @override
  Future<Account?> update({
    required String id,
    required String name,
    String kind = 'other',
    AccountIcon icon = AccountIcon.other,
    String color = '#7C5CFF',
  }) async =>
      null;
}

class _FakeHome extends CHome {
  @override
  Future<void> getAnalysis(String idUser) async {}
  @override
  double get totalBalance => super.totalBalance + 1000000;
  @override
  List<double> get week =>
      [for (var i = 0; i < super.week.length; i++) 0.0];
  @override
  double get monthIncome => super.monthIncome + 1;
  @override
  double get monthOutcome => super.monthOutcome + 1;
  @override
  double get differentMonth => super.differentMonth + 1;
  @override
  String get percentIncome => '${super.percentIncome}0';
  @override
  String get monthPercent => '${super.monthPercent}x';
}

class _OfflineHistory extends CHistory {
  @override
  Future<void> getList(String idUser) async {}
}

void main() {
  late _FakeStore store;
  late CAccounts accounts;

  setUpAll(() => initializeDateFormatting('id_ID'));

  setUp(() {
    Get.testMode = true;
    Get.put(CUser()).setData(const User(idUser: 'u1', name: 'Davin'));
    Get.put<CHome>(_FakeHome());
    store = _FakeStore();
    accounts = Get.put<CAccounts>(CAccounts(store: store));
    accounts.accounts.addAll(const [
      Account(id: 'acc-cash', userId: 'u1', name: 'Cash', icon: AccountIcon.cash),
    ]);
    store.rows.addAll(accounts.accounts);
    store.balanceMap['acc-cash'] = 425000;
    accounts.balances['acc-cash'] = 425000;
    Get.put<CHistory>(_OfflineHistory());
  });

  tearDown(Get.reset);

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GetMaterialApp(home: MainShell()));
    await tester.pumpAndSettle();
    // Wallet is where accounts are created.
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
  }

  Future<void> createAccount(WidgetTester tester, String name,
      {String? opening}) async {
    await tester.tap(find.byKey(const Key('wallet_add_account')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, name);
    if (opening != null) {
      await tester.enterText(
          find.byKey(const Key('account_opening_field')), opening);
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save account'));
    await tester.pumpAndSettle();
  }

  // ------------------------------------------------- 1. the refresh bug

  testWidgets('a new account appears on Wallet and Home without a restart',
      (tester) async {
    await pumpShell(tester);
    expect(find.byKey(const Key('wallet_account_acc-0')), findsNothing);

    await createAccount(tester, 'GoPay');

    // Sheet closed, and the grid already shows the new card: the controller
    // refreshed its own list, so nothing had to re-fetch or re-navigate.
    expect(find.text('New account'), findsNothing);
    expect(find.byKey(const Key('wallet_account_acc-0')), findsOneWidget);
    expect(find.text('GoPay'), findsOneWidget);
    expect(find.text('2 accounts'), findsOneWidget);

    // Home reads the same controller: its carousel grew a page for it.
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('carousel_dot_2')), findsOneWidget);
  });

  testWidgets('a failed create keeps the sheet open and explains itself',
      (tester) async {
    await pumpShell(tester);
    store.failNextAdd = true;

    await createAccount(tester, 'GoPay');

    // Still open, still holding what was typed, and saying what happened.
    expect(find.text('New account'), findsOneWidget);
    expect(find.byKey(const Key('account_save_error')), findsOneWidget);
    expect(find.text('GoPay'), findsWidgets);
    // And nothing was added to the grid.
    expect(find.byKey(const Key('wallet_account_acc-0')), findsNothing);
  });

  // --------------------------------------------- 2. Saldo Awal behaviour

  testWidgets('a starting balance creates the account and its entry together',
      (tester) async {
    await pumpShell(tester);

    await createAccount(tester, 'GoPay', opening: '250000');

    expect(store.creates, hasLength(1));
    expect(store.creates.single.name, 'GoPay');
    // One call carried both, so they cannot come apart.
    expect(store.creates.single.opening, 250000);
    expect(find.byKey(const Key('wallet_account_acc-0')), findsOneWidget);
    // The opening balance is what that account holds.
    expect(find.text('Rp 250.000,00'), findsOneWidget);
  });

  testWidgets('a blank starting balance writes no entry and no phantom',
      (tester) async {
    await pumpShell(tester);

    await createAccount(tester, 'GoPay');

    expect(store.creates, hasLength(1));
    expect(store.creates.single.opening, 0);
    expect(store.balanceMap['acc-0'], isNull);
    expect(find.text('Rp 0,00'), findsOneWidget);
  });

  testWidgets('the starting-balance field formats as Rupiah while typing',
      (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byKey(const Key('wallet_add_account')));
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('account_opening_field'));
    await tester.enterText(field, '2500000');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, 'Rp 2.500.000');
  });

  test('an opening balance counts toward the balance and nothing else', () {
    final rows = [
      {
        'type': 'opening',
        'total': 500000,
        'account_id': 'a',
        'transfer_to_account_id': null,
      },
      {
        'type': 'income',
        'total': 100000,
        'account_id': 'a',
        'transfer_to_account_id': null,
      },
      {
        'type': 'expense',
        'total': 40000,
        'account_id': 'a',
        'transfer_to_account_id': null,
      },
      {
        'type': 'transfer',
        'total': 25000,
        'account_id': 'a',
        'transfer_to_account_id': 'b',
      },
    ];

    // Included in balances: 500000 + 100000 - 40000 - 25000.
    final balances = AccountBalance.apply(rows);
    expect(balances['a'], 535000);
    expect(balances['b'], 25000);

    // Excluded from income/expense totals: the aggregates name their types,
    // and 'opening' is not one of them.
    expect(History.incomeExpenseDbTypes, ['income', 'expense']);
    expect(History.incomeExpenseDbTypes, isNot(contains(History.dbOpening)));
    expect(History.incomeExpenseDbTypes, isNot(contains(History.dbTransfer)));

    // The opening row is its own UI type, not a disguised income entry.
    expect(History.typeToDb('Saldo Awal'), 'opening');
    expect(History.typeFromDb('opening'), 'Saldo Awal');

    final opening = History.fromSupabase({
      'id': 't1',
      'type': 'opening',
      'date': '2026-09-17',
      'total': 500000,
      'account_id': 'a',
      'items': [
        {'name': 'Saldo Awal', 'price': '500000'}
      ],
    });
    expect(opening.isOpening, isTrue);
    expect(opening.isTransfer, isFalse);
    expect(opening.type, 'Saldo Awal');
  });
}
