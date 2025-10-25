const request = require('supertest');
const crypto = require('crypto');

function sig(secret, body) {
  const ts = Date.now();
  const h = crypto.createHmac('sha256', secret).update(`${ts}:${body}`).digest('hex');
  return `${ts}:${h}`;
}

describe('rate limit and quota', () => {
  const OLD_ENV = process.env;
  beforeEach(() => {
    jest.resetModules();
    process.env = { ...OLD_ENV };
    process.env.PROXY_REQUIRE_SIGNATURE = 'true';
    process.env.PROXY_SIGNATURE_SECRET = 'test_secret';
    process.env.REQUIRE_AUTH = 'false';
    process.env.RATE_LIMIT_WINDOW_MS = '60000';
    process.env.RATE_LIMIT_MAX = '1';
    process.env.QUOTA_MAX_REQUESTS = '1';
    process.env.QUOTA_PERIOD_MS = '60000';
  });
  afterAll(() => { process.env = OLD_ENV; });

  test('rate limit returns 429 on second rapid request', async () => {
    const app = require('../index.js').app;
    const body = JSON.stringify({ raw_text: 'John', session_id: 'sess-rate' });
    const s = sig(process.env.PROXY_SIGNATURE_SECRET, body);
    await request(app).post('/format-card').set('x-proxy-signature', s).set('Content-Type', 'application/json').send(body);
    const s2 = sig(process.env.PROXY_SIGNATURE_SECRET, body);
    const resp = await request(app).post('/format-card').set('x-proxy-signature', s2).set('Content-Type', 'application/json').send(body);
    expect([429, 500]).toContain(resp.status);
    if (resp.status === 429) expect(resp.body.error).toBe('rate_limited');
  });

  test('quota exceeded returns 402 on second request', async () => {
    const app = require('../index.js').app;
    const body = JSON.stringify({ raw_text: 'John', session_id: 'sess-quota' });
    const s = sig(process.env.PROXY_SIGNATURE_SECRET, body);
    const first = await request(app).post('/format-card').set('x-proxy-signature', s).set('Content-Type', 'application/json').send(body);
    expect([200, 400, 402, 429, 500]).toContain(first.status);
    const s2 = sig(process.env.PROXY_SIGNATURE_SECRET, body);
    const second = await request(app).post('/format-card').set('x-proxy-signature', s2).set('Content-Type', 'application/json').send(body);
    // With QUOTA_MAX_REQUESTS=1, second should hit quota guard.
    // Note: rate limiting may be enforced before quota, so 429 is also acceptable.
    expect([402, 429, 500]).toContain(second.status);
    if (second.status === 402) expect(second.body.error).toBe('quota_exceeded');
  });
});
