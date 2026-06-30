import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/news_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

/// Layout mode screen — choose how articles are displayed.
class LayoutModeScreen extends StatelessWidget {
  const LayoutModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final news = context.watch<NewsProvider>();
    final currentMode = news.layoutMode;

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
              'Layout Mode',
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
              child: Text(
                'Choose how articles are displayed in the feed.',
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  color: fx.textSecondary,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final modes = [
                  (label: 'Sidebar Panel', icon: Icons.view_sidebar_outlined, mode: AppLayoutMode.sidebarPanel),
                  (label: 'Carousel', icon: Icons.dashboard_outlined, mode: AppLayoutMode.carouselWheel),
                  (label: 'Dual Deck', icon: Icons.view_compact_outlined, mode: AppLayoutMode.dualDeck),
                ];
                final item = modes[index];
                final isSelected = currentMode == item.mode;
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? fx.accent.withValues(alpha: 0.12)
                        : fx.glassSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? fx.accent
                          : fx.glassBorder.withValues(alpha: 0.6),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(item.icon, color: fx.iconFg, size: 24),
                    title: Text(
                      item.label,
                      style: GoogleFonts.notoSans(
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? fx.accent : fx.title,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle_rounded, color: fx.accent)
                        : null,
                    onTap: () {
                      context.read<NewsProvider>().setLayoutMode(item.mode);
                      context.pop();
                    },
                  ),
                );
              },
              childCount: 3,
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.bottom + 20)),
        ],
      ),
    );
  }
}
