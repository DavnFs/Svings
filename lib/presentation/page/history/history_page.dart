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
import 'package:cause_money_record/presentation/widget/aurora_background.dart';
import 'package:cause_money_record/presentation/widget/glass_app_bar.dart';
import 'package:cause_money_record/presentation/widget/liquid_glass.dart';
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: 'Transaction History'),
      body: const AuroraBackground(child: HistoryBody()),
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
  final cHistory = Get.put(CHistory());
  final cUser = Get.put(CUser());
  String _filter = 'All';

  void _refresh() => cHistory.getList(cUser.id);

  Future<void> _delete(String idHistory) async {
    final yes = await AppDialog.confirm(context, 'Delete', 'Are you sure you want to delete this transaction?');
    if (yes) {
      final success = await SourceHistory.delete(idHistory);
      if (success) _refresh();
    }
  }

  @override
  void initState() {
    super.initState();
    _refresh();
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: LiquidGlass(
              radius: 14,
              blur: 16,
              padding: const EdgeInsets.all(4),
              child: Row(
                children: ['All', 'Income', 'Expense'].map((f) {
                  final isSelected = _filter == f;
                  return Expanded(
                    child: Pressable(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _filter = f);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColor.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            f,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppColor.onPrimary : AppColor.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  children: [
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: AppColor.border,
                          indent: 64,
                          endIndent: 16,
                        ),
                        itemBuilder: (context, index) {
                          final h = filtered[index];
                          final isIncome = h.type == 'Pemasukan';
                          return Pressable(
                            onTap: () => Get.to(() => DetailHistoryPage(idHistory: h.idHistory!)),
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
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppFormat.date(h.date),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColor.textPrimary,
                                            fontSize: 14,
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
                                    '${isIncome ? '+' : '-'}${AppFormat.currency(h.total)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: isIncome ? AppColor.income : AppColor.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Semantics(
                                    label: 'Delete transaction on ${AppFormat.date(h.date)}',
                                    button: true,
                                    child: IconButton(
                                      tooltip: 'Delete',
                                      icon: Icon(Icons.delete_outline_rounded, color: AppColor.textSecondary, size: 19),
                                      onPressed: () => _delete(h.idHistory!),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
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
