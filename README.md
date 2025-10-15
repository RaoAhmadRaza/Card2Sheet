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
