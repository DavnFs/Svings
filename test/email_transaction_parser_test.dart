import 'package:flutter_test/flutter_test.dart';

import 'package:cause_money_record/data/email/email_transaction_parser.dart';

/// Covers the parser's engine: Indonesian number normalisation, day-first
/// date forms, and direction keywords.
///
/// These bodies are built from the *shape* Indonesian bank notifications share,
/// not copied from any specific sender. They prove the parsing rules work; they
/// do not prove fidelity to BCA's or Dana's exact wording. Tune against real
/// emails before trusting the output.
void main() {
  group('parseAmount — Indonesian formatting', () {
    test('dot thousands, comma decimals', () {
      expect(EmailTransactionParser.parseAmount('1.500.000,50'), 1500000.5);
    });

    test('dots as thousands only', () {
      expect(EmailTransactionParser.parseAmount('500.000'), 500000);
      expect(EmailTransactionParser.parseAmount('1.234.567'), 1234567);
    });

    test('plain integer', () {
      expect(EmailTransactionParser.parseAmount('25000'), 25000);
    });

    test('comma as decimal separator', () {
      expect(EmailTransactionParser.parseAmount('1500,75'), 1500.75);
    });

    test('comma as thousands separator', () {
      expect(EmailTransactionParser.parseAmount('1,500,000'), 1500000);
    });

    test('strips currency noise', () {
      expect(EmailTransactionParser.parseAmount('Rp 25.000'), 25000);
    });

    test('rejects non-numeric', () {
      expect(EmailTransactionParser.parseAmount('abc'), isNull);
    });
  });

  group('parseDate', () {
    test('day-first slash form', () {
      expect(EmailTransactionParser.parseDate('pada 12/09/2026'), DateTime(2026, 9, 12));
    });

    test('day-first dash form', () {
      expect(EmailTransactionParser.parseDate('tgl 05-01-2026'), DateTime(2026, 1, 5));
    });

    test('iso form', () {
      expect(EmailTransactionParser.parseDate('2026-09-12 14:30'), DateTime(2026, 9, 12));
    });

    test('Indonesian month name', () {
      expect(EmailTransactionParser.parseDate('12 September 2026'), DateTime(2026, 9, 12));
      expect(EmailTransactionParser.parseDate('3 Agu 2026'), DateTime(2026, 8, 3));
      expect(EmailTransactionParser.parseDate('1 Des 2026'), DateTime(2026, 12, 1));
    });

    test('returns null when there is no date', () {
      expect(EmailTransactionParser.parseDate('no date here'), isNull);
    });

    test('rejects an impossible date instead of rolling it over', () {
      expect(EmailTransactionParser.parseDate('31/02/2026'), isNull);
    });
  });

  group('parseType', () {
    test('income words', () {
      expect(EmailTransactionParser.parseType('Dana masuk sebesar Rp 100.000'), 'Pemasukan');
      expect(EmailTransactionParser.parseType('Anda menerima transfer'), 'Pemasukan');
      expect(EmailTransactionParser.parseType('Cashback Rp 5.000'), 'Pemasukan');
    });

    test('expense words', () {
      expect(EmailTransactionParser.parseType('Pembayaran berhasil'), 'Pengeluaran');
      expect(EmailTransactionParser.parseType('Transfer ke rekening lain'), 'Pengeluaran');
      expect(EmailTransactionParser.parseType('Penarikan tunai'), 'Pengeluaran');
    });

    test('defaults to expense when nothing matches', () {
      expect(EmailTransactionParser.parseType('Halo'), 'Pengeluaran');
    });
  });

  group('parse', () {
    test('prefers the amount next to a transaction keyword over a balance', () {
      final result = EmailTransactionParser.parse(
        'Transaksi sebesar Rp 50.000 berhasil. Saldo Anda Rp 1.250.000.',
        receivedAt: DateTime(2026, 9, 12),
      );
      expect(result, isNotNull);
      expect(result!.total, 50000);
      expect(result.matchedBy, 'amount-after-keyword');
    });

    test('falls back to any Rupiah amount', () {
      final result = EmailTransactionParser.parse(
        'Rp 75.000',
        receivedAt: DateTime(2026, 9, 12),
      );
      expect(result, isNotNull);
      expect(result!.total, 75000);
      expect(result.matchedBy, 'amount-any');
    });

    test('reads direction, date and merchant together', () {
      final result = EmailTransactionParser.parse(
        'Pembayaran di GoFood sebesar Rp 25.000 pada 12/09/2026 berhasil.',
      );
      expect(result, isNotNull);
      expect(result!.total, 25000);
      expect(result.type, 'Pengeluaran');
      expect(result.date, DateTime(2026, 9, 12));
      expect(result.merchant, contains('GoFood'));
    });

    test('detects an incoming transfer', () {
      final result = EmailTransactionParser.parse(
        'Dana masuk Rp 500.000 dari BUDI pada 2026-09-12',
      );
      expect(result!.type, 'Pemasukan');
      expect(result.total, 500000);
    });

    test('falls back to the received date when the body has none', () {
      final result = EmailTransactionParser.parse(
        'Pembayaran Rp 10.000 berhasil',
        receivedAt: DateTime(2026, 3, 4, 9, 30),
      );
      expect(result!.date, DateTime(2026, 3, 4));
    });

    test('returns null when the body has no amount to record', () {
      expect(EmailTransactionParser.parse('Terima kasih telah menggunakan layanan kami.'), isNull);
    });

    test('requires a date from somewhere — transactions.date is NOT NULL', () {
      // No date in the body and none supplied by the caller: not recordable.
      expect(EmailTransactionParser.parse('Pembayaran Rp 10.000 berhasil'), isNull);
      // In production the email layer always passes the message timestamp.
      expect(
        EmailTransactionParser.parse(
          'Pembayaran Rp 10.000 berhasil',
          receivedAt: DateTime(2026, 9, 12),
        ),
        isNotNull,
      );
    });

    test('returns null for an empty body', () {
      expect(EmailTransactionParser.parse('   '), isNull);
    });

    test('ignores a zero amount', () {
      expect(EmailTransactionParser.parse('Transaksi sebesar Rp 0'), isNull);
    });
  });
}
