import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import '../models/history_item.dart';
import '../providers/history_provider.dart';
import '../services/csv_service.dart';
import '../services/xlsx_service.dart';
import '../utils/schema.dart';
import '../../core/routes.dart';

class CardDetailScreen extends ConsumerStatefulWidget {
  final HistoryItem historyItem;
  final String heroTag;

  const CardDetailScreen({
    super.key,
    required this.historyItem,
    required this.heroTag,
  });

  @override
  ConsumerState<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends ConsumerState<CardDetailScreen> 
    with TickerProviderStateMixin {
  bool _isDeleting = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.elasticOut),
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.historyItem;
    final name = item.structured['name']?.toString().trim() ?? 'Unknown';
    final company = item.structured['company']?.toString().trim() ?? '';
    final position = item.structured['job_title']?.toString().trim() ??
        item.structured['title']?.toString().trim() ??
        item.structured['position']?.toString().trim() ?? '';
    final email = item.structured['email']?.toString().trim() ?? '';
    final phone = item.structured['phone']?.toString().trim() ?? '';
    final website = item.structured['website']?.toString().trim() ?? '';
    final address = item.structured['address']?.toString().trim() ?? '';
    final notes = item.structured['personal_thoughts']?.toString().trim() ?? '';
    
    final initials = _getInitials(name);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF2F2F7),
              Color(0xFFE5E5EA),
              Color(0xFFD1D1D6),
            ],
          ),
        ),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) => CustomScrollView(
            slivers: [
              // iOS Premium App Bar with Glassmorphism
              SliverAppBar(
                expandedHeight: 360,
                floating: false,
                pinned: true,
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE5E5EA),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, 
                                       color: Color(0xFF1D1D1F), size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE5E5EA),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline, 
                                         color: Colors.redAccent, size: 18),
                          onPressed: _isDeleting ? null : () => _confirmAndDeleteCard(context),
                        ),
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      // Glassmorphism background
                      Positioned.fill(
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withOpacity(0.8),
                                  Colors.white.withOpacity(0.6),
                                ],
                              ),
                            ),
                          ),
                          ),
                        ),
                      ),
                      // Profile content with premium styling
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 40,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Premium Avatar with glow effect
                                _buildPremiumAvatar(initials, 130),
                                const SizedBox(height: 24),
                                // Name with SF Pro Rounded style
                                Text(
                                  name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1D1D1F),
                                    letterSpacing: 0.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (company.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    company,
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF1D1D1F).withOpacity(0.8),
                                      letterSpacing: 0.1,
                                      height: 1.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                                if (position.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    position,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                      color: const Color(0xFF1D1D1F).withOpacity(0.7),
                                      letterSpacing: 0.1,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Premium Contact Details with Glassmorphism
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Contact Information Section
                        _buildPremiumSection(
                          title: 'Contact Information',
                          children: [
                            if (email.isNotEmpty)
                              _buildPremiumContactTile(
                                icon: Icons.mail_outline,
                                label: 'Email',
                                value: email,
                                onTap: () => _sendEmail(context, email),
                              ),
                            if (phone.isNotEmpty)
                              _buildPremiumContactTile(
                                icon: Icons.phone_outlined,
                                label: 'Phone',
                                value: phone,
                                onTap: () => _callPhone(phone),
                              ),
                            if (website.isNotEmpty)
                              _buildPremiumContactTile(
                                icon: Icons.language_outlined,
                                label: 'Website',
                                value: website,
                                onTap: () => _openWebsite(context, website),
                              ),
                            if (address.isNotEmpty)
                              _buildPremiumContactTile(
                                icon: Icons.location_on_outlined,
                                label: 'Address',
                                value: address,
                                onTap: () => _copyValue(address),
                              ),
                          ],
                        ),
                        
                        // Personal Notes Section
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _buildPremiumSection(
                            title: 'Personal Notes',
                            children: [
                              _buildPremiumNotesTile(notes),
                            ],
                          ),
                        ],
                        
                        // Scan Information Section
                        const SizedBox(height: 20),
                        _buildPremiumSection(
                          title: 'Scan Information',
                          children: [
                            _buildPremiumInfoTile(
                              label: 'Scanned',
                              value: _formatDate(item.timestamp),
                            ),
                            if (item.destination.path.isNotEmpty)
                              _buildPremiumInfoTile(
                                label: 'Saved to',
                                value: item.destination.path.split('/').last,
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 60), // Bottom padding for safe area
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Premium floating action button during deletion
      floatingActionButton: _isDeleting
          ? FloatingActionButton(
              onPressed: () {},
              backgroundColor: const Color(0xFF1D1D1F),
              child: const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildPremiumAvatar(String initials, double size) {
    return Hero(
      tag: widget.heroTag,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1D1D1F), Color(0xFF2C2C2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFE5E5EA),
            width: 1,
          ),
          boxShadow: [
            // Soft shadow
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8 * (size / 56.0),
              spreadRadius: 0,
              offset: Offset(0, 4 * (size / 56.0)),
            ),
          ],
        ),
        child: Center(
          child: Text(
            initials,
            style: GoogleFonts.inter(
              fontSize: 18 * (size / 56.0),
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumSection({required String title, required List<Widget> children}) {
    if (children.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1D1D1F),
              letterSpacing: -0.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE5E5EA),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildPremiumContactTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _copyValue(value);
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedScale(
          scale: 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                // Premium icon container
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1D1F).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF1D1D1F),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1D1D1F).withOpacity(0.6),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1D1D1F),
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: const Color(0xFF1D1D1F).withOpacity(0.3),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumNotesTile(String notes) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E5E7),
          width: 1,
        ),
      ),
      child: Text(
        notes,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF1D1D1F),
          height: 1.5,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _buildPremiumInfoTile({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1D1D1F).withOpacity(0.6),
              letterSpacing: 0.1,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1D1D1F),
              letterSpacing: -0.1,
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _copyValue(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  void _callPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _sendEmail(BuildContext context, String email) async {
    // Prefer Gmail app when possible, with graceful fallbacks
    try {
      if (Platform.isIOS) {
        // Try Gmail iOS URL scheme
        final gmailUri = Uri.parse('googlegmail://co?to=${Uri.encodeComponent(email)}');
        if (await canLaunchUrl(gmailUri)) {
          await launchUrl(gmailUri, mode: LaunchMode.externalApplication);
          return;
        }
        // Fallback to default mail app
        final mailto = Uri(scheme: 'mailto', path: email);
        if (await canLaunchUrl(mailto)) {
          await launchUrl(mailto, mode: LaunchMode.externalApplication);
          return;
        }
      } else if (Platform.isAndroid) {
        // Attempt to open Gmail compose via intent targeting Gmail package
        // Prefer Gmail app if available
        try {
          final gmailIntent = AndroidIntent(
            action: 'android.intent.action.SENDTO',
            data: Uri(scheme: 'mailto', path: email).toString(),
            package: 'com.google.android.gm',
          );
          await gmailIntent.launch();
          return;
        } catch (_) {/* continue */}
        // Fallback: generic chooser for SENDTO mailto
        try {
          final genericIntent = AndroidIntent(
            action: 'android.intent.action.SENDTO',
            data: Uri(scheme: 'mailto', path: email).toString(),
          );
          await genericIntent.launch();
          return;
        } catch (_) {/* continue */}
      }
    } catch (_) {
      // ignore and try fallbacks
    }

    // Last resort: open Gmail web compose (ideally in Chrome via _openWebsiteInChrome)
    final gmailWeb = Uri.parse('https://mail.google.com/mail/?view=cm&to=${Uri.encodeComponent(email)}');
    await _openWebsiteInChrome(context, gmailWeb.toString());
  }

  void _openWebsite(BuildContext context, String website) async {
    await _openWebsiteInChrome(context, website);
  }

  Future<void> _openWebsiteInChrome(BuildContext context, String website) async {
    String url = website.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    try {
      if (Platform.isIOS) {
        // Try Chrome on iOS via URL scheme
        final uri = Uri.parse(url);
        final isHttps = uri.scheme == 'https';
        final chromeScheme = isHttps ? 'googlechromes' : 'googlechrome';
        final chromeUrl = uri.replace(scheme: chromeScheme);
        if (await canLaunchUrl(chromeUrl)) {
          await launchUrl(chromeUrl, mode: LaunchMode.externalApplication);
          return;
        }
        // Fallback to default browser
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } else if (Platform.isAndroid) {
        // Try Chrome first
        try {
          final chromeIntent = AndroidIntent(
            action: 'android.intent.action.VIEW',
            data: url,
            package: 'com.android.chrome',
          );
          await chromeIntent.launch();
          return;
        } catch (_) {/* continue */}
        // Fallback: generic VIEW intent
        try {
          final genericIntent = AndroidIntent(
            action: 'android.intent.action.VIEW',
            data: url,
          );
          await genericIntent.launch();
          return;
        } catch (_) {/* continue */}
      }
    } catch (_) {
      // ignore and try generic launcher below
    }

    // Generic fallback
    final generic = Uri.parse(url);
    if (await canLaunchUrl(generic)) {
      await launchUrl(generic, mode: LaunchMode.externalApplication);
      return;
    }
    _showSnack(context, 'No app found to open this link');
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _confirmAndDeleteCard(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Card'),
        content: const Text('Are you sure you want to delete this card permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteCard(context);
    }
  }

  Future<void> _deleteCard(BuildContext context) async {
    if (_isDeleting) return;
    setState(() => _isDeleting = true);

    // Normalize card data to strict schema to match sheet row values
    final normalized = normalizeToStrictSchema(
      Map<String, dynamic>.from(widget.historyItem.structured),
      fillMissingWithNone: true,
    );

    // First: try deleting from spreadsheet quickly; upon success, delete from history
    final dest = widget.historyItem.destination;
    final String path = dest.path;

    Future<bool> _deleteFromSheetOnce() async {
      if (path.isEmpty) return true; // nothing to delete in sheet
      try {
        if (dest.type.name == 'csv') {
          final file = File(path);
          if (!await file.exists()) return true; // treat as success
          return await CSVService().removeRowMatchingNormalized(file, normalized);
        } else {
          return await XlsxService().removeRowMatchingNormalized(
            filePath: path,
            normalized: normalized,
            sheetName: dest.sheetName ?? 'Sheet1',
          );
        }
      } catch (_) {
        return false;
      }
    }

    Future<bool> _withOneRetry(Future<bool> Function() op) async {
      final ok = await op();
      if (ok) return true;
      return await op();
    }

    try {
      final sheetOk = await _withOneRetry(_deleteFromSheetOnce);
      if (!sheetOk) {
        _showSnack(context, 'Could not delete from sheet. Please try again.');
        setState(() => _isDeleting = false);
        return;
      }

      // Now delete from local history/backend with one retry
      Future<bool> _deleteHistory() async {
        try {
          await ref.read(historyProvider.notifier).deleteById(widget.historyItem.id);
          return true;
        } catch (_) {
          return false;
        }
      }
      final backOk = await _withOneRetry(_deleteHistory);
      if (!backOk) {
        _showSnack(context, 'Could not delete local entry. Please try again.');
        setState(() => _isDeleting = false);
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card deleted successfully!'), backgroundColor: Colors.green),
      );
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }
}