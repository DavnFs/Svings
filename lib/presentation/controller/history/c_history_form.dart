import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cause_money_record/data/model/history.dart';
import 'package:cause_money_record/data/source/source_history.dart';

/// Shared state for creating and editing a transaction.
///
/// Replaces CAddHistory + CUpdateHistory, which differed only in which
/// SourceHistory method they called.
class CHistoryForm extends GetxController {
  final _date = DateFormat('yyyy-MM-dd').format(DateTime.now()).obs;
  String get date => _date.value;
  setDate(String n) => _date.value = n;

  final _type = 'Pemasukan'.obs;
  String get type => _type.value;
  setType(String n) => _type.value = n;

  /// Owning account for income/expense; SOURCE for transfers.
  final _accountId = RxnString();
  String? get accountId => _accountId.value;
  setAccountId(String? id) => _accountId.value = id;

  /// DESTINATION for transfers; null otherwise.
  final _transferToAccountId = RxnString();
  String? get transferToAccountId => _transferToAccountId.value;
  setTransferToAccountId(String? id) => _transferToAccountId.value = id;

  final _items = <HistoryItem>[].obs;
  List<HistoryItem> get items => _items;

  void addItem(HistoryItem item) {
    _items.add(item);
    _recalculate();
  }

  void deleteItem(int index) {
    _items.removeAt(index);
    _recalculate();
  }

  final _total = 0.0.obs;
  double get total => _total.value;

  /// Clear stale state — the controller is app-scoped now, so a new entry must
  /// not inherit the previous form's items.
  void reset() {
    _items.clear();
    _total.value = 0;
    _date.value = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _type.value = 'Pemasukan';
    _accountId.value = null;
    _transferToAccountId.value = null;
  }

  void _recalculate() {
    double sum = 0;
    for (final item in _items) {
      sum += double.tryParse(item.price) ?? 0;
    }
    _total.value = sum;
  }

  /// Prefill the form from an existing transaction when editing.
  Future<void> load(String idHistory) async {
    final history = await SourceHistory.byId(idHistory);
    if (history == null) return;
    setDate(history.date);
    setType(history.type);
    setAccountId(history.accountId);
    setTransferToAccountId(history.transferToAccountId);
    _items.assignAll(history.items);
    _recalculate();
  }
}
