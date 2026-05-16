import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../providers/shorts_playback_controller.dart';
import '../../theme/app_palette.dart';
import 'shorts_feed_theme.dart';
import 'shorts_media_layer.dart';

/// Dailyhunt-style Shorts card — video on top, metadata + actions below.
class DailyhuntShortsPage extends StatefulWidget {
  final NewsPost post;
  final bool isActive;
  final bool liked;
  final bool saved;
  final bool translating;
  final String? translatedSummary;
  final Future<bool> Function() onLike;
  final Future<bool> Function() onSave;
  final VoidCallback onShare;
  final VoidCallback onTranslate;
  final VoidCallback onOpenArticle;
  final double bottomContentPadding;
  final double topChromeHeight;

  const DailyhuntShortsPage({
    super.key,
    required this.post,
    required this.isActive,
    required this.liked,
    required this.saved,
    required this.translating,
    this.translatedSummary,
    required this.onLike,
    required this.onSave,
    required this.onShare,
    required this.onTranslate,
    required this.onOpenArticle,
    required this.bottomContentPadding,
    this.topChromeHeight = 108,
  });

  @override
  State<DailyhuntShortsPage> createState() => _DailyhuntShortsPageState();
}

class _DailyhuntShortsPageState extends State<DailyhuntShortsPage> {
  late bool _liked;
  late bool _saved;

  @override
  void initState() {
    super.initState();
    _liked = widget.liked;
    _saved = widget.saved;
  }

  @override
  void didUpdateWidget(covariant DailyhuntShortsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _liked = widget.liked;
      _saved = widget.saved;
    } else {
      if (oldWidget.liked != widget.liked) _liked = widget.liked;
      if (oldWidget.saved != widget.saved) _saved = widget.saved;
    }
  }

  String get _channelName {
    final post = widget.post;
    if (post.isYoutube) return post.youtubeChannelLabel;
    return post.sourceName?.trim().isNotEmpty == true
        ? post.sourceName!.trim()
        : (post.category?.name ?? 'News');
  }

  String get _viewsLabel {
    final v = ShortsFeedTheme.formatViews(widget.post.views);
    final ago = timeago.format(widget.post.displayTime);
    if (v.isEmpty) return ago;
    return '$v · $ago';
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _handleLike() async {
    setState(() => _liked = !_liked);
    final ok = await widget.onLike();
    if (!mounted || ok) return;
    setState(() => _liked = !_liked);
  }

  Future<void> _handleSave() async {
    setState(() => _saved = !_saved);
    final ok = await widget.onSave();
    if (!mounted || ok) return;
    setState(() => _saved = !_saved);
  }

  void _onComment() {
    if (widget.post.isYoutube) {
      _openUrl(widget.post.youtubeWatchUrl);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Comments coming soon'),
        behavior: SnackBarBehavior.floating,
        width: 280,
        duration: Duration(milliseconds: 1400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isYt = widget.post.isYoutube;
    final playback = context.watch<ShortsPlaybackController>();

    return ColoredBox(
      color: ShortsFeedTheme.background,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          ShortsFeedTheme.pageHPad,
          widget.topChromeHeight,
          ShortsFeedTheme.pageHPad,
          widget.bottomContentPadding,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ShortsFeedTheme.card,
            borderRadius: BorderRadius.circular(ShortsFeedTheme.cardRadius),
            border: Border.all(color: ShortsFeedTheme.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ShortsFeedTheme.cardRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ShortsMediaLayer(
                        post: widget.post,
                        isActive: widget.isActive,
                        immersive: false,
                      ),
                      if (isYt)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: _SourcePill(
                            label: 'YouTube',
                            icon: Icons.play_circle_filled,
                            iconColor: const Color(0xFFFF0000),
                          ),
                        ),
                      if (isYt && widget.isActive)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: _MuteButton(
                            muted: playback.muted,
                            onTap: () {
                              if (playback.muted) {
                                playback.setMuted(false);
                              } else {
                                playback.setMuted(true);
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: isYt
                            ? () => _openUrl(widget.post.youtubeWatchUrl)
                            : widget.onOpenArticle,
                        child: Text(
                          widget.post.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: ShortsFeedTheme.titleStyle,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: isYt
                            ? () => _openUrl(widget.post.youtubeChannelUrl)
                            : null,
                        child: Row(
                          children: [
                            _ChannelAvatar(label: _channelName),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _channelName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: ShortsFeedTheme.title,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _viewsLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: ShortsFeedTheme.metaStyle,
                                  ),
                                ],
                              ),
                            ),
                            if (isYt)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                onPressed: () =>
                                    _openUrl(widget.post.youtubeWatchUrl),
                                icon: const Icon(
                                  Icons.open_in_new_rounded,
                                  color: ShortsFeedTheme.meta,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: ShortsFeedTheme.cardBorder),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _ActionChip(
                            icon: _liked
                                ? Icons.thumb_up_alt_rounded
                                : Icons.thumb_up_alt_outlined,
                            label: _formatCount(widget.post.likes, 'Like'),
                            active: _liked,
                            activeColor: p.primary,
                            onTap: _handleLike,
                          ),
                          _ActionChip(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: 'Comment',
                            onTap: _onComment,
                          ),
                          _ActionChip(
                            icon: Icons.share_outlined,
                            label: 'Share',
                            onTap: widget.onShare,
                          ),
                          _ActionChip(
                            icon: _saved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_outline_rounded,
                            label: 'Save',
                            active: _saved,
                            activeColor: p.primary,
                            onTap: _handleSave,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCount(int n, String fallback) {
    if (n <= 0) return fallback;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _ChannelAvatar extends StatelessWidget {
  final String label;

  const _ChannelAvatar({required this.label});

  @override
  Widget build(BuildContext context) {
    final initial = label.isNotEmpty ? label[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 18,
      backgroundColor: ShortsFeedTheme.surfaceMuted,
      child: Text(
        initial,
        style: const TextStyle(
          color: ShortsFeedTheme.title,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _SourcePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;

  const _SourcePill({
    required this.label,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MuteButton extends StatelessWidget {
  final bool muted;
  final VoidCallback onTap;

  const _MuteButton({required this.muted, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color? activeColor;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? (activeColor ?? ShortsFeedTheme.accent)
        : ShortsFeedTheme.body;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: ShortsFeedTheme.actionLabelStyle.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
