import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_account_icon.dart';
import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/data/model/account.dart';
import 'package:cause_money_record/presentation/controller/c_accounts.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/page/history/history_page.dart';
import 'package:cause_money_record/presentation/widget/account_icon_view.dart';

/// Single home for account visuals: Home's preview cards and Wallet's full
/// list share these, so there is exactly one place that decides how an
/// account looks and one sheet that creates/edits one.
///
/// Account EDITING lives here too (via [AccountSheet] with [account] set),
/// so Wallet is the only management surface — Home shows read-only previews.

/// Option lists for the account sheet. Centralized so add + edit agree.
const accountKinds = ['bank', 'e-wallet', 'cash', 'other'];
const accountColors = [
  '#7C5CFF',
  '#059669',
  '#DC2626',
  '#D97706',
  '#0284C7',
  '#DB2777'
];

/// Tapping opens that account's own transaction list: the shared HistoryBody
/// with an account pre-filter, NOT a forked list screen.
class AccountTransactionsPage extends StatelessWidget {
  final Account account;

  const AccountTransactionsPage({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(account.name)),
      body: HistoryBody(accountId: account.id),
    );
  }
}

/// Add/edit sheet. Null [account] = create; non-null = edit that account's
/// name/icon/color. Balance never enters this sheet — it is ledger-derived.
class AccountSheet extends StatefulWidget {
  final Account? account;

  const AccountSheet({super.key, this.account});

