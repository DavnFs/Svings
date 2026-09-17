import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/presentation/controller/c_accounts.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/widget/account_widgets.dart';
import 'package:cause_money_record/presentation/widget/state_view.dart';

/// Wallet: the single account-management surface. Full vertical account list
/// (same cards as Home, one per row), tap for detail (edit / history), and
/// an inline "+ Add account" affordance.
///
/// Reordering: deliberately NOT built here. Account order is creation order
/// from the server; drag-to-reorder needs a persisted position (new column +
/// migration + conflict story for multi-device) — follow-up, not this pass.
class WalletBody extends StatelessWidget {
  const WalletBody({super.key});

  @override
  Widget build(BuildContext context) {
    // No fetching here: MainShell._refresh owns loads, same as Home.
    final cAccounts = Get.find<CAccounts>();
    return Obx(() {
      if (cAccounts.loading && cAccounts.accounts.isEmpty) {
        return ListView(children: const [
          SizedBox(height: 80),
          StateView(
              loading: true,
              error: null,
              empty: false,
              child: SizedBox.shrink()),
        ]);
      }
      if (cAccounts.error != null) {
        return ListView(children: [
          const SizedBox(height: 80),
          StateView(
            loading: false,
            error: cAccounts.error,
            empty: false,
            onRetry: () => cAccounts.getAccounts(Get.find<CUser>().id),
            child: const SizedBox.shrink(),
          ),
        ]);
      }
      final accounts = cAccounts.accounts;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Text(AppFormat.currency(cAccounts.total),
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${accounts.length} account${accounts.length == 1 ? '' : 's'}',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13)),
          const SizedBox(height: 16),
          ...accounts.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _WalletRow(accountId: a.id),
              )),
          _AddAccountRow(onAdded: () {}),
        ],
      );
    });
  }
}

/// One Wallet row: the shared AccountTile inside a tonal card, tapping opens
/// the account detail sheet (edit / view history).
class _WalletRow extends StatelessWidget {
  final String accountId;

  const _WalletRow({required this.accountId});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cAccounts = Get.find<CAccounts>();
    return Obx(() {
      final a = cAccounts.byId(accountId);
      if (a == null) return const SizedBox.shrink();
      final tint = CAccounts.parseColor(a.color);
      return InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _AccountDetailSheet.show(context, accountId: a.id),
        child: Container(
          height: 108,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border(
              left: BorderSide(color: tint, width: 4),
            ),
          ),
          child: AccountTile(account: a, balance: cAccounts.balanceOf(a.id)),
        ),
      );
    });
  }
}

/// Inline "+ Add account" affordance at the end of the Wallet list. Same
/// AccountSheet Home used to host — one sheet, one creation path.
class _AddAccountRow extends StatelessWidget {
  final VoidCallback onAdded;

  const _AddAccountRow({required this.onAdded});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => AccountSheet.show(context),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: scheme.primary),
            const SizedBox(width: 4),
            Text('Add account',
                style: TextStyle(fontSize: 14, color: scheme.primary)),
          ],
        ),
      ),
    );
  }
}

/// Per-account detail: balance, edit affordance, and a shortcut into that
/// account's filtered transaction history.
class _AccountDetailSheet extends StatelessWidget {
  final String accountId;

  const _AccountDetailSheet({required this.accountId});

  static Future<void> show(BuildContext context,
          {required String accountId}) =>
      showModalBottomSheet(
        context: context,
        builder: (_) => _AccountDetailSheet(accountId: accountId),
      );

  @override
  Widget build(BuildContext context) {
    final cAccounts = Get.find<CAccounts>();
    return Obx(() {
      final a = cAccounts.byId(accountId);
      if (a == null) {
        Navigator.pop(context);
        return const SizedBox.shrink();
      }
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(a.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name,
                            style: Theme.of(context).textTheme.titleLarge),
                        Text(a.kind,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 13)),
                      ]),
                ),
                IconButton(
                  tooltip: 'Edit account',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () {
                    Navigator.pop(context);
                    AccountSheet.show(context, account: a);
                  },
                ),
              ]),
              const SizedBox(height: 16),
              Text(AppFormat.currency(cAccounts.balanceOf(a.id)),
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Current balance',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.pop(context);
                    Get.to(() => AccountTransactionsPage(account: a));
                  },
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('View transactions'),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
