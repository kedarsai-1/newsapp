import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants.dart';
import '../../utils/i18n.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

/// Privacy Policy screen with modern glass design.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/feed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);

    return Scaffold(
      backgroundColor: fx.background,
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
              decoration: BoxDecoration(
                color: fx.background,
                border: Border(
                  bottom: BorderSide(color: fx.divider, width: 1),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: fx.iconFg),
                    onPressed: () => _handleBack(context),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: fx.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.shield_outlined, color: fx.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          I18n.t(context, 'privacy_title'),
                          style: GoogleFonts.notoSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: fx.title,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Last updated: Jan 2026',
                          style: GoogleFonts.notoSans(
                            fontSize: 11,
                            color: fx.actionMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Introduction Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          fx.accent.withValues(alpha: 0.1),
                          fx.accentTertiary.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: fx.glassBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: fx.accent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.privacy_tip_outlined, color: fx.accent, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Your privacy matters to us. Read how ${AppConstants.appName} protects and uses your data.',
                            style: GoogleFonts.notoSans(
                              fontSize: 13,
                              color: fx.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Data Collection Section
                  _PolicySection(
                    icon: Icons.storage_rounded,
                    title: I18n.t(context, 'privacy_collect_title'),
                    body: I18n.t(context, 'privacy_collect_body'),
                    fx: fx,
                  ),
                  const SizedBox(height: 20),

                  // Data Usage Section
                  _PolicySection(
                    icon: Icons.analytics_outlined,
                    title: I18n.t(context, 'privacy_use_title'),
                    body: I18n.t(context, 'privacy_use_body'),
                    fx: fx,
                  ),
                  const SizedBox(height: 20),

                  // Contact Section
                  _PolicySection(
                    icon: Icons.contact_mail_outlined,
                    title: I18n.t(context, 'privacy_contact_title'),
                    body: I18n.t(context, 'privacy_contact_body'),
                    fx: fx,
                  ),
                  const SizedBox(height: 32),

                  // Footer
                  Center(
                    child: Text(
                      '© 2026 ${AppConstants.appName}. All rights reserved.',
                      style: GoogleFonts.notoSans(
                        fontSize: 11,
                        color: fx.actionMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final dynamic fx;

  const _PolicySection({
    required this.icon,
    required this.title,
    required this.body,
    required this.fx,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fx.glassSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fx.glassBorder),
        boxShadow: [
          BoxShadow(
            color: fx.heroShadow,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [fx.accent, fx.accentTertiary],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.notoSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: fx.title,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: GoogleFonts.notoSans(
              fontSize: 13,
              color: fx.textSecondary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
