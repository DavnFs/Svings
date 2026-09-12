/// A money-tracker entry (Pemasukan / Pengeluaran).
///
/// Maps to `public.transactions` in Supabase.
class History {
  final String? idHistory;
  final String? idUser;
  final String type;          // 'Pemasukan' / 'Pengeluaran'  (UI label)
  final String date;          // 'yyyy-MM-dd'
  final double total;
  final String? notes;
  final List<HistoryItem> items;
  final String? createdAt;
  final String? updatedAt;

  History({
    this.idHistory,
    this.idUser,
    required this.type,
    required this.date,
    required this.total,
    this.notes,
    this.items = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory History.fromSupabase(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List? ?? const [];
    return History(
      idHistory: json['id']?.toString(),
      idUser: json['user_id']?.toString(),
      type: (json['type'] == 'income') ? 'Pemasukan' : 'Pengeluaran',
      date: (json['date'] as String?)?.split('T').first ?? '',
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      items: itemsJson
          .whereType<Map<String, dynamic>>()
          .map((e) => HistoryItem.fromJson(e))
          .toList(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toSupabaseInsert() => {
        'type': type == 'Pemasukan' ? 'income' : 'expense',
        'date': date,
        'total': total,
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
      };
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
