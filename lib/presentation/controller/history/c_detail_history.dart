import 'package:get/get.dart';
import 'package:cause_money_record/data/model/history.dart';
import 'package:cause_money_record/data/source/source_history.dart';

class CDetailHistory extends GetxController {
  final _data = Rxn<History>();
  History? get data => _data.value;

  Future<void> getData(String idHistory) async {
    _data.value = await SourceHistory.byId(idHistory);
  }
}
