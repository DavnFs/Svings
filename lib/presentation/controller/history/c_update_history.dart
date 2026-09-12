import 'dart:convert';

import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../data/source/source_history.dart';

class CUpdateHistory extends GetxController {
  final _date = DateFormat('yyyy-MM-dd').format(DateTime.now()).obs;
  String get date => _date.value;
  setDate(String n) => _date.value = n;

  final _type = 'Pemasukan'.obs;
  String get type => _type.value;
  setType(String n) => _type.value = n;

  final _items = <Map<String, String>>[].obs;
  List<Map<String, String>> get items => _items;

  void addItem(Map<String, String> item) {
    _items.add(item);
    _recalculate();
  }

  void deleteItem(int index) {
    _items.removeAt(index);
    _recalculate();
  }

  final _total = 0.0.obs;
  double get total => _total.value;

  void _recalculate() {
    double sum = 0;
    for (final item in _items) {
      sum += double.tryParse(item['price'] ?? '0') ?? 0;
    }
    _total.value = sum;
  }

  Future<void> init(String idUser, String date) async {
    final history = await SourceHistory.whereDate(idUser, date);
    if (history == null) return;
    setDate(history.date ?? '');
    setType(history.type ?? '');
    final List decoded = jsonDecode(history.details ?? '[]');
    _items.assignAll(decoded.map((e) => Map<String, String>.from(e)).toList());
    _recalculate();
  }
}
