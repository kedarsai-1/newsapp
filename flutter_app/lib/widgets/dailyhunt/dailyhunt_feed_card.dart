import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../theme/dailyhunt_theme.dart';
import '../feed/compact_news_row.dart';

/// Demo feed row — local interaction state, no parent [setState] on tap.
class DailyhuntFeedCard extends StatefulWidget {
  final String imageUrl;
  final String headline;
  final String summary;
  final String sourceName;
  final DateTime publishedAt;
  final int likeCount;
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

  static String _formatCount(int n) {
    if (n < 1000) return '$n';
    if (n < 1000000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    }
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.likeCount + (_liked ? 1 : 0);
    return CompactNewsRow(
      title: widget.headline,
      summary: widget.summary,
      imageUrl: widget.imageUrl,
      metaLine: '${widget.sourceName} · ${timeago.format(widget.publishedAt)}',
      onTap: widget.onTap,
      actionBar: CompactFeedActionBar(
        actions: [
          CompactFeedAction(
            icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            label: _formatCount(count),
            color: _liked ? Colors.redAccent : const Color(0xFF666666),
            onTap: () => setState(() => _liked = !_liked),
          ),
          CompactFeedAction(
            icon: Icons.share_outlined,
            label: 'Share',
            color: const Color(0xFF666666),
            onTap: widget.onShare,
          ),
          CompactFeedAction(
            icon: _bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            label: 'Save',
            color: _bookmarked ? DailyhuntTheme.accentGreen : const Color(0xFF666666),
            onTap: () {
              setState(() => _bookmarked = !_bookmarked);
              widget.onBookmark?.call();
            },
          ),
        ],
      ),
    );
  }
}
