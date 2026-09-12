import 'package:get/get.dart';
import 'package:cause_money_record/data/source/source_history.dart';

class CHome extends GetxController {
  final _loading = false.obs;
  bool get loading => _loading.value;

  final _error = RxnString();
  String? get error => _error.value;

  final _today = 0.0.obs;
  double get today => _today.value;

  final _todayPercent = ''.obs;
  String get todayPercent => _todayPercent.value;

  final _week = RxList<double>.generate(7, (_) => 0.0);
  List<double> get week => _week;

  final _monthIncome = 0.0.obs;
  double get monthIncome => _monthIncome.value;

  final _monthOutcome = 0.0.obs;
  double get monthOutcome => _monthOutcome.value;

  final _percentIncome = '0'.obs;
  String get percentIncome => _percentIncome.value;

  final _monthPercent = ''.obs;
  String get monthPercent => _monthPercent.value;

  final _differentMonth = 0.0.obs;
  double get differentMonth => _differentMonth.value;

  static const _dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  List<String> weekText() {
    final today = DateTime.now();
    return List.generate(7, (i) {
      final offset = i - 6;
      final day = today.add(Duration(days: offset));
      return _dayNames[day.weekday - 1];
    });
  }

  Future<void> getAnalysis(String idUser) async {
    if (idUser.isEmpty) {
      _error.value = 'Not signed in';
      return;
    }
    _loading.value = true;
    _error.value = null;
    try {
      final data = await SourceHistory.analysis(idUser);

      _today.value = (data['today'] as num).toDouble();
      final yesterday = (data['yesterday'] as num).toDouble();
      final diff = (_today.value - yesterday).abs();
      final denominator = (_today.value + yesterday);
      final div = denominator == 0 ? 1.0 : denominator;
      final percent = (diff / div) * 100;
      _todayPercent.value = _today.value > yesterday
          ? '+${percent.toStringAsFixed(1)}% dibanding kemarin'
          : _today.value < yesterday
              ? '-${percent.toStringAsFixed(1)}% dibanding kemarin'
              : '100% sama dengan kemarin';

      final weekData =
          (data['week'] as List).map((e) => (e as num).toDouble()).toList();
      for (var i = 0; i < 7; i++) {
        _week[i] = weekData[i];
      }
      _week.refresh();

      _monthIncome.value = (data['month']['income'] as num).toDouble();
      _monthOutcome.value = (data['month']['outcome'] as num).toDouble();
      _differentMonth.value = (_monthIncome.value - _monthOutcome.value).abs();
      final monthDiv = (_monthIncome.value + _monthOutcome.value);
      final mDiv = monthDiv == 0 ? 1.0 : monthDiv;
      final mPercent = (_differentMonth.value / mDiv) * 100;
      _percentIncome.value = mPercent.toStringAsFixed(1);
      _monthPercent.value = _monthIncome.value > _monthOutcome.value
          ? 'Pemasukan\nlebih besar $percentIncome%\ndari Pengeluaran'
          : _monthIncome.value < _monthOutcome.value
              ? 'Pemasukan\nlebih kecil $percentIncome%\ndari Pengeluaran'
              : 'Pemasukan\n100% sama\ndengan Pengeluaran';
    } catch (e) {
      _error.value = e.toString();
    } finally {
      _loading.value = false;
    }
  }
}
