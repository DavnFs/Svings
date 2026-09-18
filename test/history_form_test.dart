import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:cause_money_record/config/app_account_icon.dart';
import 'package:cause_money_record/data/model/account.dart';
import 'package:cause_money_record/presentation/controller/c_accounts.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/controller/history/c_history_form.dart';
import 'package:cause_money_record/presentation/page/history/history_form_page.dart';

/// New Entry screen contract, per GetX's actual tracking mechanism.
///
/// `RxInterface.notifyChildren` sets the global `RxInterface.proxy` only for the
/// duration of an Obx builder closure, and every Rx read calls
/// `proxy?.addListener`. So a dependency is registered ONLY for reads that
/// happen while the closure runs: a read inside a child widget's build happens
/// after the closure returned, registers nothing, and makes the Obx throw
/// "improper use of a GetX".
///
/// These tests render the real screen and drive it, so they fail if any Obx in
/// the form goes back to reading its observable through a child widget.
void main() {
  late CHistoryForm cForm;

  // main() does this before runApp; the form's date row formats id_ID dates.
  setUpAll(() => initializeDateFormatting('id_ID'));

  setUp(() {
    Get.testMode = true;
    Get.put(CUser());
    Get.put(CAccounts()).accounts.addAll(const [
      Account(
          id: 'acc-cash', userId: 'u1', name: 'Cash', icon: AccountIcon.cash),
      Account(
          id: 'acc-bank',
          userId: 'u1',
          name: 'Bank',
          kind: 'bank',
          icon: AccountIcon.bank),
    ]);
    cForm = Get.put(CHistoryForm());
  });

  tearDown(Get.reset);

  Future<void> pumpForm(WidgetTester tester) async {
    // The app's own max content width (main.dart constrains the app to 600).
    // Tall as well as wide: the form scrolls on a real phone, and these tests
    // are about reactivity, so every element is rendered instead of scrolled
    // to. The pinned pad and the amount display still take their real height.
    tester.view.physicalSize = const Size(600, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GetMaterialApp(home: HistoryFormPage()));
    await tester.pumpAndSettle();
  }

  /// Opens a picker by its field (not its floating label, which is not the hit
  /// target) and taps the named account in the opened menu. Options render the
  /// account's vector mark plus its name, so the name is what to look for.
  Future<void> pickAccount(
    WidgetTester tester,
    String label,
    String accountName,
  ) async {
    await tester.tap(find.ancestor(
      of: find.text(label),
      matching: find.byType(DropdownButtonFormField<String>),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text(accountName).last);
    await tester.pumpAndSettle();
  }

  Future<void> selectTransfer(WidgetTester tester) async {
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
  }

  /// Keys the amount on the pad, one tap per character. The pad is the only
  /// amount input on the screen, so these taps are the user's real path.
  Future<void> keyAmount(WidgetTester tester, String digits) async {
    for (final char in digits.split('')) {
      await tester.tap(find.byKey(Key('keypad_$char')));
      await tester.pump();
    }
  }

  /// The segment's own selected value: proves the control rebuilt from c.type,
  /// not just that the widgets around it reacted.
  Set<String> segmentSelection(WidgetTester tester) => tester
      .widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>))
      .selected;

  testWidgets('renders income form and switches to transfer without throwing',
      (tester) async {
    await pumpForm(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('New Entry'), findsOneWidget);
    // Income/expense: item rows, one account picker, no transfer pickers.
    expect(find.text('Add Item'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('From'), findsNothing);
    expect(segmentSelection(tester), {'Pemasukan'});

    await selectTransfer(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Transfer Amount'), findsOneWidget);
    expect(find.text('From'), findsOneWidget);
    expect(find.text('To'), findsOneWidget);
    expect(find.text('Add Item'), findsNothing);
    expect(segmentSelection(tester), {'Transfer'});

    // Back to expense: the item form returns.
    await tester.tap(find.text('Expense'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Add Item'), findsOneWidget);
    expect(find.text('From'), findsNothing);
    expect(segmentSelection(tester), {'Pengeluaran'});
  });

  testWidgets('transfer preview follows the amount, the accounts and the type',
      (tester) async {
    await pumpForm(tester);
    await selectTransfer(tester);

    // Defaults from _AccountPickers: first account is the source, second the
    // destination. Rendered by the preview's own Obx.
    expect(find.text('Cash  →  Bank'), findsOneWidget);

    // Typing is mirrored into Rx by the form, and the preview must follow it.
    // The pad formats as it goes: 250000 reads as "Rp 250.000" above the keys.
    await keyAmount(tester, '250000');
    expect(find.text('Rp 250.000'), findsOneWidget);
    expect(find.text('Rp 250.000,00'), findsWidgets);

    // Backspace edits the entry, and the display follows down.
    await tester.tap(find.byKey(const Key('keypad_backspace')));
    await tester.pump();
    expect(find.text('Rp 25.000'), findsOneWidget);
    await keyAmount(tester, '0');
    expect(find.text('Rp 250.000'), findsOneWidget);

    // Changing the source account through the real dropdown updates the
    // direction line.
    await pickAccount(tester, 'From', 'Bank');
    expect(tester.takeException(), isNull);
    expect(find.text('Bank  →  Bank'), findsOneWidget);

    // And a controller-level change reaches the same preview, which is what
    // proves the Obx is wired to the Rx and not to a stale build closure.
    cForm.setTransferToAccountId('acc-cash');
    await tester.pump();
    expect(find.text('Bank  →  Cash'), findsOneWidget);

    cForm.setType('Pengeluaran');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Add Item'), findsOneWidget);
    expect(find.text('Bank  →  Cash'), findsNothing);
  });

  testWidgets('adding an item updates the list, the total and the save gate',
      (tester) async {
    await pumpForm(tester);

    FilledButton saveButton() =>
        tester.widget<FilledButton>(find.byType(FilledButton));

    // Nothing recorded yet: the empty-state copy and a disabled gate.
    expect(find.textContaining('No items added yet'), findsOneWidget);
    expect(saveButton().onPressed, isNull);

    // The item name is the only field still on the OS keyboard; the amount is
    // keyed on the pad.
    await tester.enterText(find.byType(TextField), 'Lunch');
    await keyAmount(tester, '25000');
    await tester.tap(find.text('Add to List'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Row (name + amount) and the group total both come from c.items/c.total.
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Rp 25.000,00'), findsWidgets);
    expect(find.textContaining('No items added yet'), findsNothing);
    // The pad empties once its amount becomes a row.
    expect(find.text('Rp 0'), findsOneWidget);
    expect(saveButton().onPressed, isNotNull);

    // Removing the row empties the list again and closes the gate.
    await tester.tap(find.byTooltip('Remove item'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Lunch'), findsNothing);
    expect(saveButton().onPressed, isNull);
  });

  testWidgets('save gate reacts to the reactive sources it reads',
      (tester) async {
    await pumpForm(tester);
    await selectTransfer(tester);
    FilledButton saveButton() =>
        tester.widget<FilledButton>(find.byType(FilledButton));

    // Nothing filled in yet: amount is 0.
    expect(saveButton().onPressed, isNull);

    await keyAmount(tester, '250000');
    // Amount plus two distinct accounts: the gate opens without a rebuild of
    // anything but the button, because its Obx reads these directly.
    expect(saveButton().onPressed, isNotNull);

    cForm.setTransferToAccountId('acc-cash');
    await tester.pump();
    // Same account on both sides is not a transfer.
    expect(saveButton().onPressed, isNull);
  });
}
