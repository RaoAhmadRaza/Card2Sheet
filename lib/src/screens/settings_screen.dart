import 'package:flutter/material.dart';
import '../../core/env.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final useProxy = envIsTrue('USE_PROXY');
    final proxyUrl = env('PROXY_URL') ?? '';
    final hasKey = (env('GEMINI_API_KEY') ?? '').isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('USE_PROXY: $useProxy'),
            const SizedBox(height: 8),
            Text('PROXY_URL: ${proxyUrl.isEmpty ? '(not set)' : proxyUrl}'),
            const SizedBox(height: 8),
            Text('GEMINI_API_KEY: ${hasKey ? '(present)' : '(missing)'}'),
            const SizedBox(height: 16),
            const Text('Note: Edit .env and restart the app to change these.'),
          ],
        ),
      ),
    );
  }
}
