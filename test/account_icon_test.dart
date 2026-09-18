import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:cause_money_record/config/app_account_icon.dart';
import 'package:cause_money_record/data/model/account.dart';
import 'package:cause_money_record/presentation/controller/c_accounts.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/widget/account_widgets.dart';

/// Account icon contract:
///
/// - every icon is a bundled vector mark, stored as a stable key, so rendering
///   never depends on the device having an emoji font;
/// - brands with a real mark in `simple_icons` are used, and every other name
///   (all Indonesian banks and local e-wallets were checked and are absent)
///   falls back to the generic mark for the account kind;
/// - a typed name suggests a mark, and the user can still override it;
/// - rows written before this change hold an emoji: they migrate without losing
///   anything else on the account.
class _RecordingAccounts extends CAccounts {
  AccountIcon? savedIcon;
  String? savedKind;
  String? savedName;
  String? savedColor;

  @override
  Future<Account?> addAccount({
    required String idUser,
    required String name,
    String kind = 'other',
    AccountIcon icon = AccountIcon.other,
    String color = '#7C5CFF',
    double openingBalance = 0,
  }) async {
    savedName = name;
    savedKind = kind;
    savedIcon = icon;
    savedColor = color;
    return Account(
        id: 'new', userId: idUser, name: name, kind: kind, icon: icon);
  }
}

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(CUser());
  });

  tearDown(Get.reset);

  // ------------------------------------------------------------ suggestions

  test('a brand name suggests its own mark', () {
    expect(AccountIcon.suggest('GoPay Utama'), AccountIcon.gojek);
    expect(AccountIcon.suggest('gopay'), AccountIcon.gojek);
    expect(AccountIcon.suggest('ShopeePay'), AccountIcon.shopee);
    expect(AccountIcon.suggest('GrabBike top up'), AccountIcon.grab);
    expect(AccountIcon.suggest('Kartu Visa BCA'), AccountIcon.visa);
    expect(AccountIcon.suggest('PayPal'), AccountIcon.paypal);
  });

  test('a bank without a mark suggests nothing, so the kind decides', () {
    // Mandiri, BCA, BNI, BRI, OVO, DANA, Jenius and friends have no brand mark
    // in simple_icons (verified one by one). They must not be guessed at, and
    // not be mistaken for a generic word either: "Tabungan Mandiri" is a bank
    // account, so it lands on the kind's bank mark, not on a piggy bank.
    expect(AccountIcon.suggest('Tabungan Mandiri'), isNull);
    expect(AccountIcon.genericFor('bank'), AccountIcon.bank);
    expect(AccountIcon.suggest('Bank BCA'), AccountIcon.bank);
  });

  test('a plain container name suggests the matching generic mark', () {
    expect(AccountIcon.suggest('Dompet'), AccountIcon.wallet);
    expect(AccountIcon.suggest('Uang Tunai'), AccountIcon.cash);
    expect(AccountIcon.suggest('Kartu Kredit'), AccountIcon.card);
    // Nothing recognisable at all: no suggestion, not a wrong one.
    expect(AccountIcon.suggest('Sesuatu yang aneh'), isNull);
    expect(AccountIcon.suggest('   '), isNull);
  });

  test('a brand suggestion carries the brand colour', () {
    expect(AccountIcon.gojek.brandHex, '#00AA13');
    expect(AccountIcon.shopee.brandHex, '#EE4D2D');
    expect(AccountIcon.bank.brandHex, isNull);
  });

  // ------------------------------------------------------------- migration

  test('legacy emoji map onto identifiers, by emoji first then by kind', () {
    expect(AccountIcon.fromStored('🏦'), AccountIcon.bank);
    expect(AccountIcon.fromStored('👛'), AccountIcon.wallet);
    expect(AccountIcon.fromStored('💵'), AccountIcon.cash);
    expect(AccountIcon.fromStored('💰'), AccountIcon.savings);
    expect(AccountIcon.fromStored('💳'), AccountIcon.card);
    expect(AccountIcon.fromStored('🐷'), AccountIcon.savings);

    // The emoji wins over the kind: it was the user's explicit choice.
    expect(AccountIcon.fromStored('🏦', kind: 'e-wallet'), AccountIcon.bank);

    // Unknown or missing values fall back to the kind, never to nothing.
    expect(AccountIcon.fromStored('🚀', kind: 'e-wallet'), AccountIcon.wallet);
    expect(AccountIcon.fromStored('', kind: 'cash'), AccountIcon.cash);
    expect(AccountIcon.fromStored(null, kind: 'bank'), AccountIcon.bank);
    expect(AccountIcon.fromStored('nonsense', kind: 'other'),
        AccountIcon.other);

    // A current key round-trips unchanged.
    expect(AccountIcon.fromStored('gojek'), AccountIcon.gojek);
  });

  test('migrating a stored row keeps everything except the icon glyph', () {
    final row = Account.fromSupabase({
      'id': 'acc-1',
      'user_id': 'u-9',
      'name': 'Tabungan Mandiri',
      'kind': 'bank',
      'icon': '🏦', // legacy emoji
      'color': '#0284C7',
    });

    expect(row.id, 'acc-1');
    expect(row.userId, 'u-9');
    expect(row.name, 'Tabungan Mandiri');
    expect(row.kind, 'bank');
    expect(row.color, '#0284C7');
    expect(row.icon, AccountIcon.bank);

    // And it is written back as a key, not a glyph.
    expect(row.toInsert('u-9')['icon'], 'bank');
    expect(row.toInsert('u-9')['name'], 'Tabungan Mandiri');
    expect(row.toInsert('u-9')['color'], '#0284C7');
    expect(row.toInsert('u-9')['kind'], 'bank');
    expect(row.toInsert('u-9')['user_id'], 'u-9');
  });

  test('every icon resolves to a real glyph, never a text fallback', () {
    for (final icon in AccountIcon.values) {
      expect(icon.key, isNotEmpty);
      expect(icon.data.fontFamily, isNotNull);
      // No icon should be rendered as a text glyph from a system emoji font:
      // Material icons and the bundled brand font are the only families here.
      expect(icon.data.fontPackage, anyOf(isNull, 'simple_icons'));
    }
  });

  // ------------------------------------------------------------- the sheet

  Future<_RecordingAccounts> pumpSheet(WidgetTester tester) async {
    final accounts = _RecordingAccounts();
    Get.put<CAccounts>(accounts);
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            // The sheet is what Wallet opens; pumping it directly keeps this a
            // test of the sheet rather than of the navigation.
            WidgetsBinding.instance
                .addPostFrameCallback((_) => AccountSheet.show(context));
            return const SizedBox.shrink();
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return accounts;
  }

  testWidgets('typing a brand name fills in its mark and colour', (tester) async {
    final accounts = await pumpSheet(tester);

    await tester.enterText(find.byKey(const Key('account_name_field')),
        'GoPay Utama');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save account'));
    await tester.pumpAndSettle();

    expect(accounts.savedName, 'GoPay Utama');
    expect(accounts.savedIcon, AccountIcon.gojek);
    expect(accounts.savedColor, AccountIcon.gojek.brandHex);
  });

  testWidgets('a name with no brand keeps the kind default', (tester) async {
    final accounts = await pumpSheet(tester);

    await tester.enterText(
        find.byKey(const Key('account_name_field')), 'Tabungan Mandiri');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save account'));
    await tester.pumpAndSettle();

    // The sheet opens on the bank kind, and nothing in the name overrides it.
    expect(accounts.savedKind, 'bank');
    expect(accounts.savedIcon, AccountIcon.bank);
  });

  testWidgets('a manual icon choice wins over the suggestion', (tester) async {
    final accounts = await pumpSheet(tester);

    await tester.enterText(
        find.byKey(const Key('account_name_field')), 'GoPay Utama');
    await tester.pumpAndSettle();
    // The user disagrees with the suggestion.
    await tester.tap(find.byKey(const Key('account_icon_cash')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save account'));
    await tester.pumpAndSettle();

    expect(accounts.savedIcon, AccountIcon.cash);
  });
}
