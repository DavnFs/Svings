import 'package:get/get.dart';
import 'package:cause_money_record/config/api.dart';
import 'package:cause_money_record/config/app_request.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';

class SourceAI {
  static String get _idUser => Get.find<CUser>().data.idUser ?? '';

  static Future<Map?> getTransactionAdvice({
    required String amount,
    required String category,
    String? description,
  }) async {
    return AppRequest.post('${Api.ai}transaction_advice', {
      'id_user': _idUser,
      'amount': amount,
      'category': category,
      'description': description ?? '',
    });
  }

  static Future<Map?> getMonthlyAnalysis() async {
    return AppRequest.post('${Api.ai}monthly_analysis', {
      'id_user': _idUser,
    });
  }

  static Future<Map?> getBudgetRecommendation(String monthlyIncome) async {
    return AppRequest.post('${Api.ai}budget_recommendation', {
      'id_user': _idUser,
      'monthly_income': monthlyIncome,
    });
  }

  static Future<Map?> checkBudgetFeasibility({
    required String amount,
    required String days,
  }) async {
    return AppRequest.post('${Api.ai}budget_check', {
      'id_user': _idUser,
      'amount': amount,
      'days': days,
    });
  }

  static Future<Map?> getDailyPlan(String dailyBudget) async {
    return AppRequest.post('${Api.ai}daily_plan', {
      'id_user': _idUser,
      'daily_budget': dailyBudget,
    });
  }
}
