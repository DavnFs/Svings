import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:cause_money_record/presentation/controller/c_settings.dart';

class AppFormat {
  /// Formats an ISO date string as `d MMM yyyy` (id_ID).
  ///
  /// Returns the input unchanged when it cannot be parsed, so a blank or
  /// malformed date renders as-is instead of throwing inside `build()`.
  static String date(String stringDate) {
    final dateTime = DateTime.tryParse(stringDate);
    if (dateTime == null) return stringDate;
    return DateFormat('d MMM yyyy', 'id_ID').format(dateTime);
  }

  /// Formats a number as IDR. Decimal display follows the Settings toggle
  /// (Rp 25.000 vs Rp 25.000,00) — one source of truth, no per-screen flag.
  static String currency(num number) {
    var showDecimals = true;
    if (Get.isRegistered<CSettings>()) {
      try {
        showDecimals = Get.find<CSettings>().showDecimals;
      } catch (_) {
        // Settings not ready (tests) — fall through to decimals.
      }
    }
    return NumberFormat.currency(
      decimalDigits: showDecimals ? 2 : 0,
      locale: 'id_ID',
      symbol: 'Rp ',
    ).format(number);
  }
}
