import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../feed/compact_news_row.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

/// Demo feed row — Dailyhunt-style layout.
class DailyhuntFeedCard extends StatefulWidget {
  final String imageUrl;
  final String headline;
  final String summary;
  final String sourceName;
  final DateTime publishedAt;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final bool liked;
  final bool bookmarked;
  final VoidCallback? onTap;
  final VoidCallback? onShare;
  final VoidCallback? onBookmark;

  const DailyhuntFeedCard({
    super.key,
    required this.imageUrl,
    required this.headline,
    required this.summary,
    required this.sourceName,
    required this.publishedAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.liked = false,
    this.bookmarked = false,
    this.onTap,
    this.onShare,
    this.onBookmark,
  });

  @override
  State<DailyhuntFeedCard> createState() => _DailyhuntFeedCardState();
}

class _DailyhuntFeedCardState extends State<DailyhuntFeedCard> {
  late bool _liked;
  late bool _bookmarked;

  @override
  void initState() {
    super.initState();
    _liked = widget.liked;
    _bookmarked = widget.bookmarked;
  }

  String? get _shortSummary {
    final s = widget.summary.trim();
    if (s.isEmpty) return null;
    return s;
  }

  String? _count(int n) => n > 0 ? '$n' : null;

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return CompactNewsRow(
      title: widget.headline,
      summary: _shortSummary,
      showSummary: false,
      imageUrl: widget.imageUrl,
      sourceName: widget.sourceName,
      timeLabel: timeago.format(widget.publishedAt),
      onTap: widget.onTap,
      footerActions: [
        CompactFeedAction(
          icon: Icons.chat_bubble_outline_rounded,
          color: fx.actionMuted,
          count: _count(widget.commentCount),
          onTap: widget.onTap,
        ),
        CompactFeedAction(
          icon: Icons.share_outlined,
          color: fx.shareAccent,
          count: _count(widget.shareCount),
          onTap: widget.onShare,
        ),
        CompactFeedAction(
          icon: Icons.more_vert,
          color: fx.actionMuted,
          onTap: widget.onBookmark,
        ),
      ],
    );
  }
}
