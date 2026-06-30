import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/feed/feed_xpresso_theme.dart';

/// Terms of service screen.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  static const _url = 'https://example.com/terms-of-service';

  Future<void> _openLink(BuildContext context) async {
    final uri = Uri.parse(_url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the link')),
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
              'Terms of Service',
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
                    'Last updated: June 2026',
                    style: GoogleFonts.notoSans(
                      fontSize: 13,
                      color: fx.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome to NewsApp. By using our service, you agree to the following terms:',
                    style: GoogleFonts.notoSans(
                      fontSize: 15,
                      color: fx.title,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    fx: fx,
                    title: '1. Use of Service',
                    children: [
                      _Bullet(fx, 'You may use this app for personal, non-commercial purposes only.'),
                      _Bullet(fx, 'You must not misuse, abuse, or attempt to disrupt the service.'),
                    ],
                  ),
                  _Section(
                    fx: fx,
                    title: '2. Content',
                    children: [
                      _Bullet(fx, 'News content is provided for informational purposes.'),
                      _Bullet(fx, 'We strive for accuracy but do not guarantee it.'),
                    ],
                  ),
                  _Section(
                    fx: fx,
                    title: '3. Accounts',
                    children: [
                      _Bullet(fx, 'Keep your account credentials secure.'),
                      _Bullet(fx, 'Notify us immediately of any unauthorized access.'),
                    ],
                  ),
                  _Section(
                    fx: fx,
                    title: '4. Termination',
                    children: [
                      _Bullet(fx, 'We may suspend or terminate access at our discretion.'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'For the full terms, please visit our website.',
                    style: GoogleFonts.notoSans(
                      fontSize: 13,
                      color: fx.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _openLink(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: fx.accent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Read Full Terms',
                      style: GoogleFonts.notoSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final dynamic fx;
  final String title;
  final List<Widget> children;

  const _Section({
    required this.fx,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.notoSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: fx.title,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final dynamic fx;
  final String text;

  const _Bullet(this.fx, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: GoogleFonts.notoSans(color: fx.accent, fontSize: 15)),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.notoSans(
                fontSize: 14,
                color: fx.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
