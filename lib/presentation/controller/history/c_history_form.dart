import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cause_money_record/config/app_format.dart';
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

  /// The amount being keyed on the numeric pad, as raw digits with an optional
  /// ',' for sen ("21500", "21500,5"). One source for both flows: it is the
  /// payload of a transfer and the price of the next item on income/expense.
  final _amount = ''.obs;
  String get amount => _amount.value;

  /// Longest entry we accept, in digits. Twelve still formats far inside the
  /// display's width (Rp 999.999.999.999) and stops a stuck key from pushing
  /// the layout around.
  static const _maxDigits = 12;

  /// Append one pad key. A ',' is accepted once and never first, and a leading
  /// zero is replaced rather than kept, so "0" then "5" reads as 5.
  void pushAmount(String key) {
    final current = _amount.value;
    if (key == ',') {
      if (current.isEmpty || current.contains(',')) return;
      _amount.value = '$current,';
      return;
    }
    if (current.replaceAll(',', '').length >= _maxDigits) return;
    if (current == '0') {
      _amount.value = key;
      return;
    }
    _amount.value = '$current$key';
  }

  void popAmount() {
    final current = _amount.value;
    if (current.isEmpty) return;
    _amount.value = current.substring(0, current.length - 1);
  }

  void clearAmount() => _amount.value = '';

  void setAmount(String raw) => _amount.value = raw;

  /// The entry as a number: ',' is the decimal mark on the pad, the models store
  /// a dot.
  double get amountValue =>
      double.tryParse(_amount.value.replaceAll(',', '.')) ?? 0;

  /// The entry in the form the models store it, so a saved price round-trips
  /// through [AppFormat.amountDigits] without a trailing ".0".
  String get amountRaw => _amount.value.replaceAll(',', '.');

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
    _amount.value = '';
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
    // A transfer's amount IS its payload, so it comes back onto the pad. For
    // income/expense the rows are the payload and the pad starts empty.
    if (history.type == 'Transfer' && history.items.isNotEmpty) {
      setAmount(AppFormat.amountDigits(history.items.first.price));
    }
  }
}
