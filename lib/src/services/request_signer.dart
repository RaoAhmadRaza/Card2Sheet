import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Computes an HMAC-SHA256 signature over "<ts>:<rawBody>" using the provided secret.
/// Returns the header value in the format "<ts>:<hex_hmac>".
String computeProxySignature({
  required int timestampMs,
  required String rawBody,
  required String secret,
}) {
  final payload = '${timestampMs.toString()}:$rawBody';
  final hmacSha256 = Hmac(sha256, utf8.encode(secret));
  final digest = hmacSha256.convert(utf8.encode(payload)).toString();
  return '${timestampMs.toString()}:$digest';
}
