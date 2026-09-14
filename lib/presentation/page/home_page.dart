import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_asset.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/config/sessions.dart';
import 'package:cause_money_record/data/source/source_user.dart';
import 'package:cause_money_record/presentation/controller/c_home.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/controller/history/c_history.dart';
import 'package:cause_money_record/presentation/page/auth/login_page.dart';
import 'package:cause_money_record/presentation/page/history/detail_history_page.dart';
import 'package:cause_money_record/presentation/page/history/history_form_page.dart';
import 'package:cause_money_record/presentation/page/history/history_page.dart';
import 'package:cause_money_record/presentation/page/history/income_outcome_page.dart';
import 'package:cause_money_record/presentation/widget/state_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final cUser = Get.put(CUser());
  final cHome = Get.put(CHome());
  final cHistory = Get.put(CHistory());
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await Future.wait([
      cHome.getAnalysis(cUser.id),
      cHistory.getList(cUser.id),
    ]);
  }

  Future<void> _signOut() async {
    await SourceUser.logout();
    await Session.clearUser();
    Get.off(() => const LoginPage());
  }

  void _showProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColor.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColor.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(AppAsset.profile, width: 64, height: 64),
                ),
                const SizedBox(height: 14),
                Obx(() => Text(
                      cUser.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColor.textPrimary,
                      ),
                    )),
                const SizedBox(height: 4),
                Obx(() => Text(
                      cUser.data.email ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColor.textSecondary,
                      ),
                    )),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _signOut();
                    },
                    icon: Icon(Icons.logout_rounded, color: AppColor.danger, size: 18),
                    label: Text(
                      'Sign Out',
                      style: TextStyle(
                        color: AppColor.danger,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColor.danger.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.surface,
      body: Stack(
        children: [
          SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: _navIndex == 0 ? _buildDashboardView() : const HistoryPage(),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _header(context),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _bottomNavBar(context),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          color: AppColor.surface.withValues(alpha: 0.75),
          padding: EdgeInsets.fromLTRB(20, topPadding + 8, 20, 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _showProfileSheet(context),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColor.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(AppAsset.profile, width: 38, height: 38),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Hello,',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColor.textSecondary,
                      ),
                    ),
                    Obx(() => Text(
                          cUser.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColor.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        )),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Add Transaction',
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColor.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                ),
                onPressed: () {
                  Get.to(() => const HistoryFormPage())?.then((v) {
                    if (v == true) _refresh();
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomNavBar(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          color: AppColor.surface.withValues(alpha: 0.8),
          padding: EdgeInsets.fromLTRB(28, 10, 28, max(bottomPadding, 10)),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColor.card.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColor.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.pie_chart_rounded, 'Dashboard'),
                _navItem(1, Icons.receipt_long_rounded, 'Transactions'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isSelected = _navIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _navIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColor.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : AppColor.textSecondary,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardView() {
    final topInset = MediaQuery.of(context).padding.top + 68;
    return RefreshIndicator(
      color: AppColor.accent,
      edgeOffset: topInset,
      onRefresh: _refresh,
      child: Obx(() {
        if (cHome.loading && cHome.today == 0) {
          return ListView(
            padding: EdgeInsets.only(top: topInset + 40, bottom: 90),
            children: const [
              StateView(loading: true, error: null, empty: false, child: SizedBox.shrink()),
            ],
          );
        }
        if (cHome.error != null) {
          return ListView(
            padding: EdgeInsets.only(top: topInset + 40, bottom: 90),
            children: [
              StateView(
                loading: false,
                error: cHome.error,
                empty: false,
                onRetry: _refresh,
                child: const SizedBox.shrink(),
              ),
            ],
          );
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 100),
          children: [
            _todayCard(context),
            const SizedBox(height: 18),
            _quickActions(context),
            const SizedBox(height: 28),
            _sectionLabel('Weekly Expense Trend'),
            const SizedBox(height: 10),
            _weeklyChart(),
            const SizedBox(height: 28),
            _sectionLabel('Monthly Distribution'),
            const SizedBox(height: 10),
            _monthlySection(context),
            const SizedBox(height: 28),
            _recentTransactionsSection(),
          ],
        );
      }),
    );
  }

  Widget _quickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            label: 'Income',
            icon: Icons.arrow_downward_rounded,
            color: AppColor.income,
            onTap: () => Get.to(() => const IncomeOutcomePage(type: 'Pemasukan')),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionButton(
            label: 'Expense',
            icon: Icons.arrow_upward_rounded,
            color: AppColor.outcome,
            onTap: () => Get.to(() => const IncomeOutcomePage(type: 'Pengeluaran')),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionButton(
            label: 'History',
            icon: Icons.history_rounded,
            color: AppColor.accent,
            onTap: () => setState(() => _navIndex = 1),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColor.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColor.border),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColor.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColor.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _todayCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColor.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Expense",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Obx(() {
                final percent = cHome.todayPercent;
                if (percent.isEmpty) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    percent,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 10),
          Obx(() => Text(
                AppFormat.currency(cHome.today),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              )),
          const SizedBox(height: 16),
          Obx(() {
            final todayId = cHome.todayId;
            if (todayId == null) return const SizedBox.shrink();
            return GestureDetector(
              onTap: () => Get.to(() => DetailHistoryPage(idHistory: todayId)),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Today Details',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _weeklyChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColor.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColor.border),
      ),
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
              emptyTitle: 'No Activity This Week',
              emptyMessage: 'Recorded expenses will automatically plot daily trends.',
              emptyIcon: Icons.bar_chart_rounded,
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
              final isPositive = data[i] > 0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isPositive)
                        Text(
                          '${data[i].toInt()}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColor.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: (ratio * 110).clamp(6.0, 110),
                        decoration: BoxDecoration(
                          color: isPositive ? AppColor.accent : AppColor.border,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColor.textSecondary,
                        ),
                      ),
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

  Widget _monthlySection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColor.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColor.border),
      ),
      child: Obx(() {
        if (cHome.monthIncome == 0 && cHome.monthOutcome == 0) {
          return const SizedBox(
            height: 180,
            child: StateView(
              loading: false,
              error: null,
              empty: true,
              emptyTitle: 'No Monthly Activity',
              emptyMessage: 'Add an income or expense to see monthly ratios.',
              emptyIcon: Icons.pie_chart_rounded,
              child: SizedBox.shrink(),
            ),
          );
        }

        return Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: const Size(130, 130),
                        painter: _DonutPainter(
                          income: cHome.monthIncome,
                          outcome: cHome.monthOutcome,
                          incomeColor: AppColor.income,
                          outcomeColor: AppColor.outcome,
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${cHome.percentIncome}%',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColor.textPrimary,
                              ),
                            ),
                            Text(
                              'Income',
                              style: TextStyle(fontSize: 10, color: AppColor.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _legendItem(AppColor.income, 'Income', AppFormat.currency(cHome.monthIncome)),
                      const SizedBox(height: 10),
                      _legendItem(AppColor.outcome, 'Expense', AppFormat.currency(cHome.monthOutcome)),
                      const SizedBox(height: 14),
                      Text(
                        cHome.monthPercent,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColor.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: AppColor.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    'Net Difference',
                    style: TextStyle(color: AppColor.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Text(
                    AppFormat.currency(cHome.differentMonth),
                    style: TextStyle(
                      color: AppColor.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _legendItem(Color color, String label, String amount) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColor.textPrimary),
        ),
        const Spacer(),
        Text(
          amount,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColor.textSecondary),
        ),
      ],
    );
  }

  Widget _recentTransactionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionLabel('Recent Activity'),
            GestureDetector(
              onTap: () => setState(() => _navIndex = 1),
              child: Text(
                'See All',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColor.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Obx(() {
          final list = cHistory.list.take(3).toList();
          if (list.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColor.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColor.border),
              ),
              child: Center(
                child: Text(
                  'No recent transactions recorded.',
                  style: TextStyle(color: AppColor.textSecondary, fontSize: 13),
                ),
              ),
            );
          }

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
              itemCount: list.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: AppColor.border,
                indent: 64,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                final h = list[index];
                final isIncome = h.type == 'Pemasukan';
                return InkWell(
                  onTap: () => Get.to(() => DetailHistoryPage(idHistory: h.idHistory!)),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
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
                        Icon(Icons.chevron_right_rounded, color: AppColor.textSecondary, size: 18),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double income;
  final double outcome;
  final Color incomeColor;
  final Color outcomeColor;

  _DonutPainter({
    required this.income,
    required this.outcome,
    required this.incomeColor,
    required this.outcomeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 16.0;
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
