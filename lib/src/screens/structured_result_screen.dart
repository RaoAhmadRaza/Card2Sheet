import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
// import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
// Removed SharedPreferences; using providers instead
import 'success_screen.dart';
import '../providers/scan_result_provider.dart';
import '../providers/sheet_provider.dart';
import '../providers/session_provider.dart';
import '../models/sheet_destination.dart';
import '../services/analytics_service.dart';
import '../providers/scan_history_simple_provider.dart';
import '../models/scan_history.dart';

class StructuredResultScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? structuredData;
  final String? originalText;

  const StructuredResultScreen({
    super.key,
    this.structuredData,
    this.originalText,
  });

  @override
  ConsumerState<StructuredResultScreen> createState() => _StructuredResultScreenState();
}

class _StructuredResultScreenState extends ConsumerState<StructuredResultScreen> {
  late Map<String, String> _editableData;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _editingField;
  late TextEditingController _editController;
  late FocusNode _editFocusNode;
  late TextEditingController _notesController;

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
    _notesController = TextEditingController();
    _initializeEditableData();
  }

  @override
  void dispose() {
    _editController.dispose();
    _editFocusNode.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _initializeEditableData() {
    _editableData = <String, String>{};
    final provided = widget.structuredData;
    if (provided != null && provided.isNotEmpty) {
      for (final entry in provided.entries) {
        final value = entry.value;
        if (value != null && value.toString().trim().isNotEmpty) {
          _editableData[entry.key.toLowerCase().replaceAll(' ', '_')] = value.toString();
        }
      }
      return;
    }
    // Fallback: load from provider
    final sr = ref.read(scanResultProvider);
    if (sr != null) {
      for (final entry in sr.structured.entries) {
        final value = entry.value;
        if (value.toString().trim().isNotEmpty) {
          _editableData[entry.key.toLowerCase().replaceAll(' ', '_')] = value.toString();
        }
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
    if (_isSaving) return; // single-flight guard
    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();
    // Use provider-driven selection but offer a picker if not set
    final sheetState = ref.read(sheetProvider);
    String? path = sheetState.filePath;
    String type = sheetState.type.name; // 'csv' | 'xlsx'
    String sheetName = 'Sheet1';

    // If none selected, let user choose: default CSV or pick a file
    if (path == null || path.isEmpty) {
      if (!mounted) return;
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
        ref.read(sheetProvider.notifier).setType(SheetType.csv);
        ref.read(sheetProvider.notifier).setFilePath(path);
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
        ref.read(sheetProvider.notifier).setType(ext == 'xlsx' ? SheetType.xlsx : SheetType.csv);
        ref.read(sheetProvider.notifier).setFilePath(path);
      }
    }

    if (path == null || path.isEmpty) return; // still no selection

    try {
      // Prepare data with optional personal thoughts
      final data = Map<String, String>.from(_editableData);
      final notes = _notesController.text.trim();
      if (notes.isNotEmpty) {
        data['personal_thoughts'] = notes;
      }
      // Persist via providers (debounced save) using values-only export
      await ref.read(sheetProvider.notifier).saveEntryDebounced(data,
          destination: SheetDestination(
            type: type == 'xlsx' ? SheetType.xlsx : SheetType.csv,
            path: path,
            sheetName: sheetName,
            templateHeaders: _orderedHeaders(includeNotes: notes.isNotEmpty),
          ));
      ref.read(analyticsProvider).track(
        type == 'xlsx' ? 'exported_to_xlsx' : 'exported_to_csv',
        props: {'fields': data.length, 'has_notes': notes.isNotEmpty},
      );
      // Demo/tutorial: also record a minimal ScanHistory entry in a separate box
      final cardName = _editableData['name']?.trim().isNotEmpty == true
          ? _editableData['name']!.trim()
          : 'Business Card - ${DateTime.now().millisecondsSinceEpoch}';
      await ref.read(scanHistoryProvider.notifier).addHistory(
            ScanHistory(cardName, path, DateTime.now()),
          );
      // Optionally update session
      await ref.read(sessionProvider.notifier).updateLastFilePathIfNeeded();
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
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
      final headers = _orderedHeaders(includeNotes: _notesController.text.trim().isNotEmpty).map(_getDisplayLabel).toList();
      final csv = const ListToCsvConverter().convert([headers]);
      await file.writeAsString(csv);
    }
    return file;
  }


  // Build ordered headers: common fields first, then any extras
  // Build ordered headers: common fields first, then any extras
  List<String> _orderedHeaders({bool includeNotes = false}) {
    final headers = <String>[];
    for (final field in _displayFields) {
      if (_editableData.containsKey(field)) headers.add(field);
    }
    for (final key in _editableData.keys) {
      if (!headers.contains(key)) headers.add(key);
    }
    if (includeNotes && !headers.contains('personal_thoughts')) {
      headers.add('personal_thoughts');
    }
    return headers;
  }

  // Removed header-detection helpers since we now write values-only rows

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
                          color: Colors.black.withValues(alpha: 0.1), // Stronger shadow
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
                
                // Personal thoughts (Optional)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Personal thoughts',
                            style: TextStyle(
                              fontFamily: '.SF Pro Text',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111111),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Optional',
                              style: TextStyle(
                                fontFamily: '.SF Pro Text',
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        minLines: 2,
                        maxLines: 4,
                        style: const TextStyle(
                          fontFamily: '.SF Pro Text',
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF111111),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Add any notes about this contact…',
                          hintStyle: TextStyle(
                            fontFamily: '.SF Pro Text',
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF1D1D1F).withValues(alpha: 0.35),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFDDDDDF), width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFBBBBBF), width: 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Save Button
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16), // Rounded corners
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2), // Soft outer shadow
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
                        onPressed: _isSaving ? null : _saveToSpreadsheet,
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
                        child: Text(
                          _isSaving ? 'Saving…' : 'Save to Spreadsheet',
                          style: const TextStyle(
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