/// A money-tracker entry (Pemasukan / Pengeluaran / Transfer).
///
/// Maps to `public.transactions` in Supabase.
class History {
  final String? idHistory;
  final String? idUser;
  final String type;          // 'Pemasukan' / 'Pengeluaran' / 'Transfer' (UI label)
  final String date;          // 'yyyy-MM-dd'
  final double total;
  final String? notes;
  final List<HistoryItem> items;

  /// Owning account for income/expense; SOURCE account for transfers.
  final String? accountId;

  /// DESTINATION account for transfers; null otherwise.
  final String? transferToAccountId;

  /// 'manual' | 'email'. Drives the Settings auto-imports log filter.
  final String source;

  /// raw_emails row this came from, if any. Undo deletes the transaction
  /// and marks this email ignored so the next sync skips it.
  final String? rawEmailId;

  History({
    this.idHistory,
    this.idUser,
    required this.type,
    required this.date,
    required this.total,
    this.notes,
    this.items = const [],
    this.source = 'manual',
    this.rawEmailId,
    this.accountId,
    this.transferToAccountId,
  });

  bool get isAutoImported => source == 'email';

  /// Transfers move money between accounts; they are never income/expense.
  bool get isTransfer => type == 'Transfer';

  /// db value -> UI label. Unknown future values fall back to Pengeluaran
  /// (same as before: expense is the safe default for the confirmation UI).
  static String typeFromDb(String? db) => switch (db) {
        'income' => 'Pemasukan',
        'transfer' => 'Transfer',
        _ => 'Pengeluaran',
      };

  /// UI label -> db value.
  static String typeToDb(String ui) => switch (ui) {
        'Pemasukan' => 'income',
        'Transfer' => 'transfer',
        _ => 'expense',
      };

  factory History.fromSupabase(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List? ?? const [];
    return History(
      idHistory: json['id']?.toString(),
      idUser: json['user_id']?.toString(),
      type: typeFromDb(json['type'] as String?),
      date: (json['date'] as String?)?.split('T').first ?? '',
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      items: itemsJson
          .whereType<Map<String, dynamic>>()
          .map((e) => HistoryItem.fromJson(e))
          .toList(),
      source: json['source'] as String? ?? 'manual',
      rawEmailId: json['raw_email_id']?.toString(),
      accountId: json['account_id']?.toString(),
      transferToAccountId: json['transfer_to_account_id']?.toString(),
    );
  }
}

class HistoryItem {
  final String name;
  final String price;
  const HistoryItem({required this.name, required this.price});

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        name: json['name']?.toString() ?? '',
        price: json['price']?.toString() ?? '0',
      );

  Map<String, dynamic> toJson() => {'name': name, 'price': price};
}
