import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/data/model/account.dart';
import 'package:cause_money_record/data/source/source_account.dart';

/// Accounts + derived balances for the Home dashboard.
///
/// Balances come from [SourceAccount.balances] (ledger-derived, never stored),
/// so this controller holds no money math of its own — just the account list,
/// the balance map, and their sum.
class CAccounts extends GetxController {
  final _loading = false.obs;
  bool get loading => _loading.value;

  final _error = RxnString();
  String? get error => _error.value;

  final _accounts = <Account>[].obs;
  List<Account> get accounts => _accounts;

  final _balances = <String, double>{}.obs;
  Map<String, double> get balances => _balances;

  /// Sum of every account balance. Transfers net to zero here (out of one,
  /// into another), so the aggregate is unaffected by moving money around.
  double get total => _balances.values.fold(0.0, (a, b) => a + b);

  double balanceOf(String accountId) => _balances[accountId] ?? 0.0;

  /// Parses '#RRGGBB' to a Color. Centralized so cards, sheets, and tests
  /// agree on fallback behavior for malformed values.
  static Color parseColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    final v = int.tryParse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
    return v == null ? const Color(0xFF7C5CFF) : Color(v);
  }

  Account? byId(String? id) {
    if (id == null) return null;
    for (final a in _accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Loads accounts (creating the default when missing) then balances.
  /// Safe to call on every Home build: idempotent, no duplicates.
  Future<void> getAccounts(String idUser) async {
    if (idUser.isEmpty) return;
    _loading.value = true;
    _error.value = null;
    try {
      await SourceAccount.ensureDefault(idUser);
      _accounts.assignAll(await SourceAccount.list(idUser));
      _balances.assignAll(await SourceAccount.balances(idUser));
    } catch (e) {
      _error.value = e.toString();
    } finally {
      _loading.value = false;
    }
  }

  Future<Account?> addAccount({
    required String idUser,
    required String name,
    String kind = 'other',
    String icon = '💰',
    String color = '#7C5CFF',
  }) async {
    final created = await SourceAccount.add(
      idUser: idUser,
      name: name,
      kind: kind,
      icon: icon,
      color: color,
    );
    if (created != null) await getAccounts(idUser);
    return created;
  }
}
