import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:cause_money_record/data/email/email_transaction_parser.dart';
import 'package:cause_money_record/data/email/gmail_client.dart';

/// Covers the Gmail response mapping — the part of the client that runs without
/// a network or an OAuth client. The auth and HTTP calls are thin by design.
void main() {
  // Gmail returns base64url WITHOUT padding; Dart's decoder requires it.
  // Encoding this way means every fixture exercises the padding fix.
  String b64(String s) => base64Url.encode(utf8.encode(s)).replaceAll('=', '');

  Map<String, dynamic> message({
    required Map<String, dynamic> payload,
    String id = 'msg-1',
    String? internalDate,
    String? dateHeader,
  }) =>
      {
        'id': id,
        'threadId': 'thread-$id',
        if (internalDate != null) 'internalDate': internalDate,
        'payload': {
          'mimeType': payload['mimeType'],
          'headers': [
            {'name': 'From', 'value': 'notifikasi@bank.example'},
            {'name': 'Subject', 'value': 'Notifikasi Transaksi'},
            if (dateHeader != null) {'name': 'Date', 'value': dateHeader},
          ],
          if (payload['parts'] != null) 'parts': payload['parts'],
          if (payload['body'] != null) 'body': payload['body'],
        },
      };

  const bodyText = 'Pembayaran di GoFood sebesar Rp 25.000 pada 14/09/2026 berhasil.';

  group('fromGmailMessage', () {
    test('reads a simple text/plain message', () {
      final email = GmailClient.fromGmailMessage(message(
        payload: {'mimeType': 'text/plain', 'body': {'data': b64(bodyText)}},
        internalDate: '1789317600000',
      ));

      expect(email, isNotNull);
      expect(email!.messageId, 'msg-1');
      expect(email.threadId, 'thread-msg-1');
      expect(email.sender, 'notifikasi@bank.example');
      expect(email.subject, 'Notifikasi Transaksi');
      expect(email.body, contains('Rp 25.000'));
      expect(email.receivedAt, isNotNull);
    });

    test('prefers text/plain over text/html when both are present', () {
      final email = GmailClient.fromGmailMessage(message(
        payload: {
          'mimeType': 'multipart/alternative',
          'parts': [
            {'mimeType': 'text/plain', 'body': {'data': b64(bodyText)}},
            {'mimeType': 'text/html', 'body': {'data': b64('<p>HTML VERSION</p>')}},
          ],
        },
      ));

      expect(email!.body, contains('GoFood'));
      expect(email.body, isNot(contains('HTML VERSION')));
    });

    test('strips tags from an html-only message', () {
      final email = GmailClient.fromGmailMessage(message(
        payload: {
          'mimeType': 'text/html',
          'body': {
            'data': b64('<html><body><p>Pembayaran Rp 25.000</p>'
                '<script>var x=1;</script><br/>pada 14/09/2026</body></html>'),
          },
        },
      ));

      expect(email, isNotNull);
      expect(email!.body, contains('Rp 25.000'));
      expect(email.body, contains('14/09/2026'));
      expect(email.body, isNot(contains('<')));
      expect(email.body, isNot(contains('var x')));
    });

    test('descends into nested parts', () {
      final email = GmailClient.fromGmailMessage(message(
        payload: {
          'mimeType': 'multipart/mixed',
          'parts': [
            {
              'mimeType': 'multipart/alternative',
              'parts': [
                {'mimeType': 'text/plain', 'body': {'data': b64(bodyText)}},
              ],
            },
          ],
        },
      ));

      expect(email!.body, contains('GoFood'));
    });

    test('prefers internalDate over the Date header', () {
      // 2026-09-14T10:00:00Z
      final email = GmailClient.fromGmailMessage(message(
        payload: {'mimeType': 'text/plain', 'body': {'data': b64(bodyText)}},
        internalDate: '1789317600000',
        dateHeader: 'Mon, 01 Jan 2001 00:00:00 +0700',
      ));

      expect(email!.receivedAt!.toUtc().year, 2026);
    });

    test('leaves receivedAt null when internalDate is absent', () {
      // The Date header is RFC 2822 and DateTime.parse reads only ISO 8601, so
      // it is deliberately not used as a fallback. Downstream this message is
      // stored and flagged unparseable rather than dropped.
      final email = GmailClient.fromGmailMessage(message(
        payload: {'mimeType': 'text/plain', 'body': {'data': b64(bodyText)}},
        dateHeader: 'Mon, 14 Sep 2026 10:00:00 +0700',
      ));

      expect(email, isNotNull);
      expect(email!.receivedAt, isNull);
    });

    test('returns null without an id', () {
      expect(GmailClient.fromGmailMessage({
        'payload': {'mimeType': 'text/plain', 'body': {'data': b64(bodyText)}},
      }), isNull);
    });

    test('returns null without a payload', () {
      expect(GmailClient.fromGmailMessage({'id': 'x'}), isNull);
    });

    test('returns null when the body is empty', () {
      expect(GmailClient.fromGmailMessage(message(
        payload: {'mimeType': 'text/plain', 'body': {'data': b64('   ')}},
      )), isNull);
    });

    test('returns null when no body data is present at all', () {
      // Typed explicitly: an untyped {} infers as Map<dynamic, dynamic>, whereas
      // jsonDecode always produces Map<String, dynamic>. Matching production
      // typing here is the point of the fixture.
      expect(GmailClient.fromGmailMessage(message(
        payload: {'mimeType': 'text/plain', 'body': <String, dynamic>{}},
      )), isNull);
    });

    test('survives undecodable base64 instead of throwing', () {
      expect(GmailClient.fromGmailMessage(message(
        payload: {'mimeType': 'text/plain', 'body': {'data': '!!!not base64!!!'}},
      )), isNull);
    });
  });

  group('Gmail response through to a transaction', () {
    test('a notification email becomes a parsed candidate', () {
      final email = GmailClient.fromGmailMessage(message(
        payload: {'mimeType': 'text/plain', 'body': {'data': b64(bodyText)}},
        internalDate: '1789317600000',
      ))!;

      final parsed = EmailTransactionParser.parse(
        email.body,
        receivedAt: email.receivedAt,
      );

      expect(parsed, isNotNull);
      expect(parsed!.total, 25000);
      expect(parsed.type, 'Pengeluaran');
      expect(parsed.merchant, contains('GoFood'));
    });
  });
}
