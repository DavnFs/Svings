import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/presentation/controller/history/c_detail_history.dart';

class DetailHistoryPage extends StatefulWidget {
  final String idHistory;

  const DetailHistoryPage({Key? key, required this.idHistory}) : super(key: key);

  @override
  State<DetailHistoryPage> createState() => _DetailHistoryPageState();
}

class _DetailHistoryPageState extends State<DetailHistoryPage> {
  final cDetail = Get.put(CDetailHistory());

  @override
  void initState() {
    super.initState();
    cDetail.getData(widget.idHistory);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.surface,
      appBar: AppBar(
        backgroundColor: AppColor.card,
        foregroundColor: AppColor.textPrimary,
        elevation: 0,
        title: Obx(() {
          final d = cDetail.data;
          if (d == null) return const SizedBox.shrink();
          final isIncome = d.type == 'Pemasukan';
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppFormat.date(d.date),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isIncome ? AppColor.income.withOpacity(0.1) : AppColor.outcome.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isIncome ? 'Income' : 'Expense',
                  style: TextStyle(
                    color: isIncome ? AppColor.income : AppColor.outcome,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
      body: Obx(() {
        final d = cDetail.data;
        if (d == null) {
          return Center(
            child: Text('No data', style: TextStyle(color: AppColor.textSecondary)),
          );
        }
        final items = d.items;
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColor.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColor.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total', style: TextStyle(color: AppColor.textSecondary, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    AppFormat.currency(d.total),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColor.textPrimary,
                    ),
                  ),
                  if (d.notes != null && d.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      d.notes!,
                      style: TextStyle(fontSize: 13, color: AppColor.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: items.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: AppColor.border, indent: 16, endIndent: 16),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColor.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(color: AppColor.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(fontSize: 15, color: AppColor.textPrimary),
                          ),
                        ),
                        Text(
                          AppFormat.currency(num.tryParse(item.price) ?? 0),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColor.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }
}
