import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_category.dart';
import 'package:cause_money_record/config/app_dialog.dart';
import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/config/app_history_view.dart';
import 'package:cause_money_record/data/model/account.dart';
import 'package:cause_money_record/data/model/history.dart';
import 'package:cause_money_record/data/source/source_history.dart';
import 'package:cause_money_record/presentation/controller/c_accounts.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/controller/history/c_history.dart';
import 'package:cause_money_record/presentation/page/history/detail_history_page.dart';
import 'package:cause_money_record/presentation/widget/state_view.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('Transaction History')),
      body: const HistoryBody(),
    );
  }
}

/// The list content of [HistoryPage], extracted so the [MainShell] can embed it
/// as a tab under a shared [NavigationBar].
///
/// [accountId] optionally pre-filters to one account (account card tap).
/// Null (default) shows every account.
class HistoryBody extends StatefulWidget {
  final String? accountId;
  const HistoryBody({super.key, this.accountId});

  @override
  State<HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends State<HistoryBody> {
  late final CHistory cHistory;
  late final CUser cUser;
  late final CAccounts cAccounts;

  /// Active filters. Both are plain screen state on purpose: they live as long
  /// as this screen does and are gone on the next launch, which is what a
  /// filter should do.
  String _filter = 'All';
  String? _accountFilter;

  @override
  void initState() {
    super.initState();
    cHistory = Get.find<CHistory>();
    cUser = Get.find<CUser>();
    // Only read for the transfer row's "from → to" line. Accounts are loaded by
    // the shell, so this is a lookup, never a fetch.
    cAccounts = Get.find<CAccounts>();
    // Opened from an account card, that account starts selected; the pill can
    // still change it from there.
    _accountFilter = widget.accountId;
    _refresh();
  }

  void _refresh() => cHistory.getList(cUser.id);

  Future<void> _delete(String idHistory) async {
    final yes = await AppDialog.confirm(
        context, 'Delete', 'Are you sure you want to delete this transaction?');
    if (yes) {
      final success = await SourceHistory.delete(idHistory);
      if (success) _refresh();
    }
  }

  Future<void> _pickAccount() async {
    final accounts = cAccounts.accounts;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _AccountFilterSheet(
        accounts: accounts,
        selected: _accountFilter,
        onSelected: (id) {
          setState(() => _accountFilter = id);
          Navigator.pop(sheetContext);
        },
      ),
    );
  }

  /// Account filter first, then the type segment. They compose: "GoPay" plus
  /// "Expense" is a valid pair, and neither hides the other's control.
  List<History> _getFilteredList(List<History> all) {
    var out = all
        .where((h) => AppHistoryView.touchesAccount(h, _accountFilter))
        .toList();
    if (_filter == 'Income') {
      return out.where((h) => h.type == 'Pemasukan').toList();
    } else if (_filter == 'Expense') {
      return out.where((h) => h.type == 'Pengeluaran').toList();
    } else if (_filter == 'Transfer') {
      return out.where((h) => h.type == 'Transfer').toList();
    }
    return out;
  }

