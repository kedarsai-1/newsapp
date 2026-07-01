import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/models.dart';
import '../../services/history_service.dart';
import '../../utils/feed_image_url.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

/// History screen — shows recently viewed articles.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final bottomInset = FeedXpressoTheme.feedBottomInset(context);
    final history = context.watch<HistoryService>();

    if (!history.loaded) {
      return Scaffold(
        backgroundColor: fx.background,
        appBar: _buildAppBar(context, fx, history),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final posts = history.allPosts;

    return Scaffold(
      backgroundColor: fx.background,
      appBar: _buildAppBar(context, fx, history),
      body: posts.isEmpty
          ? _buildEmptyState(fx)
          : _buildHistoryList(context, fx, posts, bottomInset),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, dynamic fx, HistoryService history) {
    return AppBar(
      toolbarHeight: 52,
      backgroundColor: fx.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: fx.title,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: fx.iconFg, size: 22),
        onPressed: () => context.pop(),
      ),
      title: Text(
        'History',
        style: GoogleFonts.notoSans(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: fx.title,
        ),
      ),
      actions: [
        if (history.count > 0)
          Semantics(
            label: 'Clear history',
            button: true,
            child: IconButton(
              tooltip: 'Clear history',
              icon: Icon(Icons.delete_outline_rounded,
                  color: fx.iconFg, size: 22),
              onPressed: () => _confirmClear(context, fx, history),
            ),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: fx.divider),
      ),
    );
  }

  Widget _buildEmptyState(dynamic fx) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    fx.accent.withValues(alpha: 0.15),
                    fx.accentTertiary.withValues(alpha: 0.15),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history_rounded,
                  size: 48, color: fx.accent.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 24),
            Text(
              'No history yet',
              style: GoogleFonts.notoSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: fx.title,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Articles you read will appear here.',
              style: GoogleFonts.notoSans(
                fontSize: 14,
                color: fx.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Semantics(
              label: 'Explore feed',
              button: true,
              child: GestureDetector(
                onTap: () => context.go('/feed'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [fx.accent, fx.accentTertiary],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: fx.accent.withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.explore_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Explore Feed',
                        style: GoogleFonts.notoSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, dynamic fx,
      List<NewsPost> posts, double bottomInset) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 20),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return _HistoryTile(
          post: post,
          fx: fx,
          onTap: () => context.push('/article/${post.id}'),
          onRemove: () {
            HapticFeedback.lightImpact();
            context.read<HistoryService>().clearHistory();
          },
        );
      },
    );
  }

  void _confirmClear(
      BuildContext context, dynamic fx, HistoryService history) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: fx.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Clear History?',
          style: GoogleFonts.notoSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: fx.title,
          ),
        ),
        content: Text(
          'This will remove all your reading history. This action cannot be undone.',
          style: GoogleFonts.notoSans(
            fontSize: 14,
            color: fx.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.notoSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: fx.textSecondary,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              history.clearHistory();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('History cleared'),
                  behavior: SnackBarBehavior.floating,
                  width: 200,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: fx.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Clear',
              style: GoogleFonts.notoSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single history list tile — compact card style.
class _HistoryTile extends StatelessWidget {
  final NewsPost post;
  final dynamic fx;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _HistoryTile({
    required this.post,
    required this.fx,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final imgUrl = feedImageUrlForPost(post);

    return Semantics(
      label: 'History: ${post.title}',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: fx.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: fx.glassBorder.withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Thumbnail
              if (imgUrl != null && imgUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imgUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: fx.imagePlaceholder,
                        child:
                            Icon(Icons.image_rounded,
                                color: fx.iconFgMuted, size: 28),
                      ),
                    ),
                  ),
                ),

              // Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: imgUrl != null ? 0 : 14,
                    right: 8,
                    top: 12,
                    bottom: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (post.category != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: fx.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            post.category!.name,
                            style: GoogleFonts.notoSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: fx.accent,
                            ),
                          ),
                        ),
                      Text(
                        post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: fx.title,
                          height: 1.35,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            post.displaySourceName,
                            style: GoogleFonts.notoSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: fx.textTertiary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text('·',
                              style:
                                  TextStyle(color: fx.textTertiary, fontSize: 11)),
                          const SizedBox(width: 4),
                          Text(
                            timeago.format(post.displayTime),
                            style: GoogleFonts.notoSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: fx.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Remove button
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Semantics(
                  label: 'Remove from history',
                  button: true,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Remove',
                    onPressed: onRemove,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: fx.iconFgMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
