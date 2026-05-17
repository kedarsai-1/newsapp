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
    final st = ShortsFeedTheme.fx(context);
    final t = total <= 0 ? 0.0 : (index + 1).clamp(1, total) / total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: t,
        minHeight: 3,
        backgroundColor: st.onVideo.withValues(alpha: 0.15),
        color: st.accent,
      ),
    );
  }
}

/// Shorts header — theme-aware chrome over video.
class DailyhuntShortsTopBar extends StatelessWidget {
  const DailyhuntShortsTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final st = ShortsFeedTheme.fx(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            st.background.withValues(alpha: 0.95),
            st.background.withValues(alpha: 0.72),
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
                st: st,
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Shorts',
                      style: GoogleFonts.notoSans(
                        color: st.chromeFg,
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
                        color: st.chromeFgMuted,
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
                st: st,
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
  final ShortsFeedPalette st;

  const _TopIconButton({
    required this.icon,
    required this.onTap,
    required this.st,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: st.surfaceMuted,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: st.iconOnChrome, size: 22),
        ),
      ),
    );
    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}