  static Future<bool?> show(BuildContext context, {Account? account}) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => AccountSheet(account: account),
      );

  @override
  State<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<AccountSheet> {
  late final TextEditingController _name;

  /// Starting balance. Only meaningful while creating: an existing account's
  /// balance comes from its ledger, so an edit cannot restate it.
  final _opening = TextEditingController();

  late String _kind;
  late AccountIcon _icon;
  late String _color;
  bool _saving = false;
  String? _error;

  /// Once the user picks an icon or colour by hand, the name no longer
  /// overwrites it. Editing an existing account starts "touched", so opening
  /// the sheet and touching the name cannot silently restyle a saved account.
  late bool _iconTouched;
  late bool _colorTouched;

  bool get _editing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _name = TextEditingController(text: a?.name ?? '');
    _kind = a?.kind ?? 'bank';
    if (!accountKinds.contains(_kind)) _kind = 'other';
    _icon = a?.icon ?? AccountIcon.bank;
    _color = a?.color ?? '#7C5CFF';
    _iconTouched = _editing;
    _colorTouched = _editing;
    _name.addListener(_applySuggestion);
    _opening.addListener(() => _onOpeningChanged(_opening.text));
  }

  @override
  void dispose() {
    _name.removeListener(_applySuggestion);
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  /// Suggests a mark (and a brand accent) from the typed name. A brand name
  /// keeps its own colour, since that is what makes the account recognisable.
  void _applySuggestion() {
    final suggested = AccountIcon.suggest(_name.text);
    if (suggested == null) return;
    if (_iconTouched && _colorTouched) return;
    setState(() {
      if (!_iconTouched) _icon = suggested;
      final brand = suggested.brandHex;
      if (!_colorTouched && brand != null) _color = brand;
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final accounts = Get.find<CAccounts>();
    final idUser = Get.find<CUser>().id;
    final done = _editing
        ? await accounts.updateAccount(idUser,
            id: widget.account!.id,
            name: name,
            kind: _kind,
            icon: _icon,
            color: _color)
        : await accounts.addAccount(
            idUser: idUser,
            name: name,
            kind: _kind,
            icon: _icon,
            color: _color,
            openingBalance: _openingValue,
          );
    if (!mounted) return;
    if (done == null) {
      // Keep the sheet open and say so. Closing on a failed write is
      // indistinguishable from a save that worked and then vanished.
      setState(() {
        _saving = false;
        _error = _editing
            ? 'Could not save the account. Please try again.'
            : 'Could not create the account. The name may already be used, or '
                'the connection dropped. Your input is still here.';
      });
      return;
    }
    Navigator.pop(context, true);
  }

  /// Digits the user typed into the starting-balance field. The field shows the
  /// formatted figure, the value keeps the digits, so a re-format mid-typing
  /// cannot feed its own output back in.
  String _openingDigits = '';

  double get _openingValue => double.tryParse(_openingDigits) ?? 0;

  void _onOpeningChanged(String _) {
    final digits = _opening.text.replaceAll(RegExp(r'[^0-9]'), '');
    final formatted = digits.isEmpty ? '' : AppFormat.typedCurrency(digits);
    if (_opening.text != formatted) {
      // Same formatting the New Entry pad uses, so an amount looks the same
      // wherever it is typed. Cursor to the end: these are appended digits, not
      // edited prose.
      _opening.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    if (digits == _openingDigits) return;
    setState(() => _openingDigits = digits);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_editing ? 'Edit account' : 'New account',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              key: const Key('account_name_field'),
              controller: _name,
              decoration: const InputDecoration(
                hintText: 'Name (e.g. BCA, GoPay, Cash)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(
                  labelText: 'Type', border: OutlineInputBorder()),
              items: accountKinds
                  .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _kind = v;
                  // The kind is a signal too: switching to e-wallet with an
                  // untouched icon moves it to the wallet mark instead of
                  // leaving a bank building on a wallet.
                  if (!_iconTouched) _icon = AccountIcon.genericFor(v);
                });
              },
            ),
            // Starting balance: only on create, and only as an opening entry.
            // There is no balance field on the account itself — the ledger
            // stays the single source of truth for what an account holds.
            if (!_editing) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('account_opening_field'),
                controller: _opening,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Saldo Awal (optional)',
                  helperText: 'Recorded as a Saldo Awal entry in this account',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // One bundled vector icon at a time: brands first (the ones that
            // exist in the icon set), then the generic marks every other
            // account falls back to.
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Icon',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AccountIcon.values
                  .map((option) => _IconChoice(
                        key: Key('account_icon_${option.key}'),
                        icon: option,
                        colorHex: _color,
                        selected: _icon == option,
                        onTap: () => setState(() {
                          _icon = option;
                          _iconTouched = true;
                        }),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Colour',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: accountColors
                  .map((hex) => ChoiceChip(
                        label: Text('⬤',
                            style: TextStyle(color: CAccounts.parseColor(hex))),
                        selected: _color == hex,
                        onSelected: (_) => setState(() {
                          _color = hex;
                          _colorTouched = true;
                        }),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Row(children: [
                Icon(Icons.error_outline_rounded,
                    size: 18, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    key: const Key('account_save_error'),
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_editing ? 'Save changes' : 'Save account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One account option in a dropdown: its mark plus its name, so the list reads
/// the same way the Wallet cards do.
class AccountDropdownItem extends StatelessWidget {
  final Account account;

  const AccountDropdownItem({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AccountIconView(icon: account.icon, colorHex: account.color, size: 24),
        const SizedBox(width: 8),
        Text(account.name),
      ],
    );
  }
}

/// One icon option in the sheet: the mark in the currently chosen colour, with
/// a ring when selected. 48dp so it is a comfortable target, and it carries the
/// icon's name for screen readers rather than an unlabelled glyph.
class _IconChoice extends StatelessWidget {
  final AccountIcon icon;
  final String colorHex;
  final bool selected;
  final VoidCallback onTap;

  const _IconChoice({
    super.key,
    required this.icon,
    required this.colorHex,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = CAccounts.parseColor(colorHex);
    return Semantics(
      button: true,
      selected: selected,
      label: icon.key,
      child: Material(
        color: selected
            ? color.withValues(alpha: 0.22)
            : scheme.surfaceContainerHighest,
        shape: CircleBorder(
          side: selected ? BorderSide(color: color, width: 2) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon.data,
                size: 22, color: selected ? color : scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
