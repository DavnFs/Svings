import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'package:cause_money_record/data/model/fetched_email.dart';

/// Raised for anything the user should see about the Google connection.
class GmailException implements Exception {
  final String message;
  const GmailException(this.message);
  @override
  String toString() => message;
}

/// Reads Gmail over the REST API using a Google Sign-In access token.
///
/// ponytail: no `googleapis` package. Listing and fetching a message is two
/// HTTP calls, and `http` is already a dependency, so the whole client is
/// `pubspec`-cheap. Only `google_sign_in` is added, because the native OAuth
/// flow cannot be hand-rolled.
///
/// ponytail: no `google-services.json`. The server client ID comes from `.env`
/// instead, so no Firebase project is needed for a personal app.
class GmailClient {
  GmailClient._();

  static const _scope = 'https://www.googleapis.com/auth/gmail.readonly';
  static const _api = 'https://gmail.googleapis.com/gmail/v1/users/me';

  static bool _initialized = false;
  static String? _accessToken;
  static String? _accountEmail;

  static bool get isConnected => _accessToken != null;
  static String? get accountEmail => _accountEmail;

  /// Read from `.env`. This is the **Web** application client ID, not the
  /// Android one — google_sign_in uses it as `serverClientId`.
  static String get _serverClientId =>
      dotenv.env['GOOGLE_SERVER_CLIENT_ID']?.trim() ?? '';

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    if (_serverClientId.isEmpty) {
      throw const GmailException(
        'GOOGLE_SERVER_CLIENT_ID is not set. Add the Web OAuth client ID '
        'from the Google Cloud Console to .env.',
      );
    }
    await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
    _initialized = true;
  }

  /// Signs in and asks for read-only Gmail access.
  ///
  /// Authentication and authorization are separate in google_sign_in 7: the
  /// access token only exists after `authorizeScopes`.
  static Future<void> connect() async {
    await _ensureInitialized();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final authorization =
          await account.authorizationClient.authorizeScopes([_scope]);
      _accessToken = authorization.accessToken;
      _accountEmail = account.email;
    } on GoogleSignInException catch (e) {
      throw GmailException(_describe(e));
    }
  }

  static Future<void> disconnect() async {
    await GoogleSignIn.instance.signOut();
    _accessToken = null;
    _accountEmail = null;
  }

  /// Fetches matching messages, newest first.
  ///
  /// [query] uses Gmail search syntax. The default is deliberately narrow:
  /// notification emails only, not the whole mailbox. Tune it once you know
  /// which sender your bank actually uses.
  static Future<List<FetchedEmail>> fetch({
    String query = 'newer_than:30d (transaksi OR pembayaran OR payment OR transfer OR notifikasi)',
    int maxResults = 25,
  }) async {
    final token = _accessToken;
    if (token == null) {
      throw const GmailException('Not connected. Call connect() first.');
    }

    final listUri = Uri.parse(
      '$_api/messages?q=${Uri.encodeQueryComponent(query)}&maxResults=$maxResults',
    );
    final listRes = await http.get(listUri, headers: _headers(token));
    if (listRes.statusCode != 200) {
      throw GmailException('Gmail list failed: ${listRes.statusCode} ${listRes.body}');
    }

    final listJson = jsonDecode(listRes.body) as Map<String, dynamic>;
    final ids = (listJson['messages'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((m) => m['id'] as String?)
        .whereType<String>();

    final messages = <FetchedEmail>[];
    for (final id in ids) {
      final uri = Uri.parse('$_api/messages/$id?format=full');
      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode != 200) continue;
      final parsed = _safeMap(res.body);
      if (parsed != null) messages.add(parsed);
    }
    return messages;
  }

  /// Maps one message body, or null if it is unusable.
  ///
  /// Wrapped because this is a trust boundary fed by an external service: one
  /// unexpected shape must not abort a sync and lose every other message.
  static FetchedEmail? _safeMap(String responseBody) {
    try {
      final json = jsonDecode(responseBody);
      if (json is! Map<String, dynamic>) return null;
      return fromGmailMessage(json);
    } catch (_) {
      return null;
    }
  }

  /// Sends the parser the raw stored text. Exposed for the stored-then-reparse
  /// path, where the message was fetched on an earlier run — but re-parsing
  /// only needs the body, which `raw_emails` already holds.
  static Future<List<FetchedEmail>> fetchBodiesOnly(List<String> ids) async {
    final token = _accessToken;
    if (token == null) throw const GmailException('Not connected.');
    final out = <FetchedEmail>[];
    for (final id in ids) {
      final res = await http.get(
        Uri.parse('$_api/messages/$id?format=full'),
        headers: _headers(token),
      );
      if (res.statusCode != 200) continue;
      final parsed = _safeMap(res.body);
      if (parsed != null) out.add(parsed);
    }
    return out;
  }

  static Map<String, String> _headers(String token) => {'Authorization': 'Bearer $token'};

  static String _describe(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Google sign-in was cancelled.';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'Google sign-in is misconfigured. Check that the Android OAuth '
            'client uses package com.example.cause_money_record and this '
            'machine\'s debug SHA-1.';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google account provider unavailable on this device.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google sign-in UI unavailable.';
      case GoogleSignInExceptionCode.userMismatch:
        return 'Signed in as a different account.';
      case GoogleSignInExceptionCode.interrupted:
        return 'Google sign-in was interrupted. Try again.';
      default:
        return 'Google sign-in failed: ${e.description ?? e.code.name}';
    }
  }

  // ---------------------------------------------------------------------
  // Mapping — pure, so it is tested against fixtures without a network.
  // ---------------------------------------------------------------------

  /// Maps a `messages.get?format=full` response to a [FetchedEmail].
  /// Returns null when the message carries no readable body.
  static FetchedEmail? fromGmailMessage(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null) return null;

    final payload = json['payload'] as Map<String, dynamic>?;
    if (payload == null) return null;

    final headers = _headersOf(payload);
    final body = _extractBody(payload);
    if (body == null || body.trim().isEmpty) return null;

    return FetchedEmail(
      messageId: id,
      threadId: json['threadId'] as String?,
      receivedAt: _receivedAt(json),
      sender: headers['from'],
      subject: headers['subject'],
      body: body,
    );
  }

  static Map<String, String> _headersOf(Map<String, dynamic> payload) {
    final out = <String, String>{};
    for (final raw in (payload['headers'] as List? ?? const [])) {
      if (raw is Map && raw['name'] != null) {
        out[(raw['name'] as String).toLowerCase()] = raw['value']?.toString() ?? '';
      }
    }
    return out;
  }

  /// `internalDate` is epoch milliseconds and is always present on a
  /// `messages.get` response.
  ///
  /// The `Date` header is deliberately ignored: it is RFC 2822
  /// (`Mon, 14 Sep 2026 10:00:00 +0700`) and Dart's `DateTime.parse` only
  /// accepts ISO 8601, so a naive fallback silently produces null. A partial
  /// RFC 2822 parser would work for some senders and quietly fail for others,
  /// which is worse than not having one. When this is null the message is
  /// stored but flagged unparseable rather than dropped.
  static DateTime? _receivedAt(Map<String, dynamic> json) {
    final internal = json['internalDate']?.toString();
    final ms = internal == null ? null : int.tryParse(internal);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }

  /// Prefers text/plain, falls back to text/html with tags stripped.
  static String? _extractBody(Map<String, dynamic> payload) {
    final plain = _findPart(payload, 'text/plain');
    if (plain != null) return plain;

    final html = _findPart(payload, 'text/html');
    if (html != null) return _stripHtml(html);

    return null;
  }

  static String? _findPart(Map<String, dynamic> part, String mimeType) {
    if (part['mimeType'] == mimeType) {
      final decoded = _decodeBody(part);
      if (decoded != null) return decoded;
    }
    for (final child in (part['parts'] as List? ?? const [])) {
      if (child is Map<String, dynamic>) {
        final found = _findPart(child, mimeType);
        if (found != null) return found;
      }
    }
    return null;
  }

  static String? _decodeBody(Map<String, dynamic> part) {
    final data = (part['body'] as Map<String, dynamic>?)?['data'] as String?;
    if (data == null) return null;
    return _decodeBase64Url(data);
  }

  /// Gmail returns base64url without padding; Dart requires it.
  static String? _decodeBase64Url(String data) {
    try {
      final padded = data.padRight((data.length + 3) & ~3, '=');
      return utf8.decode(base64Url.decode(padded));
    } catch (_) {
      return null;
    }
  }

  /// Crude, and only reached for html-only messages. The parser wants the
  /// amounts and dates, which survive tag stripping.
  static String _stripHtml(String html) => html
      .replaceAll(RegExp(r'<(script|style)[^>]*>.*?</\1>', dotAll: true, caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</(p|div|tr)>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'&nbsp;', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'&amp;', caseSensitive: false), '&')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .trim();
}
