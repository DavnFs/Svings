import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:cause_money_record/config/app_account_icon.dart';
import 'package:cause_money_record/config/app_category.dart';
import 'package:cause_money_record/config/app_history_view.dart';
import 'package:cause_money_record/data/model/account.dart';
import 'package:cause_money_record/data/model/history.dart';
import 'package:cause_money_record/presentation/controller/c_accounts.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/controller/history/c_history.dart';
import 'package:cause_money_record/presentation/page/history/history_page.dart';

/// Transactions list contract:
///
/// - day sections: today and yesterday are named, older days keep their year,
///   sections run newest-first and a day keeps its incoming row order;
/// - the account filter composes with the type filter instead of replacing it;
/// - a transfer read while filtered to one account shows that account's side of
///   it (money in versus money out), and is never hidden;
/// - rows still lead with the description and its category, signed and coloured.
///
/// No network: the list is seeded and the fetch is stubbed out.
class _OfflineHistory extends CHistory {
  @override
  Future<void> getList(String idUser) async {}
}

String _iso(DateTime d) =>
    DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, d.day));

History _tx({
  required String type,
  required double total,
  required String item,
  String? from,
  String? to,
  String date = '2026-09-14',
}) =>
    History(
      idHistory: 'h-$type-$item-$date',
      type: type,
      date: date,
      total: total,
      items: [HistoryItem(name: item, price: total.toString())],
      accountId: from,
      transferToAccountId: to,
    );

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  setUp(() {
    Get.testMode = true;
    Get.put(CUser());
    Get.put(CAccounts()).accounts.addAll(const [
      Account(
          id: 'acc-cash', userId: 'u1', name: 'Cash', icon: AccountIcon.cash),
      Account(
          id: 'acc-bank', userId: 'u1', name: 'Bank', icon: AccountIcon.bank),
    ]);
  });

  tearDown(Get.reset);

  // ---------------------------------------------------------------- grouping

  test('day sections split on today, yesterday and older in local time', () {
    final now = DateTime(2026, 11, 19, 23, 30);
    final rows = [
      _tx(type: 'Pengeluaran', total: 1000, item: 'Late', date: _iso(now)),
      _tx(
        type: 'Pengeluaran',
        total: 2000,
        item: 'Midnight',
        date: _iso(DateTime(2026, 11, 18, 0, 5)),
      ),
      _tx(
        type: 'Pengeluaran',
        total: 3000,
        item: 'Older',
        date: _iso(DateTime(2025, 12, 31)),
      ),
    ];

    final groups = AppHistoryView.groupByDay(rows, now: now);

    expect(groups.map((g) => g.label).toList(),
        ['Hari ini', 'Kemarin', '31 Desember 2025']);
    // A day past midnight is yesterday, not today: the boundary is the calendar
    // day in local time, not a 24h window from "now".
    expect(groups[1].items.single.items.first.name, 'Midnight');
    // Newest section first, and the year survives for older entries.
    expect(groups.first.day, DateTime(2026, 11, 19));
    expect(groups.last.day, DateTime(2025, 12, 31));
  });

  test('sections are reverse-chronological and a day keeps its row order', () {
    final now = DateTime(2026, 11, 19, 12);
    final rows = [
      _tx(type: 'Pemasukan', total: 1, item: 'Today A', date: _iso(now)),
      _tx(type: 'Pemasukan', total: 2, item: 'Today B', date: _iso(now)),
      _tx(
        type: 'Pemasukan',
        total: 3,
        item: 'Yesterday',
        date: _iso(DateTime(2026, 11, 18)),
      ),
    ];

    final groups = AppHistoryView.groupByDay(rows, now: now);

    expect(groups, hasLength(2));
    expect(groups.first.label, 'Hari ini');
    expect(
      groups.first.items.map((h) => h.items.first.name).toList(),
      ['Today A', 'Today B'],
      reason: 'the ledger carries no time, so the query order is preserved',
    );
    expect(groups.last.label, 'Kemarin');
  });

  test('a row with an unparseable date still gets a section', () {
    final groups = AppHistoryView.groupByDay(
      [_tx(type: 'Pengeluaran', total: 500, item: 'Broken', date: '')],
      now: DateTime(2026, 11, 19),
    );

    expect(groups, hasLength(1));
    expect(groups.single.items.single.items.first.name, 'Broken');
  });

  test('label keeps the year, and names the two days people compare', () {
    final today = DateTime(2026, 11, 19);
    expect(AppHistoryView.dayLabel(DateTime(2026, 11, 19), today), 'Hari ini');
    expect(AppHistoryView.dayLabel(DateTime(2026, 11, 18), today), 'Kemarin');
    expect(
      AppHistoryView.dayLabel(DateTime(2026, 11, 17), today),
      '17 November 2026',
    );
    // Month and year rollovers are still yesterday.
    expect(
      AppHistoryView.dayLabel(DateTime(2026, 10, 31), DateTime(2026, 11, 1)),
      'Kemarin',
    );
  });

  // -------------------------------------------------------- transfer legs

  test('a filtered transfer reads from the filtered account side', () {
    final intoBank = _tx(
      type: 'Transfer',
      total: 250000,
      item: 'Transfer',
      from: 'acc-cash',
      to: 'acc-bank',
    );

    expect(
        AppHistoryView.transferLeg(intoBank, 'acc-bank'), TransferLeg.incoming);
    expect(
        AppHistoryView.transferLeg(intoBank, 'acc-cash'), TransferLeg.outgoing);
    // Neither an unfiltered list nor an unrelated account has a side to show.
    expect(AppHistoryView.transferLeg(intoBank, null), TransferLeg.neutral);
    expect(
        AppHistoryView.transferLeg(intoBank, 'acc-other'), TransferLeg.neutral);
    // Income and expense are already directional; the leg never applies.
    final income = _tx(type: 'Pemasukan', total: 1000, item: 'Gaji');
    expect(AppHistoryView.transferLeg(income, 'acc-bank'), TransferLeg.neutral);
  });

  test('a transfer belongs to both of its accounts', () {
    final transfer = _tx(
      type: 'Transfer',
      total: 250000,
      item: 'Transfer',
      from: 'acc-cash',
      to: 'acc-bank',
    );

    expect(AppHistoryView.touchesAccount(transfer, 'acc-cash'), isTrue);
    expect(AppHistoryView.touchesAccount(transfer, 'acc-bank'), isTrue);
    expect(AppHistoryView.touchesAccount(transfer, 'acc-other'), isFalse);
    expect(AppHistoryView.touchesAccount(transfer, null), isTrue);
  });

  // ------------------------------------------------------------ the screen

  Future<void> pumpList(WidgetTester tester, List<History> rows) async {
    final history = Get.put<CHistory>(_OfflineHistory());
    history.list.addAll(rows);
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: HistoryBody())),
    );
    await tester.pumpAndSettle();
  }

  ColorScheme schemeOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(HistoryBody))).colorScheme;

  List<History> mixedRows() {
    final now = DateTime.now();
    return [
      _tx(
        type: 'Pengeluaran',
        total: 21500,
        item: 'Nasi Goreng',
        date: _iso(now),
      ),
      _tx(
        type: 'Pemasukan',
        total: 5000000,
        item: 'Gaji September',
        date: _iso(now.subtract(const Duration(days: 1))),
      ),
      _tx(
        type: 'Transfer',
        total: 250000,
        item: 'Transfer',
        from: 'acc-cash',
        to: 'acc-bank',
        date: _iso(now.subtract(const Duration(days: 40))),
      ),
    ];
  }

  testWidgets('the list renders day sections with their headings',
      (tester) async {
    await pumpList(tester, mixedRows());

    expect(find.text('Hari ini'), findsOneWidget);
    expect(find.text('Kemarin'), findsOneWidget);
    // Older entries are dated, year included.
    expect(find.textContaining(RegExp(r'\d{4}')), findsWidgets);
    expect(find.text('Nasi Goreng'), findsOneWidget);
    expect(find.text('Gaji September'), findsOneWidget);

    // Newest section comes first.
    expect(
      tester.getTopLeft(find.text('Hari ini')).dy,
      lessThan(tester.getTopLeft(find.text('Kemarin')).dy),
    );
  });

  testWidgets('the type filter still narrows the list', (tester) async {
    await pumpList(tester, mixedRows());

    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    expect(find.text('Gaji September'), findsOneWidget);
    expect(find.text('Nasi Goreng'), findsNothing);
    // Grouping applies to whatever the filter left: only yesterday remains.
    expect(find.text('Kemarin'), findsOneWidget);
    expect(find.text('Hari ini'), findsNothing);
  });

  testWidgets('the account pill filters, and composes with the type filter',
      (tester) async {
    await pumpList(tester, mixedRows());

    // Defaults to every account.
    expect(find.text('Semua Akun'), findsOneWidget);

    await tester.tap(find.byKey(const Key('account_filter_pill')));
    await tester.pumpAndSettle();
    expect(find.text('Filter by account'), findsOneWidget);
    await tester.tap(find.byKey(const Key('account_option_acc-bank')));
    await tester.pumpAndSettle();

    // Bank's own rows plus the transfer that lands in it; nothing else. The
    // transfer reads as money in, because that is what it is for Bank.
    expect(find.text('Bank'), findsOneWidget);
    expect(find.text('Gaji September'), findsNothing);
    expect(find.text('Nasi Goreng'), findsNothing);
    expect(find.text('+Rp 250.000,00'), findsOneWidget);

    // Both filters on at once: Cash + income leaves nothing.
    await tester.tap(find.byKey(const Key('account_filter_pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account_option_acc-cash')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No Income Entries'), findsOneWidget);
  });

  testWidgets('a filtered transfer shows the filtered account side',
      (tester) async {
    await pumpList(tester, [
      _tx(
        type: 'Transfer',
        total: 250000,
        item: 'Transfer',
        from: 'acc-cash',
        to: 'acc-bank',
        date: _iso(DateTime.now()),
      ),
    ]);
    final scheme = schemeOf(tester);

    // Unfiltered: a wash, so no sign and a neutral colour.
    expect(find.text('Rp 250.000,00'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Rp 250.000,00')).style?.color,
      scheme.onSurfaceVariant,
    );

    // Into Bank: money in for the account in view.
    await tester.tap(find.byKey(const Key('account_filter_pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account_option_acc-bank')));
    await tester.pumpAndSettle();
    expect(find.text('+Rp 250.000,00'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('+Rp 250.000,00')).style?.color,
      scheme.tertiary,
    );

    // Out of Cash: the same transaction, the other side of it.
    await tester.tap(find.byKey(const Key('account_filter_pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account_option_acc-cash')));
    await tester.pumpAndSettle();
    expect(find.text('-Rp 250.000,00'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('-Rp 250.000,00')).style?.color,
      scheme.error,
    );
  });

  testWidgets('rows lead with the description and name the category',
      (tester) async {
    await pumpList(tester, mixedRows());

    expect(find.text('Nasi Goreng'), findsOneWidget);
    expect(find.text('Food & Drink'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    // A transfer shows where the money went rather than "Transfer" twice.
    expect(find.textContaining('Cash'), findsWidgets);
    expect(find.textContaining('→'), findsOneWidget);
  });

  testWidgets('income and expense keep their sign and colour', (tester) async {
    await pumpList(tester, mixedRows());
    final scheme = schemeOf(tester);

    expect(
      tester.widget<Text>(find.text('+Rp 5.000.000,00')).style?.color,
      scheme.tertiary,
    );
    expect(
      tester.widget<Text>(find.text('-Rp 21.500,00')).style?.color,
      scheme.error,
    );
  });

  test('category keywords map, and unknown names never invent one', () {
    expect(
        AppCategory.label('Nasi Goreng', type: 'Pengeluaran'), 'Food & Drink');
    expect(
        AppCategory.label('Gojek ke kampus', type: 'Pengeluaran'), 'Transport');
    expect(AppCategory.label('Gaji September', type: 'Pemasukan'), 'Salary');
    expect(AppCategory.label('Sesuatu', type: 'Pengeluaran'), 'Expense');
    expect(AppCategory.icon('Transfer', type: 'Transfer'),
        Icons.swap_horiz_rounded);
  });
}
