// Load environment variables from a local .env file if present (dev/local only)
try {
  // eslint-disable-next-line global-require
  require('dotenv').config();
} catch (e) {
  // dotenv is optional; ignore if not installed/available
}

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const crypto = require('crypto');

const app = express();
app.use(helmet());

// CORS hardening: allow a configurable list of origins in production.
// Set PROXY_ALLOWED_ORIGINS to a comma-separated list of allowed origins (example: https://example.com,https://app.example.com)
const ALLOWED_ORIGINS = process.env.PROXY_ALLOWED_ORIGINS ? process.env.PROXY_ALLOWED_ORIGINS.split(',').map(s => s.trim()).filter(Boolean) : null;
app.use(cors({
  origin: function(origin, callback) {
    // allow requests with no origin (mobile apps, curl)
    if (!origin) return callback(null, true);
    if (!ALLOWED_ORIGINS) return callback(null, true); // permissive for dev when not configured
    if (ALLOWED_ORIGINS.indexOf(origin) !== -1) return callback(null, true);
    return callback(new Error('CORS not allowed for origin: ' + origin));
  }
}));

// Capture raw body for signature verification (verify option)
app.use(express.json({ limit: '128kb', verify: (req, res, buf) => { req.rawBody = buf && buf.length ? buf.toString('utf8') : ''; } }));

// Initialize Sentry (optional)
let Sentry = null;
if (process.env.SENTRY_DSN) {
  try {
    Sentry = require('@sentry/node');
    Sentry.init({ dsn: process.env.SENTRY_DSN });
    console.log('Sentry initialized');
    // Ensure request handler is registered before routes
    app.use(Sentry.Handlers.requestHandler());
  } catch (e) {
    console.warn('Sentry init failed:', e.message || e);
    Sentry = null;
  }
}
// Lightweight latency logging
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    try {
      console.log(`[${res.statusCode}] ${req.path} - ${Date.now() - start}ms`);
    } catch (_) { /* noop */ }
  });
  next();
});

// Initialize Google Cloud Logging (optional)
let loggingClient = null;
try {
  const {Logging} = require('@google-cloud/logging');
  loggingClient = new Logging();
} catch (e) {
  loggingClient = null;
}

function logEvent(level, message, meta = {}) {
  const logEntry = Object.assign({ message }, meta);
  if (loggingClient) {
    try {
      const log = loggingClient.log('bizcard-proxy');
      const entry = log.entry({ resource: { type: 'global' } }, logEntry);
      log.write(entry).catch((err) => console.warn('Cloud Logging write failed', err));
    } catch (e) {
      console.warn('Cloud Logging error', e.message || e);
    }
  }
  // fallback to console
  if (level === 'warn') console.warn(message, meta);
  else if (level === 'error') console.error(message, meta);
  else console.log(message, meta);
}

// Optional Firebase Admin (for token verification) and Redis (for production rate limiting)
let admin = null;
try {
  admin = require('firebase-admin');
  // Initialize if not already initialized and if credentials are available via env
  if (!admin.apps || admin.apps.length === 0) {
    try {
      // 1) If service account JSON is provided via env var, use it (helpful for local testing)
      if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
        try {
          const sa = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
          admin.initializeApp({ credential: admin.credential.cert(sa) });
          console.log('firebase-admin initialized from FIREBASE_SERVICE_ACCOUNT_JSON');
        } catch (e) {
          console.warn('Failed to parse FIREBASE_SERVICE_ACCOUNT_JSON, falling back to default init', e.message || e);
          admin.initializeApp();
        }
      } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
        // 2) If GOOGLE_APPLICATION_CREDENTIALS is set (file path), default init will read it
        admin.initializeApp();
        console.log('firebase-admin initialized using GOOGLE_APPLICATION_CREDENTIALS');
      } else {
        // 3) Otherwise, try default initialization (works on GCP/Firebase runtimes)
        admin.initializeApp();
        console.log('firebase-admin initialized with default credentials (GCP environment)');
      }
    } catch (e) {
      // ignore init errors when running locally without proper service account; token verify will fail if required
      console.warn('firebase-admin initialization warning:', e.message || e);
    }
  }
} catch (e) {
  // firebase-admin not installed or not available
  admin = null;
}

