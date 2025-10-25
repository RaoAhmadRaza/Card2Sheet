import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'local_trust_service.dart';
import 'request_signer.dart';
import 'session_id_service.dart';

class AIProcessingResult {
  final String cleanedText;
  final Map<String, dynamic> structuredJson;
  final Map<String, dynamic> finalJson;

  const AIProcessingResult({
    required this.cleanedText,
    required this.structuredJson,
    required this.finalJson,
  });
}

class AIProcessingService {
  AIProcessingService();

  Future<AIProcessingResult> processOcrText(String extractedText, {String? sessionId}) async {
    // Prefer proxy; else use direct Gemini if API key is present; else pass-through.
    final useProxy = dotenv.maybeGet('USE_PROXY')?.toLowerCase() == 'true';
    final proxyUrl = dotenv.maybeGet('PROXY_URL')?.trim();
    final apiKey = dotenv.maybeGet('GEMINI_API_KEY')?.trim();

    // 1) Proxy path
    if (useProxy && proxyUrl != null && proxyUrl.isNotEmpty) {
      final uri = Uri.parse('$proxyUrl/process-ocr');
      final token = await LocalTrustService.getOrCreateToken();
      final sid = sessionId ?? await SessionIdService.getOrCreateSessionId();
      final bodyMap = <String, dynamic>{
        'raw_text': extractedText,
        'session_id': sid,
      };
      final body = jsonEncode(bodyMap);

      Map<String, String> _buildHeaders() {
        final headers = <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        };
        // Optional app-level token + signature
        final appSecret = dotenv.maybeGet('APP_SECRET') ?? const String.fromEnvironment('APP_SECRET');
        if (appSecret.isNotEmpty) {
          headers['X-App-Token'] = token;
          headers['X-App-Signature'] = computeTokenSignature(token: token, secret: appSecret);
        }
        final secret = dotenv.maybeGet('PROXY_SIGNATURE_SECRET') ?? const String.fromEnvironment('PROXY_SIGNATURE_SECRET');
        if (secret.isNotEmpty) {
          final ts = DateTime.now().millisecondsSinceEpoch;
          final signature = computeProxySignature(
            timestampMs: ts,
            rawBody: body,
            secret: secret,
          );
          final headerName = dotenv.maybeGet('PROXY_SIGNATURE_HEADER') ?? const String.fromEnvironment('PROXY_SIGNATURE_HEADER', defaultValue: 'x-proxy-signature');
          headers[headerName] = signature;
        }
        return headers;
      }

      Future<http.Response> _sendOnce() => http.post(uri, headers: _buildHeaders(), body: body);

      var resp = await _sendOnce();
      if (resp.statusCode == 401) {
        // Retry once with a fresh timestamp/signature
        resp = await _sendOnce();
      }

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('AI processing failed (${resp.statusCode}): ${resp.body}');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['ok'] != true) {
        throw Exception('AI processing error: ${data['error'] ?? 'unknown'}');
      }

      final cleanedText = (data['cleaned_text'] as String?) ?? '';
      final structured = (data['structured_json'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      final finalJson = (data['final_json'] as Map?)?.cast<String, dynamic>() ?? structured;

      return AIProcessingResult(
        cleanedText: cleanedText,
        structuredJson: structured,
        finalJson: finalJson,
      );
    }

    // 2) Direct Gemini path
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final endpoint = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey');

        // a) Refine
        final refinePrompt = 'You are an OCR text refinement AI. Clean and normalize the following text extracted from an image. Remove noise, fix spacing and formatting issues, and output only the corrected readable text — no extra explanation.\n\nText:\n$extractedText';
        final refined = await _callGeminiForText(endpoint, refinePrompt);

        // b) Structure
        final structurePrompt = 'You are a data structuring AI. Analyze the following extracted text and convert it into well-structured JSON. Include only meaningful fields like name, address, ID number, date, card number, etc., based on what appears. Do not invent data. Return valid JSON only — no comments or explanations.\n\nText:\n$refined';
        final structureText = await _callGeminiForText(endpoint, structurePrompt);
        final structured = _extractJsonFromText(structureText) ?? <String, dynamic>{};

        // c) Finalize
        final finalizePrompt = 'You are a validation and cleanup AI. Review this JSON data for consistency and accuracy. Fix obvious OCR misreads (like wrong date formats or misplaced values), ensure all keys follow lower_snake_case, and reformat it neatly as valid JSON.\n\nJSON Input:\n${jsonEncode(structured)}';
        final finalText = await _callGeminiForText(endpoint, finalizePrompt);
        final finalJson = _extractJsonFromText(finalText) ?? structured;

        return AIProcessingResult(
          cleanedText: refined.trim(),
          structuredJson: structured,
          finalJson: finalJson,
        );
      } catch (_) {
        // Fail soft: return pass-through
        return AIProcessingResult(
          cleanedText: extractedText,
          structuredJson: const {},
          finalJson: const {},
        );
      }
    }

    // 3) No proxy and no API key: pass-through
    return AIProcessingResult(
      cleanedText: extractedText,
      structuredJson: const {},
      finalJson: const {},
    );
  }

  Future<String> _callGeminiForText(Uri endpoint, String prompt) async {
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ]
    });
    final resp = await http.post(
      endpoint,
      headers: const {'Content-Type': 'application/json'},
      body: body,
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Gemini call failed: ${resp.statusCode} ${resp.body}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final text = (json['candidates'] as List?)?.isNotEmpty == true
        ? (json['candidates'][0]?['content']?['parts']?[0]?['text'] as String?)
        : null;
    if (text == null || text.trim().isEmpty) {
      throw Exception('Gemini returned empty response');
    }
    return text.trim();
  }

  Map<String, dynamic>? _extractJsonFromText(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    final jsonString = text.substring(start, end + 1);
    try {
      final parsed = jsonDecode(jsonString);
      if (parsed is Map<String, dynamic>) return parsed;
      if (parsed is Map) return Map<String, dynamic>.from(parsed);
      return null;
    } catch (_) {
      return null;
    }
  }
}
