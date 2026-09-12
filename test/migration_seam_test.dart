import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/data/model/history.dart';

/// Covers the Supabase migration seam: money/date formatting and the
/// PHP-shaped -> Supabase-shaped model mapping that this rewrite replaced.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  group('AppFormat.currency', () {
    test('formats a double without a String round-trip', () {
      expect(AppFormat.currency(30000.0), contains('30.000'));
    });

    test('formats an int', () {
      expect(AppFormat.currency(1500000), contains('1.500.000'));
    });

    test('handles zero', () {
      expect(AppFormat.currency(0), contains('0'));
    });
  });

  group('AppFormat.date', () {
    test('formats an ISO date', () {
      expect(AppFormat.date('2026-09-12'), '12 Sep 2026');
    });

    test('returns unparseable input unchanged instead of throwing', () {
      // The old DateTime.parse('') threw inside build(). This is the guard.
      expect(AppFormat.date(''), '');
      expect(AppFormat.date('not-a-date'), 'not-a-date');
    });
  });

  group('History.fromSupabase', () {
    test('maps an expense row', () {
      final h = History.fromSupabase({
        'id': 'abc-123',
        'user_id': 'user-1',
        'type': 'expense',
        'date': '2026-09-12',
        'total': 45000,
        'notes': 'makan siang',
        'items': [
          {'name': 'Nasi + Lauk', 'price': '30000'},
          {'name': 'Es Teh', 'price': '15000'},
        ],
      });

      expect(h.idHistory, 'abc-123');
      expect(h.type, 'Pengeluaran');
      expect(h.date, '2026-09-12');
      expect(h.total, 45000.0);
      expect(h.notes, 'makan siang');
      expect(h.items, hasLength(2));
      expect(h.items.first.name, 'Nasi + Lauk');
    });

    test('maps an income row', () {
      final h = History.fromSupabase({
        'id': 'def-456',
        'type': 'income',
        'date': '2026-09-01',
        'total': 1500000,
        'items': [
          {'name': 'Uang Saku', 'price': '1500000'},
        ],
      });
      expect(h.type, 'Pemasukan');
    });

    test('keeps item price as the string the schema stores', () {
      // supabase/seed/99_demo_users.sql writes price as text and the view
      // aggregates with x->>'price', so the model must not coerce it to double.
      final h = History.fromSupabase({
        'id': 'x',
        'type': 'expense',
        'date': '2026-09-12',
        'total': 1000,
        'items': [
          {'name': 'Kopi', 'price': '15000'},
        ],
      });
      expect(h.items.single.price, isA<String>());
      expect(h.items.single.price, '15000');
    });

    test('strips a timestamp off the date field', () {
      final h = History.fromSupabase({
        'id': 'x',
        'type': 'expense',
        'date': '2026-09-12T00:00:00+07:00',
        'total': 1,
      });
      expect(h.date, '2026-09-12');
    });

    test('tolerates a missing items array', () {
      final h = History.fromSupabase({
        'id': 'x',
        'type': 'expense',
        'date': '2026-09-12',
        'total': 1,
      });
      expect(h.items, isEmpty);
    });
  });

  group('HistoryItem', () {
    test('round-trips through JSON', () {
      const item = HistoryItem(name: 'Bensin', price: '25000');
      final json = item.toJson();
      expect(json, {'name': 'Bensin', 'price': '25000'});
      expect(HistoryItem.fromJson(json).price, '25000');
    });
  });
}