let Redis = null;
let redisClient = null;
const REDIS_URL = process.env.REDIS_URL || null;
if (REDIS_URL) {
  try {
    Redis = require('ioredis');
    redisClient = new Redis(REDIS_URL);
  } catch (e) {
    console.warn('ioredis not available or failed to connect:', e.message || e);
    redisClient = null;
  }
}
// Expose redis client on the app instance for routes/healthchecks
app.set('redis', redisClient);

// Google Secret Manager support (optional)
let secretManagerClient = null;
let cachedGeminiKey = null;
const SECRET_MANAGER_NAME = process.env.GEMINI_SECRET_NAME || null; // e.g. projects/PROJECT_ID/secrets/NAME/versions/latest
try {
  if (SECRET_MANAGER_NAME) {
    const {SecretManagerServiceClient} = require('@google-cloud/secret-manager');
    secretManagerClient = new SecretManagerServiceClient();
  }
} catch (e) {
  secretManagerClient = null;
}

async function getGeminiKey() {
  if (cachedGeminiKey) return cachedGeminiKey;
  // 1) Prefer Secret Manager
  if (secretManagerClient && SECRET_MANAGER_NAME) {
    try {
      const [accessResponse] = await secretManagerClient.accessSecretVersion({ name: SECRET_MANAGER_NAME });
      const payload = accessResponse.payload && accessResponse.payload.data ? accessResponse.payload.data.toString('utf8') : null;
      if (payload) {
        cachedGeminiKey = payload.trim();
        return cachedGeminiKey;
      }
    } catch (e) {
      console.warn('Secret Manager fetch failed, falling back to env var:', e.message || e);
    }
  }

  // 2) Fallback to environment variable
  const envKey = process.env.GEMINI_API_KEY || null;
  if (envKey) {
    cachedGeminiKey = envKey;
    return cachedGeminiKey;
  }
  return null;
}

// Retry/backoff helper for transient errors when calling external APIs
const RETRY_MAX_ATTEMPTS = process.env.RETRY_MAX_ATTEMPTS ? parseInt(process.env.RETRY_MAX_ATTEMPTS, 10) : 4;
const RETRY_INITIAL_MS = process.env.RETRY_INITIAL_MS ? parseInt(process.env.RETRY_INITIAL_MS, 10) : 500; // 0.5s
const RETRY_MAX_MS = process.env.RETRY_MAX_MS ? parseInt(process.env.RETRY_MAX_MS, 10) : 8000; // 8s

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function fetchWithRetry(url, options = {}, maxAttempts = RETRY_MAX_ATTEMPTS) {
  let attempt = 0;
  let delay = RETRY_INITIAL_MS;
  while (attempt < maxAttempts) {
    attempt += 1;
    try {
      const resp = await fetch(url, options);
      // Retry on 5xx or 429
      if (resp.status >= 500 || resp.status === 429) {
        const text = await resp.text().catch(() => '');
        logEvent('warn', 'fetch_retry_status', { url, status: resp.status, attempt, text: text.substring(0, 200) });
        if (attempt >= maxAttempts) return resp; // return last response
        // exponential backoff + jitter
        const jitter = Math.floor(Math.random() * 200);
        const wait = Math.min(delay + jitter, RETRY_MAX_MS);
        await sleep(wait);
        delay = Math.min(delay * 2, RETRY_MAX_MS);
        continue;
      }
      return resp;
    } catch (err) {
      // network error - retry
      logEvent('warn', 'fetch_retry_error', { url, error: err.message || err, attempt });
      if (Sentry) Sentry.captureException(err);
      if (attempt >= maxAttempts) throw err;
      const jitter = Math.floor(Math.random() * 200);
      const wait = Math.min(delay + jitter, RETRY_MAX_MS);
      await sleep(wait);
      delay = Math.min(delay * 2, RETRY_MAX_MS);
    }
  }
}

