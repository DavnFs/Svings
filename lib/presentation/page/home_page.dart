import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_asset.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/config/sessions.dart';
import 'package:cause_money_record/data/source/source_user.dart';
import 'package:cause_money_record/presentation/controller/c_home.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/page/auth/login_page.dart';
import 'package:cause_money_record/presentation/page/history/detail_history_page.dart';
import 'package:cause_money_record/presentation/page/history/history_form_page.dart';
import 'package:cause_money_record/presentation/page/history/history_page.dart';
import 'package:cause_money_record/presentation/page/history/income_outcome_page.dart';
import 'package:cause_money_record/presentation/page/student/student_dashboard_page.dart';
import 'package:cause_money_record/presentation/widget/state_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final cUser = Get.put(CUser());
  final cHome = Get.put(CHome());

  @override
  void initState() {
    super.initState();
    cHome.getAnalysis(cUser.id);
  }

  Future<void> _refresh() => cHome.getAnalysis(cUser.id);

  Future<void> _signOut() async {
    await SourceUser.logout();
    await Session.clearUser();
    Get.off(() => const LoginPage());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.surface,
      endDrawer: _drawer(),
      body: Column(children: [
        _header(context),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh, color: AppColor.accent,
            child: Obx(() {
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
                    onRetry: _refresh,
                    child: const SizedBox.shrink(),
                  ),
                ]);
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  _sectionLabel('Today'), const SizedBox(height: 8),
                  _todayCard(context),
                  const SizedBox(height: 28),
                  _sectionLabel('This Week'), const SizedBox(height: 8),
                  _weeklyChart(),
                  const SizedBox(height: 28),
                  _sectionLabel('This Month'), const SizedBox(height: 8),
                  _monthlySection(context),
                ],
              );
            }),
          ),
        ),
      ]),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 12),
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset(AppAsset.profile, width: 44, height: 44)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hi,', style: TextStyle(fontSize: 14, color: AppColor.textSecondary)),
          Obx(() => Text(cUser.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColor.textPrimary))),
        ])),
        Material(
          color: AppColor.card, borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => Scaffold.of(context).openEndDrawer(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: AppColor.border), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.menu, color: AppColor.textPrimary, size: 22),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _drawer() {
    return Drawer(
      backgroundColor: AppColor.card,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.asset(AppAsset.profile, width: 52, height: 52)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Obx(() => Text(cUser.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColor.textPrimary))),
                  Obx(() => Text(cUser.data.email ?? '', style: TextStyle(fontSize: 13, color: AppColor.textSecondary))),
                ])),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 42,
                child: OutlinedButton(
                  onPressed: _signOut,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColor.danger, side: BorderSide(color: AppColor.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Sign Out'),
                ),
              ),
            ]),
          ),
          Divider(height: 1, color: AppColor.border),
          _drawerItem(Icons.school_outlined, 'Akademik', () {
            Get.to(() => const StudentDashboardPage());
          }),
          _drawerItem(Icons.add_circle_outline, 'New Entry', () {
            Get.to(() => const HistoryFormPage())?.then((v) { if (v == true) _refresh(); });
          }),
          _drawerItem(Icons.arrow_downward_rounded, 'Income', () {
            Get.to(() => const IncomeOutcomePage(type: 'Pemasukan'));
          }),
          _drawerItem(Icons.arrow_upward_rounded, 'Expense', () {
            Get.to(() => const IncomeOutcomePage(type: 'Pengeluaran'));
          }),
          _drawerItem(Icons.receipt_long_outlined, 'History', () {
            Get.to(() => const HistoryPage());
          }),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('svings', style: TextStyle(color: AppColor.textSecondary.withOpacity(0.5), fontSize: 12)),
          ),
        ]),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Icon(icon, color: AppColor.textPrimary, size: 22),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColor.textPrimary)),
          const Spacer(),
          Icon(Icons.chevron_right, color: AppColor.textSecondary, size: 20),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColor.textSecondary, letterSpacing: 0.5));
  }

  Widget _todayCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColor.primary, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Obx(() => Text(AppFormat.currency(cHome.today),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, color: Colors.white))),
        const SizedBox(height: 4),
        Obx(() => Text(cHome.todayPercent, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13))),
        const SizedBox(height: 16),
        Obx(() {
          final todayId = cHome.todayId;
          if (todayId == null) return const SizedBox.shrink();
          return GestureDetector(
            onTap: () => Get.to(() => DetailHistoryPage(idHistory: todayId)),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Text('View Details', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, color: Colors.white, size: 16),
              ]),
            ),
          );
        }),
      ]),
    );
  }

  Widget _weeklyChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColor.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColor.border)),
      child: Obx(() {
        final data = cHome.week;
        final labels = cHome.weekText();
        final maxVal = data.reduce(max).clamp(1.0, double.infinity);
        final hasData = data.any((v) => v > 0);
        if (!hasData) {
          return const SizedBox(
            height: 160,
            child: StateView(
              loading: false, error: null, empty: true,
              child: SizedBox.shrink(),
              emptyTitle: 'Belum ada data minggu ini',
              emptyMessage: 'Catat transaksi pertama Anda untuk melihat grafik',
              emptyIcon: Icons.bar_chart_outlined,
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
                        Text('${data[i].toInt()}',
                          style: TextStyle(fontSize: 9, color: AppColor.textSecondary)),
                      const SizedBox(height: 4),
                      Container(
                        height: (ratio * 120).clamp(4.0, 120),
                        decoration: BoxDecoration(
                          color: AppColor.accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
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

  Widget _monthlySection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColor.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColor.border)),
      child: Obx(() {
        if (cHome.monthIncome == 0 && cHome.monthOutcome == 0) {
          return const SizedBox(
            height: 200,
            child: StateView(
              loading: false, error: null, empty: true,
              child: SizedBox.shrink(),
              emptyTitle: 'Belum ada transaksi bulan ini',
              emptyMessage: 'Tambah Pemasukan atau Pengeluaran untuk mulai melacak',
              emptyIcon: Icons.pie_chart_outline,
            ),
          );
        }
        return Column(children: [
          Row(children: [
            SizedBox(
              width: 140, height: 140,
              child: Stack(children: [
                CustomPaint(
                  size: const Size(140, 140),
                  painter: _DonutPainter(
                    income: cHome.monthIncome, outcome: cHome.monthOutcome,
                    incomeColor: AppColor.income, outcomeColor: AppColor.outcome,
                  ),
                ),
                Center(child: Text('${cHome.percentIncome}%',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColor.textPrimary))),
              ]),
            ),
            const SizedBox(width: 24),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _legendItem(AppColor.income, 'Income'),
              const SizedBox(height: 8),
              _legendItem(AppColor.outcome, 'Expense'),
              const SizedBox(height: 16),
              Text(cHome.monthPercent, style: TextStyle(fontSize: 12, color: AppColor.textSecondary, height: 1.4)),
            ])),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(color: AppColor.surface, borderRadius: BorderRadius.circular(10)),
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

  Widget _legendItem(Color color, String label) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontSize: 13, color: AppColor.textSecondary)),
    ]);
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
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round;

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
