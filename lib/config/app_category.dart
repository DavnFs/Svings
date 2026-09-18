import 'package:flutter/material.dart';

/// Category for a transaction row: the label on the row's second line and the
/// glyph in its leading circle.
///
/// The ledger stores an item NAME, not a category, so the category is derived
/// from that name by keyword. That keeps the database untouched (no new column,
/// no migration, no backfill) and treats a transaction imported from email
/// exactly like a hand-typed one.
///
/// The rule list is deliberately small and ordered: the first keyword found in
/// the name wins, so a narrow match (a specific shop) can sit ahead of a broad
/// one (a general category word).
class AppCategory {
  AppCategory._();

  static const _rules = <(List<String>, String, IconData)>[
    (
      ['gaji', 'salary', 'bonus', 'thr', 'upah', 'honor'],
      'Salary',
      Icons.payments_outlined,
    ),
    (
      [
        'makan',
        'kopi',
        'nasi',
        'resto',
        'restaurant',
        'cafe',
        'kafe',
        'bakso',
        'ayam',
        'roti',
        'jajan',
        'snack',
        'food',
        'catering',
      ],
      'Food & Drink',
      Icons.restaurant_outlined,
    ),
    (
      [
        'indomaret',
        'alfamart',
        'supermarket',
        'grocer',
        'belanja',
        'sayur',
        'pasar',
        'minimarket',
      ],
      'Groceries',
      Icons.shopping_basket_outlined,
    ),
    (
      [
        'bensin',
        'pertalite',
        'pertamax',
        'transport',
        'ojek',
        'grab',
        'gojek',
        'tol',
        'parkir',
        'kereta',
        'bus',
        'tiket',
        'taksi',
        'taxi',
      ],
      'Transport',
      Icons.directions_car_outlined,
    ),
    (
      [
        'listrik',
        'token',
        'pulsa',
        'internet',
        'wifi',
        'pdam',
        'tagihan',
        'bpjs',
        'asuransi',
        'cicilan',
        'sewa',
        'iuran',
      ],
      'Bills',
      Icons.receipt_long_outlined,
    ),
    (
      ['obat', 'dokter', 'klinik', 'rumah sakit', 'apotek', 'vitamin'],
      'Health',
      Icons.medical_services_outlined,
    ),
    (
      ['buku', 'sekolah', 'kuliah', 'kursus', 'semester', 'ukt', 'tuition'],
      'Education',
      Icons.school_outlined,
    ),
    (
      ['netflix', 'spotify', 'game', 'steam', 'hiburan', 'bioskop', 'film'],
      'Entertainment',
      Icons.movie_outlined,
    ),
    (
      ['top up', 'topup', 'e-wallet', 'ewallet', 'dompet digital'],
      'Top Up',
      Icons.account_balance_wallet_outlined,
    ),
  ];

  /// Category label for [itemName]. Unmatched names fall back to the
  /// transaction's own kind, so a row never claims a category it does not have.
  static String label(String itemName, {required String type}) {
    final match = _match(itemName);
    if (match != null) return match.$2;
    return switch (type) {
      'Pemasukan' => 'Income',
      'Transfer' => 'Transfer',
      'Saldo Awal' => 'Saldo Awal',
      _ => 'Expense',
    };
  }

  /// Leading glyph for [itemName]. A transfer keeps its swap icon: direction of
  /// money is the useful signal there, not the merchant.
  static IconData icon(String itemName, {required String type}) {
    if (type == 'Transfer') return Icons.swap_horiz_rounded;
    // An opening balance starts the account rather than being spent from it.
    if (type == 'Saldo Awal') return Icons.flag_outlined;
    final match = _match(itemName);
    if (match != null) return match.$3;
    return type == 'Pemasukan'
        ? Icons.south_west_rounded
        : Icons.north_east_rounded;
  }

  static (List<String>, String, IconData)? _match(String itemName) {
    final name = itemName.toLowerCase();
    for (final rule in _rules) {
      for (final keyword in rule.$1) {
        if (name.contains(keyword)) return rule;
      }
    }
    return null;
  }
}