// Unified parser utilities
const {
  sanitizeRawText,
  validateRequest,
  estimateTokensFromText,
  extractJsonFromText,
} = require('./utils/parser');

// Simple in-memory rate limiter per session_id (fallback when Redis not configured)
const limits = new Map();
const WINDOW_MS = 60 * 1000; // 1 minute
const MAX_PER_WINDOW = 30; // max 30 requests per minute per session

// Quota controls (tokens + requests)
const QUOTA_MAX_TOKENS = process.env.QUOTA_MAX_TOKENS ? parseInt(process.env.QUOTA_MAX_TOKENS, 10) : 100000; // tokens per period
const QUOTA_PERIOD_MS = process.env.QUOTA_PERIOD_MS ? parseInt(process.env.QUOTA_PERIOD_MS, 10) : 30 * 24 * 60 * 60 * 1000; // 30 days
const QUOTA_MAX_REQUESTS = process.env.QUOTA_MAX_REQUESTS ? parseInt(process.env.QUOTA_MAX_REQUESTS, 10) : 1000; // requests per period

// In-memory fallback for quotas (not persistent)
const quotaMemory = new Map();

async function checkAndReserveQuota(sessionId, reserveTokens = 0, reserveRequests = 1) {
  // If Redis available, use it
  if (redisClient) {
    try {
      const tokensKey = `quota:tokens:${sessionId}`;
      const reqKey = `quota:req:${sessionId}`;
      // Reserve tokens
      const newTokens = await redisClient.incrby(tokensKey, reserveTokens);
      if (newTokens === reserveTokens) {
        // first time, set expiry
        await redisClient.pexpire(tokensKey, QUOTA_PERIOD_MS);
      }
      if (newTokens > QUOTA_MAX_TOKENS) {
        // revert
        await redisClient.decrby(tokensKey, reserveTokens);
        return false;
      }
      // Reserve requests
      const newReqs = await redisClient.incrby(reqKey, reserveRequests);
      if (newReqs === reserveRequests) {
        await redisClient.pexpire(reqKey, QUOTA_PERIOD_MS);
      }
      if (newReqs > QUOTA_MAX_REQUESTS) {
        // revert both
        await redisClient.decrby(tokensKey, reserveTokens);
        await redisClient.decrby(reqKey, reserveRequests);
        return false;
      }
      return true;
    } catch (e) {
      logEvent('warn', 'quota_redis_error', { error: e.message || e });
    }
  }

  // Fallback to in-memory simple quota
  const now = Date.now();
  const entry = quotaMemory.get(sessionId) || { tokens: 0, reqs: 0, ts: now };
  if (now - entry.ts > QUOTA_PERIOD_MS) {
    entry.tokens = 0;
    entry.reqs = 0;
    entry.ts = now;
  }
  if (entry.tokens + reserveTokens > QUOTA_MAX_TOKENS) return false;
  if (entry.reqs + reserveRequests > QUOTA_MAX_REQUESTS) return false;
  entry.tokens += reserveTokens;
  entry.reqs += reserveRequests;
  quotaMemory.set(sessionId, entry);
  return true;
}

async function adjustQuotaAfterCall(sessionId, additionalTokens = 0) {
  if (!additionalTokens) return;
  if (redisClient) {
    try {
      const tokensKey = `quota:tokens:${sessionId}`;
      const newTokens = await redisClient.incrby(tokensKey, additionalTokens);
      // ensure expiry present
      await redisClient.pexpire(tokensKey, QUOTA_PERIOD_MS);
      return newTokens;
    } catch (e) {
      logEvent('warn', 'quota_adjust_redis_error', { error: e.message || e });
    }
  }
  const entry = quotaMemory.get(sessionId) || { tokens: 0, reqs: 0, ts: Date.now() };
  entry.tokens += additionalTokens;
  quotaMemory.set(sessionId, entry);
  return entry.tokens;
}

