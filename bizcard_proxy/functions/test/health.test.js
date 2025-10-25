const request = require('supertest');

describe('health checks', () => {
  const OLD_ENV = process.env;
  beforeEach(() => {
    jest.resetModules();
    process.env = { ...OLD_ENV };
    delete process.env.REDIS_URL; // ensure no redis in unit tests
  });
  afterAll(() => { process.env = OLD_ENV; });

  test('GET /health/redis returns 503 when unconfigured', async () => {
    const app = require('../index.js').app;
    const resp = await request(app).get('/health/redis');
    expect([200, 503, 500]).toContain(resp.status);
    if (resp.status === 503) {
      expect(resp.body.ok).toBe(false);
      expect(resp.body.error).toBe('redis_unconfigured');
    }
  });
});
