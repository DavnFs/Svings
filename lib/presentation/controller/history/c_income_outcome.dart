import 'package:get/get.dart';
import 'package:cause_money_record/data/model/history.dart';
import 'package:cause_money_record/data/source/source_history.dart';

class CIncomeOutcome extends GetxController {
  final _loading = false.obs;
  bool get loading => _loading.value;

  final _list = <History>[].obs;
  List<History> get list => _list;

  Future<void> getList(String idUser, String type) async {
    _loading.value = true;
    _list.assignAll(await SourceHistory.incomeOutcome(idUser, type));
    _loading.value = false;
  }

  Future<void> search(String idUser, String type, String date) async {
    _loading.value = true;
    _list.assignAll(await SourceHistory.incomeOutcomeSearch(idUser, type, date));
    _loading.value = false;
  }
}