async function getQuotaStatus(sessionId) {
  if (redisClient) {
    try {
      const tokensKey = `quota:tokens:${sessionId}`;
      const reqKey = `quota:req:${sessionId}`;
      const [tokens, reqs] = await Promise.all([redisClient.get(tokensKey), redisClient.get(reqKey)]);
      return {
        tokens: parseInt(tokens || '0', 10),
        requests: parseInt(reqs || '0', 10),
        maxTokens: QUOTA_MAX_TOKENS,
        maxRequests: QUOTA_MAX_REQUESTS,
        periodMs: QUOTA_PERIOD_MS,
      };
    } catch (e) {
      logEvent('warn', 'quota_status_redis_error', { error: e.message || e });
    }
  }
  const entry = quotaMemory.get(sessionId) || { tokens: 0, reqs: 0, ts: Date.now() };
  return {
    tokens: entry.tokens,
    requests: entry.reqs,
    maxTokens: QUOTA_MAX_TOKENS,
    maxRequests: QUOTA_MAX_REQUESTS,
    periodMs: QUOTA_PERIOD_MS,
  };
}

async function checkRateLimit(sessionId) {
  // If Redis is configured, use a simple INCR+EXPIRE approach
  if (redisClient) {
    const banKey = `ban:${sessionId}`;
    try {
      // Check ban first
      const isBanned = await redisClient.get(banKey);
      if (isBanned) {
        return false;
      }

      // Sliding window using sorted set
      const key = `rl:${sessionId}`;
      const now = Date.now();
      const windowMs = process.env.RATE_LIMIT_WINDOW_MS ? parseInt(process.env.RATE_LIMIT_WINDOW_MS, 10) : WINDOW_MS;
      const maxPerWindow = process.env.RATE_LIMIT_MAX ? parseInt(process.env.RATE_LIMIT_MAX, 10) : MAX_PER_WINDOW;

      // Add current event with score == timestamp
      // member needs to be unique; use timestamp+random
      const member = `${now}-${Math.random()}`;
      await redisClient.zadd(key, now, member);

      // Remove old entries outside the window
      await redisClient.zremrangebyscore(key, 0, now - windowMs);

      // Count current items
      const count = await redisClient.zcard(key);

      if (count > maxPerWindow) {
        // Violation: increment violation counter and impose an escalating ban
        const vioKey = `vio:${sessionId}`;
        const vio = await redisClient.incr(vioKey);
        // Keep vio counter for a reasonable period (10x window)
        await redisClient.pexpire(vioKey, windowMs * 10);

        const baseBanMs = process.env.BAN_BASE_MS ? parseInt(process.env.BAN_BASE_MS, 10) : 5 * 60 * 1000; // 5 minutes
        const banMaxMs = process.env.BAN_MAX_MS ? parseInt(process.env.BAN_MAX_MS, 10) : 24 * 60 * 60 * 1000; // 24 hours
        // Exponential backoff: base * 2^(vio-1), capped to banMaxMs
        const banMs = Math.min(baseBanMs * Math.pow(2, Math.max(0, vio - 1)), banMaxMs);
        await redisClient.set(banKey, '1', 'PX', banMs);

  // Log the ban event
  logEvent('warn', 'rate_limit_ban', { sessionId, banMs, vio });
  if (Sentry) Sentry.captureMessage(`Rate limit ban for ${sessionId}`, 'warning');
        return false;
      }

      return true;
    } catch (e) {
      logEvent('warn', 'redis_rate_limit_error', { error: e.message || e });
      console.warn('Redis rate limit failed, falling back to memory limiter', e.message || e);
    }
  }

  // Fallback to in-memory
  const now = Date.now();
  // Respect environment overrides for window and max even in memory mode
  const windowMs = process.env.RATE_LIMIT_WINDOW_MS ? parseInt(process.env.RATE_LIMIT_WINDOW_MS, 10) : WINDOW_MS;
  const maxPerWindow = process.env.RATE_LIMIT_MAX ? parseInt(process.env.RATE_LIMIT_MAX, 10) : MAX_PER_WINDOW;
  const entry = limits.get(sessionId) || { ts: now, count: 0 };
  if (now - entry.ts > windowMs) {
    entry.ts = now;
    entry.count = 1;
  } else {
    entry.count += 1;
  }
  limits.set(sessionId, entry);
  return entry.count <= maxPerWindow;
}

