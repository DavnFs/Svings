import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/config/app_dialog.dart';
import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/data/model/history.dart';
import 'package:cause_money_record/data/source/source_history.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/controller/history/c_history.dart';
import 'package:cause_money_record/presentation/page/history/detail_history_page.dart';
import 'package:cause_money_record/presentation/widget/frosted_app_bar.dart';
import 'package:cause_money_record/presentation/widget/pressable.dart';
import 'package:cause_money_record/presentation/widget/state_view.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: FrostedAppBar(title: 'Transaction History'),
      body: HistoryBody(),
    );
  }
}

/// The list content of [HistoryPage], extracted so the [MainShell] can embed it
/// as a tab under a shared [NavigationBar].
class HistoryBody extends StatefulWidget {
  const HistoryBody({super.key});

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
    if (_filter == 'Income') {
      return all.where((h) => h.type == 'Pemasukan').toList();
    } else if (_filter == 'Expense') {
      return all.where((h) => h.type == 'Pengeluaran').toList();
    }
    return all;
  }

  @override
  Widget build(BuildContext context) {
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
                  color: AppColor.accent,
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
                color: AppColor.accent,
                onRefresh: () async => _refresh(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  children: [
                    _GroupedList(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final h = filtered[index];
                        final isIncome = h.type == 'Pemasukan';
                        return _TransactionRow(
                          date: AppFormat.date(h.date),
                          isIncome: isIncome,
                          amount: '${isIncome ? '+' : '-'}${AppFormat.currency(h.total)}',
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

/// All/Income/Expense segmented control in a single grouped surface.
class _FilterSegment extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _FilterSegment({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColor.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColor.border),
      ),
      child: Row(
        children: ['All', 'Income', 'Expense'].map((f) {
          final isSelected = value == f;
          return Expanded(
            child: Pressable(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(f);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColor.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    f,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColor.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// DESIGN.md inset grouped list: rows share ONE continuous card with hairline
/// inset dividers — no per-row card boxes.
class _GroupedList extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

  const _GroupedList({required this.itemCount, required this.itemBuilder});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColor.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColor.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: itemCount,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: AppColor.border,
          indent: 64,
          endIndent: 16,
        ),
        itemBuilder: itemBuilder,
      ),
    );
  }
}

/// One transaction row: status icon, date + type, signed amount, delete.
class _TransactionRow extends StatelessWidget {
  final String date;
  final bool isIncome;
  final String amount;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final String deleteLabel;

  const _TransactionRow({
    required this.date,
    required this.isIncome,
    required this.amount,
    required this.onTap,
    required this.onDelete,
    required this.deleteLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isIncome
                    ? AppColor.income.withValues(alpha: 0.12)
                    : AppColor.outcome.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: isIncome ? AppColor.income : AppColor.outcome,
                size: 18,
              ),
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
                      color: AppColor.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isIncome ? 'Income' : 'Expense',
                    style: TextStyle(
                      color: isIncome ? AppColor.income : AppColor.outcome,
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
                color: isIncome ? AppColor.income : AppColor.textPrimary,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 4),
            Semantics(
              label: deleteLabel,
              button: true,
              child: IconButton(
                tooltip: 'Delete',
                icon: Icon(Icons.delete_outline_rounded, color: AppColor.textSecondary, size: 19),
                onPressed: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
