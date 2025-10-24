import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xlsx;
// import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'success_screen.dart';

class StructuredResultScreen extends StatefulWidget {
  final Map<String, dynamic> structuredData;
  final String originalText;

  const StructuredResultScreen({
    super.key,
    required this.structuredData,
    required this.originalText,
  });

  @override
  State<StructuredResultScreen> createState() => _StructuredResultScreenState();
}

class _StructuredResultScreenState extends State<StructuredResultScreen> {
  late Map<String, String> _editableData;
  bool _isEditing = false;
  String? _editingField;
  late TextEditingController _editController;
  late FocusNode _editFocusNode;

  // Common business card fields in display order
  final List<String> _displayFields = [
    'name',
    'company',
    'email',
    'phone',
    'website',
    'address',
    'title',
    'position',
    'job_title',
  ];

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();
    _editFocusNode = FocusNode();
    _initializeEditableData();
  }

  @override
  void dispose() {
    _editController.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  void _initializeEditableData() {
    _editableData = <String, String>{};
    
    // Convert structured data to string values
    for (final entry in widget.structuredData.entries) {
      final value = entry.value;
      if (value != null && value.toString().trim().isNotEmpty) {
        _editableData[entry.key.toLowerCase().replaceAll(' ', '_')] = value.toString();
      }
    }
  }

  String _getDisplayLabel(String key) {
    switch (key.toLowerCase()) {
      case 'name':
        return 'Name';
      case 'company':
        return 'Company';
      case 'email':
        return 'Email';
      case 'phone':
        return 'Phone';
      case 'website':
        return 'Website';
      case 'address':
        return 'Address';
      case 'title':
      case 'position':
      case 'job_title':
        return 'Title';
      default:
        return key.split('_').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
    }
  }

  String _formatValue(String value, String key) {
    if (value.isEmpty) return value;
    
    // Apply Title Case formatting for better iOS feel
    if (key.toLowerCase() == 'name' || key.toLowerCase().contains('title') || key.toLowerCase() == 'company') {
      return _toTitleCase(value);
    }
    
    return value;
  }

  String _toTitleCase(String text) {
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '';
    final words = name.trim().split(' ');
    if (words.length == 1) {
      return words[0].substring(0, 1).toUpperCase();
    } else {
      return '${words.first.substring(0, 1)}${words.last.substring(0, 1)}'.toUpperCase();
    }
  }

  void _editField(String key, String currentValue) {
    setState(() {
      _editingField = key;
      _editController.text = currentValue;
    });
    
    // Focus the text field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _editFocusNode.requestFocus();
    });
  }

  void _saveCurrentEdit() {
    if (_editingField != null) {
      setState(() {
        _editableData[_editingField!] = _editController.text;
        _editingField = null;
      });
      _editFocusNode.unfocus();
      HapticFeedback.heavyImpact(); // Success haptic on save
    }
  }

  void _cancelCurrentEdit() {
    setState(() {
      _editingField = null;
    });
    _editFocusNode.unfocus();
  }

  Future<void> _saveToSpreadsheet() async {
    HapticFeedback.heavyImpact();

    // 1) Check current selection
    final current = await _getSelectedSpreadsheet();
    String? path = current?['path'];
    String? type = current?['type']; // 'csv' | 'xlsx'
    String sheetName = current?['sheet'] ?? 'Sheet1';

    // 2) If none selected, let user choose: default CSV or pick a file
    if (path == null || type == null) {
      final action = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: const Color(0xFFF2F2F7),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(60, 60, 67, 0.3),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.description_outlined, color: Color.fromRGBO(60, 60, 67, 0.6)),
                title: const Text('Use Default CSV'),
                subtitle: const Text('Create/append in app storage'),
                onTap: () => Navigator.pop(context, 'default_csv'),
              ),
              ListTile(
                leading: const Icon(Icons.upload_file, color: Color.fromRGBO(60, 60, 67, 0.6)),
                title: const Text('Pick .csv or .xlsx file'),
                onTap: () => Navigator.pop(context, 'pick'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );

      if (action == null) return; // canceled

      if (action == 'default_csv') {
        final file = await _ensureDefaultCsv();
        path = file.path;
        type = 'csv';
  await _setSelectedSpreadsheet(path: path, type: type);
      } else if (action == 'pick') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['csv', 'xlsx'],
        );
        if (result == null || result.files.single.path == null) return; // canceled
        path = result.files.single.path!;
  final ext = path.toLowerCase().endsWith('.xlsx') ? 'xlsx' : (path.toLowerCase().endsWith('.csv') ? 'csv' : null);
        if (ext == null) {
          _showError('Unsupported file type. Please choose .csv or .xlsx');
          return;
        }
        type = ext;
  await _setSelectedSpreadsheet(path: path, type: type, sheet: sheetName);
      }
    }

    if (path == null || type == null) return; // still no selection

    try {
      final file = File(path);
      if (type == 'csv') {
        await _appendToCsv(file);
      } else {
        await _appendToExcel(file, sheetName: 'Sheet1');
      }
      if (!mounted) return;
      // Navigate to success screen after successful append
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SuccessScreen(
            filePath: path,
            type: type,
          ),
        ),
      );
    } catch (e) {
      _showError('Failed to append: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<File> _ensureDefaultCsv() async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File('${docs.path}/Card2Sheet_Default.csv');
    if (!(await file.exists())) {
      final headers = _orderedHeaders().map(_getDisplayLabel).toList();
      final csv = const ListToCsvConverter().convert([headers]);
      await file.writeAsString(csv);
    }
    return file;
  }

  Future<Map<String, String>?> _getSelectedSpreadsheet() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('spreadsheet_path');
    final type = prefs.getString('spreadsheet_type');
    final sheet = prefs.getString('spreadsheet_sheet');
    if (path == null || type == null) return null;
    return {'path': path, 'type': type, 'sheet': sheet ?? 'Sheet1'};
  }

  Future<void> _setSelectedSpreadsheet({required String path, required String type, String sheet = 'Sheet1'}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('spreadsheet_path', path);
    await prefs.setString('spreadsheet_type', type);
    await prefs.setString('spreadsheet_sheet', sheet);
  }

  // Build ordered headers: common fields first, then any extras
  List<String> _orderedHeaders() {
    final headers = <String>[];
    for (final field in _displayFields) {
      if (_editableData.containsKey(field)) headers.add(field);
    }
    for (final key in _editableData.keys) {
      if (!headers.contains(key)) headers.add(key);
    }
    return headers;
  }

  // Removed unused helper

  Future<void> _appendToCsv(File file) async {
    final exists = await file.exists();
    final currentHeaders = <String>[];
    final rows = <List<dynamic>>[];

    if (exists) {
      final content = await file.readAsString();
      if (content.trim().isNotEmpty) {
        final parsed = const CsvToListConverter().convert(content);
        if (parsed.isNotEmpty) {
          currentHeaders.addAll(parsed.first.map((e) => e.toString()));
          if (parsed.length > 1) {
            rows.addAll(parsed.sublist(1));
          }
        }
      }
    }

    if (currentHeaders.isEmpty) {
      currentHeaders.addAll(_orderedHeaders().map(_getDisplayLabel));
    }

    // Map our data by display label (lowercase) for matching
    final ourMap = <String, String>{};
    for (final key in _orderedHeaders()) {
      ourMap[_getDisplayLabel(key).toLowerCase()] = _editableData[key] ?? '';
    }

    final newRow = currentHeaders
        .map((h) => ourMap[h.toLowerCase()] ?? '')
        .toList();

    // Rebuild CSV with existing headers, existing rows, and appended row
    final allRows = <List<dynamic>>[currentHeaders, ...rows, newRow];
    final csv = const ListToCsvConverter().convert(allRows);
    await file.writeAsString(csv);
  }

  Future<void> _appendToExcel(File file, {String sheetName = 'Sheet1'}) async {
    final exists = await file.exists();
    xlsx.Excel book;
    if (exists) {
      final bytes = await file.readAsBytes();
      book = xlsx.Excel.decodeBytes(bytes);
    } else {
      book = xlsx.Excel.createExcel();
    }

    sheetName = book.getDefaultSheet() ?? sheetName;
    final sheet = book[sheetName];

    // Read existing headers from first row (rowIndex 0)
    final currentHeaders = <String>[];
    for (var c = 0; c < 100; c++) {
      final cell = sheet.cell(xlsx.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
      final val = cell.value;
      if (val == null) {
        // stop when trailing nulls start and we already have some headers
        if (currentHeaders.isNotEmpty) break;
        else continue;
      }
      final String text = val.toString();
      if (text.trim().isEmpty && currentHeaders.isNotEmpty) break;
      if (text.trim().isNotEmpty) currentHeaders.add(text);
    }

    if (currentHeaders.isEmpty) {
      // Write our headers
      final headers = _orderedHeaders().map(_getDisplayLabel).toList();
      sheet.appendRow(headers
          .map<xlsx.CellValue?>((h) => xlsx.TextCellValue(h))
          .toList());
      currentHeaders.addAll(headers);
    }

    // Map our data by display label (lowercase)
    final ourMap = <String, String>{};
    for (final key in _orderedHeaders()) {
      ourMap[_getDisplayLabel(key).toLowerCase()] = _editableData[key] ?? '';
    }

    final row = currentHeaders
        .map<xlsx.CellValue?>((h) => xlsx.TextCellValue(ourMap[h.toLowerCase()] ?? ''))
        .toList();
    sheet.appendRow(row);

    final bytes = book.encode();
    if (bytes == null) throw Exception('Failed to encode Excel file');
    await file.writeAsBytes(bytes, flush: true);
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        // If exiting edit mode, cancel any active edit
        _editingField = null;
        _editFocusNode.unfocus();
      }
    });
  }

  // Context menu actions
  void _copyValue(String value) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _callPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _sendEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openWebsite(String website) async {
    String url = website;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showContextMenu(BuildContext context, String label, String value) {
    final fieldType = label.toLowerCase();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF2F2F7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: const Color.fromRGBO(60, 60, 67, 0.3),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.content_copy, color: Color.fromRGBO(60, 60, 67, 0.6)), // doc.on.clipboard SF Symbol
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                _copyValue(value);
              },
            ),
            if (fieldType == 'phone') ...[
              ListTile(
                leading: const Icon(Icons.phone, color: Color.fromRGBO(60, 60, 67, 0.6)), // phone SF Symbol
                title: const Text('Call'),
                onTap: () {
                  Navigator.pop(context);
                  _callPhone(value);
                },
              ),
            ],
            if (fieldType == 'email') ...[
              ListTile(
                leading: const Icon(Icons.email_outlined, color: Color.fromRGBO(60, 60, 67, 0.6)), // envelope SF Symbol
                title: const Text('Send Email'),
                onTap: () {
                  Navigator.pop(context);
                  _sendEmail(value);
                },
              ),
            ],
            if (fieldType == 'website') ...[
              ListTile(
                leading: const Icon(Icons.link, color: Color.fromRGBO(60, 60, 67, 0.6)), // link SF Symbol
                title: const Text('Open Link'),
                onTap: () {
                  Navigator.pop(context);
                  _openWebsite(value);
                },
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get fields that have values, prioritizing common fields
    final fieldsToShow = <String>[];
    
    // Add common fields that have values
    for (final field in _displayFields) {
      if (_editableData.containsKey(field) && _editableData[field]!.isNotEmpty) {
        fieldsToShow.add(field);
      }
    }
    
    // Add any remaining fields not in the common list
    for (final key in _editableData.keys) {
      if (!fieldsToShow.contains(key) && _editableData[key]!.isNotEmpty) {
        fieldsToShow.add(key);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // systemGroupedBackground
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 20), // Add top padding for status bar
            child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400), // Limit max width for better centering
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Scan Result',
                      style: TextStyle(
                        fontFamily: '.SF Pro Text', // SF Pro Text
                        fontSize: 28, // Large title size
                        fontWeight: FontWeight.w700, // Bold
                        color: Color(0xFF111111), // label (primary text)
                      ),
                    ),
                    if (_editingField != null) ...[
                      Row(
                        children: [
                          TextButton(
                            onPressed: _cancelCurrentEdit,
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontFamily: '.SF Pro Text',
                                fontSize: 17,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF0B0B0C), // monochrome tint
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _saveCurrentEdit,
                            child: const Text(
                              'Save',
                              style: TextStyle(
                                fontFamily: '.SF Pro Text',
                                fontSize: 17,
                                fontWeight: FontWeight.w600, // Bold for save action
                                color: Color(0xFF0B0B0C), // monochrome tint
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      ElevatedButton(
                        onPressed: _toggleEditMode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(142, 142, 147, 1), // Gray background
                          foregroundColor: Colors.white, // White text
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12), // Radius: 12
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          minimumSize: Size.zero,
                        ),
                        child: Text(
                          _isEditing ? 'Done' : 'Edit',
                          style: const TextStyle(
                            fontFamily: '.SF Pro Text', // SF Pro Text
                            fontSize: 17, // Body size
                            fontWeight: FontWeight.w400, // Regular weight
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24), // Space between title and card
                
                // Contact Information Section
                if (fieldsToShow.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 32), // Space between card and button
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF), // White card background
                      borderRadius: BorderRadius.circular(16), // More rounded corners
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1), // Stronger shadow
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      children: fieldsToShow.map((key) {
                        final value = _editableData[key] ?? '';
                        final label = _getDisplayLabel(key);
                        final isLast = key == fieldsToShow.last;
                        
                        return _buildListTile(
                          label: label,
                          value: value,
                          isLast: isLast,
                          onTap: () => _editField(_getFieldKey(label), value),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                
                // Save Button
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16), // Rounded corners
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2), // Soft outer shadow
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: SizedBox(
                    height: 56, // Standard iOS button height
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF1C1C1E), // Subtle gradient black start
                            Color(0xFF000000), // Subtle gradient black end
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton(
                        onPressed: _saveToSpreadsheet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent, // Transparent to show gradient
                          foregroundColor: Colors.white, // white text
                          elevation: 0, // No elevation (shadow handled by container)
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16), // Match container radius
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          'Save to Spreadsheet',
                          style: TextStyle(
                            fontFamily: '.SF Pro Text', // SF Pro Text
                            fontSize: 16, // Medium, 16pt
                            fontWeight: FontWeight.w500, // Medium weight
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      )
    );
  }

  Widget _buildListTile({
    required String label,
    required String value,
    required bool isLast,
    required VoidCallback onTap,
  }) {
    final formattedValue = _formatValue(value, label.toLowerCase());
    final isNameField = label.toLowerCase() == 'name';
    final fieldKey = _getFieldKey(label);
    final isCurrentlyEditing = _editingField == fieldKey;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isCurrentlyEditing ? null : () {
          HapticFeedback.lightImpact(); // Light haptic on tap
          onTap();
        },
        onLongPress: isCurrentlyEditing ? null : () {
          HapticFeedback.mediumImpact(); // Medium haptic on long press
          _showContextMenu(context, label, formattedValue);
        },
        splashColor: const Color.fromRGBO(0, 0, 0, 0.1), // Subtle cell highlight
        highlightColor: const Color.fromRGBO(0, 0, 0, 0.05), // System gray highlight
        borderRadius: BorderRadius.vertical(
          top: label == _getDisplayLabel(_displayFields.first) ? const Radius.circular(16) : Radius.zero, // Match card radius
          bottom: isLast ? const Radius.circular(16) : Radius.zero, // Match card radius
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // Row height 56-60pt (16*2 + content = ~56pt)
          constraints: const BoxConstraints(minHeight: 56), // Ensure minimum row height
          decoration: BoxDecoration(
            border: isLast ? null : Border(
              bottom: BorderSide(
                color: const Color.fromRGBO(60, 60, 67, 0.29), // separator color at 1px
                width: 1.0, // 1px separator
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: '.SF Pro Text', // SF Pro Text
                    fontSize: 13, // Caption/Footnote size
                    fontWeight: FontWeight.w400,
                    color: Color.fromRGBO(60, 60, 67, 0.6), // secondaryLabel
                  ),
                ),
              ),
              const SizedBox(width: 4), // Vertical spacing between label and value 4-6pt
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    // Avatar for Name field
                    if (isNameField && !isCurrentlyEditing) ...[
                      Container(
                        width: 32, // Slightly larger
                        height: 32,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFF8F8F8), // Light gray
                              Color(0xFFFFFFFF), // White
                            ],
                          ),
                          border: Border.all(
                            color: const Color.fromRGBO(60, 60, 67, 0.2), // Lighter stroke
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(formattedValue),
                            style: const TextStyle(
                              fontFamily: '.SF Pro Text',
                              fontSize: 13, // Slightly larger text
                              fontWeight: FontWeight.w600,
                              color: Color.fromRGBO(60, 60, 67, 0.9), // Darker for better contrast
                            ),
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: isCurrentlyEditing
                    ? TextField(
                        controller: _editController,
                        focusNode: _editFocusNode,
                        style: TextStyle(
                          fontFamily: '.SF Pro Text',
                          fontSize: isNameField ? 20 : 17,
                          fontWeight: isNameField ? FontWeight.w600 : FontWeight.w400,
                          color: const Color(0xFF111111),
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.cancel, // More iOS-like clear button
                              size: 18,
                              color: Color.fromRGBO(60, 60, 67, 0.6), // tertiaryLabel
                            ),
                            onPressed: () => _editController.clear(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                          ),
                        ),
                        textAlign: TextAlign.right,
                        maxLines: fieldKey == 'address' ? 3 : 1,
                        onSubmitted: (_) => _saveCurrentEdit(),
                      )
                    : Text(
                        formattedValue,
                        style: TextStyle(
                          fontFamily: '.SF Pro Text', // SF Pro Text
                          fontSize: isNameField ? 20 : 17, // 17-20pt for Name, 17pt Body for others
                          fontWeight: isNameField ? FontWeight.w600 : FontWeight.w400, // Semibold for Name, regular for others
                          color: const Color(0xFF111111), // label (primary text)
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isCurrentlyEditing) ...[
                const SizedBox(width: 6), // Adjust spacing
                Icon(
                  _isEditing ? Icons.edit_outlined : Icons.chevron_right, // SF Symbols: pencil / chevron.right
                  color: const Color.fromRGBO(60, 60, 67, 0.3), // tertiaryLabel
                  size: _isEditing ? 18 : 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getFieldKey(String label) {
    // Convert display label back to field key
    for (final field in _displayFields) {
      if (_getDisplayLabel(field) == label) {
        return field;
      }
    }
    // Fallback for custom fields
    return label.toLowerCase().replaceAll(' ', '_');
  }


}