// extractJsonFromText provided by utils/parser

// Simple local token verification middleware (no Firebase login).
// If REQUIRE_AUTH=true and signature middleware is not enforced, verify Authorization: Bearer <token>
// using either a static APP_SECRET or an HMAC signature comparison (APP_SIGNATURE).
app.use((req, res, next) => {
  try {
    const requireAuth = process.env.REQUIRE_AUTH === 'true';
    if (!requireAuth) return next();

    // If signature requirement is active, defer to signature middleware for enforcement.
    if (PROXY_REQUIRE_SIGNATURE && PROXY_SIGNATURE_SECRET) return next();

    // Prefer X-App-Token/X-App-Signature if present
    const xToken = req.headers['x-app-token'];
    const xSig = req.headers['x-app-signature'];

    let token = null;
    if (typeof xToken === 'string' && xToken.length > 0) {
      token = xToken;
    } else {
      const header = req.headers.authorization || req.headers.Authorization;
      if (!header || typeof header !== 'string' || !header.startsWith('Bearer ')) {
        return res.status(401).json({ ok: false, error: 'missing_auth' });
      }
      token = header.split(' ')[1];
    }

    const APP_SECRET = process.env.APP_SECRET || '';
    const APP_SIGNATURE = process.env.APP_SIGNATURE || '';

    // Option 1: Static shared secret
    if (APP_SECRET && token === APP_SECRET) return next();

    // Option 2a: Dynamic HMAC(token) header verification (X-App-Signature)
    if (APP_SECRET && xSig && typeof xSig === 'string') {
      const h = crypto.createHmac('sha256', APP_SECRET).update(token).digest('hex');
      // timing-safe compare
      try {
        const a = Buffer.from(h, 'utf8');
        const b = Buffer.from(xSig, 'utf8');
        if (a.length === b.length && crypto.timingSafeEqual(a, b)) return next();
      } catch (_) { /* no-op */ }
    }

    // Option 2b: Precomputed signature env compare (legacy)
    if (APP_SECRET && APP_SIGNATURE) {
      try {
        const h = crypto.createHmac('sha256', APP_SECRET).update(token).digest('hex');
        if (h === APP_SIGNATURE) return next();
      } catch (_) {}
    }

    return res.status(401).json({ ok: false, error: 'invalid_token' });
  } catch (e) {
    logEvent('error', 'local_auth_middleware_error', { error: e.message || e });
    return res.status(500).json({ ok: false, error: 'internal_error' });
  }
});

// Optional HMAC signature middleware for anti-replay and CSRF-like protection.
// Set PROXY_REQUIRE_SIGNATURE=true and provide one or more secrets to enable.
// The client should send header PROXY_SIGNATURE_HEADER (default 'x-proxy-signature') with value: <timestamp>:<hex_hmac>
const PROXY_SIGNATURE_SECRET = process.env.PROXY_SIGNATURE_SECRET || null;
const PROXY_SIGNATURE_SECRET_PREV = process.env.PROXY_SIGNATURE_SECRET_PREV || null;
const PROXY_SIGNATURE_SECRETS = (process.env.PROXY_SIGNATURE_SECRETS || '')
  .split(',')
  .map(s => s.trim())
  .filter(Boolean);
// Consolidate candidate secrets: CSV list takes precedence; else use current + prev if provided
const SIG_SECRETS = PROXY_SIGNATURE_SECRETS.length > 0
  ? PROXY_SIGNATURE_SECRETS
  : [PROXY_SIGNATURE_SECRET, PROXY_SIGNATURE_SECRET_PREV].filter(Boolean);
// If explicitly set to 'false', do not require signature. Otherwise, require if any secret configured or env says true.
const PROXY_REQUIRE_SIGNATURE = process.env.PROXY_REQUIRE_SIGNATURE === 'false' ? false : (process.env.PROXY_REQUIRE_SIGNATURE === 'true' || SIG_SECRETS.length > 0);
const PROXY_SIGNATURE_HEADER = process.env.PROXY_SIGNATURE_HEADER || 'x-proxy-signature';
const PROXY_SIGNATURE_TTL_MS = process.env.PROXY_SIGNATURE_TTL_MS ? parseInt(process.env.PROXY_SIGNATURE_TTL_MS, 10) : 2 * 60 * 1000; // 2 minutes

