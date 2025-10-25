import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/env.dart';
import '../providers/auth_session_provider.dart';
import '../providers/session_provider.dart';
import '../../core/routes.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useProxy = envIsTrue('USE_PROXY');
    final proxyUrl = env('PROXY_URL') ?? '';
    final hasKey = (env('GEMINI_API_KEY') ?? '').isNotEmpty;

    final session = ref.watch(authSessionProvider);
    final isLoggedIn = session?.isLoggedIn == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Environment'),
          const SizedBox(height: 8),
          _kv('USE_PROXY', useProxy.toString()),
          _kv('PROXY_URL', proxyUrl.isEmpty ? '(not set)' : proxyUrl),
          _kv('GEMINI_API_KEY', hasKey ? '(present)' : '(missing)'),
          const SizedBox(height: 8),
          const Text('Note: Edit .env and restart the app to change these.'),

          const Divider(height: 32),
          const Text('Account'),
          const SizedBox(height: 8),
          _kv('Status', isLoggedIn ? 'Signed in' : 'Signed out'),
          if (isLoggedIn) _kv('Email', session?.userEmail ?? '(unknown)'),
          const SizedBox(height: 12),
          Row(
            children: [
              if (isLoggedIn)
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                    onPressed: () async {
                      await ref.read(authSessionProvider.notifier).clearSession();
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          AppRoutes.onboarding,
                          (_) => false,
                        );
                      }
                    },
                  ),
                )
              else
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('Go to onboarding'),
                    onPressed: () {
                      Navigator.of(context).pushNamed(AppRoutes.onboarding);
                    },
                  ),
                ),
            ],
          ),

          const Divider(height: 32),
          const Text('Privacy & Data'),
          const SizedBox(height: 8),
          const Text(
            'Delete all local app data (history, session, in-app settings). '
            'Exports (CSV/XLSX) on disk are kept.',
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Delete all local data'),
            style: FilledButton.styleFrom(
              foregroundColor: Colors.red.shade700,
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete all local data?'),
                  content: const Text(
                      'This will clear in-app history, session, and settings. Exported files are not deleted.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(sessionProvider.notifier).deleteAllData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Local data deleted')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}
