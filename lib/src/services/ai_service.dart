import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:card2sheet/core/env.dart';
import 'local_trust_service.dart';
import 'request_signer.dart';
import 'session_id_service.dart';
import '../utils/schema.dart';

/// Build a strict prompt that enforces exactly 7 fields with 'NONE' for missing.
String getStructuredPrompt(String rawText) {
  final headers = kStrictHeaderLabels;
  return '''
You are an AI that converts unstructured text from a business card into structured JSON.

Requirements:
- Always return exactly 7 fields with these keys and this order:
  1. ${headers[0]}
  2. ${headers[1]}
  3. ${headers[2]}
  4. ${headers[3]}
  5. ${headers[4]}
  6. ${headers[5]}
  7. ${headers[6]}
- If any field is missing or not detected, set its value to the string "NONE".
- Do not include any extra keys, comments, or metadata.
- Output must be valid JSON only, no markdown or explanations.

Return JSON in this exact shape (keys must match exactly):
{
  "${headers[0]}": "string or NONE",
  "${headers[1]}": "string or NONE",
  "${headers[2]}": "string or NONE",
  "${headers[3]}": "string or NONE",
  "${headers[4]}": "string or NONE",
  "${headers[5]}": "string or NONE",
  "${headers[6]}": "string or NONE"
}

Raw text:
$rawText
''';
}

class AIService {
  late final String? _apiKey = env('GEMINI_API_KEY');
  late final bool _useProxy = envIsTrue('USE_PROXY');
  late final String? _proxyUrl = env('PROXY_URL');

  Future<Map<String, dynamic>> formatWithTemplate(
    String rawText,
    List<String> headers, {
    String? sessionId,
  }) async {
    if (_useProxy && _proxyUrl != null && _proxyUrl.isNotEmpty) {
      // Force strict template regardless of incoming headers
      return _callProxy(rawText, kStrictHeaderLabels, sessionId: sessionId);
    }

    if (_apiKey == null || _apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY is not configured.');
    }

    return _callGeminiDirect(rawText, kStrictHeaderLabels);
  }

  Future<Map<String, dynamic>> _callProxy(
    String rawText,
    List<String> headers, {
    String? sessionId,
  }) async {
    final url = _proxyUrl!.replaceAll(RegExp(r'/*$'), '');
    final endpoint = Uri.parse('$url/format-card');

    final token = await LocalTrustService.getOrCreateToken();
    final sid = sessionId ?? await SessionIdService.getOrCreateSessionId();

    final bodyMap = {
      'raw_text': rawText,
      'template': headers,
      'session_id': sid,
    };
    final rawBody = jsonEncode(bodyMap);

    Future<http.Response> _sendOnce() async {
      final headersMap = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final appSecret = env('APP_SECRET');
      if (appSecret != null && appSecret.isNotEmpty) {
        headersMap['X-App-Token'] = token;
        headersMap['X-App-Signature'] = computeTokenSignature(token: token, secret: appSecret);
      }
      final secret = env('PROXY_SIGNATURE_SECRET');
      if (secret != null && secret.isNotEmpty) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        final signature = computeProxySignature(
          timestampMs: ts,
          rawBody: rawBody,
          secret: secret,
        );
        final headerName = env('PROXY_SIGNATURE_HEADER') ?? 'x-proxy-signature';
        headersMap[headerName] = signature;
      }
      return http.post(endpoint, headers: headersMap, body: rawBody);
    }

    var resp = await _sendOnce();
    if (resp.statusCode == 401) {
      // Retry once (e.g., clock skew for signature TTL or transient policy)
      resp = await _sendOnce();
    }

    if (resp.statusCode == 200) {
      final decoded = jsonDecode(resp.body);
      if (decoded['ok'] == true && decoded['data'] != null) {
        return Map<String, dynamic>.from(decoded['data']);
      } else {
        throw Exception(
          'Proxy error: ${decoded['error'] ?? decoded['message'] ?? resp.body}',
        );
      }
    } else {
      throw Exception('Proxy call failed: ${resp.statusCode} ${resp.body}');
    }
  }

  Future<Map<String, dynamic>> _callGeminiDirect(
    String rawText,
    List<String> headers,
  ) async {
    final String endpoint =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_apiKey";

  final prompt = getStructuredPrompt(rawText);

    final body = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
          ],
        },
      ],
    };

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      final text = decoded["candidates"]?[0]?["content"]?["parts"]?[0]?["text"];

      if (text == null) throw Exception("No text content returned by Gemini.");

      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start != -1 && end != -1) {
        final jsonString = text.substring(start, end + 1);
        return jsonDecode(jsonString);
      } else {
        throw Exception("Failed to parse JSON from Gemini output: $text");
      }
    } else {
      throw Exception(
        "Gemini API call failed: ${response.statusCode} ${response.body}",
      );
    }
  }
}