const replayCache = new Set(); // simple in-memory replay cache fallback


async function isReplay(key) {
  if (redisClient) {
    try {
      const exists = await redisClient.get(key);
      if (exists) return true;
      await redisClient.set(key, '1', 'PX', PROXY_SIGNATURE_TTL_MS);
      return false;
    } catch (e) {
      logEvent('warn', 'replay_redis_error', { error: e.message || e });
    }
  }
  if (replayCache.has(key)) return true;
  replayCache.add(key);
  // schedule eviction
  const t = setTimeout(() => replayCache.delete(key), Math.max(1000, PROXY_SIGNATURE_TTL_MS));
  if (typeof t.unref === 'function') t.unref();
  return false;
}

app.use(async (req, res, next) => {
  try {
    if (!PROXY_REQUIRE_SIGNATURE) return next();
    if (!SIG_SECRETS || SIG_SECRETS.length === 0) {
      logEvent('warn', 'signature_config_missing');
      return res.status(500).json({ ok: false, error: 'server_misconfigured', message: 'signature secrets required' });
    }
    const header = req.headers[PROXY_SIGNATURE_HEADER];
    if (!header || typeof header !== 'string') return res.status(401).json({ ok: false, error: 'missing_signature' });
    const parts = header.split(':');
    if (parts.length !== 2) return res.status(401).json({ ok: false, error: 'invalid_signature_format' });
    const ts = parseInt(parts[0], 10);
    const sig = parts[1];
    if (Number.isNaN(ts)) return res.status(401).json({ ok: false, error: 'invalid_signature_timestamp' });
    const now = Date.now();
    if (Math.abs(now - ts) > PROXY_SIGNATURE_TTL_MS) return res.status(401).json({ ok: false, error: 'signature_expired' });

    const payload = `${ts}:${req.rawBody || ''}`;
    // Try all candidate secrets for rotation window support
    let matchedHmac = null;
    for (const secret of SIG_SECRETS) {
      try {
        const h = crypto.createHmac('sha256', secret).update(payload).digest('hex');
        if (crypto.timingSafeEqual(Buffer.from(h), Buffer.from(sig))) {
          matchedHmac = h;
          break;
        }
      } catch (_) { /* ignore */ }
    }
    if (!matchedHmac) return res.status(401).json({ ok: false, error: 'invalid_signature' });

    // prevent replay attacks using the matched signature as key
    const replayKey = `sig:${matchedHmac}`;
    if (await isReplay(replayKey)) return res.status(401).json({ ok: false, error: 'replay' });

    return next();
  } catch (e) {
    logEvent('error', 'signature_middleware_error', { error: e.message || e });
    return res.status(500).json({ ok: false, error: 'internal_error' });
  }
});
// Redis healthcheck endpoint
app.get('/health/redis', async (req, res) => {
  const rc = req.app.get('redis');
  if (!rc) return res.status(503).json({ ok: false, connected: false, error: 'redis_unconfigured' });
  try {
    const pong = await rc.ping();
    return res.json({ ok: true, connected: true, ping: pong });
  } catch (e) {
    return res.status(500).json({ ok: false, connected: false, error: e.message || String(e) });
  }
});

