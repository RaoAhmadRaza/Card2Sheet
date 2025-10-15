import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../services/ai_service.dart';
import '../services/ocr_service.dart';
import '../services/csv_service.dart';
import '../../core/providers/template_provider.dart';
import '../../core/providers/result_provider.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _ai = AIService();
  final _ocr = OCRService();
  final _csv = CSVService();

  String _status = 'Idle';
  String _recognizedText = '';
  Map<String, dynamic>? _aiResult;
  File? _savedCsv;

  List<String> get _headersOrDefault {
    final headers = ref.read(templateProvider);
    if (headers.isNotEmpty) return headers;
    return const [
      'Name',
      'Designation',
      'Company',
      'Email',
      'Phone',
      'Website',
      'Address',
    ];
  }

  Future<void> _pickTemplateCsv() async {
    setState(() => _status = 'Loading template...');
    try {
      await ref.read(templateLoaderProvider).loadTemplate();
      setState(() => _status = 'Template loaded');
    } catch (e) {
      setState(() => _status = 'Template load failed: $e');
    }
  }

  Future<void> _pickImageAndOCR() async {
    setState(() {
      _status = 'Picking image...';
      _recognizedText = '';
      _aiResult = null;
      _savedCsv = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.single.path == null) {
        setState(() => _status = 'Image pick cancelled');
        return;
      }
      final file = File(result.files.single.path!);
      setState(() => _status = 'Running OCR...');
      final text = await _ocr.extractTextFromImage(file);
      setState(() {
        _recognizedText = text;
        _status = 'OCR complete';
      });
      // update shared state (singleton)
      ScanResultStore.instance.setRecognizedText(text);
    } catch (e) {
      setState(() => _status = 'OCR failed: $e');
    }
  }

  Future<void> _runAI() async {
    if (_recognizedText.trim().isEmpty) {
      setState(() => _status = 'No text recognized yet');
      return;
    }
    setState(() {
      _status = 'Calling AI...';
      _aiResult = null;
      _savedCsv = null;
    });
    try {
      final result = await _ai.formatWithTemplate(
        _recognizedText,
        _headersOrDefault,
      );
      setState(() {
        _aiResult = result;
        _status = 'AI complete';
      });
      ScanResultStore.instance.setAiResult(result);
    } catch (e) {
      setState(() => _status = 'AI error: $e');
    }
  }

  Future<void> _saveCsv() async {
    if (_aiResult == null) {
      setState(() => _status = 'Nothing to save yet');
      return;
    }
    setState(() => _status = 'Saving CSV...');
    try {
      final file = await _csv.saveAsCsv(_aiResult!);
      setState(() {
        _savedCsv = file;
        _status = 'Saved: ${file.path}';
      });
      ScanResultStore.instance.setSavedCsv(file);
    } catch (e) {
      setState(() => _status = 'Save failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final headers = _headersOrDefault;
    return Scaffold(
      appBar: AppBar(title: const Text('Card2Sheet')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _pickTemplateCsv,
                  child: const Text('Load CSV headers'),
                ),
                ElevatedButton(
                  onPressed: _pickImageAndOCR,
                  child: const Text('Pick card image + OCR'),
                ),
                ElevatedButton(
                  onPressed: _runAI,
                  child: const Text('Convert with AI'),
                ),
                ElevatedButton(
                  onPressed: _saveCsv,
                  child: const Text('Save CSV'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Status: $_status'),
            const SizedBox(height: 12),
            if (headers.isNotEmpty)
              Text('Headers (${headers.length}): ${headers.join(', ')}'),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Recognized Text:'),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                _recognizedText.isEmpty
                                    ? '(none)'
                                    : _recognizedText,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('AI Output (JSON):'),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                _aiResult == null
                                    ? '(none)'
                                    : const JsonEncoder.withIndent(
                                        '  ',
                                      ).convert(_aiResult),
                              ),
                            ),
                          ),
                        ),
                        if (_savedCsv != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Saved: ${_savedCsv!.path}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
