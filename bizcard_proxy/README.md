BizCard Proxy
=================

This folder contains a minimal Express-based proxy that calls the Gemini Generative API on behalf of the Flutter client.

Quick start (Firebase Functions):

1. Install dependencies:

   npm install

2. Configure environment variables

   Preferred for local development: copy `.env.example` to `.env` and fill in values:

      cp functions/.env.example functions/.env
      # edit functions/.env and set GEMINI_API_KEY

   Alternatively, you can export env vars in your shell (do NOT commit secrets):

      export GEMINI_API_KEY="YOUR_KEY"

3. Run locally:

   node index.js

4. Deploy to Firebase Functions (recommended for this project):

   # Install Firebase CLI if you don't have it
   npm install -g firebase-tools

   # Log in and select your project
   firebase login
   firebase use --add

   # Set the Gemini key in Firebase Functions config (server-side secret)
   firebase functions:config:set gemini.key="YOUR_KEY"

   # Deploy functions
   cd functions
   npm install
   cd ..
   firebase deploy --only functions

   After deploy, set `PROXY_URL` in your Flutter app `.env` to your function URL, e.g.:

   PROXY_URL=https://us-central1-YOUR_FIREBASE_PROJECT.cloudfunctions.net/api

   Notes:
   - This is intentionally minimal. For production, add authentication and persistent rate limiting (Redis), logging (Stackdriver/Sentry), and automated secrets via Secret Manager.

   Optional environment variables (recommended):

   - REQUIRE_AUTH=true  # require Firebase ID tokens in Authorization: Bearer <token>
   - REDIS_URL=redis://:password@host:6379  # enable Redis-backed rate limiter

   Redis / Cloud Memorystore (recommended for rate limiting)

   For production rate limiting we recommend Google Cloud Memorystore (Redis). Create an instance and set `REDIS_URL` to point to it. Example (gcloud):

      gcloud redis instances create my-redis --size=1 --region=us-central1 --redis-version=redis_6_x

   Then set `REDIS_URL` in your functions runtime environment to the connection string (for private VPCs you might need to deploy to Cloud Run or configure VPC connector for Functions gen2). Example env:

      REDIS_URL=redis://:PASSWORD@10.0.0.5:6379

   Rate limiting configuration (optional env vars):
      RATE_LIMIT_WINDOW_MS=60000
      RATE_LIMIT_MAX=30
      BAN_BASE_MS=300000
      BAN_MAX_MS=86400000

   Quota controls (optional)

   The proxy supports per-session quotas to control monthly token usage and request counts. Configure with env vars:

      QUOTA_MAX_TOKENS=100000      # tokens allowed per period
      QUOTA_PERIOD_MS=2592000000   # period in ms (default 30 days)
      QUOTA_MAX_REQUESTS=1000      # requests per period

   You can check per-session usage via:

      GET /quota-status/:sessionId

   If a request would exceed quota the proxy returns HTTP 402 with { ok: false, error: 'quota_exceeded' }.


   If `REQUIRE_AUTH` is enabled you must initialize `firebase-admin` with proper credentials in the Functions environment (or set the service account via runtime config). For local testing you can use `GOOGLE_APPLICATION_CREDENTIALS` pointing to a service account JSON.

   CI / GitHub Actions

   The repository includes a GitHub Actions workflow to deploy functions on push to `main`. Add the following repository secrets:

   - `FIREBASE_SERVICE_ACCOUNT_JSON` — the JSON content of a Firebase service account (set as a single-line secret value).
   - `FIREBASE_PROJECT_ID` — your Firebase project id.

   The workflow will write the service account JSON to a temp file and set `GOOGLE_APPLICATION_CREDENTIALS` for the deploy step.

   Secret Manager (recommended)

   Instead of storing the Gemini key in plain env vars, you can use Google Secret Manager. Steps:

   1. Create the secret (one-time):

      gcloud secrets create GEMINI_API_KEY --replication-policy="automatic"
      echo -n "YOUR_GEMINI_KEY" | gcloud secrets versions add GEMINI_API_KEY --data-file=-

   2. Grant the Cloud Functions service account permission to access the secret:

      # replace PROJECT-ID and FUNCTIONS-SERVICE-ACCOUNT if needed
      gcloud secrets add-iam-policy-binding GEMINI_API_KEY \
        --member="serviceAccount:PROJECT_ID@appspot.gserviceaccount.com" \
        --role="roles/secretmanager.secretAccessor"

   3. Set `GEMINI_SECRET_NAME` environment variable for your functions to the full secret resource name:

      projects/PROJECT_ID/secrets/GEMINI_API_KEY/versions/latest

   If `GEMINI_SECRET_NAME` is set, the function will fetch the secret at runtime and cache it in memory.

   CI secrets and deploy safety
   ---------------------------

   Before enabling automatic deploys you must configure two repository secrets used by the workflow:

   - `FIREBASE_SERVICE_ACCOUNT_JSON` — the full service account JSON content (make sure it's the JSON text, not a file path).
   - `FIREBASE_PROJECT_ID` — the Firebase project id (e.g. my-project-12345).

   You can add them via the GitHub web UI (Settings → Secrets and variables → Actions) or via the GitHub CLI. Example using `gh`:

   ```bash
   gh secret set FIREBASE_SERVICE_ACCOUNT_JSON --body "$(cat /path/to/firebase-service-account.json | tr -d '\n')"
   gh secret set FIREBASE_PROJECT_ID --body "my-project-12345"
   ```

   The CI workflow will perform a pre-check and fail fast with a clear message if either secret is missing.

   Firebase Admin & REQUIRE_AUTH

   To enable `REQUIRE_AUTH=true` you must ensure `firebase-admin` is initialized with credentials that can verify ID tokens.

   Options to initialize `firebase-admin`:

   - Provide the service account JSON as an environment variable in your CI/CD or Functions runtime (convenient for CI):

      FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account", ... }'

      The GitHub Actions workflow can store this JSON in the secret `FIREBASE_SERVICE_ACCOUNT_JSON` and write it to the env before deploy.

   - Or set `GOOGLE_APPLICATION_CREDENTIALS` to point to a service account JSON file path in the Functions runtime (less common for managed Functions).

   - On GCP/Firebase hosting, default credentials are usually available to the runtime; verify that the functions service account has `roles/iam.serviceAccountTokenCreator` and other required roles.

   Only enable `REQUIRE_AUTH=true` after the runtime is configured to initialize admin SDK successfully.

   Observability (Sentry / Cloud Logging)

   You can enable Sentry and structured Cloud Logging for better visibility:

   - Sentry: set `SENTRY_DSN` in the Functions runtime to initialize Sentry SDK and capture errors/exceptions.
   - Cloud Logging: the function will try to write to Cloud Logging if the runtime credentials permit it. Logs are written to a log named `bizcard-proxy`.

   Example env:
      SENTRY_DSN=https://<PUBLIC_DSN>@sentry.io/12345

   Retry/backoff configuration

   The proxy will retry transient Gemini/network errors (5xx and 429) with exponential backoff and jitter. Configure via env vars:

      RETRY_MAX_ATTEMPTS=4
      RETRY_INITIAL_MS=500
      RETRY_MAX_MS=8000


      Security hardening (CORS + request signature)
      ---------------------------------------------

      For production you should lock down CORS and enable a request signature to prevent replay/CSRF-like attacks from untrusted origins.

      - `PROXY_ALLOWED_ORIGINS` — comma-separated list of allowed origins. Example:

            PROXY_ALLOWED_ORIGINS=https://app.example.com,https://admin.example.com

         When not set the proxy remains permissive to allow local testing.

      - `PROXY_REQUIRE_SIGNATURE` — set to `true` to require an HMAC signature on requests. When enabled you must also set `PROXY_SIGNATURE_SECRET`.

      - `PROXY_SIGNATURE_SECRET` — a shared secret (keep it server-only). The client uses this to HMAC the request payload and timestamp.

      - `PROXY_SIGNATURE_HEADER` — header name the client must send (default `x-proxy-signature`). The header value format is: `<timestamp>:<hex_hmac>` where `hex_hmac` is HMAC-SHA256 of the string `${timestamp}:${rawBody}`.

      - `PROXY_SIGNATURE_TTL_MS` — allowed clock skew/time window for signatures (default 120000 ms / 2 minutes).

      Client example (Node or browser with crypto):

      ```js
      // Build the signature header before sending the request.
      // timestamp is milliseconds since epoch
      const timestamp = Date.now();
      const rawBody = JSON.stringify({ raw_text: 'John Doe...'});
      // Use an HMAC-SHA256 implementation. In Node:
      const crypto = require('crypto');
      const secret = process.env.CLIENT_PROXY_SECRET; // do NOT store this in client code for public apps; this is for trusted clients only
      const payload = `${timestamp}:${rawBody}`;
      const hmac = crypto.createHmac('sha256', secret).update(payload).digest('hex');
      const headerValue = `${timestamp}:${hmac}`;

      fetch(PROXY_URL + '/format-card', {
         method: 'POST',
         headers: {
            'Content-Type': 'application/json',
            'x-proxy-signature': headerValue,
         },
         body: rawBody,
      });
      ```

      Important: if your client runs in an untrusted environment (public mobile or web app), you cannot safely embed `PROXY_SIGNATURE_SECRET` there. In that case:

      - Use the signature only for trusted server-to-server or backend-for-frontend flows.
      - For public clients, prefer requiring `REQUIRE_AUTH=true` with Firebase ID tokens and rely on server-side verification + per-user quotas.



