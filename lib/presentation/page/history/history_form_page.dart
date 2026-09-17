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
import 'package:cause_money_record/presentation/controller/history/c_history_form.dart';

/// Create or edit a transaction. Pass [idHistory] to edit, omit it to create.
class HistoryFormPage extends StatefulWidget {
  final String? idHistory;

  const HistoryFormPage({super.key, this.idHistory});

  @override
  State<HistoryFormPage> createState() => _HistoryFormPageState();
}

class _HistoryFormPageState extends State<HistoryFormPage> {
  late final CHistoryForm c;
  late final CUser cUser;
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _transferAmount = ''.obs;

  bool get _isEditing => widget.idHistory != null;

  @override
  void initState() {
    super.initState();
    c = Get.find<CHistoryForm>();
    cUser = Get.find<CUser>();
    c.reset();
    _priceController.addListener(() {
      // Transfer amount is a stateless TextField; mirror it into Rx so the
      // preview + total + save gate rebuild as the user types.
      if (c.type == 'Transfer') _transferAmount.value = _priceController.text;
    });
    if (_isEditing) c.load(widget.idHistory!);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  /// Prefills the amount field when editing a transfer (load() only fills
  /// the controller, which does not own a TextEditingController). Called from
  /// inside Obx — writes the TextField (not Rx) plus the Rx mirror directly,
  /// so no post-frame callback is needed.
  void _prefillTransferAmount() {
    if (_isEditing &&
        c.type == 'Transfer' &&
        _priceController.text.isEmpty &&
        c.items.isNotEmpty) {
      final price = c.items.first.price;
      _priceController.text = price == '0' ? '' : price;
      _transferAmount.value = _priceController.text;
    }
  }

  double get _transferTotal =>
      double.tryParse(_transferAmount.value.trim()) ?? 0;

  Future<void> _submit() async {
    // Transfers carry no items/categories — the amount IS the payload, read
    // from the single amount field below. Income/expense sum their item rows.
    final items = c.type == 'Transfer'
        ? [HistoryItem(name: 'Transfer', price: _transferTotal.toString())]
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

  void _addItem() {
    final name = _nameController.text.trim();
    final price = _priceController.text.trim();
    if (name.isEmpty || price.isEmpty) return;
    HapticFeedback.lightImpact();
    c.addItem(HistoryItem(name: name, price: price));
    _nameController.clear();
    _priceController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(_isEditing ? 'Edit Entry' : 'New Entry')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const _SectionLabel(text: 'Transaction Details'),
          const SizedBox(height: 8),
          _FormGroup(
            child: Column(
              children: [
                Obx(() => _TypeSegment(c: c)),
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 20, color: scheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          'Date',
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 14),
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
              // Transfers have no item rows — one amount + two accounts.
              // _transferAmount is the reactive source; the TextField is not.
              if (c.type == 'Transfer') {
                _prefillTransferAmount();
                return _ItemField(
                  controller: _priceController,
                  hint: 'Amount (Rp)',
                  icon: Icons.payments_outlined,
                  isNumber: true,
                );
              }
              return Column(
                children: [
                  _ItemField(
                    controller: _nameController,
                    hint: 'Item Description (e.g. Lunch)',
                    icon: Icons.edit_note_rounded,
                  ),
                  const SizedBox(height: 12),
                  _ItemField(
                    controller: _priceController,
                    hint: 'Amount (Rp)',
                    icon: Icons.payments_outlined,
                    isNumber: true,
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
              // _transferAmount (not the TextField) so typing rebuilds this.
              if (c.type == 'Transfer') {
                _prefillTransferAmount();
                return _TransferPreview(amount: _transferTotal);
              }
              if (c.items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No items added yet. Add an item above to continue.',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                              backgroundColor: scheme.surfaceContainerHighest,
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
                              AppFormat.currency(num.tryParse(item.price) ?? 0),
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
                                  size: 18, color: scheme.onSurfaceVariant),
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
                            ? _transferTotal
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
            child: Obx(
              () => FilledButton(
                onPressed: _canSubmit() ? _submit : null,
                child: Text(_isEditing ? 'Save Changes' : 'Save Transaction'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Save gate per type: income/expense need an item row; transfers need an
  /// amount plus two DISTINCT accounts. Reads _transferTotal (Rx-backed) so
  /// the button enables as the user types.
  bool _canSubmit() {
    if (c.type == 'Transfer') {
      return _transferTotal > 0 &&
          c.accountId != null &&
          c.transferToAccountId != null &&
          c.accountId != c.transferToAccountId;
    }
    return c.items.isNotEmpty;
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
      selected: {c.type},
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
        return const Text('Add an account first (Home → + Add account)');
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
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: accounts
          .map((a) => DropdownMenuItem(value: a.id, child: Text('${a.icon} ${a.name}')))
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppFormat.currency(amount),
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface)),
            const SizedBox(height: 4),
            Text('${from?.name ?? '—'}  →  ${to?.name ?? '—'}',
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

/// MD3 outlined input: scheme outline, primary focus ring.
class _ItemField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isNumber;

  const _ItemField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.isNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
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
