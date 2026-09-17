import 'package:flutter_test/flutter_test.dart';

import 'package:cause_money_record/data/email/email_sync.dart';
import 'package:cause_money_record/data/email/email_transaction_parser.dart';
import 'package:cause_money_record/data/model/fetched_email.dart';

/// The sync pipeline is the part that decides whether an email becomes a
/// transaction, a duplicate, or a failure — so it is tested with an injected
/// store rather than against a live mailbox.
void main() {
  FetchedEmail mail(String id, String body, {DateTime? receivedAt}) => FetchedEmail(
        messageId: id,
        body: body,
        receivedAt: receivedAt ?? DateTime(2026, 9, 14),
        sender: 'notifikasi@bank.example',
        subject: 'Notifikasi Transaksi',
      );

  const parseable = 'Pembayaran di GoFood sebesar Rp 25.000 pada 14/09/2026 berhasil.';
  const nonsense = 'Terima kasih telah menggunakan layanan kami.';

  group('sync', () {
    test('stores a new message and yields a candidate', () async {
      final marked = <String>[];
      final sync = EmailSync(
        store: (m) async => 'row-1',
        mark: (id, {error}) async => marked.add('$id:${error ?? "ok"}'),
      );

      final outcome = await sync.sync([mail('m1', parseable)]);

      expect(outcome.stored, 1);
      expect(outcome.duplicates, 0);
      expect(outcome.failed, 0);
      expect(outcome.candidates, hasLength(1));
      expect(outcome.candidates.single.rawEmailId, 'row-1');
      expect(outcome.candidates.single.transaction.total, 25000);
      expect(marked, ['row-1:ok']);
    });

    test('counts an already-stored message as a duplicate, not a candidate', () async {
      // store returning null is how the (user_id, message_id) constraint
      // surfaces from PostgREST.
      final sync = EmailSync(store: (m) async => null, mark: (id, {error}) async {});

      final outcome = await sync.sync([mail('m1', parseable)]);

      expect(outcome.stored, 0);
      expect(outcome.duplicates, 1);
      expect(outcome.candidates, isEmpty);
    });

    test('stores an unparseable body and records why', () async {
      final marked = <String, String?>{};
      final sync = EmailSync(
        store: (m) async => 'row-2',
        mark: (id, {error}) async => marked[id] = error,
      );

      final outcome = await sync.sync([mail('m2', nonsense)]);

      expect(outcome.stored, 1);
      expect(outcome.unparseable, 1);
      expect(outcome.candidates, isEmpty);
      expect(marked['row-2'], isNotNull);
    });

    test('a storage failure is not a duplicate and does not abort the batch', () async {
      var calls = 0;
      final sync = EmailSync(
        store: (m) async {
          calls++;
          if (m.messageId == 'boom') throw Exception('network');
          return 'row-$calls';
        },
        mark: (id, {error}) async {},
      );

      final outcome = await sync.sync([
        mail('boom', parseable),
        mail('ok', parseable),
      ]);

      expect(outcome.failed, 1, reason: 'the throwing message');
      expect(outcome.duplicates, 0, reason: 'a failure must not look like a duplicate');
      expect(outcome.stored, 1, reason: 'the second message still processed');
      expect(outcome.candidates, hasLength(1));
    });

    test('a marking failure does not lose the candidate', () async {
      final sync = EmailSync(
        store: (m) async => 'row-3',
        mark: (id, {error}) async => throw Exception('update failed'),
      );

      final outcome = await sync.sync([mail('m3', parseable)]);

      expect(outcome.candidates, hasLength(1));
    });

    test('tallies a mixed batch', () async {
      final sync = EmailSync(
        store: (m) async => m.messageId == 'dupe' ? null : 'row-${m.messageId}',
        mark: (id, {error}) async {},
      );

      final outcome = await sync.sync([
        mail('new1', parseable),
        mail('dupe', parseable),
        mail('new2', nonsense),
      ]);

      expect(outcome.stored, 2);
      expect(outcome.duplicates, 1);
      expect(outcome.unparseable, 1);
      expect(outcome.candidates, hasLength(1));
      expect(outcome.isEmpty, isFalse);
    });

    test('an empty batch is a no-op', () async {
      final sync = EmailSync(store: (m) async => 'x', mark: (id, {error}) async {});
      final outcome = await sync.sync([]);
      expect(outcome.isEmpty, isTrue);
      expect(outcome.candidates, isEmpty);
    });
  });

  group('sender mapping', () {
    FetchedEmail from(String sender, String body) => FetchedEmail(
          messageId: 'm-${sender.hashCode}',
          body: body,
          receivedAt: DateTime(2026, 9, 14),
          sender: sender,
          subject: 'Notifikasi Transaksi',
        );

    test('mapped sender resolves to its account', () async {
      final sync = EmailSync(
        store: (m) async => 'row-1',
        mark: (id, {error}) async {},
        accountForSender: (s) =>
            s == 'noreply@bca.co.id' ? 'acc-bca' : null,
      );

      final outcome =
          await sync.sync([from('noreply@bca.co.id', parseable)]);

      expect(outcome.candidates.single.accountId, 'acc-bca');
    });

    test('unmapped sender stays null so the caller can use Lainnya', () async {
      final sync = EmailSync(
        store: (m) async => 'row-2',
        mark: (id, {error}) async {},
        accountForSender: (_) => null,
      );

      final outcome = await sync.sync([from('unknown@x.co.id', parseable)]);

      expect(outcome.candidates.single.accountId, isNull);
    });

    test('a throwing resolver never breaks the sync', () async {
      final sync = EmailSync(
        store: (m) async => 'row-3',
        mark: (id, {error}) async {},
        accountForSender: (_) => throw Exception('prefs corrupt'),
      );

      final outcome = await sync.sync([from('a@b.co', parseable)]);

      expect(outcome.candidates.single.accountId, isNull);
    });
  });

  group('transfer detection', () {
    test('same-day same-amount opposite entry flags a possible transfer', () async {
      final sync = EmailSync(
        store: (m) async => 'row-new',
        mark: (id, {error}) async {},
        recentEmailTransactions: () async => [
          const TransferMatchRow(
            id: 'old-out',
            date: '2026-09-14',
            total: 25000,
            type: 'Pengeluaran',
            accountId: 'acc-bca',
          ),
        ],
      );

      // parseable fixture is an expense of 25000 on 14/09/2026... the detector
      // needs an INCOME to pair with the stored expense, so the counter-entry
      // below uses an income word ('masuk') the parser recognizes.
      final incoming = EmailTransactionParser.parse(
          'Dana masuk sebesar Rp 25.000 pada 14/09/2026 berhasil.',
          receivedAt: DateTime(2026, 9, 14))!;
      expect(incoming.type, 'Pemasukan');

      final outcome = await sync.sync([
        FetchedEmail(
          messageId: 'm-in',
          // Same amount as the stored expense, income direction.
          body: 'Dana masuk sebesar Rp 25.000 pada 14/09/2026 berhasil.',
          receivedAt: DateTime(2026, 9, 14),
          sender: 'gopay@gojek.com',
          subject: 'Dana masuk',
        ),
      ]);

      expect(outcome.candidates, hasLength(1));
      expect(outcome.candidates.single.possibleTransferWith, 'old-out');
    });

    test('no match, no flag — and rows are never merged', () async {
      final sync = EmailSync(
        store: (m) async => 'row-x',
        mark: (id, {error}) async {},
        recentEmailTransactions: () async => const [],
      );

      final outcome = await sync.sync([mail('mx', parseable)]);

      // Still a plain candidate: the detector only flags, never merges or
      // drops.
      expect(outcome.candidates, hasLength(1));
      expect(outcome.candidates.single.possibleTransferWith, isNull);
    });
  });

  group('reparseStored', () {
    test('never calls the store — the rows already exist', () async {
      // Regression guard: an earlier version routed this through sync(), which
      // would have re-inserted every row, seen them all as duplicates, and
      // returned zero candidates forever.
      var storeCalls = 0;
      final sync = EmailSync(
        store: (m) async {
          storeCalls++;
          return 'should-not-happen';
        },
        mark: (id, {error}) async {},
        loadUnparsed: () async => [
          {
            'id': 'stored-1',
            'message_id': 'm1',
            'received_at': '2026-09-14T00:00:00Z',
            'sender': 'notifikasi@bank.example',
            'subject': 'Notifikasi',
            'body': parseable,
          },
        ],
      );

      final outcome = await sync.reparseStored();

      expect(storeCalls, 0);
      expect(outcome.stored, 0);
      expect(outcome.duplicates, 0);
      expect(outcome.candidates, hasLength(1));
      expect(outcome.candidates.single.rawEmailId, 'stored-1');
    });

    test('reports bodies that still cannot be parsed', () async {
      final sync = EmailSync(
        store: (m) async => 'x',
        mark: (id, {error}) async {},
        loadUnparsed: () async => [
          {
            'id': 'stored-2',
            'message_id': 'm2',
            'received_at': null,
            'sender': null,
            'subject': null,
            'body': nonsense,
          },
        ],
      );

      final outcome = await sync.reparseStored();

      expect(outcome.unparseable, 1);
      expect(outcome.candidates, isEmpty);
    });
  });
}
