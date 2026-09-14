/// An email fetched from a mailbox, before anything has been parsed from it.
///
/// Deliberately provider-agnostic. The Gmail fetcher is the only thing that
/// constructs these, which is what lets the whole sync pipeline be tested
/// without a mailbox or an OAuth client.
class FetchedEmail {
  /// The provider's message id. Dedupe key — see `raw_emails.message_id`.
  final String messageId;
  final String? threadId;
  final DateTime? receivedAt;
  final String? sender;
  final String? subject;

  /// The text the parser reads. Plain text or a text-rendered HTML body.
  final String body;

  const FetchedEmail({
    required this.messageId,
    required this.body,
    this.threadId,
    this.receivedAt,
    this.sender,
    this.subject,
  });

  @override
  String toString() => 'FetchedEmail($messageId, from: $sender)';
}
