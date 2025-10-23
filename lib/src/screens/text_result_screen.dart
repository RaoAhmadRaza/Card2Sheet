import 'dart:io';
import 'package:flutter/material.dart';
import 'package:card2sheet/src/services/ocr_service.dart';

class TextResultScreen extends StatefulWidget {
  final String imagePath;
  final String? extractedText;
  const TextResultScreen({super.key, required this.imagePath, this.extractedText});

  @override
  State<TextResultScreen> createState() => _TextResultScreenState();
}

class _TextResultScreenState extends State<TextResultScreen> {
  String? _text;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Extracted Text')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _text?.isNotEmpty == true ? _text! : '(No text found)',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
    );
  }
}
