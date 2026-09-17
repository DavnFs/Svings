/// A money account ("Sumber Dana"): a named, color-coded balance container.
///
/// Balance is DERIVED — income adds, expense subtracts, transfer-out
/// subtracts, transfer-in adds — computed by [SourceAccount.balances], never
/// stored. A stored balance column would drift from the transaction ledger;
/// the ledger is the single source of truth.
class Account {
  final String id;
  final String userId;
  final String name;

  /// 'bank' | 'e-wallet' | 'cash' | 'other'. Free text so new kinds need no
  /// migration.
  final String kind;

  /// Emoji/glyph shown on the card, e.g. '🏦'. No asset pipeline needed.
  final String icon;

  /// ARGB hex string, e.g. '#7C5CFF'.
  final String color;

  const Account({
    required this.id,
    required this.userId,
    required this.name,
    this.kind = 'other',
    this.icon = '💰',
    this.color = '#7C5CFF',
  });

  /// Every user gets one of these; pre-existing transactions are assigned to
  /// it on migration.
  static const defaultName = 'Lainnya';

  factory Account.fromSupabase(Map<String, dynamic> json) => Account(
        id: json['id'].toString(),
        userId: json['user_id'].toString(),
        name: json['name'] as String? ?? defaultName,
        kind: json['kind'] as String? ?? 'other',
        icon: json['icon'] as String? ?? '💰',
        color: json['color'] as String? ?? '#7C5CFF',
      );

  Map<String, dynamic> toInsert(String userId) => {
        'user_id': userId,
        'name': name,
        'kind': kind,
        'icon': icon,
        'color': color,
      };
}
