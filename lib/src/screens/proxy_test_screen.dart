import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/ai_service.dart';

class ProxyTestScreen extends StatefulWidget {
  const ProxyTestScreen({super.key});

  @override
  State<ProxyTestScreen> createState() => _ProxyTestScreenState();
}

class _ProxyTestScreenState extends State<ProxyTestScreen> {
  final AIService _ai = AIService();
  String _output = '';
  bool _loading = false;

  Future<void> _runTest() async {
    setState(() {
      _loading = true;
      _output = '';
    });

    try {
      final headers = [
        'Name',
        'Designation',
        'Company',
        'Email',
        'Phone',
        'Website'
      ];
      final result = await _ai.formatWithTemplate(
        'John S. Miller | Regional Manager | SwiftTech Solutions | +92 331 1234567 | john.miller@swifttech.co | www.swifttech.co',
        headers,
      );
      setState(() {
        _output = const JsonEncoder.withIndent('  ').convert(result);
      });
    } catch (e) {
      setState(() {
        _output = 'Error: $e';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Proxy Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _loading ? null : _runTest,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Run Proxy Test'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child:
                    SelectableText(_output.isEmpty ? 'No output yet' : _output),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
