import 'package:flutter/material.dart';

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
    _initializeEditableData();
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

  void _editField(String key, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${_getDisplayLabel(key)}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          maxLines: key == 'address' ? 3 : 1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _editableData[key] = controller.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _saveToSpreadsheet() {
    // TODO: Implement save to spreadsheet functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Save to Spreadsheet functionality coming soon!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
    });
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
      backgroundColor: const Color(0xFFF2F2F7), // iOS grouped background
      appBar: AppBar(
        title: const Text(
          'Scan Result',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          TextButton(
            onPressed: _toggleEditMode,
            child: Text(
              _isEditing ? 'Done' : 'Edit',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 20),
        children: [
          // Contact Information Section
          if (fieldsToShow.isNotEmpty) ...[
            _buildSectionHeader('Contact Information'),
            _buildInsetGroup(
              children: fieldsToShow.map((key) {
                final value = _editableData[key] ?? '';
                final label = _getDisplayLabel(key);
                final isLast = key == fieldsToShow.last;
                
                return _buildListTile(
                  label: label,
                  value: value,
                  isLast: isLast,
                  onTap: () => _editField(key, value),
                );
              }).toList(),
            ),
            const SizedBox(height: 35),
          ],
          
          // Actions Section
          _buildSectionHeader('Actions'),
          _buildInsetGroup(
            children: [
              _buildActionTile(
                title: 'Save to Spreadsheet',
                icon: Icons.check_circle,
                color: Colors.green,
                onTap: _saveToSpreadsheet,
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Colors.grey[600],
          letterSpacing: -0.08,
        ),
      ),
    );
  }

  Widget _buildInsetGroup({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile({
    required String label,
    required String value,
    required bool isLast,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: label == _getDisplayLabel(_displayFields.first) ? const Radius.circular(10) : Radius.zero,
          bottom: isLast ? const Radius.circular(10) : Radius.zero,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            border: isLast ? null : Border(
              bottom: BorderSide(
                color: Colors.grey.withOpacity(0.3),
                width: 0.5,
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
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _isEditing ? Icons.edit : Icons.chevron_right,
                color: Colors.grey[400],
                size: _isEditing ? 18 : 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}