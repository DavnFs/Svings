/// Ledger rules for money, kept pure so the arithmetic that decides an
/// account's balance can be tested without a database.
///
/// Balance is always DERIVED from the transaction rows, never stored: a stored
/// balance column drifts from the ledger the first time a write half-succeeds,
/// and there would be no way to tell which of the two is right.
class AccountBalance {
  AccountBalance._();

  /// Balance per account id from raw `transactions` rows.
  ///
  /// - income adds, expense subtracts;
  /// - a transfer moves money out of its source and into its destination, so it
  ///   nets to zero across accounts;
  /// - an opening balance adds, and nets to nothing: the money really is in
  ///   that account, which is the whole point of recording it.
  ///
  /// An unknown row type changes nothing rather than being counted as spending,
  /// so a future type cannot silently corrupt every balance.
  static Map<String, double> apply(List<dynamic> rows) {
    final out = <String, double>{};
    for (final raw in rows) {
      final row = raw as Map;
      final total = (row['total'] as num?)?.toDouble() ?? 0;
      switch (row['type']) {
        case 'income':
        case 'opening':
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
  }
}
