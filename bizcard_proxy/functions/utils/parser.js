// Unified parser/sanitization helpers for the proxy
// Exports one source of truth to avoid drift between files and tests.
const { z } = require('zod');

const MAX_RAW_TEXT_LEN = process.env.MAX_RAW_TEXT_LEN ? parseInt(process.env.MAX_RAW_TEXT_LEN, 10) : 4000; // characters
const MAX_TEMPLATE_HEADERS = process.env.MAX_TEMPLATE_HEADERS ? parseInt(process.env.MAX_TEMPLATE_HEADERS, 10) : 40;
const MAX_TEMPLATE_HEADER_LEN = process.env.MAX_TEMPLATE_HEADER_LEN ? parseInt(process.env.MAX_TEMPLATE_HEADER_LEN, 10) : 64;
const MAX_BODY_KEYS = process.env.MAX_BODY_KEYS ? parseInt(process.env.MAX_BODY_KEYS, 10) : 20;
const HEADER_NAME_REGEX = /^[\w \-\.()]{1,64}$/; // allow letters, numbers, underscore, space, hyphen, dot, parentheses

function sanitizeRawText(raw) {
  if (!raw || typeof raw !== 'string') return '';
  // Trim and remove control characters except common whitespace
  // Replace consecutive whitespace with single space
  const cleaned = raw.replace(/[\x00-\x1F\x7F]+/g, ' ').trim().replace(/\s+/g, ' ');
  return cleaned;
}

function sanitizeTemplateHeaders(template) {
  if (!Array.isArray(template)) return [];
  const out = [];
  for (const h of template) {
    if (typeof h !== 'string') continue;
    if (!h || h.length > MAX_TEMPLATE_HEADER_LEN) continue;
    if (!HEADER_NAME_REGEX.test(h)) continue;
    out.push(h);
    if (out.length >= MAX_TEMPLATE_HEADERS) break;
  }
  return out;
}

function validateRequest(body) {
  if (!body || typeof body !== 'object') return 'missing_body';
  const keys = Object.keys(body || {});
  if (keys.length > MAX_BODY_KEYS) return 'too_many_fields';

  const raw = body.raw_text;
  if (!raw || typeof raw !== 'string') return 'missing_raw_text';
  if (raw.length > MAX_RAW_TEXT_LEN) return 'raw_text_too_long';

  if (body.session_id && typeof body.session_id === 'string') {
    if (body.session_id.length > 256) return 'session_id_too_long';
  }

  if (body.template !== undefined) {
    if (!Array.isArray(body.template)) return 'invalid_template_format';
    if (body.template.length > MAX_TEMPLATE_HEADERS) return 'too_many_template_headers';
    for (const h of body.template) {
      if (typeof h !== 'string') return 'invalid_template_header_type';
      if (h.length === 0 || h.length > MAX_TEMPLATE_HEADER_LEN) return 'template_header_length';
      if (!HEADER_NAME_REGEX.test(h)) return 'template_header_invalid_chars';
    }
  }

  return null;
}

function estimateTokens(str) {
  if (!str || typeof str !== 'string') return 0;
  // crude approximation: 1 token per 4 chars
  return Math.max(1, Math.ceil(str.length / 4));
}

function extractJsonFromText(text) {
  if (!text) return null;
  // Schema-enforced extraction: match the first JSON object and validate
  const cardSchema = z.object({
    name: z.string().optional(),
    email: z.string().email().optional(),
    phone: z.string().optional(),
    company: z.string().optional(),
    address: z.string().optional(),
  });

  const match = text.match(/\{[\s\S]*\}/);
  if (!match) return null;
  try {
    const parsed = JSON.parse(match[0]);
    return cardSchema.parse(parsed);
  } catch (_) {
    return null;
  }
}

function safeJsonParse(str, fallback = null) {
  try {
    return JSON.parse(str);
  } catch (_) {
    return fallback;
  }
}

// Backward-compatible alias for existing callers/tests
const estimateTokensFromText = estimateTokens;

module.exports = {
  sanitizeRawText,
  sanitizeTemplateHeaders,
  validateRequest,
  estimateTokens,
  estimateTokensFromText,
  extractJsonFromText,
  safeJsonParse,
};
