import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/feed/feed_xpresso_theme.dart';

/// Contact us screen — support, feedback, and suggestions.
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  static const _email = 'support@newsapp.example.com';

  Future<void> _sendEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _email,
      query: 'subject=NewsApp Feedback',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email app')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return Scaffold(
      backgroundColor: fx.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            toolbarHeight: 52,
            backgroundColor: fx.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            foregroundColor: fx.title,
            title: Text(
              'Contact Us',
              style: GoogleFonts.notoSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: fx.title,
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: fx.iconFg, size: 22),
              onPressed: () => context.pop(),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, thickness: 1, color: fx.divider),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'We\'d love to hear from you. Reach out with questions, feedback, or suggestions.',
                    style: GoogleFonts.notoSans(
                      fontSize: 15,
                      color: fx.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ContactCard(
                    fx: fx,
                    icon: Icons.email_rounded,
                    iconColor: const Color(0xFF6366F1),
                    title: 'Email us',
                    subtitle: _email,
                    onTap: () => _sendEmail(context),
                  ),
                  const SizedBox(height: 12),
                  _ContactCard(
                    fx: fx,
                    icon: Icons.share_rounded,
                    iconColor: const Color(0xFF10B981),
                    title: 'Share feedback',
                    subtitle: 'Tell us what you think',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Feedback form coming soon!'),
                          behavior: SnackBarBehavior.floating,
                          width: 280,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.bottom + 20)),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final dynamic fx;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactCard({
    required this.fx,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: fx.glassSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: fx.glassBorder, width: 1),
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          title: Text(
            title,
            style: GoogleFonts.notoSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: fx.title,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.notoSans(
              fontSize: 13,
              color: fx.textSecondary,
            ),
          ),
          trailing: Icon(Icons.chevron_right_rounded, color: fx.iconFgMuted, size: 20),
        ),
      ),
    );
  }
}
