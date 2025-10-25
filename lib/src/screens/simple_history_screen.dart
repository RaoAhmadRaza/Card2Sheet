import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../providers/scan_history_simple_provider.dart';
import '../models/scan_history.dart';
import '../providers/session_provider.dart';

class SimpleHistoryScreen extends ConsumerWidget {
  const SimpleHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(scanHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple History (Demo)'),
        actions: [
          IconButton(
            tooltip: 'Export to JSON',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () async {
              final dir = await getApplicationDocumentsDirectory();
              final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
              final path = '${dir.path}/SimpleScanHistory_$ts.json';
              final written = await ref.read(scanHistoryProvider.notifier).exportToJson(path);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Exported to $written')),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Clear history',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              await ref.read(scanHistoryProvider.notifier).clearHistory();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('History cleared')),
              );
            },
          ),
        ],
      ),
      body: items.isEmpty
          ? const Center(child: Text('No entries yet'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(item.cardName),
                  subtitle: Text(item.filePath),
                  trailing: Text(
                    item.dateTime.toLocal().toString().split(' ').first,
                    style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final lastPath = ref.read(sessionProvider).lastDestination?.path ?? '';
          final now = DateTime.now();
          final demo = ScanHistory('Business Card - ${now.millisecondsSinceEpoch}', lastPath, now);
          await ref.read(scanHistoryProvider.notifier).addHistory(demo);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Added demo history item')),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add demo'),
      ),
    );
  }
}
