import 'package:cause_money_record/config/app_account_icon.dart';

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

  /// A bundled vector icon, not a glyph: the database stores [AccountIcon.key],
  /// so a row's meaning never depends on a font being present on the device.
  final AccountIcon icon;

  /// ARGB hex string, e.g. '#7C5CFF'.
  final String color;

  const Account({
    required this.id,
    required this.userId,
    required this.name,
    this.kind = 'other',
    this.icon = AccountIcon.other,
    this.color = '#7C5CFF',
  });

  /// Every user gets one of these; pre-existing transactions are assigned to
  /// it on migration.
  static const defaultName = 'Lainnya';

  factory Account.fromSupabase(Map<String, dynamic> json) {
    final kind = json['kind'] as String? ?? 'other';
    return Account(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      name: json['name'] as String? ?? defaultName,
      kind: kind,
      // Legacy rows hold an emoji; fromStored maps those, and anything else it
      // does not recognise, onto a key for this account's kind. Nothing is
      // dropped: name, kind and colour read straight through.
      icon: AccountIcon.fromStored(json['icon'] as String?, kind: kind),
      color: json['color'] as String? ?? '#7C5CFF',
    );
  }

  Map<String, dynamic> toInsert(String userId) => {
        'user_id': userId,
        'name': name,
        'kind': kind,
        'icon': icon.key,
        'color': color,
      };
}
