import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/feed_language.dart';
import '../../widgets/premium_news_ui.dart';
import 'feed_xpresso_theme.dart';

/// Horizontal YouTube videos row at the top of the feed.
class FeedYoutubeRail extends StatefulWidget {
  final void Function(NewsPost post) onOpen;
  final String? language;

  const FeedYoutubeRail({
    super.key,
    required this.onOpen,
    this.language,
  });

  @override
  State<FeedYoutubeRail> createState() => _FeedYoutubeRailState();
}

class _FeedYoutubeRailState extends State<FeedYoutubeRail> {
  List<NewsPost> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FeedYoutubeRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.getFeed(
      page: 1,
      sourceTypes: const ['youtube'],
      hasVideo: true,
      days: 14,
      language: widget.language,
    );
    if (!mounted) return;

    final fetched = <NewsPost>[];
    if (res['success'] == true && res['posts'] is List) {
      for (final raw in res['posts'] as List) {
        if (raw is! Map) continue;
        try {
          final post = NewsPost.fromJson(Map<String, dynamic>.from(raw));
          if (!post.isYoutube) continue;
          if ((post.youtube?.videoId ?? '').isEmpty) continue;
          if (widget.language != null &&
              widget.language != 'all' &&
              !postMatchesFeedLanguage(post, widget.language!)) {
            continue;
          }
          fetched.add(post);
        } catch (_) {}
      }
    }

    setState(() {
      _posts = fetched.take(12).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        height: 168,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_posts.isEmpty) return const SizedBox.shrink();

    final fx = FeedXpressoTheme.fx(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: Row(
            children: [
              Icon(Icons.play_circle_outline_rounded, color: fx.accent, size: 20),
              SizedBox(width: 6),
              Text(
                'Videos & Shorts',
                style: TextStyle(
                  color: fx.iconFg,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: _posts.length,
            separatorBuilder: (_, __) => SizedBox(width: 10),
            itemBuilder: (context, index) {
              final post = _posts[index];
              final imageUrl = premiumImageUrl(post);
              return _YoutubeTile(
                title: post.title,
                channel: post.youtubeChannelLabel,
                imageUrl: imageUrl,
                isShort: post.youtube?.isShort == true,
                onTap: () => widget.onOpen(post),
              );
            },
          ),
        ),
        SizedBox(height: 6),
      ],
    );
  }
}

class _YoutubeTile extends StatelessWidget {
  final String title;
  final String channel;
  final String imageUrl;
  final bool isShort;
  final VoidCallback onTap;

  const _YoutubeTile({
    required this.title,
    required this.channel,
    required this.imageUrl,
    required this.isShort,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return SizedBox(
      width: 128,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: imageUrl.isEmpty
                          ? ColoredBox(color: fx.imagePlaceholder)
                          : CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  ColoredBox(color: fx.imagePlaceholder),
                              errorWidget: (_, __, ___) =>
                                  ColoredBox(color: fx.imagePlaceholder),
                            ),
                    ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: fx.onImage.withValues(alpha: 0.92),
                        size: 34,
                      ),
                    ),
                  ),
                  if (isShort)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: fx.overlayScrim,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'SHORT',
                          style: TextStyle(
                            color: fx.onImage,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fx.iconFg,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              Text(
                channel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fx.actionMuted, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
