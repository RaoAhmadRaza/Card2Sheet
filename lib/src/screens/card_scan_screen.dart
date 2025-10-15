import 'package:flutter/material.dart';
import '../../core/routes.dart';
import 'scan_screen.dart' as legacy;

class CardScanScreen extends StatelessWidget {
  const CardScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Card')),
      body: Column(
        children: [
          Expanded(child: legacy.ScanScreen()),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Upload'),
                ),
                ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.extraction),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Extract'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
