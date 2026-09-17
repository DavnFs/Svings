import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/data/model/account.dart';
import 'package:cause_money_record/presentation/controller/c_accounts.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/page/history/history_page.dart';

/// Single home for account visuals: Home's preview cards and Wallet's full
/// list share these, so there is exactly one place that decides how an
/// account looks and one sheet that creates/edits one.
///
/// Account EDITING lives here too (via [AccountSheet] with [account] set),
/// so Wallet is the only management surface — Home shows read-only previews.

/// Option lists for the account sheet. Centralized so add + edit agree.
const accountKinds = ['bank', 'e-wallet', 'cash', 'other'];
const accountIcons = ['🏦', '👛', '💵', '💰', '💳', '🐷'];
const accountColors = ['#7C5CFF', '#059669', '#DC2626', '#D97706', '#0284C7', '#DB2777'];

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
  late String _kind;
  late String _icon;
  late String _color;
  bool _saving = false;

  bool get _editing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _name = TextEditingController(text: a?.name ?? '');
    _kind = a?.kind ?? 'bank';
    if (!accountKinds.contains(_kind)) _kind = 'other';
    _icon = a?.icon ?? '🏦';
    _color = a?.color ?? '#7C5CFF';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
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
            color: _color);
    if (!mounted) return;
    Navigator.pop(context, done != null);
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
                if (v != null) setState(() => _kind = v);
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: accountIcons
                  .map((e) => ChoiceChip(
                        label: Text(e),
                        selected: _icon == e,
                        onSelected: (_) => setState(() => _icon = e),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: accountColors
                  .map((hex) => ChoiceChip(
                        label: Text('⬤',
                            style: TextStyle(
                                color: CAccounts.parseColor(hex))),
                        selected: _color == hex,
                        onSelected: (_) => setState(() => _color = hex),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
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

/// Read-only card: icon + name, balance, kind. Used by Home previews and
/// composed inside Wallet rows — no tap handling of its own.
class AccountTile extends StatelessWidget {
  final Account account;
  final double balance;

  const AccountTile({super.key, required this.account, required this.balance});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(account.icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(account.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface)),
          ),
        ]),
        const Spacer(),
        Text(AppFormat.currency(balance),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface)),
        Text(account.kind,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}
