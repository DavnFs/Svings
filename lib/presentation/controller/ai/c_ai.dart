import 'package:get/get.dart';
import 'package:cause_money_record/data/source/source_ai.dart';

class CAI extends GetxController {
  var isLoading = false.obs;
  var transactionAdvice = ''.obs;
  var monthlyAnalysis = <String, dynamic>{}.obs;
  var budgetRecommendation = ''.obs;
  var budgetCheckResult = <String, dynamic>{}.obs;
  var dailyPlanResult = <String, dynamic>{}.obs;

  Future<void> getTransactionAdvice({
    required String amount,
    required String category,
    String? description,
  }) async {
    isLoading.value = true;
    try {
      final result = await SourceAI.getTransactionAdvice(
        amount: amount,
        category: category,
        description: description,
      );
      if (result != null && result['success'] == true) {
        transactionAdvice.value = result['advice']?.toString() ?? 'Tidak ada saran';
      } else {
        transactionAdvice.value = 'Gagal mendapatkan saran';
      }
    } catch (e) {
      transactionAdvice.value = 'Error: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> getMonthlyAnalysis() async {
    isLoading.value = true;
    try {
      final result = await SourceAI.getMonthlyAnalysis();
      if (result != null && result['success'] == true) {
        monthlyAnalysis.value = Map<String, dynamic>.from(result);
      } else {
        monthlyAnalysis.value = {};
      }
    } catch (e) {
      monthlyAnalysis.value = {'error': e.toString()};
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> getBudgetRecommendation(String monthlyIncome) async {
    isLoading.value = true;
    try {
      final result = await SourceAI.getBudgetRecommendation(monthlyIncome);
      if (result != null && result['success'] == true) {
        budgetRecommendation.value = result['recommendation']?.toString() ?? 'Tidak ada rekomendasi';
      } else {
        budgetRecommendation.value = 'Gagal mendapatkan rekomendasi';
      }
    } catch (e) {
      budgetRecommendation.value = 'Error: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> checkBudgetFeasibility({
    required String amount,
    required String days,
  }) async {
    isLoading.value = true;
    try {
      final result = await SourceAI.checkBudgetFeasibility(
        amount: amount,
        days: days,
      );
      if (result != null && result['success'] == true) {
        budgetCheckResult.value = Map<String, dynamic>.from(result);
      } else {
        budgetCheckResult.value = {};
      }
    } catch (e) {
      budgetCheckResult.value = {'error': e.toString()};
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> getDailyPlan(String dailyBudget) async {
    isLoading.value = true;
    try {
      final result = await SourceAI.getDailyPlan(dailyBudget);
      if (result != null && result['success'] == true) {
        dailyPlanResult.value = Map<String, dynamic>.from(result);
      } else {
        dailyPlanResult.value = {};
      }
    } catch (e) {
      dailyPlanResult.value = {'error': e.toString()};
    } finally {
      isLoading.value = false;
    }
  }

  void clearAdvice() {
    transactionAdvice.value = '';
    monthlyAnalysis.clear();
    budgetRecommendation.value = '';
    budgetCheckResult.clear();
    dailyPlanResult.clear();
  }
}