app.post('/format-card', async (req, res) => {
  try {
    const body = req.body || {};
    const validationError = validateRequest(body);
    if (validationError) {
      logEvent('warn', 'validation_error', { error: validationError, ip: req.ip });
      return res.status(400).json({ ok: false, error: validationError });
    }

    // Sanitized values
    const raw_text = sanitizeRawText(body.raw_text);
    const template = Array.isArray(body.template) ? body.template : undefined;
    const session_id = typeof body.session_id === 'string' ? body.session_id : undefined;
    const sessionId = session_id || (req.user && req.user.uid) || req.ip || 'anonymous';

    const allowed = await checkRateLimit(sessionId);
    if (!allowed) {
      return res.status(429).json({ ok: false, error: 'rate_limited' });
    }

    // Quota reservation: estimate tokens and reserve
    const estimatedTokens = estimateTokensFromText(raw_text);
    const quotaOk = await checkAndReserveQuota(sessionId, estimatedTokens, 1);
    if (!quotaOk) {
      logEvent('warn', 'quota_exceeded', { sessionId });
      return res.status(402).json({ ok: false, error: 'quota_exceeded' });
    }

    const key = await getGeminiKey();
    if (!key) {
      console.error('Missing GEMINI API key (Secret Manager or GEMINI_API_KEY env).');
      return res.status(500).json({ ok: false, error: 'server_misconfigured' });
    }

    // Build prompt
    const headers = Array.isArray(template) ? template : [];
    const headerList = headers.length ? headers.join(', ') : 'Name, Company, Email, Phone, Website, Address';

    const prompt = `You are an AI that converts unstructured text from a business card into structured JSON. Use these column names exactly as the JSON keys: ${headerList}. If a value is missing, return it as an empty string "". Return only valid JSON — no explanations or markdown. Raw text: ${raw_text}`;

    const aiRequestBody = {
      contents: [
        { parts: [{ text: prompt }] }
      ]
    };

    const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${key}`;

    const resp = await fetchWithRetry(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(aiRequestBody),
    }, RETRY_MAX_ATTEMPTS);

    const json = await resp.json();
    const text = json?.candidates?.[0]?.content?.parts?.[0]?.text;
    const data = extractJsonFromText(text);
    if (!data) {
      // rollback or adjust quota to reflect failure
      await adjustQuotaAfterCall(sessionId, 0); // no-op placeholder (could refund tokens if desired)
      logEvent('error', 'parse_error', { sessionId, response: json });
      if (Sentry) Sentry.captureException(new Error('Failed to parse JSON from AI output'));
      return res.status(500).json({ ok: false, error: 'parse_error', message: 'Failed to parse JSON from AI output' });
    }

    // Success: quota already reserved; optionally adjust with actual tokens used
    const actualTokens = estimateTokensFromText(text || JSON.stringify(data));
    await adjustQuotaAfterCall(sessionId, actualTokens - estimatedTokens);

    logEvent('info', 'format_card_success', { sessionId, tokens: actualTokens });
    return res.json({ ok: true, data, source: 'ai' });
  } catch (err) {
      logEvent('error', 'format_card_exception', { error: err.message || err });
      if (Sentry) Sentry.captureException(err);
      return res.status(500).json({ ok: false, error: 'internal_error', message: err.message });
  }
});

// Combined OCR processing pipeline: refine -> structure -> finalize
app.post('/process-ocr', async (req, res) => {
  try {
    const body = req.body || {};
    const validationError = validateRequest({ raw_text: body.raw_text });
    if (validationError) {
      logEvent('warn', 'validation_error', { error: validationError, ip: req.ip });
      return res.status(400).json({ ok: false, error: validationError });
    }

    const raw_text = sanitizeRawText(body.raw_text);
    const session_id = typeof body.session_id === 'string' ? body.session_id : undefined;
    const sessionId = session_id || (req.user && req.user.uid) || req.ip || 'anonymous';

    const allowed = await checkRateLimit(sessionId);
    if (!allowed) return res.status(429).json({ ok: false, error: 'rate_limited' });

    const key = await getGeminiKey();
    if (!key) {
      console.error('Missing GEMINI API key (Secret Manager or GEMINI_API_KEY env).');
      return res.status(500).json({ ok: false, error: 'server_misconfigured' });
    }

    // Reserve quota approximately for three prompts
    const estTokens = estimateTokensFromText(raw_text) * 3;
    const quotaOk = await checkAndReserveQuota(sessionId, estTokens, 1);
    if (!quotaOk) return res.status(402).json({ ok: false, error: 'quota_exceeded' });

    const baseEndpoint = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${key}`;

    // 1) Refinement prompt
    const refinePrompt = `You are an OCR text refinement AI. Clean and normalize the following text extracted from an image. Remove noise, fix spacing and formatting issues, and output only the corrected readable text — no extra explanation.\n\nText:\n${raw_text}`;
    const refineReq = { contents: [{ parts: [{ text: refinePrompt }] }] };
    const refineResp = await fetchWithRetry(baseEndpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(refineReq),
    });
    const refineJson = await refineResp.json();
    const cleaned_text = refineJson?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() || '';
    if (!cleaned_text) {
      logEvent('error', 'refine_empty', { sessionId });
      return res.status(500).json({ ok: false, error: 'refine_failed' });
    }

    // 2) Structuring prompt -> expect JSON
    const structurePrompt = `You are a data structuring AI. Analyze the following extracted text and convert it into well-structured JSON. Include only meaningful fields like name, address, ID number, date, card number, etc., based on what appears. Do not invent data. Return valid JSON only — no comments or explanations.\n\nText:\n${cleaned_text}`;
    const structureReq = { contents: [{ parts: [{ text: structurePrompt }] }] };
    const structureResp = await fetchWithRetry(baseEndpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(structureReq),
    });
    const structureJson = await structureResp.json();
    const structuredText = structureJson?.candidates?.[0]?.content?.parts?.[0]?.text || '';
    let structured = extractJsonFromText(structuredText);
    if (!structured) {
      logEvent('error', 'structure_parse_error', { sessionId, structuredText: structuredText?.slice(0, 200) });
      return res.status(500).json({ ok: false, error: 'structure_failed' });
    }

    // 3) Finalize/validation prompt
    const finalizePrompt = `You are a validation and cleanup AI. Review this JSON data for consistency and accuracy. Fix obvious OCR misreads (like wrong date formats or misplaced values), ensure all keys follow lower_snake_case, and reformat it neatly as valid JSON.\n\nJSON Input:\n${JSON.stringify(structured)}`;
    const finalizeReq = { contents: [{ parts: [{ text: finalizePrompt }] }] };
    const finalizeResp = await fetchWithRetry(baseEndpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(finalizeReq),
    });
    const finalizeJson = await finalizeResp.json();
    const finalText = finalizeJson?.candidates?.[0]?.content?.parts?.[0]?.text || '';
    let finalData = extractJsonFromText(finalText);
    if (!finalData) {
      // As a fallback, return the structured JSON if finalization parsing fails
      finalData = structured;
    }

    // Adjust quota based on approximate actual tokens (combine all texts)
    const actualTokens = estimateTokensFromText([cleaned_text, structuredText, finalText].join(' '));
    await adjustQuotaAfterCall(sessionId, actualTokens - estTokens);

    return res.json({ ok: true, cleaned_text, structured_json: structured, final_json: finalData });
  } catch (e) {
    logEvent('error', 'process_ocr_exception', { error: e.message || e });
    return res.status(500).json({ ok: false, error: 'internal_error', message: e.message });
  }
});

// Quota status endpoint
app.get('/quota-status/:sessionId', async (req, res) => {
  try {
    const sid = req.params.sessionId || req.query.session_id || req.ip;
    const status = await getQuotaStatus(sid);
    return res.json({ ok: true, status });
  } catch (e) {
    return res.status(500).json({ ok: false, error: 'internal_error' });
  }
});

// attach Sentry error handler after routes
if (Sentry) {
  app.use(Sentry.Handlers.errorHandler());
}

// Export for Firebase Functions or run standalone
if (require.main === module) {
  if (process.env.NODE_ENV === 'production' && process.env.PROXY_SIGNATURE_SECRET === 'test_secret') {
    console.warn('⚠️ Using default signature secret in production!');
  }
  const port = process.env.PORT || 3000;
  app.listen(port, () => console.log(`bizcard-proxy listening on ${port}`));
}

// Export for Firebase Functions if the package is available
try {
  // eslint-disable-next-line global-require
  const functions = require('firebase-functions');
  exports.api = functions.https.onRequest(app);
} catch (e) {
  // Not running in Firebase Functions environment - expose app for standalone run
  module.exports = app;
}

// Always export app for tests and tooling
module.exports.app = app;
