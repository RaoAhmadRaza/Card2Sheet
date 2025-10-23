# Deploy the AI proxy (no local server required)

This app can structure OCR text via a small proxy backed by Google Gemini. To avoid running it locally, deploy once and point the app to it.

## Option A — Firebase Cloud Functions (recommended)

Prereqs:
- Node.js 18+
- Firebase CLI (`npm i -g firebase-tools`), authenticated: `firebase login`
- A Firebase project created and connected to your app (already present in this repo)

Steps:
1) Switch to the proxy folder and install deps

```bash
cd bizcard_proxy/functions
npm install
```

2) Configure the Gemini API Key
- Easiest (dev): set runtime env var in Functions
```bash
firebase functions:secrets:set GEMINI_API_KEY
# paste your key when prompted
```
- Or use Google Secret Manager by setting `GEMINI_SECRET_NAME` in Function env later (advanced).

3) Deploy the HTTP function
```bash
firebase deploy --only functions
```
This exports an HTTPS function named `api`. Your base URL will look like:
```
https://REGION-PROJECT_ID.cloudfunctions.net/api
```

4) Configure the mobile app to use the deployed endpoint
- App supports two ways:
  - Explicit: set `.env` (Flutter) with `USE_PROXY=true` and `PROXY_URL=https://REGION-PROJECT_ID.cloudfunctions.net/api`
  - Auto: set `USE_PROXY=true` and leave `PROXY_URL` empty. The app will auto-derive `https://us-central1-PROJECT_ID.cloudfunctions.net/api` from your Firebase config. If you used a non-default region, set `FUNCTIONS_REGION` in `.env`.

That’s it. The AI structuring will run without any local server.

## Option B — Cloud Run / Render / Vercel

The proxy can also run as a plain Node/Express server:

```bash
cd bizcard_proxy
npm install
# set GEMINI_API_KEY in the host's env
# build step not required; start command runs server.js or functions/index.js directly
```

Deploy to your platform of choice and set the app `.env`:
```
USE_PROXY=true
PROXY_URL=https://your-host.example.com
```

## Security notes
- Do NOT put your Gemini API key in the Flutter app. Keep it on the server (Functions secret or host env).
- Optional hardening variables supported by the proxy:
  - `REQUIRE_AUTH=true` to require Firebase ID tokens
  - `PROXY_ALLOWED_ORIGINS` for CORS
  - `PROXY_REQUIRE_SIGNATURE=true` + `PROXY_SIGNATURE_SECRET` to HMAC sign requests (not recommended for mobile clients unless you can safely provision a per-user secret).
