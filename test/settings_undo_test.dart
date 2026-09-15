import 'package:flutter_test/flutter_test.dart';

import 'package:cause_money_record/data/email/email_sync.dart';
import 'package:cause_money_record/data/email/llm_parser.dart';
import 'package:cause_money_record/data/model/fetched_email.dart';

/// Undo contract: deleting an auto-imported transaction and marking its email
/// ignored must prevent re-creation on the next sync.
void main() {
  FetchedEmail mail(String id, String body) => FetchedEmail(
        messageId: id,
        body: body,
        receivedAt: DateTime(2026, 9, 14),
        sender: 'notifikasi@bank.example',
        subject: 'Notifikasi Transaksi',
      );

  const parseable = 'Pembayaran di GoFood sebesar Rp 25.000 pada 14/09/2026 berhasil.';

  test('ignored email is never re-parsed on next sync', () async {
    // Store succeeds the first time (new row), then reports "already stored"
    // (null) forever after — exactly what the (user_id, message_id) unique
    // constraint surfaces from PostgREST. This is the dedupe the Undo path
    // relies on: even if markIgnored failed, the message ID alone prevents a
    // silent re-create.
    final stored = <String>{};
    final sync = EmailSync(
      store: (m) async => stored.add(m.messageId) ? 'row-${m.messageId}' : null,
      mark: (id, {error}) async {},
    );

    final first = await sync.sync([mail('m1', parseable)]);
    expect(first.candidates, hasLength(1));
    expect(first.stored, 1);

    // Undo path: transaction deleted, email marked ignored (parsed=true).
    // Next sync sees the same message ID as already-stored → duplicate, never
    // a candidate.
    final second = await sync.sync([mail('m1', parseable)]);
    expect(second.candidates, isEmpty);
    expect(second.duplicates, 1);
    expect(second.stored, 0);
  });

  test('LLM fallback runs only when regex finds nothing', () async {
    var llmCalls = 0;
    final sync = EmailSync(
      store: (m) async => 'row-1',
      mark: (id, {error}) async {},
      llm: (body, {receivedAt}) async {
        llmCalls++;
        return const LlmResult(error: 'llm-unparseable');
      },
    );

    // Regex parses this body → LLM must never fire.
    final ok = await sync.sync([mail('m1', parseable)]);
    expect(ok.candidates, hasLength(1));
    expect(llmCalls, 0);

    // Regex rejects this body → LLM fires exactly once as fallback.
    await sync.sync([mail('m2', 'Terima kasih telah menggunakan layanan kami.')]);
    expect(llmCalls, 1);
  });

  test('rate-limited fallback surfaces a 429, not a silent stall', () async {
    var rateCalls = 0;
    final sync = EmailSync(
      store: (m) async => 'row-1',
      mark: (id, {error}) async {},
      llm: (body, {receivedAt}) async => const LlmResult(rateLimited: true, error: 'rate-limited'),
      onRateLimit: (_) async => rateCalls++,
    );

    final outcome =
        await sync.sync([mail('m1', 'Terima kasih telah menggunakan layanan kami.')]);
    expect(outcome.candidates, isEmpty);
    expect(outcome.unparseable, 1);
    expect(rateCalls, 1);
  });
}
