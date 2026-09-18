import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cause_money_record/config/app_dialog.dart';
import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/data/model/account.dart';
import 'package:cause_money_record/data/model/history.dart';
import 'package:cause_money_record/data/source/source_history.dart';
import 'package:cause_money_record/presentation/controller/c_accounts.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/widget/account_widgets.dart';
import 'package:cause_money_record/presentation/controller/history/c_history_form.dart';

/// Create or edit a transaction. Pass [idHistory] to edit, omit it to create.
///
/// [initialType] and [initialAccountId] are the create-only shortcut: Home's
/// quick actions open this same form with a type and (when a specific account
/// card is on screen) that account already chosen. Nothing about the form
/// changes; it just starts where the user already was.
class HistoryFormPage extends StatefulWidget {
  final String? idHistory;
  final String? initialType;
  final String? initialAccountId;

  const HistoryFormPage({
    super.key,
    this.idHistory,
    this.initialType,
    this.initialAccountId,
  });

  @override
  State<HistoryFormPage> createState() => _HistoryFormPageState();
}

class _HistoryFormPageState extends State<HistoryFormPage> {
  late final CHistoryForm c;
  late final CUser cUser;

  /// Only the item name is still typed on the OS keyboard. The amount comes
  /// from the numeric pad and lives in the controller, so no TextEditingController
  /// has to be mirrored into Rx (the old transfer path needed exactly that, and
  /// with it a write-during-build prefill).
  final _nameController = TextEditingController();

  bool get _isEditing => widget.idHistory != null;

