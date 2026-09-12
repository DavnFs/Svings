import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/config/app_format.dart';
import 'package:cause_money_record/presentation/controller/ai/c_ai.dart';

class AIAdvisorPage extends StatelessWidget {
  const AIAdvisorPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cAI = Get.put(CAI());
    final txAmount = TextEditingController();
    final txCategory = TextEditingController();
    final txDesc = TextEditingController();
    final monthlyIncome = TextEditingController();
    final budgetAmt = TextEditingController();
    final budgetDays = TextEditingController();
    final dailyBgt = TextEditingController();

    return Scaffold(
      backgroundColor: AppColor.surface,
      appBar: AppBar(
        backgroundColor: AppColor.card,
        foregroundColor: AppColor.textPrimary,
        elevation: 0,
        title: const Text('AI Advisor', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            icon: Icons.lightbulb_outline,
            title: 'Transaction Advice',
            color: AppColor.accent,
            children: [
              _input('Amount', '50000', txAmount, isNumber: true),
              const SizedBox(height: 12),
              _input('Category', 'food, transport', txCategory),
              const SizedBox(height: 12),
              _input('Description (optional)', 'lunch', txDesc),
              const SizedBox(height: 14),
              _actionButton(
                cAI,
                label: 'Get Advice',
                color: AppColor.accent,
                onTap: () => cAI.getTransactionAdvice(
                  amount: txAmount.text,
                  category: txCategory.text,
                  description: txDesc.text.isEmpty ? null : txDesc.text,
                ),
              ),
              Obx(() => cAI.transactionAdvice.isNotEmpty
                  ? _resultBox(cAI.transactionAdvice.value)
                  : const SizedBox.shrink()),
            ],
          ),
          const SizedBox(height: 14),

          _card(
            icon: Icons.analytics_outlined,
            title: 'Monthly Analysis',
            color: AppColor.primary,
            children: [
              _actionButton(cAI,
                  label: 'Analyze',
                  onTap: () => cAI.getMonthlyAnalysis()),
              Obx(() => cAI.monthlyAnalysis.isNotEmpty
                  ? _buildAnalysis(cAI.monthlyAnalysis)
                  : const SizedBox.shrink()),
            ],
          ),
          const SizedBox(height: 14),

          _card(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Budget Recommendation',
            color: AppColor.income,
            children: [
              _input('Monthly Income', '5000000', monthlyIncome, isNumber: true),
              const SizedBox(height: 14),
              _actionButton(cAI,
                  label: 'Get Recommendation',
                  color: AppColor.income,
                  onTap: () => cAI.getBudgetRecommendation(monthlyIncome.text)),
              Obx(() => cAI.budgetRecommendation.isNotEmpty
                  ? _resultBox(cAI.budgetRecommendation.value)
                  : const SizedBox.shrink()),
            ],
          ),
          const SizedBox(height: 14),

          _card(
            icon: Icons.check_circle_outline,
            title: 'Budget Feasibility',
            color: Colors.orange,
            children: [
              _input('Total Budget', '1000000', budgetAmt, isNumber: true),
              const SizedBox(height: 12),
              _input('Days', '30', budgetDays, isNumber: true),
              const SizedBox(height: 14),
              _actionButton(cAI,
                  label: 'Check',
                  color: Colors.orange,
                  onTap: () => cAI.checkBudgetFeasibility(
                    amount: budgetAmt.text,
                    days: budgetDays.text.isEmpty ? '30' : budgetDays.text,
                  )),
              Obx(() => cAI.budgetCheckResult.isNotEmpty
                  ? _buildBudgetCheck(cAI.budgetCheckResult)
                  : const SizedBox.shrink()),
            ],
          ),
          const SizedBox(height: 14),

          _card(
            icon: Icons.calendar_today_outlined,
            title: 'Daily Plan',
            color: Colors.purple,
            children: [
              _input('Daily Budget', '50000', dailyBgt, isNumber: true),
              const SizedBox(height: 14),
              _actionButton(cAI,
                  label: 'Create Plan',
                  color: Colors.purple,
                  onTap: () => cAI.getDailyPlan(dailyBgt.text)),
              Obx(() => cAI.dailyPlanResult.isNotEmpty
                  ? _buildDailyPlan(cAI.dailyPlanResult)
                  : const SizedBox.shrink()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColor.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColor.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          ]),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _input(String label, String hint, TextEditingController controller, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColor.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: AppColor.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColor.textSecondary, fontSize: 13),
            filled: true,
            fillColor: AppColor.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColor.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColor.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColor.accent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButton(CAI cAI, {required String label, Color? color, required VoidCallback onTap}) {
    final c = color ?? AppColor.primary;
    return Obx(() => SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: cAI.isLoading.value ? null : onTap,
            icon: cAI.isLoading.value
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome, size: 16),
            label: Text(cAI.isLoading.value ? 'Processing...' : label),
            style: ElevatedButton.styleFrom(
              backgroundColor: c,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ));
  }

  Widget _resultBox(String text) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColor.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13, color: AppColor.textPrimary, height: 1.5)),
    );
  }

  Widget _buildAnalysis(Map<String, dynamic> data) {
    final a = data['analysis'] ?? {};
    final advice = data['advice'] ?? '';
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColor.surface, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('Total Income', AppFormat.currency((a['total_income'] ?? 0).toString())),
          _infoRow('Total Expense', AppFormat.currency((a['total_expense'] ?? 0).toString())),
          _infoRow('Balance', AppFormat.currency((a['balance'] ?? 0).toString()),
              color: (a['balance'] ?? 0) >= 0 ? AppColor.income : AppColor.outcome),
          if (advice.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(advice, style: const TextStyle(fontSize: 13, color: AppColor.textPrimary)),
          ],
        ],
      ),
    );
  }

  Widget _buildBudgetCheck(Map<String, dynamic> data) {
    final feasibility = data['feasibility'] ?? '';
    final message = data['message'] ?? '';
    final isGood = feasibility == 'Sangat Aman' || feasibility == 'Aman';
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColor.surface, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('Daily Budget', AppFormat.currency((data['daily_budget'] ?? 0).toString())),
          _infoRow('Avg Daily Spend', AppFormat.currency((data['avg_daily_expense'] ?? 0).toString())),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isGood ? AppColor.income.withOpacity(0.1) : AppColor.outcome.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(isGood ? Icons.check_circle : Icons.warning,
                    color: isGood ? AppColor.income : AppColor.outcome, size: 18),
                const SizedBox(width: 8),
                Text(feasibility,
                    style: TextStyle(
                        color: isGood ? AppColor.income : AppColor.outcome,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(fontSize: 13, color: AppColor.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildDailyPlan(Map<String, dynamic> data) {
    final plan = data['plan'] ?? {};
    final message = data['message'] ?? '';
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColor.surface, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('Food (40%)', AppFormat.currency((plan['makanan'] ?? 0).toString())),
          _infoRow('Transport (20%)', AppFormat.currency((plan['transport'] ?? 0).toString())),
          _infoRow('Other (30%)', AppFormat.currency((plan['lainnya'] ?? 0).toString())),
          _infoRow('Emergency (10%)', AppFormat.currency((plan['darurat'] ?? 0).toString())),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(message, style: const TextStyle(fontSize: 12, color: AppColor.textSecondary, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColor.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color ?? AppColor.textPrimary)),
        ],
      ),
    );
  }
}
