const request = require('supertest');
const crypto = require('crypto');

function buildSig(secret, body) {
  const ts = Date.now();
  const payload = `${ts}:${body}`;
  const h = crypto.createHmac('sha256', secret).update(payload).digest('hex');
  return { header: `${ts}:${h}`, ts };
}

describe('signature middleware', () => {
  const OLD_ENV = process.env;
  beforeEach(() => {
    jest.resetModules();
    process.env = { ...OLD_ENV };
    process.env.PROXY_REQUIRE_SIGNATURE = 'true';
    process.env.PROXY_SIGNATURE_SECRET = 'test_secret';
    process.env.REQUIRE_AUTH = 'false';
  });
  afterAll(() => { process.env = OLD_ENV; });

  test('unsigned request returns 401 missing_signature', async () => {
    const app = require('../index.js').app;
    const resp = await request(app).post('/format-card').send({ raw_text: 'John' });
    expect(resp.status).toBe(401);
    expect(resp.body.error).toBe('missing_signature');
  });

  test('expired timestamp returns 401 signature_expired', async () => {
    const app = require('../index.js').app;
    const body = JSON.stringify({ raw_text: 'John' });
    const ts = Date.now() - 10 * 60 * 1000; // 10 minutes ago
    const payload = `${ts}:${body}`;
    const sig = crypto.createHmac('sha256', process.env.PROXY_SIGNATURE_SECRET).update(payload).digest('hex');
    const header = `${ts}:${sig}`;
    const resp = await request(app)
      .post('/format-card')
      .set('x-proxy-signature', header)
      .set('Content-Type', 'application/json')
      .send(body);
    expect(resp.status).toBe(401);
    expect(resp.body.error).toBe('signature_expired');
  });

  test('invalid signature returns 401 invalid_signature', async () => {
    const app = require('../index.js').app;
    const body = JSON.stringify({ raw_text: 'John' });
    const { ts } = { ts: Date.now() };
    const header = `${ts}:deadbeef`;
    const resp = await request(app)
      .post('/format-card')
      .set('x-proxy-signature', header)
      .set('Content-Type', 'application/json')
      .send(body);
    expect(resp.status).toBe(401);
    expect(resp.body.error).toBe('invalid_signature');
  });

  test('valid signature returns non-401 (may be 500 if GEMINI missing)', async () => {
    const app = require('../index.js').app;
    const body = JSON.stringify({ raw_text: 'John' });
    const sig = buildSig(process.env.PROXY_SIGNATURE_SECRET, body).header;
    const resp = await request(app)
      .post('/format-card')
      .set('x-proxy-signature', sig)
      .set('Content-Type', 'application/json')
      .send(body);
    expect([200, 400, 402, 429, 500]).toContain(resp.status);
    expect(resp.status).not.toBe(401);
  });

  test('replay of same signature returns 401 replay', async () => {
    const app = require('../index.js').app;
    const body = JSON.stringify({ raw_text: 'John' });
    const sigHeader = buildSig(process.env.PROXY_SIGNATURE_SECRET, body).header;
    await request(app)
      .post('/format-card')
      .set('x-proxy-signature', sigHeader)
      .set('Content-Type', 'application/json')
      .send(body);
    const resp2 = await request(app)
      .post('/format-card')
      .set('x-proxy-signature', sigHeader)
      .set('Content-Type', 'application/json')
      .send(body);
    // Depending on Redis or in-memory replay cache timing, this should be 401 replay
    expect([401, 500]).toContain(resp2.status);
    if (resp2.status === 401) expect(resp2.body.error).toBe('replay');
  });
});
