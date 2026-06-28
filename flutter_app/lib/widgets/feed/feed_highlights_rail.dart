import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../models/models.dart';
import '../../utils/i18n.dart';
import '../../theme/app_palette.dart';
import 'feed_xpresso_theme.dart';

/// Horizontal breaking + trending headlines above the main feed.
class FeedHighlightsRail extends StatelessWidget {
  final List<NewsPost> breaking;
  final List<NewsPost> trending;
  final bool loading;
  final void Function(NewsPost post) onOpen;

  const FeedHighlightsRail({
    super.key,
    required this.breaking,
    required this.trending,
    required this.loading,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (!loading && breaking.isEmpty && trending.isEmpty) {
      return const SizedBox.shrink();
    }
    final fx = FeedXpressoTheme.fx(context);
    final breakingColor = context.palette.breaking;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (loading && breaking.isEmpty && trending.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (breaking.isNotEmpty)
          _Strip(
            title: I18n.t(context, 'feed_breaking'),
            titleColor: breakingColor,
            posts: breaking,
            onOpen: onOpen,
          ),
        if (trending.isNotEmpty)
          _Strip(
            title: I18n.t(context, 'feed_trending'),
            titleColor: fx.accent,
            posts: trending,
            onOpen: onOpen,
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _Strip extends StatelessWidget {
  final String title;
  final Color titleColor;
  final List<NewsPost> posts;
  final void Function(NewsPost post) onOpen;

  const _Strip({
    required this.title,
    required this.titleColor,
    required this.posts,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
        ),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final post = posts[i];
              return Material(
                color: fx.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => onOpen(post),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: fx.divider, width: 0.5),
                    ),
                    child: Text(
                      post.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fx.title,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
