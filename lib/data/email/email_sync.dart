import 'package:cause_money_record/data/email/email_transaction_parser.dart';
import 'package:cause_money_record/data/email/llm_parser.dart';
import 'package:cause_money_record/data/model/fetched_email.dart';
import 'package:cause_money_record/data/source/source_email.dart';

/// Stores a message and returns the new row id, or null if already stored.
/// Throws on failure. Injectable so the pipeline can be tested without a
/// network — see `test/email_sync_test.dart`.
typedef EmailStore = Future<String?> Function(FetchedEmail email);
typedef ParseMarker = Future<void> Function(String rawEmailId, {String? error});
typedef UnparsedLoader = Future<List<Map<String, dynamic>>> Function();

/// A parsed message awaiting the user's confirmation before it becomes a
/// transaction. Nothing is written to `transactions` without one.
class EmailCandidate {
  final String rawEmailId;
  final String? sender;
  final String? subject;
  final ParsedTransaction transaction;

  /// Account id resolved from the sender mapping, if any. Null = unmapped:
  /// the caller assigns the default account and flags the row for review.
  final String? accountId;

  /// Heuristic only: same-day, same-amount counter-entry among the confirmed
  /// email transactions, suggesting this pair is one transfer. The UI shows it
  /// as "possible transfer" for the user to confirm/merge — never auto-merged.
  final String? possibleTransferWith;

  const EmailCandidate({
    required this.rawEmailId,
    required this.transaction,
    this.sender,
    this.subject,
    this.accountId,
    this.possibleTransferWith,
  });
}

class SyncOutcome {
  /// Newly stored messages.
  final int stored;

  /// Already-seen messages, skipped by the unique constraint.
  final int duplicates;

  /// No transaction could be read out of the body.
  final int unparseable;

  /// Storage failed. Not the same as a duplicate — these are worth retrying.
  final int failed;

  final List<EmailCandidate> candidates;

  const SyncOutcome({
    this.stored = 0,
    this.duplicates = 0,
    this.unparseable = 0,
    this.failed = 0,
    this.candidates = const [],
  });

  bool get isEmpty =>
      stored == 0 && duplicates == 0 && unparseable == 0 && failed == 0;

  @override
  String toString() => 'SyncOutcome(stored: $stored, duplicates: $duplicates, '
      'unparseable: $unparseable, failed: $failed, candidates: ${candidates.length})';
}

/// One confirmed email transaction, for transfer-pair matching.
class TransferMatchRow {
  final String id;
  final String date;
  final double total;
  final String type;
  final String? accountId;

  const TransferMatchRow({
    required this.id,
    required this.date,
    required this.total,
    required this.type,
    this.accountId,
  });
}

/// Turns fetched emails into candidate transactions.
///
/// Per message: store first, then parse. Storing first means nothing is lost if
/// parsing fails or the app dies mid-sync, and it is what makes a re-sync
/// idempotent.
///
/// This class writes to `raw_emails` only. `transactions` is written by the
/// caller once the user confirms a candidate.
class EmailSync {
  final EmailStore _store;
  final ParseMarker _mark;
  final UnparsedLoader _loadUnparsed;

  /// LLM fallback for bodies regex rejects. Null (default) = regex only.
  /// When set, must be [LlmParser.parseWithFallback], which re-runs regex
  /// first — the fallback order lives in that function, not here.
  final Future<LlmResult> Function(String body, {DateTime? receivedAt})? _llm;

  /// Called with the count of consecutive 429s so the UI can warn instead of
  /// silently stalling. Null in tests.
  final Future<void> Function(int consecutive)? _onRateLimit;

  /// Sender -> account id resolver from Settings. Null in tests (every
  /// candidate unmapped). Never throws: mapping is best-effort.
  final String? Function(String? sender)? _accountForSender;

  /// Confirmed email transactions to match against for transfer detection.
  /// Each entry: (id, date yyyy-MM-dd, total, type, accountId). Null in tests.
  final Future<List<TransferMatchRow>> Function()? _recentEmailTransactions;

  EmailSync({
    EmailStore? store,
    ParseMarker? mark,
    UnparsedLoader? loadUnparsed,
    Future<LlmResult> Function(String body, {DateTime? receivedAt})? llm,
    Future<void> Function(int consecutive)? onRateLimit,
    String? Function(String? sender)? accountForSender,
    Future<List<TransferMatchRow>> Function()? recentEmailTransactions,
  })  : _store = store ?? SourceEmail.store,
        _mark = mark ?? SourceEmail.markParsed,
        _loadUnparsed = loadUnparsed ?? SourceEmail.unparsed,
        _llm = llm,
        _onRateLimit = onRateLimit,
        _accountForSender = accountForSender,
        _recentEmailTransactions = recentEmailTransactions;

