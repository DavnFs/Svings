import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:cause_money_record/config/app_account_icon.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/data/model/account.dart';
import 'package:cause_money_record/presentation/controller/c_accounts.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/page/wallet/wallet_body.dart';

/// Wallet redesign contract:
///
/// - the screen is a two-column grid of account cards plus an add tile;
/// - every card is filled with its own accent, and its text colour is derived
///   from that fill's luminance, so the whole palette stays readable in both
///   themes rather than assuming white;
/// - one show/hide switch masks the total and every account balance, in the
///   grid and in the detail sheet alike;
/// - a card still opens the account detail sheet.
class _OfflineAccounts extends CAccounts {
  @override
  Future<void> getAccounts(String idUser) async {}
}

/// The real palette from account_widgets, plus the extremes a user could reach
/// by picking a colour: worst case for a light fill and for a dark one.
const _fills = <String>[
  '#7C5CFF', // indigo
  '#059669', // emerald
  '#DC2626', // crimson
  '#D97706', // amber
  '#0284C7', // sky
  '#DB2777', // pink
  '#FFFF00', // yellow: brightest case
  '#000000', // black: darkest case
];

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  setUp(() {
    Get.testMode = true;
    Get.put(CUser());
    final accounts = Get.put<CAccounts>(_OfflineAccounts());
    accounts.accounts.addAll(const [
      Account(
          id: 'acc-gopay',
          userId: 'u1',
          name: 'GoPay',
          kind: 'e-wallet',
          icon: AccountIcon.gojek,
          color: '#00AA13'),
      Account(
          id: 'acc-amber',
          userId: 'u1',
          name: 'Emas',
          kind: 'other',
          icon: AccountIcon.savings,
          color: '#D97706'),
      Account(
          id: 'acc-cash',
          userId: 'u1',
          name: 'Cash',
          kind: 'cash',
          icon: AccountIcon.cash),
    ]);
    accounts.balances['acc-gopay'] = 250000;
    accounts.balances['acc-amber'] = 1750000;
    accounts.balances['acc-cash'] = 425000;
  });

  tearDown(Get.reset);

  Future<void> pumpWallet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: const Scaffold(body: WalletBody()),
    ));
    await tester.pumpAndSettle();
  }

  // ------------------------------------------------------------- contrast

  test('every fill gets a foreground that clears WCAG AA', () {
    for (final hex in _fills) {
      final fill = CAccounts.parseColor(hex);
      final foreground = AppColor.onColor(fill);
      final ratio = AppColor.contrastRatio(fill, foreground);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: '$hex should be readable, got $ratio');
    }
  });

  test('the secondary line on a fill clears AA at full opacity too', () {
    // Both tiers on a card use onColor: the 15sp w700 name and the 11sp regular
    // kind. 11sp is normal text, so it needs 4.5:1, not the 3:1 a "secondary"
    // label used to be allowed. It used to be onColor at 0.8 alpha, which put
    // four of the nine accent colours below AA (4.10 on the brand purple, 3.22
    // on Mastercard red, 4.15 on Blibli blue, 3.34 on Bukalapak red).
    final fills = <String>{
      ..._fills,
      for (final icon in AccountIcon.values)
        if (icon.brandHex != null) icon.brandHex!,
    };
    for (final hex in fills) {
      final fill = CAccounts.parseColor(hex);
      final ratio = AppColor.contrastRatio(fill, AppColor.onColor(fill));
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: '$hex secondary text should clear AA, got $ratio');
    }
  });

  test('a light fill gets dark text and a dark fill gets light text', () {
    expect(AppColor.onColor(const Color(0xFFFFF176)), Colors.black);
    expect(AppColor.onColor(const Color(0xFF1A1A2E)), Colors.white);
    // The mid-tones are decided by measurement, not by a threshold guess: this
    // is the case that fails with the app's near-black text colour.
    expect(
        AppColor.contrastRatio(
            const Color(0xFF0284C7), AppColor.onColor(const Color(0xFF0284C7))),
        greaterThanOrEqualTo(4.5));
  });

  test('the palette resolves to the foregrounds the numbers dictate', () {
    // Pinned so a future palette edit has to face the measurements: light and
    // mid-tone fills take black, the deep ones take white.
    for (final hex in _fills) {
      final fill = CAccounts.parseColor(hex);
      final chosen = AppColor.onColor(fill);
      final other = chosen == Colors.white ? Colors.black : Colors.white;
      // ignore: avoid_print
      print('$hex -> ${chosen == Colors.white ? 'white' : 'black'} '
          '(${AppColor.contrastRatio(fill, chosen).toStringAsFixed(2)} '
          'vs ${AppColor.contrastRatio(fill, other).toStringAsFixed(2)})');
      expect(AppColor.contrastRatio(fill, chosen),
          greaterThanOrEqualTo(AppColor.contrastRatio(fill, other)));
    }
  });

  testWidgets('each card uses the foreground its fill dictates',
      (tester) async {
    await pumpWallet(tester);

    const names = {
      'acc-gopay': 'GoPay',
      'acc-amber': 'Emas',
      'acc-cash': 'Cash'
    };
    for (final entry in names.entries) {
      final card = find.byKey(Key('wallet_account_${entry.key}'));
      final fill = tester
          .widget<Material>(
              find.descendant(of: card, matching: find.byType(Material)).first)
          .color!;
      final label = tester
          .widget<Text>(
              find.descendant(of: card, matching: find.text(entry.value)))
          .style!
          .color;
      expect(label, AppColor.onColor(fill),
          reason: '${entry.value}: ${AppColor.contrastRatio(fill, label!)}:1');
    }
  });

  // ----------------------------------------------------------- the screen

  testWidgets('accounts render as grid cards with their own fill',
      (tester) async {
    await pumpWallet(tester);

    // Header: label, total, count.
    expect(find.text('Total Balance'), findsOneWidget);
    expect(find.text('Rp 2.425.000,00'), findsOneWidget);
    expect(find.text('3 accounts'), findsOneWidget);

    // One card per account plus the add tile.
    expect(find.byKey(const Key('wallet_account_acc-gopay')), findsOneWidget);
    expect(find.byKey(const Key('wallet_account_acc-cash')), findsOneWidget);
    expect(find.byKey(const Key('wallet_add_account')), findsOneWidget);

    // Card content: name, its own balance, and its kind.
    expect(find.text('GoPay'), findsOneWidget);
    expect(find.text('Rp 250.000,00'), findsOneWidget);
    expect(find.text('e-wallet'), findsOneWidget);
    expect(find.text('Rp 1.750.000,00'), findsOneWidget);

    // Two columns: the first two cards share a row.
    final first =
        tester.getTopLeft(find.byKey(const Key('wallet_account_acc-gopay')));
    final second =
        tester.getTopLeft(find.byKey(const Key('wallet_account_acc-amber')));
    expect(first.dy, second.dy);
    expect(second.dx, greaterThan(first.dx));

    // The amber card gets dark text, the dark green one light text.
    final amber = tester.widget<Material>(find
        .descendant(
            of: find.byKey(const Key('wallet_account_acc-amber')),
            matching: find.byType(Material))
        .first);
    expect(amber.color, const Color(0xFFD97706));
    expect(
        tester
            .widget<Text>(find.descendant(
                of: find.byKey(const Key('wallet_account_acc-amber')),
                matching: find.text('Emas')))
            .style
            ?.color,
        AppColor.onColor(const Color(0xFFD97706)));
  });

  testWidgets('the eye toggles every balance on the screen', (tester) async {
    await pumpWallet(tester);

    // Visible: total + each card's own figure.
    expect(find.text('Rp 2.425.000,00'), findsOneWidget);
    expect(find.text('Rp 250.000,00'), findsOneWidget);
    expect(find.text(kMaskedBalance), findsNothing);

    await tester.tap(find.byKey(const Key('wallet_toggle_balances')));
    await tester.pumpAndSettle();

    // Hidden: the total and all three cards are masked, and no real figure is
    // left anywhere on the screen.
    expect(find.text(kMaskedBalance), findsNWidgets(4));
    expect(find.text('Rp 2.425.000,00'), findsNothing);
    expect(find.text('Rp 250.000,00'), findsNothing);
    expect(find.text('Rp 1.750.000,00'), findsNothing);
    expect(find.text('Rp 425.000,00'), findsNothing);
    // Names and kinds stay readable: only the money is hidden.
    expect(find.text('GoPay'), findsOneWidget);
    expect(find.text('e-wallet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('wallet_toggle_balances')));
    await tester.pumpAndSettle();
    expect(find.text('Rp 2.425.000,00'), findsOneWidget);
    expect(find.text(kMaskedBalance), findsNothing);
  });

  testWidgets('a hidden balance stays hidden in the detail sheet',
      (tester) async {
    await pumpWallet(tester);

    await tester.tap(find.byKey(const Key('wallet_toggle_balances')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wallet_account_acc-gopay')));
    await tester.pumpAndSettle();

    // The sheet is open and prints the mask, not the figure the user hid.
    expect(find.text('Current balance'), findsOneWidget);
    expect(find.text('Rp 250.000,00'), findsNothing);
    expect(find.text(kMaskedBalance), findsWidgets);
  });

  testWidgets('a card opens its detail sheet, the add tile opens the sheet',
      (tester) async {
    await pumpWallet(tester);

    await tester.tap(find.byKey(const Key('wallet_account_acc-cash')));
    await tester.pumpAndSettle();
    expect(find.text('Current balance'), findsOneWidget);
    expect(find.text('View transactions'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // dismiss the sheet
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('wallet_add_account')));
    await tester.pumpAndSettle();
    expect(find.text('New account'), findsOneWidget);
  });
}
