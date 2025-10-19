import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/routes.dart';
import '../../core/providers/result_provider.dart';
import '../../core/preferences.dart';
import 'camera_scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isPressed = false;
  bool _isOpenSheetHovered = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Mock data for demonstration - in real app this would come from database
  final List<Map<String, String>> _mockCards = [
    {
      'name': 'Ethan Carter',
      'company': 'Acme Corp',
      'position': 'Marketing Director',
      'status': 'New',
      'avatar': 'EC'
    },
    {
      'name': 'Sophia Bennett',
      'company': 'Tech Solutions Inc.',
      'position': 'Lead Developer',
      'status': 'Recent',
      'avatar': 'SB'
    },
    {
      'name': 'Liam Harper',
      'company': 'Global Innovations',
      'position': 'Product Manager',
      'status': '',
      'avatar': 'LH'
    },
    {
      'name': 'Olivia Hayes',
      'company': 'Digital Dynamics',
      'position': 'UI/UX Designer',
      'status': '',
      'avatar': 'OH'
    },
    {
      'name': 'Noah Foster',
      'company': 'Future Tech',
      'position': 'AI Specialist',
      'status': '',
      'avatar': 'NF'
    },
    {
      'name': 'Ava Morgan',
      'company': 'Innovate Solutions',
      'position': 'CEO',
      'status': '',
      'avatar': 'AM'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Cards',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1D1D1F),
                      ),
                    ),
                    GestureDetector(
                      onTapDown: (_) => setState(() => _isOpenSheetHovered = true),
                      onTapUp: (_) => setState(() => _isOpenSheetHovered = false),
                      onTapCancel: () => setState(() => _isOpenSheetHovered = false),
                      onTap: _openLatestSheet,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        padding: EdgeInsets.symmetric(
                          horizontal: _isOpenSheetHovered ? 14 : 16,
                          vertical: _isOpenSheetHovered ? 7 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: _isOpenSheetHovered 
                            ? const Color(0xFF007AFF).withOpacity(0.1)
                            : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isOpenSheetHovered 
                              ? const Color(0xFF007AFF).withOpacity(0.3)
                              : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: AnimatedScale(
                          scale: _isOpenSheetHovered ? 0.95 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedRotation(
                                turns: _isOpenSheetHovered ? 0.05 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.table_chart_outlined,
                                  size: 18,
                                  color: const Color(0xFF007AFF),
                                ),
                              ),
                              const SizedBox(width: 6),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: GoogleFonts.inter(
                                  fontSize: _isOpenSheetHovered ? 15.5 : 16,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF007AFF),
                                ),
                                child: const Text('Open Sheet'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search cards...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.grey.shade500,
                            ),
                            prefixIcon: Icon(
                              Icons.search_outlined,
                              color: Colors.grey.shade500,
                              size: 20,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                    child: Icon(
                                      Icons.clear,
                                      color: Colors.grey.shade500,
                                      size: 20,
                                    ),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: const Color(0xFF1D1D1F),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Cards List
              Expanded(
                child: _buildCardsList(),
              ),
            ],
          ),
        ),
      ),
      
      // Glassmorphic Floating Action Button
      floatingActionButton: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: _openCameraScan,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          width: _isPressed ? 155 : 160,
          height: _isPressed ? 53 : 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: _isPressed ? 8 : 15,
                offset: Offset(0, _isPressed ? 3 : 6),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF007AFF).withOpacity(0.3),
                      const Color(0xFF5856D6).withOpacity(0.2),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Center(
                  child: AnimatedScale(
                    scale: _isPressed ? 0.95 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedRotation(
                          turns: _isPressed ? 0.1 : 0.0,
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            Icons.camera_alt_outlined,
                            color: Colors.black.withOpacity(0.9),
                            size: _isPressed ? 18 : 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 150),
                          style: GoogleFonts.inter(
                            fontSize: _isPressed ? 15 : 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black.withOpacity(0.9),
                          ),
                          child: const Text('Scan Card'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Future<void> _openLatestSheet() async {
    try {
      // 1) Try last saved/uploaded path first
      final lastPath = await Preferences.getLastSheetPath();
      if (lastPath != null) {
        final file = File(lastPath);
        if (await file.exists()) {
          final isCsv = lastPath.toLowerCase().endsWith('.csv');
          final mime = isCsv
              ? 'text/csv'
              : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          final res = await OpenFilex.open(lastPath, type: mime);
          if (res.type != ResultType.done) {
            _showSnack('Could not open file (code: ${res.type.name})');
          }
          return;
        }
      }

      // 2) Fallback: scan app documents directory for latest csv/xlsx
      final dir = await getApplicationDocumentsDirectory();
      final directory = Directory(dir.path);
      if (!await directory.exists()) {
        _showSnack('No saved files found');
        return;
      }

      final files = await directory
          .list()
          .where((e) => e is File && (e.path.endsWith('.csv') || e.path.endsWith('.xlsx')))
          .cast<File>()
          .toList();

      if (files.isEmpty) {
        _showSnack('No CSV or Excel files found');
        return;
      }

      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      final latest = files.first;

      // Determine mime type
      final isCsv = latest.path.toLowerCase().endsWith('.csv');
      final mime = isCsv
          ? 'text/csv'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

      final result = await OpenFilex.open(latest.path, type: mime);
      if (result.type != ResultType.done) {
        _showSnack('Could not open file (code: ${result.type.name})');
      }
    } catch (e) {
      _showSnack('Failed to open file');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openCameraScan() async {
    final result = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (context) => const CameraScanScreen(),
      ),
    );

    if (result != null && mounted) {
      // Process the captured image path
      // This would integrate with your existing OCR and AI processing
      Navigator.of(context).pushNamed(AppRoutes.scan);
    }
  }

  // Removed export options UI as we now directly open latest sheet via system chooser

  Widget _buildCardsList() {
    final last = ScanResultStore.instance.state;
    
    // Collect all cards data
    List<Map<String, String>> allCards = [];
    
    // Add real scanned result if exists
    if (last.aiResult != null) {
      allCards.add({
        'name': last.aiResult?['Name']?.toString() ?? 'Unknown',
        'company': last.aiResult?['Company']?.toString() ?? 'Unknown Company',
        'position': last.aiResult?['Designation']?.toString() ?? 'Unknown Position',
        'status': 'Latest',
        'avatar': _getInitials(last.aiResult?['Name']?.toString() ?? 'U'),
        'isReal': 'true',
      });
    }
    
    // Add mock cards
    allCards.addAll(_mockCards.map((card) => {
      ...card,
      'isReal': 'false',
    }));
    
    // Filter cards based on search query
    if (_searchQuery.isNotEmpty) {
      allCards = allCards.where((card) {
        final searchLower = _searchQuery.toLowerCase();
        return card['name']!.toLowerCase().contains(searchLower) ||
               card['company']!.toLowerCase().contains(searchLower) ||
               card['position']!.toLowerCase().contains(searchLower);
      }).toList();
    }
    
    if (allCards.isEmpty) {
      return _buildEmptyState();
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: allCards.length,
      itemBuilder: (context, index) {
        final card = allCards[index];
        return _buildCardItem(
          name: card['name']!,
          company: card['company']!,
          position: card['position']!,
          status: card['status']!,
          avatar: card['avatar']!,
          isReal: card['isReal'] == 'true',
        );
      },
    );
  }

  Widget _buildCardItem({
    required String name,
    required String company,
    required String position,
    required String status,
    required String avatar,
    bool isReal = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: AnimatedScale(
        scale: 1.0,
        duration: const Duration(milliseconds: 100),
        child: InkWell(
          onTap: isReal 
            ? () => Navigator.of(context).pushNamed(AppRoutes.result)
            : null,
          borderRadius: BorderRadius.circular(20),
          splashColor: const Color(0xFF007AFF).withOpacity(0.1),
          highlightColor: const Color(0xFF007AFF).withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              children: [
                // Enhanced Avatar with Gradient
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: _getAvatarGradient(avatar),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _getAvatarColor(avatar).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      avatar,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            
            const SizedBox(width: 16),
            
            // Card Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1D1D1F),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    company,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF007AFF),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    position,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            // Enhanced Status Badge with Animation
            if (status.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: _getStatusGradient(status),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.credit_card_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No cards yet',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1D1D1F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Scan Card" to get started',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  Color _getAvatarColor(String avatar) {
    final colors = [
      const Color(0xFF007AFF),
      const Color(0xFF5856D6),
      const Color(0xFFAF52DE),
      const Color(0xFFFF2D92),
      const Color(0xFFFF3B30),
      const Color(0xFFFF9500),
    ];
    return colors[avatar.hashCode % colors.length];
  }

  LinearGradient _getAvatarGradient(String avatar) {
    final gradients = [
      const LinearGradient(
        colors: [Color(0xFF007AFF), Color(0xFF5A9EFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF6A5AE0), Color(0xFF8B78F6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFAF52DE), Color(0xFFD78EFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFFF2D92), Color(0xFFFF6BB5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFFF3B30), Color(0xFFFF7066)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFFF9500), Color(0xFFFFB84D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ];
    return gradients[avatar.hashCode % gradients.length];
  }

  LinearGradient _getStatusGradient(String status) {
    switch (status.toLowerCase()) {
      case 'new':
      case 'latest':
        return const LinearGradient(
          colors: [Color(0xFF34C759), Color(0xFF30B651)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'recent':
        return const LinearGradient(
          colors: [Color(0xFFFF9500), Color(0xFFE6850E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return LinearGradient(
          colors: [Colors.grey.shade400, Colors.grey.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }


}