  /// One row, with its amount read from the filtered account's point of view
  /// when an account filter is on.
  Widget _row(BuildContext context, ColorScheme scheme, History h) {
    final isTransfer = h.type == 'Transfer';
    final isOpening = h.isOpening;
    final leg = AppHistoryView.transferLeg(h, _accountFilter);
    // An opening balance is money the account started with, so it reads as a
    // credit to that account — but never as income, and never as spending.
    final incoming =
        h.type == 'Pemasukan' || isOpening || leg == TransferLeg.incoming;
    final outgoing = h.type == 'Pengeluaran' || leg == TransferLeg.outgoing;

    final description = h.items.isEmpty
        ? (isTransfer ? 'Transfer' : h.type)
        : h.items.first.name;

    // A filtered transfer is money in or out of that account, so it takes the
    // matching sign and glyph. Income and expense keep their category glyph.
    final IconData icon;
    if (leg == TransferLeg.incoming) {
      icon = Icons.south_west_rounded;
    } else if (leg == TransferLeg.outgoing) {
      icon = Icons.north_east_rounded;
    } else {
      icon = AppCategory.icon(description, type: h.type);
    }

    // Transfers name the accounts instead of repeating "Transfer" under a
    // "Transfer" title; an opening balance names the account it opened, so the
    // reason for a non-zero starting balance is on the row itself.
    final secondary = isOpening
        ? (cAccounts.byId(h.accountId)?.name ?? 'Saldo Awal')
        : isTransfer
            ? '${cAccounts.byId(h.accountId)?.name ?? '-'}'
                '  →  '
                '${cAccounts.byId(h.transferToAccountId)?.name ?? '-'}'
            : AppCategory.label(description, type: h.type);

    // Only a transfer with both legs on screen is a wash; otherwise the amount
    // is signed and coloured like the money movement it is.
    final unsigned = isTransfer && leg == TransferLeg.neutral;
    final amount = unsigned
        ? AppFormat.currency(h.total)
        : '${incoming ? '+' : '-'}${AppFormat.currency(h.total)}';

    return _TransactionRow(
      scheme: scheme,
      description: description,
      secondary: secondary,
      icon: icon,
      incoming: incoming,
      outgoing: outgoing,
      // The opening balance is not income, so it must not borrow the income
      // green: the label carries what it is, the accent colour says "not
      // spending", and the sign explains the balance.
      creditNeutral: isOpening,
      amount: amount,
      onTap: () => Get.to(() => DetailHistoryPage(idHistory: h.idHistory!)),
      onDelete: () => _delete(h.idHistory!),
      deleteLabel: 'Delete transaction on ${AppFormat.date(h.date)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            _AccountFilterPill(
              account: cAccounts.byId(_accountFilter),
              onTap: _pickAccount,
            ),
            const Spacer(),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _FilterSegment(
            value: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
        ),
        Expanded(
          child: Obx(() {
            if (cHistory.loading) {
              return const StateView(
                loading: true,
                error: null,
                empty: false,
                child: SizedBox.shrink(),
              );
            }
            if (cHistory.error != null) {
              return StateView(
                loading: false,
                error: cHistory.error,
                empty: false,
                onRetry: _refresh,
                child: const SizedBox.shrink(),
              );
            }

            final filtered = _getFilteredList(cHistory.list);

            if (filtered.isEmpty) {
              return RefreshIndicator(
                color: scheme.primary,
                onRefresh: () async => _refresh(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 60),
                    StateView(
                      loading: false,
                      error: null,
                      empty: true,
                      emptyTitle: _filter == 'All'
                          ? 'No Transactions Yet'
                          : 'No $_filter Entries',
                      emptyMessage: _filter == 'All'
                          ? 'Record your first income or expense to see it here.'
                          : 'No transactions found under the $_filter filter.',
                      emptyIcon: Icons.receipt_long_outlined,
                      child: const SizedBox.shrink(),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              color: scheme.primary,
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                children: [
                  // Day sections, newest first, on whatever the filters left.
                  // Each day gets its own heading and its own card, so the row
                  // no longer has to repeat its own date.
                  for (final group in AppHistoryView.groupByDay(filtered)) ...[
                    _DayHeader(text: group.label),
                    const SizedBox(height: 8),
                    _GroupedList(
                      itemCount: group.items.length,
                      itemBuilder: (context, index) =>
                          _row(context, scheme, group.items[index]),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// All/Income/Expense/Transfer segmented control in a single grouped surface.
class _FilterSegment extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _FilterSegment({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'All', label: Text('All')),
          ButtonSegment(value: 'Income', label: Text('Income')),
          ButtonSegment(value: 'Expense', label: Text('Expense')),
          ButtonSegment(value: 'Transfer', label: Text('Transfer')),
        ],
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          selectedForegroundColor: scheme.onSecondaryContainer,
          selectedBackgroundColor: scheme.secondaryContainer,
        ),
      ),
    );
  }
}

/// MD3 inset grouped list: rows share ONE tonal container with hairline
/// inset dividers — no per-row card boxes, no shadows.
class _GroupedList extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

  const _GroupedList({required this.itemCount, required this.itemBuilder});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: itemCount,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: scheme.outlineVariant,
          // Aligned with the text, not the leading circle: 16 padding + 44
          // circle + 12 gap.
          indent: 72,
          endIndent: 16,
        ),
        itemBuilder: itemBuilder,
      ),
    );
  }
}

/// One transaction row: a circular category mark, the description with its
/// category (or, for a transfer, the two accounts) underneath, and the signed
/// amount on the trailing side.
///
/// Kind is carried by three things at once — the mark's glyph, the amount's sign
/// and the line of text — so colour is never the only signal.
class _TransactionRow extends StatelessWidget {
  final ColorScheme scheme;
  final String description;
  final String secondary;
  final IconData icon;

