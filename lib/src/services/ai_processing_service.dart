import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

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
    // Respect flags: if proxy is disabled or URL missing, return a safe fallback
    final useProxy = dotenv.maybeGet('USE_PROXY')?.toLowerCase() == 'true';
    final proxyUrl = dotenv.maybeGet('PROXY_URL')?.trim();
    if (!useProxy || proxyUrl == null || proxyUrl.isEmpty) {
      // No proxy configured: return pass-through so the app still works
      return AIProcessingResult(
        cleanedText: extractedText,
        structuredJson: const {},
        finalJson: const {},
      );
    }

    final uri = Uri.parse('$proxyUrl/process-ocr');
    final body = jsonEncode({
      'raw_text': extractedText,
      if (sessionId != null) 'session_id': sessionId,
    });

    final resp = await http.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
      },
      body: body,
    );

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
}
