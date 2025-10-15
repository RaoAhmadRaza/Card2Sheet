/*
  proxy_auth_helper.dart

  Helper functions and a small example for attaching a Firebase ID token
  to requests sent to the server-side proxy. The firebase_auth usage is
  purposely commented out to avoid adding a package dependency in this
  branch. If you add `firebase_auth` to `pubspec.yaml`, uncomment the
  sample and adapt as needed.

  Usage:
    final headers = buildProxyHeaders(idToken);
    final resp = await http.post(Uri.parse('$PROXY_URL/format-card'), headers: headers, body: ...);

*/

Map<String, String> buildProxyHeaders(String? idToken) {
  final headers = <String, String>{'Content-Type': 'application/json'};
  if (idToken != null && idToken.isNotEmpty) {
    headers['Authorization'] = 'Bearer $idToken';
  }
  return headers;
}

/*
// Example: (requires firebase_auth) - DO NOT UNCOMMENT UNLESS you add the package
import 'package:firebase_auth/firebase_auth.dart';

Future<String?> getIdToken() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) return user.getIdToken();
  final cred = await FirebaseAuth.instance.signInAnonymously();
  return cred.user?.getIdToken();
}

// Example use:
// final idToken = await getIdToken();
// final headers = buildProxyHeaders(idToken);
// final resp = await http.post(Uri.parse('$PROXY_URL/format-card'), headers: headers, body: ...);
*/
