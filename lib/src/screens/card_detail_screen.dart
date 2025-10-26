import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import '../models/history_item.dart';

class CardDetailScreen extends StatelessWidget {
  final HistoryItem historyItem;
  final String heroTag;

  const CardDetailScreen({
    super.key,
    required this.historyItem,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final name = historyItem.structured['name']?.toString().trim() ?? 'Unknown';
    final company = historyItem.structured['company']?.toString().trim() ?? '';
    final position = historyItem.structured['job_title']?.toString().trim() ??
        historyItem.structured['title']?.toString().trim() ??
        historyItem.structured['position']?.toString().trim() ?? '';
    final email = historyItem.structured['email']?.toString().trim() ?? '';
    final phone = historyItem.structured['phone']?.toString().trim() ?? '';
    final website = historyItem.structured['website']?.toString().trim() ?? '';
    final address = historyItem.structured['address']?.toString().trim() ?? '';
    final notes = historyItem.structured['personal_thoughts']?.toString().trim() ?? '';
    
    final initials = _getInitials(name);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: CustomScrollView(
        slivers: [
          // App Bar with Hero Avatar
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF1D1D1F),
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color.fromARGB(255, 44, 44, 47), Color.fromARGB(255, 42, 42, 46)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40), // Account for status bar
                    // Hero Avatar - matches the one from Recent cards
                    Hero(
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
                        return _buildAvatarCircle(initials, size);
                      },
                      child: _buildAvatarCircle(initials, 120),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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
                          color: Colors.white.withValues(alpha: 0.8),
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
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          
          // Contact Details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contact Information Card
                  _buildSection(
                    title: 'Contact Information',
                    children: [
                      if (email.isNotEmpty)
                        _buildContactTile(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: email,
                          onTap: () => _sendEmail(context, email),
                        ),
                      if (phone.isNotEmpty)
                        _buildContactTile(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: phone,
                          onTap: () => _callPhone(phone),
                        ),
                      if (website.isNotEmpty)
                        _buildContactTile(
                          icon: Icons.language_outlined,
                          label: 'Website',
                          value: website,
                          onTap: () => _openWebsite(context, website),
                        ),
                      if (address.isNotEmpty)
                        _buildContactTile(
                          icon: Icons.location_on_outlined,
                          label: 'Address',
                          value: address,
                          onTap: () => _copyValue(address),
                        ),
                    ],
                  ),
                  
                  // Personal Notes (if available)
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSection(
                      title: 'Personal Notes',
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
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
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  // Scan Information
                  const SizedBox(height: 20),
                  _buildSection(
                    title: 'Scan Information',
                    children: [
                      _buildInfoTile(
                        label: 'Scanned',
                        value: _formatDate(historyItem.timestamp),
                      ),
                      if (historyItem.destination.path.isNotEmpty)
                        _buildInfoTile(
                          label: 'Saved to',
                          value: historyItem.destination.path.split('/').last,
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 40), // Bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarCircle(String initials, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1D1D1F), Color(0xFF2C2C2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
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

  Widget _buildSection({required String title, required List<Widget> children}) {
    if (children.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1D1D1F),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildContactTile({
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1D1F).withValues(alpha: 0.08),
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
                        color: const Color(0xFF1D1D1F).withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1D1D1F),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: const Color(0xFF1D1D1F).withValues(alpha: 0.3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1D1D1F).withValues(alpha: 0.6),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1D1D1F),
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
    // Note: In a real app, you'd show a snackbar here
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
}