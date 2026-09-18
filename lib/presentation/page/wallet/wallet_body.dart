import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/data/model/account.dart';
import 'package:cause_money_record/presentation/controller/c_accounts.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/widget/account_icon_view.dart';
import 'package:cause_money_record/presentation/widget/account_widgets.dart';
import 'package:cause_money_record/presentation/widget/state_view.dart';

/// What a hidden balance reads as. Length is fixed on purpose: the eye toggle
/// must not shuffle the layout it is meant to protect.
const kMaskedBalance = 'Rp ••••••••';

/// Wallet: the single account-management surface. Two-column grid of account
/// cards (each filled with its own accent colour), a total with one show/hide
/// switch for the whole screen, and an "Add account" tile in the last cell.
///
/// Reordering: deliberately NOT built here. Account order is creation order
/// from the server; drag-to-reorder needs a persisted position (new column +
/// migration + conflict story for multi-device) — follow-up, not this pass.
class WalletBody extends StatefulWidget {
  const WalletBody({super.key});

  @override
  State<WalletBody> createState() => _WalletBodyState();
}

class _WalletBodyState extends State<WalletBody> {
  /// One switch for the whole screen. Hiding the total but leaving a card
  /// readable would not hide anything, so every balance on this screen reads
  /// this flag — including the detail sheet, which would otherwise print the
  /// figure the user just hid.
  bool _visible = true;

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
          _TotalHeader(
            total: cAccounts.total,
            count: accounts.length,
            visible: _visible,
            onToggle: () => setState(() => _visible = !_visible),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            // Inside the page's own scroll: the grid is content, not a second
            // scroll region.
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              // A little taller than wide, like a card in a wallet.
              childAspectRatio: 0.86,
            ),
            itemCount: accounts.length + 1,
            itemBuilder: (context, i) {
              if (i == accounts.length) {
                return _AddAccountTile(
                  key: const Key('wallet_add_account'),
                  onTap: () => AccountSheet.show(context),
                );
              }
              final account = accounts[i];
              return _AccountCard(
                key: Key('wallet_account_${account.id}'),
                account: account,
                balance: cAccounts.balanceOf(account.id),
                visible: _visible,
                onTap: () => _AccountDetailSheet.show(
                  context,
                  accountId: account.id,
                  visible: _visible,
                ),
              );
            },
          ),
        ],
      );
    });
  }
}

/// Total balance with the show/hide switch beside it, and the account count
/// underneath.
class _TotalHeader extends StatelessWidget {
  final double total;
  final int count;
  final bool visible;
  final VoidCallback onToggle;

  const _TotalHeader({
    required this.total,
    required this.count,
    required this.visible,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Total Balance',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        Row(children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                visible ? AppFormat.currency(total) : kMaskedBalance,
                maxLines: 1,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            key: const Key('wallet_toggle_balances'),
            onPressed: onToggle,
            tooltip: visible ? 'Hide balances' : 'Show balances',
            icon: Icon(
              visible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ]),
        Text('$count account${count == 1 ? '' : 's'}',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
      ],
    );
  }
}

/// One account as a filled card: the account's own accent as the fill, its icon
/// as a bundled vector mark, name in bold, balance, and its kind underneath.
///
/// The fill is the account colour itself rather than a tonal tint of it: these
/// cards are the one place the account's identity is the whole message, and a
/// 20%-alpha tint reduces six distinct accounts to six shades of the surface.
/// The foreground is chosen per fill from its luminance, so an amber card does
/// not get white text.
class _AccountCard extends StatelessWidget {
  final Account account;
  final double balance;
  final bool visible;
  final VoidCallback onTap;

  const _AccountCard({
    super.key,
    required this.account,
    required this.balance,
    required this.visible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fill = CAccounts.parseColor(account.color);
    final foreground = AppColor.onColor(fill);
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(account.icon.data, size: 22, color: foreground),
              const Spacer(),
              Text(
                account.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  visible ? AppFormat.currency(balance) : kMaskedBalance,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Same full-opacity foreground as the name above it: the tier is
              // carried by 11sp regular versus 15sp w700, because muting this
              // over the fill dropped four of the nine accent colours below
              // WCAG AA (4.10:1 on the brand purple, 3.22:1 on Mastercard red).
              Text(
                account.kind,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Last cell of the grid: the add-account affordance, shaped like the cards
/// around it. A distinct tonal fill rather than a dashed outline — dashes need
/// a custom painter and read as a hole in the grid, while a tonal tile reads as
/// an action sitting in the same rhythm as the cards.
class _AddAccountTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddAccountTile({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 26, color: scheme.primary),
              const SizedBox(height: 8),
              Text(
                'Add account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Per-account detail: balance, edit affordance, and a shortcut into that
/// account's filtered transaction history.
///
/// [visible] is the screen's show/hide state, passed in rather than re-read:
/// a sheet that printed the balance the user just hid would defeat the toggle.
class _AccountDetailSheet extends StatelessWidget {
  final String accountId;
  final bool visible;

  const _AccountDetailSheet({required this.accountId, required this.visible});

  static Future<void> show(
    BuildContext context, {
    required String accountId,
    required bool visible,
  }) =>
      showModalBottomSheet(
        context: context,
        builder: (_) =>
            _AccountDetailSheet(accountId: accountId, visible: visible),
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
                AccountIconView(icon: a.icon, colorHex: a.color, size: 44),
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
              Text(
                  visible
                      ? AppFormat.currency(cAccounts.balanceOf(a.id))
                      : kMaskedBalance,
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
