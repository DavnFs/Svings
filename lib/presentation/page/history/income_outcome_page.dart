import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/config/app_dialog.dart';
import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/data/model/history.dart';
import 'package:cause_money_record/data/source/source_history.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/controller/history/c_income_outcome.dart';
import 'package:cause_money_record/presentation/page/history/detail_history_page.dart';
import 'package:cause_money_record/presentation/page/history/history_form_page.dart';
import 'package:cause_money_record/presentation/widget/aurora_background.dart';
import 'package:cause_money_record/presentation/widget/glass_app_bar.dart';
import 'package:cause_money_record/presentation/widget/liquid_glass.dart';
import 'package:cause_money_record/presentation/widget/pressable.dart';
import 'package:cause_money_record/presentation/widget/state_view.dart';

/// Money entries of one type — 'Pemasukan' or 'Pengeluaran'.
///
/// Embeddable (no Scaffold of its own): the [MainShell] shows this as a tab
/// under a shared [NavigationBar]. Kept as a standalone page too, for the
/// deep-link routes that still push it directly.
class IncomeOutcomePage extends StatefulWidget {
  final String type;
  const IncomeOutcomePage({super.key, required this.type});

  @override
  State<IncomeOutcomePage> createState() => _IncomeOutcomePageState();
}

class _IncomeOutcomePageState extends State<IncomeOutcomePage> {
  @override
  Widget build(BuildContext context) {
    final isIncome = widget.type == 'Pemasukan';
    final titleText = isIncome ? 'Income Records' : 'Expense Records';

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: titleText),
      body: AuroraBackground(child: IncomeOutcomeBody(type: widget.type)),
    );
  }
}

/// The list content of [IncomeOutcomePage], extracted so the [MainShell] can
/// embed it as a tab without a nested Scaffold/AppBar.
class IncomeOutcomeBody extends StatefulWidget {
  final String type;
  const IncomeOutcomeBody({super.key, required this.type});

  @override
  State<IncomeOutcomeBody> createState() => _IncomeOutcomeBodyState();
}

class _IncomeOutcomeBodyState extends State<IncomeOutcomeBody> {
  final cInOut = Get.put(CIncomeOutcome());
  final cUser = Get.put(CUser());

  void _refresh() => cInOut.getList(cUser.id, widget.type);

  Future<void> _handleMenu(String value, History history) async {
    if (value == 'update') {
      final result = await Get.to(() => HistoryFormPage(idHistory: history.idHistory));
      if (result == true) _refresh();
    } else if (value == 'delete') {
      final yes = await AppDialog.confirm(context, 'Delete', 'Are you sure you want to delete this entry?');
      if (yes) {
        final success = await SourceHistory.delete(history.idHistory!);
        if (success) _refresh();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = widget.type == 'Pemasukan';
    return Obx(() {
      return _list(context, isIncome);
    });
  }

  Widget _list(BuildContext context, bool isIncome) {
        if (cInOut.loading) {
          return const StateView(
            loading: true,
            error: null,
            empty: false,
            child: SizedBox.shrink(),
          );
        }
        if (cInOut.error != null) {
          return StateView(
            loading: false,
            error: cInOut.error,
            empty: false,
            onRetry: _refresh,
            child: const SizedBox.shrink(),
          );
        }
        if (cInOut.list.isEmpty) {
          return RefreshIndicator(
            color: AppColor.accent,
            onRefresh: () async => _refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                StateView(
                  loading: false,
                  error: null,
                  empty: true,
                  emptyTitle: isIncome ? 'No Income Records Yet' : 'No Expense Records Yet',
                  emptyMessage: 'New entries created under this category will show up here.',
                  emptyIcon: isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
              GlassCard(
                padding: EdgeInsets.zero,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: cInOut.list.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: AppColor.border,
                    indent: 64,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, index) {
                    final h = cInOut.list[index];
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
                              child: Text(
                                AppFormat.date(h.date),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColor.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              AppFormat.currency(h.total),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isIncome ? AppColor.income : AppColor.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            Semantics(
                              label: 'More actions for entry on ${AppFormat.date(h.date)}',
                              button: true,
                              child: PopupMenuButton<String>(
                                tooltip: 'More actions',
                                icon: Icon(Icons.more_vert_rounded, color: AppColor.textSecondary, size: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'update', child: Text('Edit')),
                                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                                onSelected: (v) => _handleMenu(v, h),
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
  }
}
