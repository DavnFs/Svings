import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/presentation/controller/history/c_detail_history.dart';
import 'package:cause_money_record/presentation/widget/glass_app_bar.dart';
import 'package:cause_money_record/presentation/widget/state_view.dart';

class DetailHistoryPage extends StatefulWidget {
  final String idHistory;

  const DetailHistoryPage({super.key, required this.idHistory});

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
      appBar: const GlassAppBar(title: 'Transaction Detail'),
      body: Obx(() {
        final d = cDetail.data;
        if (d == null) {
          return const StateView(
            loading: true,
            error: null,
            empty: false,
            child: SizedBox.shrink(),
          );
        }
        final isIncome = d.type == 'Pemasukan';
        final items = d.items;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColor.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColor.border),
              ),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isIncome
                          ? AppColor.income.withValues(alpha: 0.12)
                          : AppColor.outcome.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      color: isIncome ? AppColor.income : AppColor.outcome,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    AppFormat.currency(d.total),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColor.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isIncome
                          ? AppColor.income.withValues(alpha: 0.1)
                          : AppColor.outcome.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isIncome ? 'Income' : 'Expense',
                      style: TextStyle(
                        color: isIncome ? AppColor.income : AppColor.outcome,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: AppColor.border),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Date',
                        style: TextStyle(color: AppColor.textSecondary, fontSize: 13),
                      ),
                      Text(
                        AppFormat.date(d.date),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColor.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  if (d.notes != null && d.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notes',
                          style: TextStyle(color: AppColor.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            d.notes!,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: AppColor.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Items Breakdown (${items.length})',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColor.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColor.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColor.border),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: items.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: AppColor.border,
                  indent: 56,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColor.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColor.border),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: AppColor.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColor.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          AppFormat.currency(num.tryParse(item.price) ?? 0),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
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
