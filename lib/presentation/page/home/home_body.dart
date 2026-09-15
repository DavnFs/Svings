import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/presentation/controller/c_home.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/page/history/detail_history_page.dart';
import 'package:cause_money_record/presentation/widget/state_view.dart';

/// The home dashboard — today's total, the weekly bar chart, and the monthly
/// donut. Extracted from the former HomePage so the [MainShell] can host it as
/// the first tab of a shared [NavigationBar].
class HomeBody extends StatelessWidget {
  const HomeBody({super.key});

  @override
  Widget build(BuildContext context) {
    final cHome = Get.find<CHome>();

    return Obx(() {
      if (cHome.loading && cHome.today == 0) {
        return ListView(children: const [
          SizedBox(height: 80),
          StateView(loading: true, error: null, empty: false, child: SizedBox.shrink()),
        ]);
      }
      if (cHome.error != null) {
        return ListView(children: [
          const SizedBox(height: 80),
          StateView(
            loading: false,
            error: cHome.error,
            empty: false,
            onRetry: () => cHome.getAnalysis(Get.find<CUser>().id),
            child: const SizedBox.shrink(),
          ),
        ]);
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          const _SectionHeader(title: 'Today'),
          const SizedBox(height: 8),
          _TodayCard(cHome: cHome),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'This Week'),
          const SizedBox(height: 8),
          _WeeklyChart(cHome: cHome),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'This Month'),
          const SizedBox(height: 8),
          _MonthlySection(cHome: cHome),
        ],
      );
    });
  }
}

/// DESIGN.md section header: 18sp w700.
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColor.textPrimary),
    );
  }
}

/// Hero summary card: solid accent fill, radius 18, white figures. The one
/// decorative surface on screen — everything around it stays matte.
class _TodayCard extends StatelessWidget {
  final CHome cHome;

  const _TodayCard({required this.cHome});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColor.accent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Obx(() => Text(
              AppFormat.currency(cHome.today),
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 30),
            )),
        const SizedBox(height: 4),
        Obx(() => Text(cHome.todayPercent,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13))),
        const SizedBox(height: 16),
        Obx(() {
          final todayId = cHome.todayId;
          if (todayId == null) return const SizedBox.shrink();
          return OutlinedButton.icon(
            onPressed: () => Get.to(() => DetailHistoryPage(idHistory: todayId)),
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('View Details'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          );
        }),
      ]),
    );
  }
}

/// Weekly bars inside a grouped card.
class _WeeklyChart extends StatelessWidget {
  final CHome cHome;

  const _WeeklyChart({required this.cHome});

  @override
  Widget build(BuildContext context) {
    return _GroupCard(
      child: Obx(() {
        final data = cHome.week;
        final labels = cHome.weekText();
        final maxVal = data.reduce(max).clamp(1.0, double.infinity);
        final hasData = data.any((v) => v > 0);
        if (!hasData) {
          return const SizedBox(
            height: 160,
            child: StateView(
              loading: false,
              error: null,
              empty: true,
              emptyTitle: 'Belum ada data minggu ini',
              emptyMessage: 'Catat transaksi pertama Anda untuk melihat grafik',
              emptyIcon: Icons.bar_chart_outlined,
              child: SizedBox.shrink(),
            ),
          );
        }
        return SizedBox(
          height: 160,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final ratio = data[i] / maxVal;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (data[i] > 0)
                        Text('${data[i].toInt()}', style: TextStyle(fontSize: 9, color: AppColor.textSecondary)),
                      const SizedBox(height: 4),
                      Container(
                        height: (ratio * 120).clamp(4.0, 120),
                        decoration: BoxDecoration(color: AppColor.accent, borderRadius: BorderRadius.circular(4)),
                      ),
                      const SizedBox(height: 6),
                      Text(labels[i], style: TextStyle(fontSize: 10, color: AppColor.textSecondary)),
                    ],
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

/// Monthly donut + ledger inside a grouped card.
class _MonthlySection extends StatelessWidget {
  final CHome cHome;

  const _MonthlySection({required this.cHome});

  @override
  Widget build(BuildContext context) {
    return _GroupCard(
      child: Obx(() {
        if (cHome.monthIncome == 0 && cHome.monthOutcome == 0) {
          return const SizedBox(
            height: 200,
            child: StateView(
              loading: false,
              error: null,
              empty: true,
              emptyTitle: 'Belum ada transaksi bulan ini',
              emptyMessage: 'Tambah Pemasukan atau Pengeluaran untuk mulai melacak',
              emptyIcon: Icons.pie_chart_outline,
              child: SizedBox.shrink(),
            ),
          );
        }
        return Column(children: [
          Row(children: [
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(children: [
                CustomPaint(
                  size: const Size(140, 140),
                  painter: _DonutPainter(
                    income: cHome.monthIncome,
                    outcome: cHome.monthOutcome,
                    incomeColor: AppColor.income,
                    outcomeColor: AppColor.outcome,
                  ),
                ),
                Center(
                  child: Text('${cHome.percentIncome}%',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColor.textPrimary)),
                ),
              ]),
            ),
            const SizedBox(width: 24),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _LegendItem(color: AppColor.income, label: 'Income'),
              const SizedBox(height: 8),
              _LegendItem(color: AppColor.outcome, label: 'Expense'),
              const SizedBox(height: 16),
              Text(cHome.monthPercent, style: TextStyle(fontSize: 12, color: AppColor.textSecondary, height: 1.4)),
            ])),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: AppColor.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColor.border),
            ),
            child: Row(children: [
              Text('Difference', style: TextStyle(color: AppColor.textSecondary, fontSize: 13)),
              const Spacer(),
              Text(AppFormat.currency(cHome.differentMonth),
                  style: TextStyle(color: AppColor.accent, fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]);
      }),
    );
  }
}

/// Swatch + label for the donut legend.
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontSize: 13, color: AppColor.textSecondary)),
    ]);
  }
}

/// DESIGN.md inset grouped surface: single solid matte card, radius 18,
/// 16dp inner padding, hairline outline. No nested cards, no glass.
class _GroupCard extends StatelessWidget {
  final Widget child;

  const _GroupCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColor.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColor.border),
      ),
      child: child,
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double income;
  final double outcome;
  final Color incomeColor;
  final Color outcomeColor;

  _DonutPainter({required this.income, required this.outcome, required this.incomeColor, required this.outcomeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 18.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final total = income + outcome;
    if (total == 0) {
      paint.color = AppColor.border;
      canvas.drawCircle(center, radius - strokeWidth / 2, paint);
      return;
    }

    final incomeAngle = (income / total) * 2 * pi;
    final outcomeAngle = (outcome / total) * 2 * pi;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    paint.color = incomeColor;
    canvas.drawArc(rect, -pi / 2, incomeAngle, false, paint);
    paint.color = outcomeColor;
    canvas.drawArc(rect, -pi / 2 + incomeAngle, outcomeAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
