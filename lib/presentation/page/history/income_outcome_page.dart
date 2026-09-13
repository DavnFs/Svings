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

class IncomeOutcomePage extends StatefulWidget {
  final String type;
  const IncomeOutcomePage({Key? key, required this.type}) : super(key: key);

  @override
  State<IncomeOutcomePage> createState() => _IncomeOutcomePageState();
}

class _IncomeOutcomePageState extends State<IncomeOutcomePage> {
  final cInOut = Get.put(CIncomeOutcome());
  final cUser = Get.put(CUser());

  void _refresh() => cInOut.getList(cUser.id, widget.type);

  Future<void> _handleMenu(String value, History history) async {
    if (value == 'update') {
      final result = await Get.to(() => HistoryFormPage(idHistory: history.idHistory));
      if (result == true) _refresh();
    } else if (value == 'delete') {
      final yes = await AppDialog.confirm(context, 'Hapus', 'Yakin untuk menghapus history ini?');
      if (yes) {
        final success = await SourceHistory.delete(history.idHistory!);
        if (success) _refresh();
      }
    }
  }

  @override
  void initState() { super.initState(); _refresh(); }

  @override
  Widget build(BuildContext context) {
    final isIncome = widget.type == 'Pemasukan';
    return Scaffold(
      backgroundColor: AppColor.surface,
      appBar: AppBar(
        backgroundColor: AppColor.card, foregroundColor: AppColor.textPrimary, elevation: 0,
        title: Text(isIncome ? 'Income' : 'Expense', style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Obx(() {
        if (cInOut.loading) return Center(child: CircularProgressIndicator(color: AppColor.accent));
        if (cInOut.list.isEmpty) return Center(child: Text('No entries', style: TextStyle(color: AppColor.textSecondary)));
        return RefreshIndicator(
          color: AppColor.accent,
          onRefresh: () async => _refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: cInOut.list.length,
            itemBuilder: (context, index) {
              final h = cInOut.list[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColor.card, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColor.border),
                ),
                child: InkWell(
                  onTap: () => Get.to(() => DetailHistoryPage(idHistory: h.idHistory!)),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: isIncome ? AppColor.income.withOpacity(0.1) : AppColor.outcome.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          color: isIncome ? AppColor.income : AppColor.outcome, size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(AppFormat.date(h.date),
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppColor.textPrimary, fontSize: 14))),
                      Text(AppFormat.currency(h.total),
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColor.textPrimary, fontSize: 15)),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: AppColor.textSecondary, size: 20),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'update', child: Text('Update')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                        onSelected: (v) => _handleMenu(v, h),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
