import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/config/app_dialog.dart';
import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/data/source/source_history.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/controller/history/c_history.dart';
import 'package:cause_money_record/presentation/page/history/detail_history_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final cHistory = Get.put(CHistory());
  final cUser = Get.put(CUser());

  void _refresh() => cHistory.getList(cUser.id);

  Future<void> _delete(String idHistory) async {
    final yes = await AppDialog.confirm(context, 'Hapus', 'Yakin untuk menghapus history ini?');
    if (yes) {
      final success = await SourceHistory.delete(idHistory);
      if (success) _refresh();
    }
  }

  @override
  void initState() { super.initState(); _refresh(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.surface,
      appBar: AppBar(
        backgroundColor: AppColor.card, foregroundColor: AppColor.textPrimary, elevation: 0,
        title: const Text('History', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Obx(() {
        if (cHistory.loading) return Center(child: CircularProgressIndicator(color: AppColor.accent));
        if (cHistory.list.isEmpty) return Center(child: Text('No entries', style: TextStyle(color: AppColor.textSecondary)));
        return RefreshIndicator(
          color: AppColor.accent,
          onRefresh: () async => _refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: cHistory.list.length,
            itemBuilder: (context, index) {
              final h = cHistory.list[index];
              final isIncome = h.type == 'Pemasukan';
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
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(AppFormat.date(h.date), style: TextStyle(fontWeight: FontWeight.w600, color: AppColor.textPrimary, fontSize: 14)),
                        Text(isIncome ? 'Income' : 'Expense',
                          style: TextStyle(color: isIncome ? AppColor.income : AppColor.outcome, fontSize: 12)),
                      ])),
                      Text(AppFormat.currency(h.total), style: TextStyle(fontWeight: FontWeight.w700, color: AppColor.textPrimary, fontSize: 15)),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: AppColor.textSecondary, size: 20),
                        onPressed: () => _delete(h.idHistory!),
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
