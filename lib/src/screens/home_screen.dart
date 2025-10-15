import 'package:flutter/material.dart';
import '../../core/routes.dart';
import '../../core/providers/result_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final last = ScanResultStore.instance.state;
    return Scaffold(
      appBar: AppBar(title: const Text('Your scans')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.scan),
        child: const Icon(Icons.add_a_photo),
      ),
      body: ListView(
        children: [
          if (last.aiResult != null)
            ListTile(
              leading: const Icon(Icons.credit_card),
              title: Text(last.aiResult?['Name']?.toString() ?? 'Last result'),
              subtitle: Text(last.aiResult?.toString() ?? ''),
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.result),
            )
          else
            const ListTile(
              title: Text('No scans yet'),
              subtitle: Text('Tap + to scan a card'),
            ),
        ],
      ),
    );
  }
}
