import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:card2sheet/src/services/ocr_service.dart';

class TextResultScreen extends StatefulWidget {
  final String imagePath;
  final String? extractedText;
  final Map<String, dynamic>? structuredData;
  const TextResultScreen({
    super.key,
    required this.imagePath,
    this.extractedText,
    this.structuredData,
  });

  @override
  State<TextResultScreen> createState() => _TextResultScreenState();
}

class _TextResultScreenState extends State<TextResultScreen> {
  String? _text;
  Map<String, dynamic>? _structured;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _structured = widget.structuredData;
    if (widget.extractedText != null) {
      // Text already provided, skip OCR
      _text = widget.extractedText!.trim();
      _loading = false;
    } else {
      // Run OCR
      _runOcr();
    }
  }

  Future<void> _runOcr() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = OCRService();
      final result = await svc.extractTextFromImage(File(widget.imagePath));
      if (!mounted) return;
      setState(() {
        _text = result.trim();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to extract text: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_structured != null && _structured!.isNotEmpty) ...[
                        Text('Structured Data', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: SelectableText(
                            const JsonEncoder.withIndent('  ').convert(_structured),
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 14, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      Text('Extracted Text', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: SelectableText(
                          _text?.isNotEmpty == true ? _text! : '(No text found)',
                          style: const TextStyle(fontSize: 16, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
