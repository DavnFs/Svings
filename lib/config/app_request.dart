import 'dart:convert';
import 'package:http/http.dart' as http;

class AppRequest {
  static const _timeout = Duration(seconds: 15);

  static Future<Map?> gets(String url, {Map<String, String>? headers}) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(_timeout);
      return jsonDecode(response.body) as Map;
    } catch (_) {
      return null;
    }
  }

  static Future<Map?> post(String url, Object? body,
      {Map<String, String>? headers}) async {
    try {
      final response = await http
          .post(Uri.parse(url), body: body, headers: headers)
          .timeout(_timeout);
      return jsonDecode(response.body) as Map;
    } catch (_) {
      return null;
    }
  }
}
