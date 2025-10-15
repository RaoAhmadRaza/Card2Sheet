Firebase Auth: client integration (optional)
=========================================

If you enable `REQUIRE_AUTH=true` on the proxy, the client must send a Firebase ID token in the Authorization header.

In Flutter (add `firebase_auth` to `pubspec.yaml` if you want to use this), the flow is:

1. Sign in (e.g. Google sign-in or anonymous):

   final userCredential = await FirebaseAuth.instance.signInAnonymously();

2. Get the ID token:

   final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();

3. Send requests with Authorization header:

   final resp = await http.post(
     Uri.parse('$PROXY_URL/format-card'),
     headers: {
       'Content-Type': 'application/json',
       'Authorization': 'Bearer $idToken',
     },
     body: jsonEncode({ 'raw_text': rawText }),
   );

This file is an example only — do not add firebase_auth to the project unless you want to manage dependency versions. If you do, run `flutter pub add firebase_auth` and ensure it matches `firebase_core` compatibility.
