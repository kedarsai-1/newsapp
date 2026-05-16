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
  late String _metaLine;
  late String _imageUrl;
  bool _hideCard = false;

  @override
  void initState() {
    super.initState();
    _syncFromPost();
  }

  void _syncFromPost() {
    _liked = widget.liked;
    _saved = widget.saved;
    _imageUrl = premiumImageUrl(widget.post);
    _metaLine = _buildMeta(widget.post);
    _hideCard = _imageUrl.trim().isEmpty;
  }

  @override
  void didUpdateWidget(covariant DailyhuntFeedArticleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _syncFromPost();
    } else {
      if (oldWidget.liked != widget.liked) _liked = widget.liked;
      if (oldWidget.saved != widget.saved) _saved = widget.saved;
    }
  }

  static String _buildMeta(NewsPost post) {
    final src = (post.sourceName?.trim().isNotEmpty == true)
        ? post.sourceName!.trim()
        : (post.category?.name ?? 'News');
    return '$src · ${timeago.format(post.displayTime)}';
  }

  Color _actionColor(bool isOn) =>
      isOn ? FeedXpressoTheme.actionActive : FeedXpressoTheme.actionMuted;

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

  void _onImageUnavailable() {
    if (_hideCard || !mounted) return;
    setState(() => _hideCard = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_hideCard) return const SizedBox.shrink();

    return RepaintBoundary(
      child: CompactNewsRow(
        title: widget.post.title,
        showSummary: false,
        imageUrl: _imageUrl,
        metaLine: _metaLine,
        onTap: widget.onOpen,
        onImageUnavailable: _onImageUnavailable,
        footerActions: [
          CompactFeedAction(
            icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: _actionColor(_liked),
            onTap: _handleLike,
          ),
          CompactFeedAction(
            icon: Icons.share_outlined,
            color: FeedXpressoTheme.actionMuted,
            onTap: widget.onShare,
          ),
          CompactFeedAction(
            icon: _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: _actionColor(_saved),
            onTap: _handleBookmark,
          ),
        ],
      ),
    );
  }
}
