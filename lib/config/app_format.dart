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

  /// Formats the amount as it is keyed on the numeric pad, from the raw digit
  /// string ("21500" -> "Rp 21.500", "21500,5" -> "Rp 21.500,5").
  ///
  /// Deliberately not [currency]: the entry reads better without the trailing
  /// ",00" while typing, and the display must not change shape when the
  /// Settings decimal toggle flips. Empty input is "Rp 0" rather than a blank
  /// box, so the display keeps its size as the user types.
  static String typedCurrency(String raw) {
    if (raw.isEmpty) return 'Rp 0';
    final parts = raw.split(',');
    final whole = int.tryParse(parts.first.isEmpty ? '0' : parts.first) ?? 0;
    final grouped = NumberFormat.decimalPattern('id_ID').format(whole);
    return parts.length > 1 ? 'Rp $grouped,${parts[1]}' : 'Rp $grouped';
  }

  /// A stored price back into pad digits: "250000.0" -> "250000",
  /// "21500.5" -> "21500,5". Used when editing a row that already has an amount.
  static String amountDigits(String price) {
    final value = double.tryParse(price) ?? 0;
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toString().replaceAll('.', ',');
  }
}
