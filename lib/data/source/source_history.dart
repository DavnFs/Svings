import 'package:intl/intl.dart';
import 'package:cause_money_record/config/supabase_config.dart';
import 'package:cause_money_record/data/model/history.dart';

/// Money-tracker queries against `public.transactions` in Supabase.
class SourceHistory {
  static get _client => SupabaseConfig.client;

  /// Aggregated analysis data for the home dashboard.
  ///
  /// Returns:
  /// ```
  /// {
  ///   'today':     double,
  ///   'todayId':   String?,   // id of the newest expense today, null if none
  ///   'yesterday': double,
  ///   'week':      [double, ... 7 items, oldest -> today],
  ///   'month':     { 'income': double, 'outcome': double }
  /// }
  /// ```
  static Future<Map> analysis(String idUser) async {
    try {
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      final yesterday =
          DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
      final firstOfMonth = DateFormat('yyyy-MM-01').format(now);
      final lastOfMonth = DateFormat('yyyy-MM-dd')
          .format(DateTime(now.year, now.month + 1, 0));

      // Today expense (id retained so the dashboard can link to the entry)
      final todayResp = await _client
          .from('transactions')
          .select('id, total')
          .eq('user_id', idUser)
          .eq('type', 'expense')
          .eq('date', today)
          .order('created_at', ascending: false);
      final todayTotal = _sum(todayResp);
      final todayId = todayResp.isEmpty ? null : todayResp.first['id'] as String?;

      // Yesterday expense
      final yesterdayResp = await _client
          .from('transactions')
          .select('total')
          .eq('user_id', idUser)
          .eq('type', 'expense')
          .eq('date', yesterday);
      final yesterdayTotal = _sum(yesterdayResp);

      // Last 7 days
      final sevenDaysAgo =
          DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 6)));
      final weekResp = await _client
          .from('transactions')
          .select('date, total')
          .eq('user_id', idUser)
          .eq('type', 'expense')
          .gte('date', sevenDaysAgo)
          .lte('date', today);
      final byDate = <String, double>{};
      for (final row in weekResp) {
        final d = (row['date'] as String).split('T').first;
        byDate[d] = (byDate[d] ?? 0) + ((row['total'] as num).toDouble());
      }
      final week = List<double>.generate(7, (i) {
        final d = DateFormat('yyyy-MM-dd')
            .format(now.subtract(Duration(days: 6 - i)));
        return byDate[d] ?? 0.0;
      });

      // This month income + expense
      final monthResp = await _client
          .from('transactions')
          .select('type, total')
          .eq('user_id', idUser)
          .gte('date', firstOfMonth)
          .lte('date', lastOfMonth);
      double income = 0, outcome = 0;
      for (final row in monthResp) {
        if (row['type'] == 'income') {
          income += (row['total'] as num).toDouble();
        } else {
          outcome += (row['total'] as num).toDouble();
        }
      }

      return {
        'today': todayTotal,
        'todayId': todayId,
        'yesterday': yesterdayTotal,
        'week': week,
        'month': {'income': income, 'outcome': outcome},
      };
    } catch (e) {
      // Return empty shape on failure so the UI can render zeros
      return {
        'today': 0.0,
        'todayId': null,
        'yesterday': 0.0,
        'week': List<double>.filled(7, 0.0),
        'month': {'income': 0.0, 'outcome': 0.0},
      };
    }
  }

  /// Add a new transaction. `idUser` is the auth user id.
  static Future<bool> add({
    required String idUser,
    required String date,
    required String type,         // 'Pemasukan' or 'Pengeluaran'
    required List<HistoryItem> items,
    String? notes,
  }) async {
    final total = items.fold<double>(0, (sum, i) => sum + (double.tryParse(i.price) ?? 0));
    try {
      await _client.from('transactions').insert({
        'user_id': idUser,
        'type': type == 'Pemasukan' ? 'income' : 'expense',
        'date': date,
        'total': total,
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Update an existing transaction.
  static Future<bool> update({
    required String idHistory,
    required String idUser,
    required String date,
    required String type,
    required List<HistoryItem> items,
    String? notes,
  }) async {
    final total = items.fold<double>(0, (sum, i) => sum + (double.tryParse(i.price) ?? 0));
    try {
      await _client.from('transactions').update({
        'date': date,
        'type': type == 'Pemasukan' ? 'income' : 'expense',
        'total': total,
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
      }).eq('id', idHistory).eq('user_id', idUser);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Delete a transaction.
  static Future<bool> delete(String idHistory) async {
    try {
      await _client.from('transactions').delete().eq('id', idHistory);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Fetch all transactions for a user, newest first.
  static Future<List<History>> history(String idUser) async {
    try {
      final resp = await _client
          .from('transactions')
          .select()
          .eq('user_id', idUser)
          .order('date', ascending: false)
          .order('created_at', ascending: false);
      return (resp as List)
          .map((e) => History.fromSupabase(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch a single transaction by its id.
  ///
  /// Replaces the old `whereDate`/`detail` pair, which both returned "the first
  /// row for this date" — ambiguous, since `transactions` has no unique
  /// constraint on (user_id, date, type), so an edit could hit the wrong row.
  /// RLS (`transactions_select_own`) already scopes this to the caller's rows.
  static Future<History?> byId(String idHistory) async {
    try {
      final resp = await _client
          .from('transactions')
          .select()
          .eq('id', idHistory)
          .maybeSingle();
      if (resp == null) return null;
      return History.fromSupabase(resp);
    } catch (_) {
      return null;
    }
  }

  /// Fetch transactions filtered by type ('Pemasukan' or 'Pengeluaran').
  static Future<List<History>> incomeOutcome(String idUser, String type) async {
    final dbType = type == 'Pemasukan' ? 'income' : 'expense';
    try {
      final resp = await _client
          .from('transactions')
          .select()
          .eq('user_id', idUser)
          .eq('type', dbType)
          .order('date', ascending: false);
      return (resp as List)
          .map((e) => History.fromSupabase(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ---------------------------------------------------------------------
  // helpers
  // ---------------------------------------------------------------------
  static double _sum(List<dynamic> rows) {
    double total = 0;
    for (final r in rows) {
      total += ((r as Map)['total'] as num).toDouble();
    }
    return total;
  }
}
