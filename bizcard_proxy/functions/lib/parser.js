// Parser helpers extracted for unit testing
const MAX_RAW_TEXT_LEN = process.env.MAX_RAW_TEXT_LEN ? parseInt(process.env.MAX_RAW_TEXT_LEN, 10) : 4000;
const MAX_TEMPLATE_HEADERS = process.env.MAX_TEMPLATE_HEADERS ? parseInt(process.env.MAX_TEMPLATE_HEADERS, 10) : 40;
const MAX_TEMPLATE_HEADER_LEN = process.env.MAX_TEMPLATE_HEADER_LEN ? parseInt(process.env.MAX_TEMPLATE_HEADER_LEN, 10) : 64;
const MAX_BODY_KEYS = process.env.MAX_BODY_KEYS ? parseInt(process.env.MAX_BODY_KEYS, 10) : 20;
const HEADER_NAME_REGEX = /^[\w \-\.()]{1,64}$/;

function sanitizeRawText(raw) {
  if (!raw || typeof raw !== 'string') return '';
  const cleaned = raw.replace(/[\x00-\x1F\x7F]+/g, ' ').trim().replace(/\s+/g, ' ');
  return cleaned;
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

function estimateTokensFromText(s) {
  if (!s || typeof s !== 'string') return 0;
  return Math.max(1, Math.ceil(s.length / 4));
}

function extractJsonFromText(text) {
  if (!text) return null;
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start !== -1 && end !== -1 && end > start) {
    const jsonString = text.substring(start, end + 1);
    try {
      return JSON.parse(jsonString);
    } catch (e) {
      return null;
    }
  }
  return null;
}

module.exports = {
  sanitizeRawText,
  validateRequest,
  estimateTokensFromText,
  extractJsonFromText,
};