  Future<SyncOutcome> sync(List<FetchedEmail> messages) async {
    var stored = 0;
    var duplicates = 0;
    var unparseable = 0;
    var failed = 0;
    final candidates = <EmailCandidate>[];

    for (final message in messages) {
      final String? rawEmailId;
      try {
        rawEmailId = await _store(message);
      } catch (_) {
        // A failure is not a duplicate. Count it separately so the caller can
        // retry instead of reporting a clean sync that quietly dropped mail.
        failed++;
        continue;
      }

      if (rawEmailId == null) {
        duplicates++;
        continue;
      }
      stored++;

      final (candidate, wasUnparseable) = await _parseAndMark(
        rawEmailId,
        message.body,
        receivedAt: message.receivedAt,
        sender: message.sender,
        subject: message.subject,
      );
      if (wasUnparseable) {
        unparseable++;
      } else {
        candidates.add(candidate!);
      }
    }

    return SyncOutcome(
      stored: stored,
      duplicates: duplicates,
      unparseable: unparseable,
      failed: failed,
      candidates: candidates,
    );
  }

  /// Re-parses everything stored but unparsed — for instance after the parser
  /// improves. Deliberately does **not** go through [sync]: these rows already
  /// exist, so storing them again would only produce duplicates and never a
  /// candidate.
  Future<SyncOutcome> reparseStored() async {
    final rows = await _loadUnparsed();
    var unparseable = 0;
    final candidates = <EmailCandidate>[];

    for (final row in rows) {
      final id = row['id'] as String;
      final receivedAt = row['received_at'] != null
          ? DateTime.tryParse(row['received_at'] as String)
          : null;

      final (candidate, wasUnparseable) = await _parseAndMark(
        id,
        row['body'] as String,
        receivedAt: receivedAt,
        sender: row['sender'] as String?,
        subject: row['subject'] as String?,
      );
      if (wasUnparseable) {
        unparseable++;
      } else {
        candidates.add(candidate!);
      }
    }

    return SyncOutcome(unparseable: unparseable, candidates: candidates);
  }

  /// Parses one stored message and records the result.
  /// Order: regex first, LLM fallback only when regex returns null.
  /// Returns `(candidate, wasUnparseable)`.
  Future<(EmailCandidate?, bool)> _parseAndMark(
    String rawEmailId,
    String body, {
    DateTime? receivedAt,
    String? sender,
    String? subject,
  }) async {
    String? accountId;
    try {
      accountId = _accountForSender?.call(sender);
    } catch (_) {
      accountId = null;
    }

    final parsed = EmailTransactionParser.parse(body, receivedAt: receivedAt);

    if (parsed == null && _llm != null) {
      final fallback = await _llm!(body, receivedAt: receivedAt);
      if (fallback.rateLimited) {
        await _onRateLimit?.call(1);
        await _tryMark(rawEmailId, 'LLM rate-limited (429)');
        return (null, true);
      }
      if (fallback.transaction != null) {
        await _tryMark(rawEmailId);
        return (
          await _withTransferHint(EmailCandidate(
            rawEmailId: rawEmailId,
            sender: sender,
            subject: subject,
            transaction: fallback.transaction!,
            accountId: accountId,
          )),
          false,
        );
      }
      // Fall through to the regex failure note below, tagged as such.
      await _tryMark(rawEmailId,
          'no Rupiah amount found in body${fallback.error == null ? '' : ' (${fallback.error})'}');
      return (null, true);
    }

    if (parsed == null) {
      await _tryMark(rawEmailId, 'no Rupiah amount found in body');
      return (null, true);
    }

    await _tryMark(rawEmailId);
    return (
      await _withTransferHint(EmailCandidate(
        rawEmailId: rawEmailId,
        sender: sender,
        subject: subject,
        transaction: parsed,
        accountId: accountId,
      )),
      false,
    );
  }

  /// Flags a possible transfer pair WITHOUT merging: same-day, same-amount,
  /// opposite-direction confirmed email transaction on a different account.
  /// Coincidental matches stay as two separate entries until the user confirms.
  Future<EmailCandidate> _withTransferHint(EmailCandidate c) async {
    final loader = _recentEmailTransactions;
    if (loader == null) return c;
    List<TransferMatchRow> rows;
    try {
      rows = await loader();
    } catch (_) {
      return c;
    }
    final day =
        '${c.transaction.date.year}-${c.transaction.date.month.toString().padLeft(2, '0')}-${c.transaction.date.day.toString().padLeft(2, '0')}';
    final wantType =
        c.transaction.type == 'Pemasukan' ? 'Pengeluaran' : 'Pemasukan';
    for (final r in rows) {
      if (r.date == day &&
          r.total == c.transaction.total &&
          r.type == wantType &&
          r.accountId != c.accountId) {
        return EmailCandidate(
          rawEmailId: c.rawEmailId,
          sender: c.sender,
          subject: c.subject,
          transaction: c.transaction,
          accountId: c.accountId,
          possibleTransferWith: r.id,
        );
      }
    }
    return c;
  }

  /// Marking is bookkeeping. A failure there must not lose the candidate.
  Future<void> _tryMark(String rawEmailId, [String? error]) async {
    try {
      await _mark(rawEmailId, error: error);
    } catch (_) {
      // Swallowed on purpose: the message is stored either way, and
      // reparseStored() will pick it up again.
    }
  }
}
