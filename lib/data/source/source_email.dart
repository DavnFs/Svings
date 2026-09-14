import 'package:cause_money_record/config/supabase_config.dart';
import 'package:cause_money_record/data/model/fetched_email.dart';

/// Reads and writes `public.raw_emails`.
///
/// Email bodies are stored before parsing so that a re-sync is idempotent and
/// so the parser can be improved later and re-run without re-fetching.
class SourceEmail {
  static get _client => SupabaseConfig.client;

  /// Stores a fetched message.
  ///
  /// Returns the new row's id, or **null** when the message was already stored
  /// (the `(user_id, message_id)` unique constraint ignored it).
  ///
  /// Throws on an actual failure. That distinction matters: a network error must
  /// never be mistaken for a duplicate, or the sync would silently skip emails
  /// and report success. The caller catches and counts failures separately.
  static Future<String?> store(FetchedEmail email) async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) {
      throw StateError('Cannot store email: not signed in');
    }

    final resp = await _client
        .from('raw_emails')
        .upsert(
          {
            'user_id': userId,
            'message_id': email.messageId,
            'thread_id': email.threadId,
            'received_at': email.receivedAt?.toUtc().toIso8601String(),
            'sender': email.sender,
            'subject': email.subject,
            'body': email.body,
          },
          // Without this target PostgREST cannot tell which constraint to
          // honour and quietly inserts a second row instead. Verified against
          // the live project: bare duplicate -> 409, with on_conflict -> ignored.
          onConflict: 'user_id,message_id',
          ignoreDuplicates: true,
        )
        .select('id');

    if (resp.isEmpty) return null;
    return resp.first['id'] as String;
  }

  /// Records that a stored message produced a transaction, or why it did not.
  static Future<void> markParsed(String rawEmailId, {String? error}) async {
    await _client.from('raw_emails').update({
      'parsed': error == null,
      'parse_error': error,
    }).eq('id', rawEmailId);
  }

  /// Stored messages that have not been parsed yet, oldest first.
  static Future<List<Map<String, dynamic>>> unparsed({int limit = 50}) async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return [];
    try {
      final resp = await _client
          .from('raw_emails')
          .select('id, message_id, received_at, sender, subject, body')
          .eq('user_id', userId)
          .eq('parsed', false)
          .order('received_at', ascending: true)
          .limit(limit);
      return (resp as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<FetchedEmail?> byId(String id) async {
    try {
      final resp = await _client
          .from('raw_emails')
          .select('message_id, thread_id, received_at, sender, subject, body')
          .eq('id', id)
          .maybeSingle();
      if (resp == null) return null;
      return FetchedEmail(
        messageId: resp['message_id'] as String,
        threadId: resp['thread_id'] as String?,
        receivedAt: resp['received_at'] != null
            ? DateTime.tryParse(resp['received_at'] as String)
            : null,
        sender: resp['sender'] as String?,
        subject: resp['subject'] as String?,
        body: resp['body'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  /// How many messages have been stored, for the sync screen's status line.
  static Future<int> count() async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return 0;
    try {
      final resp = await _client
          .from('raw_emails')
          .select('id')
          .eq('user_id', userId);
      return (resp as List).length;
    } catch (_) {
      return 0;
    }
  }
}
