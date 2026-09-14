import 'package:intl/intl.dart';

/// A transaction extracted from an email body.
class ParsedTransaction {
  final double total;
  final DateTime date;

  /// 'Pemasukan' or 'Pengeluaran' — the label the UI and `transactions.type`
  /// already use.
  final String type;
  final String? merchant;
  final String? notes;

  /// Which rule produced this, so the confirmation preview can explain itself
  /// and so a bad parse is debuggable.
  final String matchedBy;

  const ParsedTransaction({
    required this.total,
    required this.date,
    required this.type,
    this.merchant,
    this.notes,
    required this.matchedBy,
  });

  @override
  String toString() =>
      'ParsedTransaction($type, $total, ${DateFormat('yyyy-MM-dd').format(date)}, '
      'merchant: $merchant, via $matchedBy)';
}

/// Extracts a transaction from an Indonesian bank / e-wallet notification email.
///
/// ponytail: one generic pattern set rather than a template per bank.
/// Notification emails from BCA, Mandiri, Dana, GoPay and friends all share the
/// same shape — a Rupiah amount, a date, and a direction keyword — so matching
/// that shape covers every sender without owning a regex per sender forever.
///
/// The ceiling, explicitly: this cannot tell a transaction amount from a
/// balance amount with certainty, and it knows nothing about a bank's specific
/// wording. The UI must always show a confirmation preview before writing, and
/// nothing here should be treated as authoritative. When you have real emails
/// to hand, add per-sender overrides rather than growing this heuristic.
///
/// Returns null when no Rupiah amount is found: there is nothing to record.
class EmailTransactionParser {
  EmailTransactionParser._();

  /// An amount introduced by a transaction word is far more likely to be the
  /// transaction than a trailing "saldo" figure, so try that first.
  static final _keywordAmount = RegExp(
    r'(?:transaksi|nominal|sebesar|pembayaran|pembelian|transfer|top\s?up|tagihan|bayar)'
    r'\D{0,24}?rp\.?\s*([\d.,]{3,})',
    caseSensitive: false,
  );

  static final _anyAmount = RegExp(r'rp\.?\s*([\d.,]{3,})', caseSensitive: false);

  /// Indonesian formatting: `.` separates thousands, `,` separates decimals.
  /// `1.500.000,50` -> 1500000.5, `500.000` -> 500000, `25000` -> 25000.
  static double? parseAmount(String raw) {
    var s = raw.trim().replaceAll(RegExp(r'[^0-9.,]'), '');
    if (s.isEmpty) return null;

    final hasDot = s.contains('.');
    final hasComma = s.contains(',');

    if (hasDot && hasComma) {
      // Both present: the last one is the decimal separator.
      final dotIsDecimal = s.lastIndexOf('.') > s.lastIndexOf(',');
      s = dotIsDecimal
          ? s.replaceAll(',', '')
          : s.replaceAll('.', '').replaceAll(',', '.');
    } else if (hasDot) {
      s = RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s) ? s.replaceAll('.', '') : s;
    } else if (hasComma) {
      s = RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(s)
          ? s.replaceAll(',', '')
          : s.replaceAll(',', '.');
    }

    return double.tryParse(s);
  }

  static final _isoDate = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})');
  static final _dmyDate = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})');
  static final _monthNameDate = RegExp(r'(\d{1,2})\s+([A-Za-z]{3,9})\.?\s+(\d{4})');

  static const _months = {
    'jan': 1, 'januari': 1,
    'feb': 2, 'februari': 2,
    'mar': 3, 'maret': 3,
    'apr': 4, 'april': 4,
    'mei': 5,
    'jun': 6, 'juni': 6,
    'jul': 7, 'juli': 7,
    'agu': 8, 'agt': 8, 'agustus': 8,
    'sep': 9, 'september': 9,
    'okt': 10, 'oktober': 10,
    'nov': 11, 'november': 11,
    'des': 12, 'desember': 12,
  };

  /// Day-first, because these are Indonesian emails.
  static DateTime? parseDate(String body) {
    final iso = _isoDate.firstMatch(body);
    if (iso != null) {
      return _safe(int.parse(iso[1]!), int.parse(iso[2]!), int.parse(iso[3]!));
    }

    final dmy = _dmyDate.firstMatch(body);
    if (dmy != null) {
      return _safe(int.parse(dmy[3]!), int.parse(dmy[2]!), int.parse(dmy[1]!));
    }

    final named = _monthNameDate.firstMatch(body);
    if (named != null) {
      final month = _months[named[2]!.toLowerCase()];
      if (month != null) {
        return _safe(int.parse(named[3]!), month, int.parse(named[1]!));
      }
    }

    return null;
  }

  static DateTime? _safe(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final dt = DateTime(y, m, d);
    // Reject dates the calendar had to roll over, e.g. 31/02.
    if (dt.month != m || dt.day != d) return null;
    return dt;
  }

  static const _incomeWords = [
    'masuk', 'kredit', 'penerimaan', 'menerima', 'top up', 'topup',
    'cashback', 'refund', 'gaji', 'bonus', 'uang diterima',
  ];

  static const _expenseWords = [
    'keluar', 'debit', 'pembayaran', 'pembelian', 'bayar', 'transfer ke',
    'penarikan', 'tarik tunai', 'belanja', 'pengeluaran', 'tagihan',
  ];

  static final _merchant = RegExp(
    r'\b(?:di|ke|kepada)\s+([A-Za-z][A-Za-z0-9 .&\x27_-]{1,38})',
    caseSensitive: false,
  );

  /// Expense unless an income word is present. Bank notifications are
  /// overwhelmingly expenses, and the confirmation preview makes a wrong guess
  /// cheap to correct.
  static String parseType(String body) {
    final lower = body.toLowerCase();
    for (final w in _incomeWords) {
      if (lower.contains(w)) return 'Pemasukan';
    }
    for (final w in _expenseWords) {
      if (lower.contains(w)) return 'Pengeluaran';
    }
    return 'Pengeluaran';
  }

  /// [receivedAt] is the email's timestamp: the fallback when the body carries
  /// no parseable date.
  static ParsedTransaction? parse(String body, {DateTime? receivedAt}) {
    if (body.trim().isEmpty) return null;

    String? matchedBy;
    double? total;

    final keyword = _keywordAmount.firstMatch(body);
    if (keyword != null) {
      total = parseAmount(keyword[1]!);
      matchedBy = 'amount-after-keyword';
    }

    if (total == null) {
      final any = _anyAmount.firstMatch(body);
      if (any != null) {
        total = parseAmount(any[1]!);
        matchedBy = 'amount-any';
      }
    }

    if (total == null || total <= 0) return null;

    final date = parseDate(body) ?? receivedAt;
    if (date == null) return null;

    final merchantMatch = _merchant.firstMatch(body);
    final merchant = merchantMatch?[1]?.trim().replaceAll(RegExp(r'[.,;\s]+$'), '');

    return ParsedTransaction(
      total: total,
      date: DateTime(date.year, date.month, date.day),
      type: parseType(body),
      merchant: (merchant == null || merchant.isEmpty) ? null : merchant,
      notes: merchant == null || merchant.isEmpty ? null : merchant,
      matchedBy: matchedBy!,
    );
  }
}
