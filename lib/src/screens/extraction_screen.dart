import 'package:flutter/material.dart';
import '../../core/routes.dart';

class ExtractionScreen extends StatefulWidget {
  const ExtractionScreen({super.key});

  @override
  State<ExtractionScreen> createState() => _ExtractionScreenState();
}

class _ExtractionScreenState extends State<ExtractionScreen> {
  double _progress = 0.1;

  @override
  void initState() {
    super.initState();
    _simulate();
  }

  Future<void> _simulate() async {
    for (int i = 0; i < 9; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() => _progress += 0.1);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Extracting...')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Processing with AI'),
            const SizedBox(height: 12),
            SizedBox(
              width: 240,
              child: LinearProgressIndicator(value: _progress),
            ),
          ],
        ),
      ),
    );
  }
}
