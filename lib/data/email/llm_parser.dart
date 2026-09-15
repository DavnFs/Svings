import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:cause_money_record/data/email/email_transaction_parser.dart';

/// What the LLM fallback produced, or why it did not.
class LlmResult {
  final ParsedTransaction? transaction;
  final bool rateLimited;
  final String? error;

  const LlmResult({this.transaction, this.rateLimited = false, this.error});
}

/// Groq chat-completions fallback for bodies the regex parser rejects.
///
/// Call order is the contract: [parseWithFallback] runs
/// [EmailTransactionParser.parse] FIRST and only calls the network when it
/// returns null. The Settings screen states this, and this function enforces
/// it — the LLM is a fallback, never the first pass.
class LlmParser {
  LlmParser._();

  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';

  static Future<LlmResult> parseWithFallback(
    String body, {
    DateTime? receivedAt,
    required String apiKey,
    String model = 'llama-3.1-8b-instant',
    http.Client? client,
  }) async {
    // Pass 1: regex. Null means "no Rupiah amount found", not "uncertain" —
    // only then is the network worth touching.
    final regex = EmailTransactionParser.parse(body, receivedAt: receivedAt);
    if (regex != null) {
      return LlmResult(transaction: _tag(regex, 'amount-after-keyword|regex-first'));
    }

    // Pass 2: LLM fallback. No key configured means fail open: the message
    // stays stored-but-unparsed for a later retry, never silently dropped.
    if (apiKey.isEmpty) {
      return const LlmResult(error: 'no-api-key');
    }

    final httpClient = client ?? http.Client();
    try {
      final res = await httpClient.post(
        Uri.parse(_endpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'temperature': 0,
          'messages': [
            {
              'role': 'system',
              'content': 'Extract ONE Indonesian bank/e-wallet notification '
                  'transaction as JSON with keys: total (number, Rupiah), '
                  'date (yyyy-MM-dd), type ("Pemasukan" or "Pengeluaran"), '
                  'merchant (string or null). Reply with JSON only.',
            },
            {'role': 'user', 'content': body},
          ],
        }),
      );

      if (res.statusCode == 429) {
        return const LlmResult(rateLimited: true, error: 'rate-limited');
      }
      if (res.statusCode != 200) {
        return LlmResult(error: 'llm-${res.statusCode}');
      }

      final tx = _fromJson(res.body, receivedAt: receivedAt);
      if (tx == null) return const LlmResult(error: 'llm-unparseable');
      return LlmResult(transaction: tx);
    } catch (_) {
      return const LlmResult(error: 'llm-network');
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static ParsedTransaction _tag(ParsedTransaction t, String via) => ParsedTransaction(
        total: t.total,
        date: t.date,
        type: t.type,
        merchant: t.merchant,
        notes: t.notes,
        matchedBy: via,
      );

  static ParsedTransaction? _fromJson(String raw, {DateTime? receivedAt}) {
    try {
      final root = jsonDecode(raw) as Map<String, dynamic>;
      final content =
          (((root['choices'] as List).first as Map)['message'] as Map)['content'] as String;
      final start = content.indexOf('{');
      final end = content.lastIndexOf('}');
      if (start < 0 || end < 0) return null;
      final obj = jsonDecode(content.substring(start, end + 1)) as Map<String, dynamic>;
      final total = (obj['total'] as num?)?.toDouble();
      if (total == null || total <= 0) return null;
      final dateStr = obj['date'] as String?;
      final date = dateStr == null ? null : DateTime.tryParse(dateStr);
      final at = date ?? receivedAt;
      if (at == null) return null;
      final type = obj['type'] == 'Pemasukan' ? 'Pemasukan' : 'Pengeluaran';
      final merchant = (obj['merchant'] as String?)?.trim();
      return ParsedTransaction(
        total: total,
        date: DateTime(at.year, at.month, at.day),
        type: type,
        merchant: merchant == null || merchant.isEmpty ? null : merchant,
        notes: merchant == null || merchant.isEmpty ? null : merchant,
        matchedBy: 'llm-fallback',
      );
    } catch (_) {
      return null;
    }
  }
}
