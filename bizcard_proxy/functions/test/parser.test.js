const { sanitizeRawText, validateRequest, estimateTokensFromText, extractJsonFromText } = require('../utils/parser');

describe('parser utilities', () => {
  test('sanitizeRawText removes control chars and collapses whitespace', () => {
    const raw = "Name:\tJohn\nDoe\x00  Company:  ACME   \n\nEmail:   john@acme.com\r\n";
    const cleaned = sanitizeRawText(raw);
    expect(cleaned).toBe('Name: John Doe Company: ACME Email: john@acme.com');
  });

  test('validateRequest rejects missing body and raw_text', () => {
    expect(validateRequest(null)).toBe('missing_body');
    expect(validateRequest({})).toBe('missing_raw_text');
  });

  test('validateRequest enforces template header rules', () => {
    const tooMany = { raw_text: 'x', template: new Array(100).fill('a') };
    expect(validateRequest(tooMany)).toBe('too_many_template_headers');

    const invalidChar = { raw_text: 'x', template: ['Good', 'Bad/Name'] };
    expect(validateRequest(invalidChar)).toBe('template_header_invalid_chars');
  });

  test('estimateTokensFromText approximates tokens', () => {
    expect(estimateTokensFromText('abcd')).toBe(1);
    expect(estimateTokensFromText('abcdefgh')).toBe(2);
    expect(estimateTokensFromText('')).toBe(0);
  });

  test('extractJsonFromText finds JSON in noisy model output', () => {
    const noisy = 'Some preface text. {"name":"John","email":"john@acme.com"} Some trailing text.';
    const parsed = extractJsonFromText(noisy);
    expect(parsed).toEqual({ name: 'John', email: 'john@acme.com' });
  });

  test('extractJsonFromText returns null on malformed JSON', () => {
    const bad = 'prefix {"Name": John,} suffix';
    expect(extractJsonFromText(bad)).toBeNull();
  });
});
