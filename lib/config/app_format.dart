import 'package:intl/intl.dart';

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

  /// Formats a number as IDR.
  ///
  /// Takes `num` rather than `String`, so a caller already holding a double
  /// need not round-trip through `toString()`, and bad input is a compile
  /// error rather than a runtime throw from `double.parse`.
  static String currency(num number) => NumberFormat.currency(
        decimalDigits: 2,
        locale: 'id_ID',
        symbol: 'Rp ',
      ).format(number);
}
