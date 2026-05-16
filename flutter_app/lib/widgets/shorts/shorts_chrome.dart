import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants.dart';
import '../dailyhunt/xpresso_side_menu.dart';
import 'shorts_feed_theme.dart';

/// Segment progress for Shorts feed (above bottom nav).
class ShortsFeedProgress extends StatelessWidget {
  final int total;
  final int index;

  const ShortsFeedProgress({
    super.key,
    required this.total,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = total <= 0 ? 0.0 : (index + 1).clamp(1, total) / total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: t,
        minHeight: 3,
        backgroundColor: Colors.white.withValues(alpha: 0.15),
        color: p.primary,
      ),
    );
  }
}

/// Shorts header — minimal Dailyhunt-style chrome.
class DailyhuntShortsTopBar extends StatelessWidget {
  const DailyhuntShortsTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ShortsFeedTheme.background.withValues(alpha: 0.95),
            ShortsFeedTheme.background.withValues(alpha: 0.72),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          child: Row(
            children: [
              _TopIconButton(
                icon: Icons.menu_rounded,
                tooltip: 'Menu',
                onTap: () => XpressoSideMenu.open(context),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Shorts',
                      style: GoogleFonts.notoSans(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      AppConstants.appName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSans(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _TopIconButton(
                icon: Icons.search_rounded,
                tooltip: 'Search',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Search coming soon'),
                      behavior: SnackBarBehavior.floating,
                      width: 280,
                      duration: Duration(milliseconds: 1200),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _TopIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: ShortsFeedTheme.surfaceMuted,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}
