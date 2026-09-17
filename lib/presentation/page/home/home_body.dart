import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
          StateView(
              loading: true,
              error: null,
              empty: false,
              child: SizedBox.shrink()),
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
    final scheme = Theme.of(context).colorScheme;
    return Text(
      title,
      style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurface),
    );
  }
}

/// Hero summary card: primary-container tonal fill, on-primary-container
/// figures. No shadows — depth comes from tone.
class _TodayCard extends StatelessWidget {
  final CHome cHome;

  const _TodayCard({required this.cHome});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Obx(() => Text(
                AppFormat.currency(cHome.today),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                    fontSize: 30),
              )),
          const SizedBox(height: 4),
          Obx(() => Text(cHome.todayPercent,
              style: TextStyle(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
                  fontSize: 13))),
          const SizedBox(height: 16),
          Obx(() {
            final todayId = cHome.todayId;
            if (todayId == null) return const SizedBox.shrink();
            return FilledButton.tonalIcon(
              onPressed: () =>
                  Get.to(() => DetailHistoryPage(idHistory: todayId)),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('View Details'),
            );
          }),
        ]),
      ),
    );
  }
}

/// Weekly bars inside a tonal card.
class _WeeklyChart extends StatelessWidget {
  final CHome cHome;

  const _WeeklyChart({required this.cHome});

  /// Short axis label: full integers overflow 1/7 of the card width (a 5-digit
  /// total like 19570 needs ~30dp in a ~44dp cell), and the overflow rendered
  /// as a wrapped fragment that looked like a stray "/" ("195/0"). Compact
  /// form keeps every label on one line: 19570 -> "19,6rb".
  static String _compactValue(double v) {
    if (v >= 1000000) {
      final s = (v / 1000000).toStringAsFixed(1).replaceAll('.', ',');
      return '${s}jt';
    }
    if (v >= 1000) {
      final s = (v / 1000).toStringAsFixed(1).replaceAll('.', ',');
      return '${s}rb';
    }
    return v.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                emptyMessage:
                    'Catat transaksi pertama Anda untuk melihat grafik',
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
                  // Tight cells: 7 columns share the card width, so each keeps
                  // only 2dp gutters — 4dp each side clipped the last bar.
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (data[i] > 0)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _compactValue(data[i]),
                              maxLines: 1,
                              style: TextStyle(
                                  fontSize: 9, color: scheme.onSurfaceVariant),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Container(
                          height: (ratio * 120).clamp(4.0, 120),
                          decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(height: 6),
                        Text(labels[i],
                            style: TextStyle(
                                fontSize: 10, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}

/// Monthly donut + ledger inside a tonal card.
class _MonthlySection extends StatelessWidget {
  final CHome cHome;

  const _MonthlySection({required this.cHome});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          if (cHome.monthIncome == 0 && cHome.monthOutcome == 0) {
            return const SizedBox(
              height: 200,
              child: StateView(
                loading: false,
                error: null,
                empty: true,
                emptyTitle: 'Belum ada transaksi bulan ini',
                emptyMessage:
                    'Tambah Pemasukan atau Pengeluaran untuk mulai melacak',
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
                      incomeColor: scheme.tertiary,
                      outcomeColor: scheme.error,
                      emptyColor: scheme.outlineVariant,
                    ),
                  ),
                  Center(
                    child: Text('${cHome.percentIncome}%',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface)),
                  ),
                ]),
              ),
              const SizedBox(width: 24),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _LegendItem(color: scheme.tertiary, label: 'Income'),
                    const SizedBox(height: 8),
                    _LegendItem(color: scheme.error, label: 'Expense'),
                    const SizedBox(height: 16),
                    Text(cHome.monthPercent,
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                            height: 1.4)),
                  ])),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Text('Difference',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 13)),
                const Spacer(),
                Text(AppFormat.currency(cHome.differentMonth),
                    style: TextStyle(
                        color: scheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ]);
        }),
      ),
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
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
    ]);
  }
}

class _DonutPainter extends CustomPainter {
  final double income;
  final double outcome;
  final Color incomeColor;
  final Color outcomeColor;
  final Color emptyColor;

  _DonutPainter(
      {required this.income,
      required this.outcome,
      required this.incomeColor,
      required this.outcomeColor,
      required this.emptyColor});

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
      paint.color = emptyColor;
      canvas.drawCircle(center, radius - strokeWidth / 2, paint);
      return;
    }

    final incomeAngle = (income / total) * 2 * pi;
    final outcomeAngle = (outcome / total) * 2 * pi;
    final rect =
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    paint.color = incomeColor;
    canvas.drawArc(rect, -pi / 2, incomeAngle, false, paint);
    paint.color = outcomeColor;
    canvas.drawArc(rect, -pi / 2 + incomeAngle, outcomeAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.income != income ||
      oldDelegate.outcome != outcome ||
      oldDelegate.incomeColor != incomeColor ||
      oldDelegate.outcomeColor != outcomeColor ||
      oldDelegate.emptyColor != emptyColor;
}
