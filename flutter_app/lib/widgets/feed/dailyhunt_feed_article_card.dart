import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/models.dart';
import '../../theme/app_palette.dart';
import '../premium_news_ui.dart';
import 'compact_news_row.dart';

/// API feed row — Dailyhunt layout with comment, share, and more actions.
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
  late String _imageUrl;

  @override
  void initState() {
    super.initState();
    _syncFromPost();
  }

  void _syncFromPost() {
    _liked = widget.liked;
    _saved = widget.saved;
    _imageUrl = premiumImageUrl(widget.post);
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

  String get _sourceName {
    final src = widget.post.sourceName?.trim();
    if (src != null && src.isNotEmpty) return src;
    return widget.post.category?.name ?? 'News';
  }

  static String? _countLabel(int n) {
    if (n <= 0) return null;
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  void _onImageUnavailable() {
    if (_imageUrl.trim().isEmpty || !mounted) return;
    setState(() => _imageUrl = '');
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

  void _showMoreMenu() {
    final p = context.palette;
    final fx = FeedXpressoTheme.fx(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: fx.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _liked ? Colors.red : fx.actionMuted,
              ),
              title: Text(_liked ? 'Unlike' : 'Like', style: TextStyle(color: p.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _handleLike();
              },
            ),
            ListTile(
              leading: Icon(
                _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: _saved ? fx.actionActive : fx.actionMuted,
              ),
              title: Text(_saved ? 'Remove bookmark' : 'Save', style: TextStyle(color: p.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _handleBookmark();
              },
            ),
            ListTile(
              leading: Icon(Icons.open_in_new, color: fx.actionMuted),
              title: Text('Open article', style: TextStyle(color: p.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                widget.onOpen();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final shareCount = _countLabel(widget.post.views > 0 ? widget.post.views : widget.post.likes);

    return RepaintBoundary(
      child: CompactNewsRow(
        title: widget.post.title,
        titleMaxLines: 3,
        showSummary: false,
        imageUrl: _imageUrl,
        sourceName: _sourceName,
        timeLabel: timeago.format(widget.post.displayTime),
        showVerified: true,
        onTap: widget.onOpen,
        onImageUnavailable: _onImageUnavailable,
        footerActions: [
          CompactFeedAction(
            icon: Icons.chat_bubble_outline_rounded,
            color: fx.actionMuted,
            onTap: widget.onOpen,
          ),
          CompactFeedAction(
            icon: Icons.share_outlined,
            color: fx.shareAccent,
            count: shareCount,
            onTap: widget.onShare,
          ),
          CompactFeedAction(
            icon: Icons.more_vert,
            color: fx.actionMuted,
            onTap: _showMoreMenu,
          ),
        ],
      ),
    );
  }
}