  /// Money in and money out of the account in view. Income is always incoming
  /// and expense always outgoing; a transfer is either, or neither when the
  /// list is not filtered to one account.
  final bool incoming;
  final bool outgoing;

  /// A credit that is not income: an opening balance adds to the account
  /// without being earnings, so it takes the accent colour instead of the
  /// income green.
  final bool creditNeutral;
  final String amount;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final String deleteLabel;

  const _TransactionRow({
    required this.scheme,
    required this.description,
    required this.secondary,
    required this.icon,
    required this.incoming,
    required this.outgoing,
    this.creditNeutral = false,
    required this.amount,
    required this.onTap,
    required this.onDelete,
    required this.deleteLabel,
  });

  @override
  Widget build(BuildContext context) {
    // Incoming is the income colour, outgoing the expense colour; a row that is
    // neither (an unfiltered transfer) stays neutral.
    final status = creditNeutral
        ? scheme.primary
        : incoming
            ? scheme.tertiary
            : (outgoing ? scheme.error : scheme.onSurfaceVariant);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: status.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: status, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amount,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: status,
                fontSize: 15,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Semantics(
              label: deleteLabel,
              button: true,
              child: IconButton(
                tooltip: 'Delete',
                icon: Icon(Icons.delete_outline_rounded,
                    color: scheme.onSurfaceVariant, size: 19),
                onPressed: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Day heading above each section: 'Hari ini', 'Kemarin', or a dated heading.
class _DayHeader extends StatelessWidget {
  final String text;

  const _DayHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Rounded account filter, in the row above the type segment: the selected
/// account's mark and name, with a chevron that says it opens something.
class _AccountFilterPill extends StatelessWidget {
  final Account? account;
  final VoidCallback onTap;

  const _AccountFilterPill({required this.account, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = account?.name ?? 'Semua Akun';
    return Semantics(
      button: true,
      label: 'Filter by account. Current: $name',
      child: Material(
        key: const Key('account_filter_pill'),
        color: scheme.surfaceContainerHigh,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            // 8 + a 30dp mark + 8 = 46dp, clearing the 44dp minimum. It was 42,
            // two dp under, on the control that opens the account filter.
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AccountMark(account: account, size: 30),
                const SizedBox(width: 8),
                ConstrainedBox(
                  // Long account names ellipsize instead of pushing the chevron
                  // off a narrow screen.
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 20, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Account option list. "Semua Akun" is pinned first, then every account with
/// its own mark, so the sheet reads the same way the Wallet does.
class _AccountFilterSheet extends StatelessWidget {
  final List<Account> accounts;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _AccountFilterSheet({
    required this.accounts,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Filter by account',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _AccountOption(
                    key: const Key('account_option_all'),
                    account: null,
                    selected: selected == null,
                    onTap: () => onSelected(null),
                  ),
                  for (final account in accounts)
                    _AccountOption(
                      key: Key('account_option_${account.id}'),
                      account: account,
                      selected: selected == account.id,
                      onTap: () => onSelected(account.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountOption extends StatelessWidget {
  final Account? account;
  final bool selected;
  final VoidCallback onTap;

  const _AccountOption({
    super.key,
    required this.account,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      selected: selected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: _AccountMark(account: account, size: 36),
      title: Text(
        account?.name ?? 'Semua Akun',
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: scheme.onSurface,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_rounded, color: scheme.primary, size: 20)
          : null,
    );
  }
}

/// The account's visual mark: its own colour with its own glyph, or a neutral
/// wallet for the "every account" option. Shared by the pill and the sheet so
/// an account looks the same in both.
class _AccountMark extends StatelessWidget {
  final Account? account;
  final double size;

  const _AccountMark({required this.account, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = account == null
        ? scheme.onSurfaceVariant
        : CAccounts.parseColor(account!.color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: account == null
          ? Icon(Icons.account_balance_wallet_outlined,
              size: size * 0.5, color: color)
          // A bundled vector mark, tinted with the account's own colour.
          : Icon(account!.icon.data, size: size * 0.55, color: color),
    );
  }
}
