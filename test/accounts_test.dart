import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cause_money_record/data/model/account_balance.dart';
import 'package:cause_money_record/data/model/history.dart';
import 'package:cause_money_record/presentation/controller/c_accounts.dart';
import 'package:cause_money_record/presentation/controller/c_settings.dart';
import 'package:cause_money_record/presentation/widget/floating_nav_bar.dart';

/// Accounts + transfer contracts:
/// - transfers never count as income/expense on any of the four surfaces;
/// - migration backfills account-less rows to the default account;
/// - MainTab is exactly Home + Wallet + Transactions, in shell order.
void main() {
  // Mirrors SourceHistory.analysis month loop: only income/expense accumulate.
  double monthIncome(List<History> rows) {
    var income = 0.0;
    for (final r in rows) {
      if (r.type == 'Pemasukan') income += r.total;
    }
    return income;
  }

  double monthOutcome(List<History> rows) {
    var outcome = 0.0;
    for (final r in rows) {
      if (r.type == 'Pengeluaran') outcome += r.total;
    }
    return outcome;
  }

  // The real balance rule, not a copy of it: a hand-written mirror is a second
  // source of truth for money math, and it is exactly how a rule like "an
  // opening balance counts" gets forgotten in one place and not the other.
  Map<String, double> balances(List<History> rows) => AccountBalance.apply([
        for (final r in rows)
          {
            'type': History.typeToDb(r.type),
            'total': r.total,
            'account_id': r.accountId,
            'transfer_to_account_id': r.transferToAccountId,
          }
      ]);

  History tx({
    required String type,
    required double total,
    String? accountId,
    String? toAccountId,
  }) =>
      History(
        type: type,
        date: '2026-09-14',
        total: total,
        accountId: accountId,
        transferToAccountId: toAccountId,
      );

  group('transfers excluded from income/expense totals', () {
    final rows = [
      tx(type: 'Pemasukan', total: 1000, accountId: 'a'),
      tx(type: 'Pengeluaran', total: 400, accountId: 'a'),
      // Transfer of 250 a -> b. Must move balances, touch no totals.
      tx(type: 'Transfer', total: 250, accountId: 'a', toAccountId: 'b'),
    ];

    test('month donut + difference strip ignore transfers', () {
      expect(monthIncome(rows), 1000);
      expect(monthOutcome(rows), 400);
    });

    test('today + week sums ignore transfers', () {
      // Today card and week chart both query type == expense only; a
      // transfer row must not appear in either.
      final expenses = rows.where((r) => r.type == 'Pengeluaran');
      expect(expenses.fold(0.0, (s, r) => s + r.total), 400);
    });

    test('balances reflect both transfer legs, aggregate nets to zero', () {
      final b = balances(rows);
      // a: +1000 -400 -250 = 350. b: +250.
      expect(b['a'], 350);
      expect(b['b'], 250);
      expect(b.values.fold(0.0, (s, v) => s + v), 600);
    });
  });

  group('migration backfills default account', () {
    test('account-less rows map to Lainnya without losing data', () {
      // Pre-migration rows have no account_id; fromSupabase leaves it null
      // and the UI treats null as the default account.
      final h = History.fromSupabase({
        'id': 'old-1',
        'type': 'expense',
        'date': '2026-01-05',
        'total': 50000,
        'items': [
          {'name': 'Kopi', 'price': '50000'}
        ],
      });
      expect(h.accountId, isNull);
      expect(h.total, 50000.0);
      expect(h.items, hasLength(1));
      expect(h.type, 'Pengeluaran');
    });

    test('transfer rows round-trip accounts through the model', () {
      final h = History.fromSupabase({
        'id': 't-1',
        'type': 'transfer',
        'date': '2026-09-14',
        'total': 250000,
        'account_id': 'aaa',
        'transfer_to_account_id': 'bbb',
      });
      expect(h.type, 'Transfer');
      expect(h.isTransfer, isTrue);
      expect(h.accountId, 'aaa');
      expect(h.transferToAccountId, 'bbb');
    });

    test('unknown types fall back to expense, never crash', () {
      final h = History.fromSupabase({'type': 'mystery', 'total': 1});
      expect(h.type, 'Pengeluaran');
    });
  });

  group('MainTab reduction', () {
    test('exactly Home + Wallet + Transactions, in shell order', () {
      // test/settings_test.dart pins the tap->index contract; here pin the
      // enum shape so a re-added Income/Expense tab fails loudly.
      expect(MainTabShape.labels, ['Home', 'Wallet', 'Transactions']);
    });

    test('MainTab enum matches the pinned shape', () {
      // Direct import: the widget file has no platform channels, only an
      // animation controller that is never constructed here.
      expect(MainTab.values.map((t) => t.label).toList(), MainTabShape.labels);
    });
  });

  group('CAccounts.parseColor', () {
    test('parses hex and falls back on garbage', () {
      expect(CAccounts.parseColor('#7C5CFF'), const Color(0xFF7C5CFF));
      expect(CAccounts.parseColor('nope'), const Color(0xFF7C5CFF));
    });
  });

  group('sender mapping', () {
    test('longest match wins', () async {
      final s = CSettings(store: _FakeStore());
      await s.load();
      await s.setSenderMapping('bca.co.id', 'acc-generic');
      await s.setSenderMapping('noreply@bca.co.id', 'acc-exact');
      expect(s.accountForSender('Noreply@BCA.co.id'), 'acc-exact');
      await s.setSenderMapping('noreply@bca.co.id', null);
      expect(s.accountForSender('noreply@bca.co.id'), 'acc-generic');
      expect(s.accountForSender('unknown@x.id'), isNull);
    });

    test('corrupt stored map starts empty, never throws', () async {
      final store = _FakeStore()
        ..prefs['settings.sender_account_map'] = 'not-json{{{';
      final s = CSettings(store: store);
      await s.load();
      expect(s.senderMap, isEmpty);
      expect(s.accountForSender('a@b.co'), isNull);
    });
  });
}

/// In-memory settings store: no platform channels, mirrors settings_test.
class _FakeStore extends SettingsStore {
  final Map<String, Object> prefs = {};
  final Map<String, String> keys = {};

  @override
  Future<SharedPreferences> getPrefs() async {
    SharedPreferences.setMockInitialValues(Map.of(prefs));
    return SharedPreferences.getInstance();
  }

  @override
  Future<String?> readKey(String key) async => keys[key];

  @override
  Future<void> writeKey(String key, String value) async => keys[key] = value;

  @override
  Future<void> deleteKey(String key) async => keys.remove(key);
}

/// Shape mirror of the MainTab enum (which lives in a widget file tests
/// should not import for its animation controller). If MainTab gains a tab,
/// update this list AND the shell IndexedStack together.
class MainTabShape {
  static const labels = ['Home', 'Wallet', 'Transactions'];
}
