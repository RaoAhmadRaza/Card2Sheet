import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/routes.dart';
import '../../core/preferences.dart';
import 'camera_scan_screen.dart';
import 'card_detail_screen.dart';
import '../providers/history_provider.dart';
import '../models/history_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isPressed = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Cards',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1D1D1F),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openLatestSheet,
                    icon: const Icon(Icons.table_chart_outlined, size: 18),
                    label: Text(
                      'Open Sheet',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1D1D1F),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1D1D1F),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search cards...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 16,
                      color: const Color(0xFF8E8E93).withValues(alpha: 0.55),
                    ),
                    prefixIcon: Icon(
                      Icons.search_outlined,
                      color: const Color(0xFF8E8E93).withValues(alpha: 0.55),
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: Icon(
                              Icons.clear,
                              color: const Color(0xFF8E8E93).withValues(alpha: 0.55),
                              size: 20,
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF1D1D1F)),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Main content
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final history = ref.watch(historyProvider);
                  return _buildHomeSections(history);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Listener(
        onPointerDown: (_) => setState(() => _isPressed = true),
        onPointerUp: (_) => setState(() => _isPressed = false),
        onPointerCancel: (_) => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: SizedBox(
            height: 56,
            width: 160,
            child: ElevatedButton(
              onPressed: _openCameraScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D1D1F),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                overlayColor: const Color(0xFF2C2C2E),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.camera_alt_outlined, size: 20, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Scan Card',
                    style: TextStyle(
                      fontFamily: '.SF Pro Text',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
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

  // Build new split sections for Recent Scans and Sample Cards
  Widget _buildHomeSections(List<HistoryItem> historyItems) {
    // Prepare lists based on search
    final searchLower = _searchQuery.toLowerCase();
    final hasQuery = _searchQuery.isNotEmpty;

    // Build a unique list of recent items (newest-first), collapsing duplicates
    // by a stable key (prefer name/email; fallback to normalized structured map)
    final seen = <String>{};
    final uniqueRecent = <HistoryItem>[];
    for (final h in historyItems) { // historyItems already newest-first
      final key = _historyKey(h);
      if (key.isEmpty) continue;
      if (seen.contains(key)) continue;
      seen.add(key);
      uniqueRecent.add(h);
    }

    // Apply search to display name
    List<HistoryItem> recent = uniqueRecent;
    if (hasQuery) {
      recent = recent
          .where((h) => _displayName(h).toLowerCase().contains(searchLower))
          .toList(growable: false);
    }

    // Filter sample cards
  List<Map<String, String>> samples = [];
    if (hasQuery) {
      samples = samples.where((card) {
        return card['name']!.toLowerCase().contains(searchLower) ||
            card['company']!.toLowerCase().contains(searchLower) ||
            card['position']!.toLowerCase().contains(searchLower);
      }).toList();
    }

    final hasAny = recent.isNotEmpty || (kDebugMode && samples.isNotEmpty);
    if (!hasAny) return _buildEmptyState();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [

        // Recent list
        if (recent.isNotEmpty)
          Column(
            children: recent.take(10).map((h) => _buildHistoryItem(h)).toList(),
          )
        else
          _buildSectionHint('Your saved scans will appear here after export'),

        const SizedBox(height: 16),

        // Sample Cards (debug only)
        if (kDebugMode) ...[
          _sectionHeader(title: 'Sample Cards'),
          ...samples.map((card) => _buildCardItem(
                name: card['name']!,
                company: card['company']!,
                position: card['position']!,
                status: card['status']!,
                avatar: card['avatar']!,
                isReal: false,
              )),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _sectionHeader({required String title, Widget? action}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1D1D1F),
            ),
          ),
          if (action != null)
            Theme(
              data: Theme.of(context).copyWith(
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1D1D1F),
                  ),
                ),
              ),
              child: action,
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: const Color(0xFF1D1D1F).withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(HistoryItem h) {
    // Show a clean card like samples: name + optional company/position from structured map
    final status = _statusFor(h);
    final heroTag = 'avatar_${h.timestamp.millisecondsSinceEpoch}';
    
    return _buildCardItem(
      name: _displayName(h),
      company: _firstNonEmpty(h.structured, const ['company', 'organization', 'org', 'employer', 'Company']),
      position: _firstNonEmpty(h.structured, const ['designation', 'title', 'role', 'position', 'job_title', 'Designation']),
      status: status,
      avatar: _getInitials(_displayName(h)),
      isReal: true, // Set to true so it can be tapped
      heroTag: heroTag,
      historyItem: h,
    );
  }

  

  String _displayName(HistoryItem h) {
    final s = h.structured;
    final name = _firstNonEmpty(s, const ['name', 'full_name', 'Name']);
    if (name.isNotEmpty) return name;
    // Fallback to something readable if name missing
    return s['email'] ?? 'Unknown';
  }

  // Build a de-dupe key for a history item: prefer name/email; else a normalized signature
  String _historyKey(HistoryItem h) {
    final s = h.structured;
    // Prefer email if present (most specific)
    final email = _firstNonEmpty(s, const ['email', 'Email']);
    if (email.isNotEmpty) return 'email:${email.trim().toLowerCase()}';
    // Next prefer name + company combo to reduce collisions for common names
    final name = _firstNonEmpty(s, const ['name', 'full_name', 'Name']);
    if (name.isNotEmpty) {
      final company = _firstNonEmpty(s, const ['company', 'organization', 'org', 'employer', 'Company']);
      if (company.isNotEmpty) {
        return 'name:${name.trim().toLowerCase()}|company:${company.trim().toLowerCase()}';
      }
      return 'name:${name.trim().toLowerCase()}';
    }
    // Fallback: normalized map signature
    final entries = s.entries
        .map((e) => MapEntry(e.key.trim().toLowerCase(), e.value.trim()))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) => '${e.key}=${e.value}').join('|');
  }

  String _firstNonEmpty(Map<String, String> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k] ?? map[k.toLowerCase()];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  // Compute status label based on timestamp age
  // New: <= 2 hours; Recent: > 2 hours and <= 12 hours; else: ''
  String _statusFor(HistoryItem h) {
    final now = DateTime.now();
    final diff = now.difference(h.timestamp);
    if (diff.inMinutes <= 120) return 'New';
    if (diff.inHours <= 12) return 'Recent';
    return '';
  }

  // Removed filename/time helpers since Recent cards no longer display these details

  Widget _buildCardItem({
    required String name,
    required String company,
    required String position,
    required String status,
    required String avatar,
    bool isReal = false,
    String? heroTag,
    HistoryItem? historyItem,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000), // ~5% black
            blurRadius: 30,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: AnimatedScale(
        scale: 1.0,
        duration: const Duration(milliseconds: 100),
        child: InkWell(
          onTap: isReal && historyItem != null 
            ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CardDetailScreen(
                    historyItem: historyItem,
                    heroTag: heroTag ?? 'avatar_default',
                  ),
                ),
              )
            : null,
          borderRadius: BorderRadius.circular(20),
          splashColor: const Color(0xFF2C2C2E).withValues(alpha: 0.08),
          highlightColor: const Color(0xFF2C2C2E).withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              children: [
                // Enhanced Avatar with Hero Animation (buttery smooth)
                heroTag != null
                    ? Hero(
                        tag: heroTag,
                        transitionOnUserGestures: true,
                        createRectTween: (begin, end) =>
                            MaterialRectCenterArcTween(begin: begin!, end: end!),
                        flightShuttleBuilder: (
                          flightContext,
                          animation,
                          direction,
                          fromContext,
                          toContext,
                        ) {
                          const beginSize = 56.0;
                          const endSize = 120.0;
                          final t = Curves.easeInOutCubic.transform(animation.value);
                          final size = direction == HeroFlightDirection.push
                              ? beginSize + (endSize - beginSize) * t
                              : endSize + (beginSize - endSize) * t;
                          return _buildAvatarCircle(avatar, size);
                        },
                        child: _buildAvatarCircle(avatar, 56),
                      )
                    : _buildAvatarCircle(avatar, 56),
            
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
                  if (company.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      company,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1D1D1F).withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                  if (position.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      position,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF1D1D1F).withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Enhanced Status Badge with monochrome scheme
            if (status.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: _getStatusGradient(status),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF2C2C2E).withValues(alpha: 0.08),
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D000000), // ~5% black
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1D1D1F),
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

  LinearGradient _getAvatarGradient(String avatar) {
    // Single monochrome gradient derived from scheme
    return const LinearGradient(
      colors: [Color(0xFF1D1D1F), Color(0xFF2C2C2E)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  LinearGradient _getStatusGradient(String status) {
    // Monochrome neutral gradient to match app scheme
    return const LinearGradient(
      colors: [Color(0xFFF9F9FA), Color(0xFFF2F2F7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  Widget _buildAvatarCircle(String initials, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: _getAvatarGradient(initials),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8 * (size / 56.0),
            offset: Offset(0, 4 * (size / 56.0)),
          ),
        ],
      ),
      child: Center(
        child: RepaintBoundary(
          child: Text(
            initials,
            style: GoogleFonts.inter(
              fontSize: 18 * (size / 56.0),
              fontWeight: FontWeight.w600,
              color: Colors.white,
              decoration: TextDecoration.none,
              decorationColor: Colors.transparent,
            ),
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
          ),
        ),
      ),
    );
  }


}
