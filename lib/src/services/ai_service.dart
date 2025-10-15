import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:card2sheet/core/env.dart';

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
      return _callProxy(rawText, headers, sessionId: sessionId);
    }

    if (_apiKey == null || _apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY is not configured.');
    }

    return _callGeminiDirect(rawText, headers);
  }

  Future<Map<String, dynamic>> _callProxy(
    String rawText,
    List<String> headers, {
    String? sessionId,
  }) async {
    final url = _proxyUrl!.replaceAll(RegExp(r'/*$'), '');
    final endpoint = Uri.parse('$url/format-card');

    final body = {
      'raw_text': rawText,
      'template': headers,
      if (sessionId != null) 'session_id': sessionId,
    };

    final resp = await http.post(
      endpoint,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

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

    final prompt =
        '''
You are an AI that converts unstructured text from a business card into structured JSON.
Use these column names exactly as the JSON keys: ${headers.join(', ')}.
If a value is missing, return it as an empty string "".
Return only valid JSON — no explanations or markdown.
Raw text:
$rawText
''';

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
