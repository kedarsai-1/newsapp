import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/models.dart';
import '../premium_news_ui.dart';
import 'compact_news_row.dart';

/// API feed row — [RepaintBoundary] + local like/save state.
class DailyhuntFeedArticleCard extends StatefulWidget {
  final NewsPost post;
  final bool liked;
  final bool saved;
  final VoidCallback onOpen;
  final Future<bool> Function() onLike;
  final VoidCallback onShare;
  final Future<bool> Function() onBookmark;

  const DailyhuntFeedArticleCard({
    super.key,
    required this.post,
    required this.liked,
    required this.saved,
    required this.onOpen,
    required this.onLike,
    required this.onShare,
    required this.onBookmark,
  });

  @override
  State<DailyhuntFeedArticleCard> createState() => _DailyhuntFeedArticleCardState();
}

class _DailyhuntFeedArticleCardState extends State<DailyhuntFeedArticleCard> {
  late bool _liked;
  late bool _saved;
  late final String? _summary;
  late final String _metaLine;
  late final String _imageUrl;

  @override
  void initState() {
    super.initState();
    _liked = widget.liked;
    _saved = widget.saved;
    _imageUrl = premiumImageUrl(widget.post);
    _summary = _buildSummary(widget.post);
    _metaLine = _buildMeta(widget.post);
  }

  @override
  void didUpdateWidget(covariant DailyhuntFeedArticleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _liked = widget.liked;
      _saved = widget.saved;
    } else {
      if (oldWidget.liked != widget.liked) _liked = widget.liked;
      if (oldWidget.saved != widget.saved) _saved = widget.saved;
    }
  }

  static String? _buildSummary(NewsPost post) {
    final s = post.summary?.replaceAll(RegExp(r'\s+'), ' ').trim();
    final base = (s != null && s.isNotEmpty)
        ? s
        : post.body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (base.isEmpty) return null;
    if (base.length <= 58) return base;
    return '${base.substring(0, 58).trim()}…';
  }

  static String _buildMeta(NewsPost post) {
    final src = (post.sourceName?.trim().isNotEmpty == true)
        ? post.sourceName!.trim()
        : (post.category?.name ?? 'News');
    return '$src · ${timeago.format(post.displayTime)}';
  }

  Future<void> _handleLike() async {
    setState(() => _liked = !_liked);
    final ok = await widget.onLike();
    if (!mounted || ok) return;
    setState(() => _liked = !_liked);
  }

  Future<void> _handleBookmark() async {
    setState(() => _saved = !_saved);
    final ok = await widget.onBookmark();
    if (!mounted || ok) return;
    setState(() => _saved = !_saved);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CompactNewsRow(
        title: widget.post.title,
        summary: _summary,
        imageUrl: _imageUrl,
        metaLine: _metaLine,
        onTap: widget.onOpen,
        footerActions: [
          CompactFeedAction(
            icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: _liked ? CompactFeedAction.liked : CompactFeedAction.muted,
            onTap: _handleLike,
          ),
          CompactFeedAction(
            icon: Icons.share_outlined,
            color: CompactFeedAction.muted,
            onTap: widget.onShare,
          ),
          CompactFeedAction(
            icon: _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: _saved ? CompactFeedAction.saved : CompactFeedAction.muted,
            onTap: _handleBookmark,
          ),
        ],
      ),
    );
  }
}
