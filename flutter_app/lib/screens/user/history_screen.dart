import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/feed/feed_xpresso_theme.dart';

/// History screen — shows recently viewed articles.
/// TODO: Wire to NewsProvider.seenPosts / ArticleCache.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

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
              'History',
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
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_rounded, size: 64, color: fx.textTertiary),
                    const SizedBox(height: 16),
                    Text(
                      'No history yet',
                      style: GoogleFonts.notoSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: fx.title,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Articles you read will appear here.',
                      style: GoogleFonts.notoSans(
                        fontSize: 14,
                        color: fx.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
