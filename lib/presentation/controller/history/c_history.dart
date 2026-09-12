import 'package:get/get.dart';
import 'package:cause_money_record/data/model/history.dart';
import 'package:cause_money_record/data/source/source_history.dart';

class CHistory extends GetxController {
  final _loading = false.obs;
  bool get loading => _loading.value;

  final _error = RxnString();
  String? get error => _error.value;

  final _list = <History>[].obs;
  List<History> get list => _list;

  Future<void> getList(String idUser) async {
    _loading.value = true;
    _error.value = null;
    try {
      _list.assignAll(await SourceHistory.history(idUser));
    } catch (e) {
      _error.value = e.toString();
    } finally {
      _loading.value = false;
    }
  }

  Future<void> search(String idUser, String date) async {
    _loading.value = true;
    _error.value = null;
    try {
      _list.assignAll(await SourceHistory.historySearch(idUser, date));
    } catch (e) {
      _error.value = e.toString();
    } finally {
      _loading.value = false;
    }
  }
}
