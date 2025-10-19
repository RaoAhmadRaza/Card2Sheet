import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/result_provider.dart';
import '../services/csv_service.dart';
import '../services/xlsx_service.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  final _csv = CSVService();
  final _xlsx = XlsxService();
  String _status = '';

  Future<void> _appendToCsv() async {
    final data = ScanResultStore.instance.state.aiResult;
    if (data == null) {
      setState(() => _status = 'No AI result to append');
      return;
    }
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (pick == null || pick.files.single.path == null) return;
    final file = File(pick.files.single.path!);
    try {
      await _csv.appendRow(file, data);
      setState(() => _status = 'Appended to ${file.path}');
    } catch (e) {
      setState(() => _status = 'Append failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ScanResultStore.instance.state;
    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _appendToCsv,
              child: const Text('Append to existing CSV'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final data = state.aiResult;
                if (data == null) {
                  setState(() => _status = 'No AI result to save');
                  return;
                }
                try {
                  final f = await _xlsx.saveAsXlsx(data);
                  setState(() => _status = 'Saved: ${f.path}');
                } catch (e) {
                  setState(() => _status = 'Save failed: $e');
                }
              },
              child: const Text('Save Excel (.xlsx, bold headers)'),
            ),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_status, style: const TextStyle(color: Colors.blueGrey)),
            ],
            const SizedBox(height: 16),
            const Text('Recognized Text:'),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          state.recognizedText.isEmpty
                              ? '(none)'
                              : state.recognizedText,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          state.aiResult == null
                              ? '(none)'
                              : const JsonEncoder.withIndent(
                                  '  ',
                                ).convert(state.aiResult),
                        ),
                      ),
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
