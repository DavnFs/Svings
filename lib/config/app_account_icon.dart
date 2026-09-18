import 'package:flutter/material.dart';
import 'package:simple_icons/simple_icons.dart';

/// Icon for a money account, held as a stable identifier rather than a glyph.
///
/// Why not emoji: an emoji is a text glyph, so it is drawn by whatever font the
/// device happens to have. It renders differently per platform and becomes a
/// tofu box wherever that font is missing (visible in this project's own test
/// screenshots). These are bundled vector icons instead: one shape everywhere,
/// and tintable with the account's own colour.
///
/// The brand marks come from `simple_icons` and are trademarks of their owners,
/// used here so the user recognises the account they are naming. Only brands
/// that demonstrably exist in that package are listed: every Indonesian bank and
/// the local e-wallets (GoPay, OVO, DANA, ShopeePay, Mandiri, BCA, BNI, BRI,
/// Jenius, Jago, SeaBank, Permata, Bibit, LinkAja, Tokopedia, Traveloka) were
/// checked one by one and are absent, so they resolve to a generic mark through
/// [genericFor]. Adding a brand later is one line here plus one line in
/// [_brandNames].
///
/// [key] is what the database stores, so a stored value never depends on the
/// icon font, the package, or a Material icon codepoint.
enum AccountIcon {
  // ---------------------------------------------------------------- brands --
  gojek('gojek', SimpleIcons.gojek, brand: SimpleIconColors.gojek),
  shopee('shopee', SimpleIcons.shopee, brand: SimpleIconColors.shopee),
  grab('grab', SimpleIcons.grab, brand: SimpleIconColors.grab),
  visa('visa', SimpleIcons.visa, brand: SimpleIconColors.visa),
  mastercard('mastercard', SimpleIcons.mastercard,
      brand: SimpleIconColors.mastercard),
  paypal('paypal', SimpleIcons.paypal, brand: SimpleIconColors.paypal),
  blibli('blibli', SimpleIcons.blibli, brand: SimpleIconColors.blibli),
  bukalapak('bukalapak', SimpleIcons.bukalapak,
      brand: SimpleIconColors.bukalapak),

  // -------------------------------------------------------------- generic --
  cash('cash', Icons.payments_outlined),
  bank('bank', Icons.account_balance),
  wallet('wallet', Icons.account_balance_wallet_outlined),
  card('card', Icons.credit_card),
  savings('savings', Icons.savings_outlined),
  other('other', Icons.category_outlined);

  const AccountIcon(this.key, this.data, {this.brand});

  /// Stored value. Stable: renaming a glyph never has to touch stored rows.
  final String key;

  /// The glyph to draw: a brand mark or a Material icon.
  final IconData data;

  /// The brand's own colour, for the generic ones null.
  final Color? brand;

  /// [brand] as the '#RRGGBB' the account stores, so typing a brand name can
  /// seed the accent with it. Null for a generic icon.
  String? get brandHex {
    final color = brand;
    if (color == null) return null;
    final argb = color.toARGB32() & 0xFFFFFF;
    return '#${argb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static final Map<String, AccountIcon> _byKey = {
    for (final icon in values) icon.key: icon,
  };

  /// Resolves whatever a row holds: a current key, one of the emoji this app
  /// used before the enum existed, or nothing usable. [kind] is the last
  /// resort, so an account always has a mark to draw.
  static AccountIcon fromStored(String? stored, {String kind = 'other'}) {
    if (stored == null || stored.isEmpty) return genericFor(kind);
    return _byKey[stored] ?? _legacyEmoji[stored] ?? genericFor(kind);
  }

  /// The generic mark for an account kind. This is where every Indonesian bank
  /// and e-wallet lands, by design rather than by accident.
  static AccountIcon genericFor(String kind) => switch (kind) {
        'bank' => AccountIcon.bank,
        'e-wallet' => AccountIcon.wallet,
        'cash' => AccountIcon.cash,
        _ => AccountIcon.other,
      };

  /// The emoji this app stored before icons became identifiers. Mirrors the SQL
  /// migration, so rows read correctly even against a database where that
  /// migration has not run yet.
  static const _legacyEmoji = <String, AccountIcon>{
    '🏦': AccountIcon.bank,
    '👛': AccountIcon.wallet,
    '💵': AccountIcon.cash,
    '💰': AccountIcon.savings,
    '💳': AccountIcon.card,
    '🐷': AccountIcon.savings,
  };

  /// Name fragments that identify a brand. Checked before [_kindNames], so
  /// "Bank GoPay" reads as GoPay while "Bank Mandiri" falls through to the
  /// generic bank mark. Case-insensitive substring match, order as written.
  static const _brandNames = <String, AccountIcon>{
    'gopay': AccountIcon.gojek,
    'gojek': AccountIcon.gojek,
    'shopeepay': AccountIcon.shopee,
    'shopee': AccountIcon.shopee,
    'grabpay': AccountIcon.grab,
    'grab': AccountIcon.grab,
    'visa': AccountIcon.visa,
    'mastercard': AccountIcon.mastercard,
    'paypal': AccountIcon.paypal,
    'blibli': AccountIcon.blibli,
    'bukalapak': AccountIcon.bukalapak,
  };

  /// Words that describe the container rather than a brand. Deliberately
  /// narrow: "tabungan" is not here, so "Tabungan Mandiri" falls through to the
  /// kind's generic mark instead of being called a piggy bank, and a bank name
  /// never gets argued with by a generic word.
  static const _kindNames = <String, AccountIcon>{
    'dompet': AccountIcon.wallet,
    'wallet': AccountIcon.wallet,
    'tunai': AccountIcon.cash,
    'cash': AccountIcon.cash,
    'kartu': AccountIcon.card,
    'card': AccountIcon.card,
    'bank': AccountIcon.bank,
  };

  /// The mark a typed account name suggests, or null when nothing matches (the
  /// caller keeps whatever is selected instead of guessing).
  static AccountIcon? suggest(String name) {
    final needle = name.toLowerCase().trim();
    if (needle.isEmpty) return null;
    for (final entry in _brandNames.entries) {
      if (needle.contains(entry.key)) return entry.value;
    }
    for (final entry in _kindNames.entries) {
      if (needle.contains(entry.key)) return entry.value;
    }
    return null;
  }
}
