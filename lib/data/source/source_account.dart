import 'package:cause_money_record/config/supabase_config.dart';
import 'package:cause_money_record/data/model/account.dart';

/// Reads and writes `public.accounts`.
///
/// Balances are NOT stored: [balances] derives each account's balance from
/// the transaction ledger (income +, expense −, transfer-out −, transfer-in
/// +), so the numbers can never drift from history.
class SourceAccount {
  static get _client => SupabaseConfig.client;

  /// All accounts for a user, oldest first (default "Lainnya" first).
  static Future<List<Account>> list(String idUser) async {
    try {
      final resp = await _client
          .from('accounts')
          .select()
          .eq('user_id', idUser)
          .order('created_at', ascending: true);
      return (resp as List)
          .map((e) => Account.fromSupabase(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Ensures the default account exists and returns it. Called on Home load
  /// so pre-migration users (no accounts row yet) get "Lainnya" without a
  /// separate migration step in the app.
  static Future<Account?> ensureDefault(String idUser) async {
    try {
      final existing = await _client
          .from('accounts')
          .select()
          .eq('user_id', idUser)
          .eq('name', Account.defaultName)
          .maybeSingle();
      if (existing != null) return Account.fromSupabase(existing);
      final inserted = await _client
          .from('accounts')
          .insert({
            'user_id': idUser,
            'name': Account.defaultName,
            'kind': 'other',
            'icon': '💰',
            'color': '#7C5CFF',
          })
          .select()
          .single();
      return Account.fromSupabase(inserted);
    } catch (_) {
      return null;
    }
  }

  static Future<Account?> add({
    required String idUser,
    required String name,
    String kind = 'other',
    String icon = '💰',
    String color = '#7C5CFF',
  }) async {
    try {
      final resp = await _client
          .from('accounts')
          .insert({
            'user_id': idUser,
            'name': name.trim(),
            'kind': kind,
            'icon': icon,
            'color': color,
          })
          .select()
          .single();
      return Account.fromSupabase(resp);
    } catch (_) {
      return null;
    }
  }

  /// Renames / re-skins an account. Balance untouched — it is derived from
  /// the ledger, so editing metadata can never move money.
  static Future<Account?> update({
    required String id,
    required String name,
    String kind = 'other',
    String icon = '💰',
    String color = '#7C5CFF',
  }) async {
    try {
      final resp = await _client
          .from('accounts')
          .update({
            'name': name.trim(),
            'kind': kind,
            'icon': icon,
            'color': color,
          })
          .eq('id', id)
          .select()
          .single();
      return Account.fromSupabase(resp);
    } catch (_) {
      return null;
    }
  }

  /// Derived balances: account id -> balance. Income adds, expense subtracts,
  /// transfer subtracts from source and adds to destination. Transfers never
  /// touch income/expense totals — that exclusion lives in the analysis
  /// queries, but the balance math here must count both transfer legs or the
  /// aggregate total would leak money.
  static Future<Map<String, double>> balances(String idUser) async {
    try {
      final resp = await _client
          .from('transactions')
          .select('type, total, account_id, transfer_to_account_id')
          .eq('user_id', idUser);
      final out = <String, double>{};
      for (final row in (resp as List)) {
        final total = ((row as Map)['total'] as num).toDouble();
        switch (row['type']) {
          case 'income':
            final id = row['account_id']?.toString();
            if (id != null) out[id] = (out[id] ?? 0) + total;
          case 'expense':
            final id = row['account_id']?.toString();
            if (id != null) out[id] = (out[id] ?? 0) - total;
          case 'transfer':
            final from = row['account_id']?.toString();
            final to = row['transfer_to_account_id']?.toString();
            if (from != null) out[from] = (out[from] ?? 0) - total;
            if (to != null) out[to] = (out[to] ?? 0) + total;
        }
      }
      return out;
    } catch (_) {
      return {};
    }
  }
}
