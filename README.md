# card2sheet

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Project setup notes

This project is scaffolded for the "card2sheet" app and includes packages for OCR, file creation, and optional Firebase storage.

1. Environment
   - Copy `.env.example` to `.env` and fill your keys (for example `GEMINI_API_KEY`).
   - The app loads `.env` automatically on startup.

2. Firebase (optional)
   - If you want to use Firestore, add the platform Firebase config files:
     - Android: place `google-services.json` in `android/app/`
     - iOS: place `GoogleService-Info.plist` in `ios/Runner/`
   - Run `flutterfire configure` or follow Firebase console setup. The app tries to initialize Firebase on startup and logs failures without crashing.

3. Permissions
   - Camera and file access require platform permissions. Add the following to AndroidManifest and Info.plist as needed (permission_handler docs have full details).

4. Useful commands

```bash
flutter pub get
flutter run
```

## Proxy auth setup (required for secure mode)

The app can call the included Node.js proxy (`bizcard_proxy/functions`) without Firebase login by using a local device token and HMAC signatures.

Backend environment (do not commit secrets):

```bash
# .env for proxy (example)
REQUIRE_AUTH=true
APP_SECRET=change_me_strong_random
PROXY_SIGNATURE_SECRET=another_strong_random
# optional overrides
# PROXY_SIGNATURE_HEADER=x-proxy-signature
# PROXY_REQUIRE_SIGNATURE=true
# QUOTA/RATE LIMIT envs as needed
```

Quick local test (replace values and URL):

```bash
curl -X POST https://yourproxy.com/process-ocr \
   -H "Authorization: Bearer <APP_SECRET>" \
   -H "Content-Type: application/json" \
   -d '{"raw_text":"John Doe","session_id":"test-session"}'
```

Toggle auth for testing:

- REQUIRE_AUTH=false → endpoints open (development only)
- REQUIRE_AUTH=true → requests without headers/signatures are rejected with 401

Client behavior:

- Generates a persistent anonymous session UUID on onboarding
- Generates a persistent local trust token and attaches:
   - Authorization: Bearer `TOKEN`
   - Optional: X-App-Token and X-App-Signature (HMAC over token when APP_SECRET is set)
   - Optional: x-proxy-signature (timestamped HMAC over raw body when PROXY_SIGNATURE_SECRET is set)
- Retries once automatically on HTTP 401 for transient timing issues

## Release build hardening

- Keep APP_SECRET only on the server; never bake real secrets into the app.
- When shipping to stores, consider enabling Dart obfuscation and ProGuard/R8:

```bash
# Android example (CI or local):
flutter build apk --release --obfuscate --split-debug-info=build/obf

# iOS example (Xcode Release with bitcode off; Dart obfuscation):
flutter build ios --release --obfuscate --split-debug-info=build/obf
```

Note: Obfuscation makes reverse-engineering harder but isn’t a substitute for server-side verification.