  @override
  void initState() {
    super.initState();
    c = Get.find<CHistoryForm>();
    cUser = Get.find<CUser>();
    c.reset();
    if (_isEditing) {
      c.load(widget.idHistory!);
    } else {
      // Applied after reset(), so a shortcut cannot inherit the previous form's
      // state. For a transfer this account is the SOURCE, which is what the
      // controller's accountId means in that type.
      final type = widget.initialType;
      if (type != null) c.setType(type);
      final accountId = widget.initialAccountId;
      if (accountId != null) c.setAccountId(accountId);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Transfers carry no item rows: the pad amount IS the payload. Income and
    // expense sum their rows instead.
    final items = c.type == 'Transfer'
        ? [HistoryItem(name: 'Transfer', price: c.amountRaw)]
        : c.items;
    final success = _isEditing
        ? await SourceHistory.update(
            idHistory: widget.idHistory!,
            idUser: cUser.id,
            date: c.date,
            type: c.type,
            items: items,
            accountId: c.accountId,
            transferToAccountId: c.transferToAccountId,
          )
        : await SourceHistory.add(
            idUser: cUser.id,
            date: c.date,
            type: c.type,
            items: items,
            accountId: c.accountId,
            transferToAccountId: c.transferToAccountId,
          );
    if (!mounted) return;
    if (success) {
      HapticFeedback.mediumImpact();
      AppDialog.success(
          context,
          _isEditing
              ? 'Transaction updated successfully'
              : 'Transaction saved successfully');
      await Future.delayed(const Duration(milliseconds: 700));
      Get.back(result: true);
    } else {
      AppDialog.error(
          context,
          _isEditing
              ? 'Failed to update transaction'
              : 'Failed to save transaction');
    }
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(c.date) ?? DateTime.now(),
      firstDate: DateTime(2022),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (result != null) c.setDate(DateFormat('yyyy-MM-dd').format(result));
  }

  /// Commits what is on the pad as the next item row, then empties the pad so
  /// the next amount starts clean.
  void _addItem() {
    final name = _nameController.text.trim();
    if (name.isEmpty || c.amountValue <= 0) return;
    HapticFeedback.lightImpact();
    c.addItem(HistoryItem(name: name, price: c.amountRaw));
    _nameController.clear();
    c.clearAmount();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(_isEditing ? 'Edit Entry' : 'New Entry')),
      // Amount display pinned at the top, pad pinned at the bottom, form in
      // between: the entry stays visible and reachable no matter where the
      // scroll sits, which is the whole point of a pad over the OS keyboard.
      body: Column(
        children: [
          Obx(() => _AmountDisplay(raw: c.amount)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const _SectionLabel(text: 'Transaction Details'),
                const SizedBox(height: 8),
                _FormGroup(
                  child: Column(
                    children: [
                      // No Obx here: the segment owns its own reactive scope. An
                      // Obx at this level would only construct the child, and a
                      // read made in the child's build registers nothing (GetX
                      // tracks reads for the duration of the Obx closure alone).
                      _TypeSegment(c: c),
                      const SizedBox(height: 14),
                      Divider(height: 1, color: scheme.outlineVariant),
                      const SizedBox(height: 14),
                      _AccountPickers(c: c),
                      const SizedBox(height: 14),
                      Divider(height: 1, color: scheme.outlineVariant),
                      const SizedBox(height: 14),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _pickDate,
                        // 14 + a 20dp icon (the tallest child) + 14 = a 48dp tap
                        // target. It used to be 28dp, the one row on this screen
                        // under the 44dp minimum, on a primary field. Padding
                        // rather than a height, so bigger text still grows it.
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 20, color: scheme.primary),
                              const SizedBox(width: 12),
                              Text(
                                'Date',
                                style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 14),
                              ),
                              const Spacer(),
                              Obx(
                                () => Text(
                                  AppFormat.date(c.date),
                                  style: TextStyle(
                                    color: scheme.onSurface,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right_rounded,
                                  size: 18, color: scheme.onSurfaceVariant),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Obx(() => c.type == 'Transfer'
                    ? const _SectionLabel(text: 'Transfer Amount')
                    : const _SectionLabel(text: 'Add Item')),
                const SizedBox(height: 8),
                _FormGroup(
                  child: Obx(() {
                    // Transfers have no item rows: the pad amount is the whole
                    // payload, and the accounts carry the direction.
                    if (c.type == 'Transfer') {
                      return Text(
                        'The amount above is transferred from the source '
                        'account to the destination account.',
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 13),
                      );
                    }
                    return Column(
                      children: [
                        _ItemField(
                          controller: _nameController,
                          hint: 'Item Description (e.g. Lunch)',
                          icon: Icons.edit_note_rounded,
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add to List'),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 24),
                const _SectionLabel(text: 'Recorded Items'),
                const SizedBox(height: 8),
                _FormGroup(
                  child: Obx(() {
                    // Transfer preview: amount + source -> destination, no rows.
                    if (c.type == 'Transfer') {
                      return _TransferPreview(amount: c.amountValue);
                    }
                    if (c.items.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No items added yet. Add an item above to continue.',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 13),
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: c.items.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: scheme.outlineVariant),
                          itemBuilder: (context, index) {
                            final item = c.items[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor:
                                        scheme.surfaceContainerHighest,
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: scheme.onSurfaceVariant),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: scheme.onSurface),
                                    ),
                                  ),
                                  Text(
                                    AppFormat.currency(
                                        num.tryParse(item.price) ?? 0),
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: scheme.onSurface),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Remove item',
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(Icons.close_rounded,
                                        size: 18,
                                        color: scheme.onSurfaceVariant),
                                    onPressed: () => c.deleteItem(index),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        Divider(height: 1, color: scheme.outlineVariant),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Amount',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                  fontSize: 15),
                            ),
                            Obx(() {
                              final total = c.type == 'Transfer'
                                  ? c.amountValue
                                  : c.total;
                              return Text(
                                AppFormat.currency(total),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: c.type == 'Pemasukan'
                                          ? scheme.tertiary
                                          : scheme.primary,
                                    ),
                              );
                            }),
                          ],
                        ),
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Obx(() {
                    // The reads happen right here, in the closure: this is what
                    // registers the button's rebuilds. The gate below is a pure
                    // function so a later refactor cannot quietly move the reads
                    // out of the closure and kill the reactivity.
                    final enabled = _canSubmit(
                      type: c.type,
                      accountId: c.accountId,
                      transferToAccountId: c.transferToAccountId,
                      itemCount: c.items.length,
                      amount: c.amountValue,
                    );
                    return FilledButton(
                      onPressed: enabled ? _submit : null,
                      child: Text(
                          _isEditing ? 'Save Changes' : 'Save Transaction'),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
      // The pad is chrome, not content: keeping it out of the scroll means the
      // amount is always one tap away and never scrolls under the form.
      bottomNavigationBar: _AmountKeypad(
        onKey: c.pushAmount,
        onBackspace: c.popAmount,
      ),
    );
  }

  /// Save gate per type: income/expense need an item row; transfers need an
  /// amount plus two DISTINCT accounts. Pure by design — the caller passes the
  /// values it read from Rx (see the Obx above), so the dependency list lives
  /// at the reactive boundary instead of inside here.
  static bool _canSubmit({
    required String type,
    required String? accountId,
    required String? transferToAccountId,
    required int itemCount,
    required double amount,
  }) {
    if (type == 'Transfer') {
      return amount > 0 &&
          accountId != null &&
          transferToAccountId != null &&
          accountId != transferToAccountId;
    }
    return itemCount > 0;
  }
}

/// Income / Expense / Transfer picker. Three segments — transfers are a
/// first-class type here, not a category.
class _TypeSegment extends StatelessWidget {
  final CHistoryForm c;

  const _TypeSegment({required this.c});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The Obx lives here, around the control it reactivates, and reads c.type
    // inside its own closure. Reads made one level down (in a child's build)
    // happen after the closure returns and would register nothing.
    return Obx(() {
      final selected = c.type;
      return SegmentedButton<String>(
        segments: const [
          ButtonSegment(
            value: 'Pemasukan',
            label: Text('Income'),
            icon: Icon(Icons.arrow_downward_rounded, size: 16),
          ),
          ButtonSegment(
            value: 'Pengeluaran',
            label: Text('Expense'),
            icon: Icon(Icons.arrow_upward_rounded, size: 16),
          ),
          ButtonSegment(
            value: 'Transfer',
            label: Text('Transfer'),
            icon: Icon(Icons.swap_horiz_rounded, size: 16),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (s) {
          HapticFeedback.selectionClick();
          c.setType(s.first);
        },
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          selectedForegroundColor: scheme.onSecondaryContainer,
          selectedBackgroundColor: scheme.secondaryContainer,
        ),
      );
    });
  }
}

/// Account pickers: one owning account for income/expense; source +
/// destination for transfers. Options come from CAccounts (single source),
/// defaulting to the first account when the form has none yet.
class _AccountPickers extends StatelessWidget {
  final CHistoryForm c;

  const _AccountPickers({required this.c});

  @override
  Widget build(BuildContext context) {
    final accounts = Get.find<CAccounts>();
    return Obx(() {
      final list = accounts.accounts;
      if (list.isEmpty) {
        return const Text('Add an account first (Wallet → Add account)');
      }
      // Preserve the user's pick across rebuilds; only fill in blanks.
      // Writing an Rx inside Obx would re-trigger the build loop.
      final fromId = _validOr(list, c.accountId);
      final toId = c.type == 'Transfer'
          ? _validOr(list, c.transferToAccountId, fallbackIndex: 1)
          : null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (c.accountId != fromId) c.setAccountId(fromId);
        if (toId != null && c.transferToAccountId != toId) {
          c.setTransferToAccountId(toId);
        }
      });
      if (c.type == 'Transfer') {
        return Column(children: [
          _AccountDropdown(
            label: 'From',
            value: fromId,
            accounts: list,
            onChanged: c.setAccountId,
          ),
          const SizedBox(height: 12),
          _AccountDropdown(
            label: 'To',
            value: toId!,
            accounts: list,
            onChanged: c.setTransferToAccountId,
          ),
        ]);
      }
      return _AccountDropdown(
        label: 'Account',
        value: fromId,
        accounts: list,
        onChanged: c.setAccountId,
      );
    });
  }

  /// Keeps the current pick when it still exists; otherwise the first account
  /// (or [fallbackIndex] for the transfer destination).
  static String _validOr(List<Account> list, String? current,
      {int fallbackIndex = 0}) {
    if (current != null && list.any((a) => a.id == current)) return current;
    final i = fallbackIndex.clamp(0, list.length - 1);
    return list[i].id;
  }
}

class _AccountDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<Account> accounts;
  final ValueChanged<String?> onChanged;

  const _AccountDropdown({
    required this.label,
    required this.value,
    required this.accounts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ids = accounts.map((a) => a.id).toSet();
    final effective = ids.contains(value) ? value : accounts.first.id;
    return DropdownButtonFormField<String>(
      initialValue: effective,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: accounts
          .map((a) => DropdownMenuItem(
              value: a.id, child: AccountDropdownItem(account: a)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

/// Transfer preview: amount + source -> destination. Replaces the item list
/// for transfers (which have no rows).
class _TransferPreview extends StatelessWidget {
  final double amount;

  const _TransferPreview({required this.amount});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accounts = Get.find<CAccounts>();
    return Obx(() {
      final from = accounts.byId(accounts.accounts.isEmpty
          ? null
          : (Get.find<CHistoryForm>().accountId ?? accounts.accounts.first.id));
      final to = accounts.byId(Get.find<CHistoryForm>().transferToAccountId);
      return Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppFormat.currency(amount),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800, color: scheme.onSurface)),
            const SizedBox(height: 4),
            Text('${from?.name ?? '-'}  →  ${to?.name ?? '-'}',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          ]),
        ),
        const Icon(Icons.swap_horiz_rounded),
      ]);
    });
  }
}

/// MD3 tonal form group: surfaceContainerLow, no shadows.
class _FormGroup extends StatelessWidget {
  final Widget child;

  const _FormGroup({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

/// The amount being keyed, live-formatted as Rupiah while the pad is tapped.
///
/// Shrink-only scaling and tabular figures: the number grows into five or six
/// digits without the text jittering sideways or pushing the layout around, and
/// it never overflows the row it sits in.
class _AmountDisplay extends StatelessWidget {
  final String raw;

  const _AmountDisplay({required this.raw});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              AppFormat.typedCurrency(raw),
              maxLines: 1,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: raw.isEmpty ? scheme.onSurfaceVariant : scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Numeric pad for the amount: digits, a comma for sen, and backspace.
///
/// Every key is a full 56dp tall Material target with a ripple, and every key
/// carries a label for screen readers (the backspace is an icon, so it gets an
/// explicit one). No OS keyboard is involved, which is the point: it keeps the
/// form, the accounts and the amount on screen together.
class _AmountKeypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  const _AmountKeypad({required this.onKey, required this.onBackspace});

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    [',', '0', 'backspace'],
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in _rows)
                Row(
                  children: [
                    for (final key in row)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: key == 'backspace'
                              ? _KeyButton(
                                  key: const Key('keypad_backspace'),
                                  onTap: onBackspace,
                                  label: 'Backspace',
                                  child: Icon(
                                    Icons.backspace_outlined,
                                    size: 22,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                )
                              : _KeyButton(
                                  key: Key('keypad_$key'),
                                  onTap: () => onKey(key),
                                  label: key == ',' ? 'Comma' : key,
                                  child: Text(
                                    key,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One pad key: 56dp tall tonal target, ripple, and a screen-reader label.
class _KeyButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final Widget child;

  const _KeyButton({
    super.key,
    required this.onTap,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(height: 56, child: Center(child: child)),
        ),
      ),
    );
  }
}

/// MD3 outlined input: scheme outline, primary focus ring.
class _ItemField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;

  const _ItemField({
    required this.controller,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// MD3 label: 13sp w700 on-surface-variant.
class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.5,
      ),
    );
  }
}
