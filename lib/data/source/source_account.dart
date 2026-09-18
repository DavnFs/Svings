import 'package:intl/intl.dart';

import 'package:cause_money_record/config/app_account_icon.dart';
import 'package:cause_money_record/config/supabase_config.dart';
import 'package:cause_money_record/data/model/account.dart';
import 'package:cause_money_record/data/model/account_balance.dart';

/// Where accounts are read and written.
///
/// A seam, not an abstraction for its own sake: it is what lets a test drive the
/// real create-account flow (sheet → controller → store) and watch the list
/// update, instead of injecting an account straight into the controller and
/// testing nothing. Same pattern [CSettings] uses for preferences.
abstract class AccountsStore {
  Future<List<Account>> list(String idUser);
  Future<Account?> ensureDefault(String idUser);
  Future<Account?> add({
    required String idUser,
    required String name,
    String kind,
    AccountIcon icon,
    String color,
    double openingBalance,
  });
  Future<Account?> update({
    required String id,
    required String name,
    String kind,
    AccountIcon icon,
    String color,
  });
  Future<Map<String, double>> balances(String idUser);
}

/// The real store: Supabase, through [SourceAccount].
class SupabaseAccountsStore implements AccountsStore {
  const SupabaseAccountsStore();

  @override
  Future<List<Account>> list(String idUser) => SourceAccount.list(idUser);

  @override
  Future<Account?> ensureDefault(String idUser) =>
      SourceAccount.ensureDefault(idUser);

  @override
  Future<Account?> add({
    required String idUser,
    required String name,
    String kind = 'other',
    AccountIcon icon = AccountIcon.other,
    String color = '#7C5CFF',
    double openingBalance = 0,
  }) =>
      SourceAccount.add(
        idUser: idUser,
        name: name,
        kind: kind,
        icon: icon,
        color: color,
        openingBalance: openingBalance,
      );

  @override
  Future<Account?> update({
    required String id,
    required String name,
    String kind = 'other',
    AccountIcon icon = AccountIcon.other,
    String color = '#7C5CFF',
  }) =>
      SourceAccount.update(
          id: id, name: name, kind: kind, icon: icon, color: color);

  @override
  Future<Map<String, double>> balances(String idUser) =>
      SourceAccount.balances(idUser);
}

/// Reads and writes `public.accounts`.
///
/// The `Source` prefix is this project's name for the DATA SOURCE layer
/// (SourceUser, SourceHistory, SourceEmail) — it has nothing to do with a
/// transfer's "source account", which is [Account] + `accountId` everywhere.
/// The word "source" also appears as [History.source], the transaction's ORIGIN
/// ('manual' vs an imported email). Three meanings, three separate names:
/// account = money account, source = where a transaction came from,
/// Source* = which table it is read from.
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
            // A key, not a glyph: the app maps it to a bundled vector icon.
            'icon': AccountIcon.savings.key,
            'color': '#7C5CFF',
          })
          .select()
          .single();
      return Account.fromSupabase(inserted);
    } catch (_) {
      return null;
    }
  }

  /// Creates the account, and with it the opening-balance entry when
  /// [openingBalance] is positive.
  ///
  /// One server-side function, so the account and its entry are one
  /// transaction: a failure between them would otherwise leave an account whose
  /// balance has no entry behind it, or an entry pointing at an account that
  /// does not exist. A zero opening writes no entry at all — not an entry for
  /// zero — so the ledger shows nothing to explain.
  static Future<Account?> add({
    required String idUser,
    required String name,
    String kind = 'other',
    AccountIcon icon = AccountIcon.other,
    String color = '#7C5CFF',
    double openingBalance = 0,
  }) async {
    try {
      final resp = await _client.rpc('create_account_with_opening', params: {
        'p_user': idUser,
        'p_name': name.trim(),
        'p_kind': kind,
        'p_icon': icon.key,
        'p_color': color,
        'p_opening': openingBalance,
        'p_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });
      // A function returning a composite type comes back as one object; guard
      // for a one-element list in case the signature changes to setof.
      final row = resp is List ? (resp.isEmpty ? null : resp.first) : resp;
      if (row == null) return null;
      return Account.fromSupabase((row as Map).cast<String, dynamic>());
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
    AccountIcon icon = AccountIcon.other,
    String color = '#7C5CFF',
  }) async {
    try {
      final resp = await _client
          .from('accounts')
          .update({
            'name': name.trim(),
            'kind': kind,
            'icon': icon.key,
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

  /// Derived balances: account id -> balance. Income and an opening balance
  /// add, expense subtracts, and a transfer moves money between its two
  /// accounts. Transfers never touch income/expense totals — that exclusion
  /// lives in the analysis queries, but the balance math here must count both
  /// transfer legs or the aggregate total would leak money.
  static Future<Map<String, double>> balances(String idUser) async {
    try {
      final resp = await _client
          .from('transactions')
          .select('type, total, account_id, transfer_to_account_id')
          .eq('user_id', idUser);
      return AccountBalance.apply(resp as List);
    } catch (_) {
      return {};
    }
  }
}
