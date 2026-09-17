import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_dialog.dart';
import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/data/model/history.dart';
import 'package:cause_money_record/data/source/source_history.dart';
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
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    cHistory = Get.find<CHistory>();
    cUser = Get.find<CUser>();
    _refresh();
  }

  void _refresh() => cHistory.getList(cUser.id);

  Future<void> _delete(String idHistory) async {
    final yes = await AppDialog.confirm(context, 'Delete', 'Are you sure you want to delete this transaction?');
    if (yes) {
      final success = await SourceHistory.delete(idHistory);
      if (success) _refresh();
    }
  }

  List<History> _getFilteredList(List<History> all) {
    var out = all;
    // Account pre-filter first (account card tap), then the type segment.
    final accountId = widget.accountId;
    if (accountId != null) {
      out = out
          .where((h) =>
              h.accountId == accountId || h.transferToAccountId == accountId)
          .toList();
    }
    if (_filter == 'Income') {
      return out.where((h) => h.type == 'Pemasukan').toList();
    } else if (_filter == 'Expense') {
      return out.where((h) => h.type == 'Pengeluaran').toList();
    } else if (_filter == 'Transfer') {
      return out.where((h) => h.type == 'Transfer').toList();
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                        emptyTitle: _filter == 'All' ? 'No Transactions Yet' : 'No $_filter Entries',
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  children: [
                    _GroupedList(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final h = filtered[index];
                        final isIncome = h.type == 'Pemasukan';
                        final isTransfer = h.type == 'Transfer';
                        // Transfers show no sign (they are not gains/losses)
                        // and name the direction instead of Income/Expense.
                        final amount = isTransfer
                            ? AppFormat.currency(h.total)
                            : '${isIncome ? '+' : '-'}${AppFormat.currency(h.total)}';
                        return _TransactionRow(
                          scheme: scheme,
                          date: AppFormat.date(h.date),
                          isIncome: isIncome,
                          isTransfer: isTransfer,
                          amount: amount,
                          onTap: () => Get.to(() => DetailHistoryPage(idHistory: h.idHistory!)),
                          onDelete: () => _delete(h.idHistory!),
                          deleteLabel: 'Delete transaction on ${AppFormat.date(h.date)}',
                        );
                      },
                    ),
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
          indent: 64,
          endIndent: 16,
        ),
        itemBuilder: itemBuilder,
      ),
    );
  }
}

/// One transaction row: status icon, date + type, signed amount, delete.
/// Transfers render a swap icon and no sign.
class _TransactionRow extends StatelessWidget {
  final ColorScheme scheme;
  final String date;
  final bool isIncome;
  final bool isTransfer;
  final String amount;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final String deleteLabel;

  const _TransactionRow({
    required this.scheme,
    required this.date,
    required this.isIncome,
    this.isTransfer = false,
    required this.amount,
    required this.onTap,
    required this.onDelete,
    required this.deleteLabel,
  });

  @override
  Widget build(BuildContext context) {
    final status = isTransfer
        ? scheme.primary
        : (isIncome ? scheme.tertiary : scheme.error);
    final icon = isTransfer
        ? Icons.swap_horiz_rounded
        : (isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded);
    final kindLabel =
        isTransfer ? 'Transfer' : (isIncome ? 'Income' : 'Expense');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: status.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: status, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    kindLabel,
                    style: TextStyle(
                      color: status,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              amount,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isTransfer ? scheme.onSurface : (isIncome ? status : scheme.onSurface),
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 4),
            Semantics(
              label: deleteLabel,
              button: true,
              child: IconButton(
                tooltip: 'Delete',
                icon: Icon(Icons.delete_outline_rounded, color: scheme.onSurfaceVariant, size: 19),
                onPressed: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
