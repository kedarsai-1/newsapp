import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../providers/shorts_playback_controller.dart';
import '../../theme/app_palette.dart';
import 'shorts_feed_theme.dart';
import 'shorts_media_layer.dart';
import 'youtube_shorts_player_shared.dart';

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

  String get _timeLabel {
    final diff = DateTime.now().difference(widget.post.displayTime);
    if (diff.inMinutes < 2) return 'Just now';
    return timeago.format(widget.post.displayTime);
  }

  String? get _durationLabel {
    final sec = widget.post.youtube?.durationSeconds;
    if (sec == null || sec <= 0) return null;
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
    widget.onOpenArticle();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isYt = widget.post.isYoutube;
    final playback = context.watch<ShortsPlaybackController>();
    final topSafe = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: ShortsFeedTheme.background,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ShortsFeedTheme.maxCardWidth + ShortsFeedTheme.pageHPad * 2,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              ShortsFeedTheme.pageHPad,
              topSafe + 88,
              ShortsFeedTheme.pageHPad,
              widget.bottomContentPadding,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const metaHeight = 200.0;
                final cardW = constraints.maxWidth.clamp(0.0, ShortsFeedTheme.maxCardWidth);
                final videoHeight = (constraints.maxHeight - metaHeight)
                    .clamp(200.0, cardW * 16 / 9);

                return SizedBox(
                  width: cardW,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: ShortsFeedTheme.card,
                      borderRadius:
                          BorderRadius.circular(ShortsFeedTheme.cardRadius),
                      border: Border.all(color: ShortsFeedTheme.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(ShortsFeedTheme.cardRadius),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: videoHeight,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(ShortsFeedTheme.videoRadius),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ShortsMediaLayer(
                                    post: widget.post,
                                    isActive: widget.isActive,
                                    immersive: false,
                                  ),
                                  const DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        stops: [0.0, 0.35, 1.0],
                                        colors: [
                                          Color(0x66000000),
                                          Colors.transparent,
                                          Color(0x99000000),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isYt)
                                    const Positioned(
                                      top: 10,
                                      left: 10,
                                      child: _SourcePill(
                                        label: 'YouTube',
                                        icon: Icons.play_circle_filled,
                                        iconColor: Color(0xFFFF0000),
                                      ),
                                    ),
                                  Positioned(
                                    left: 10,
                                    bottom: 10,
                                    child: _DurationViewsPill(
                                      duration: _durationLabel,
                                      views: ShortsFeedTheme.formatViews(
                                        widget.post.views,
                                      ),
                                    ),
                                  ),
                                  if (isYt && widget.isActive)
                                    Positioned(
                                      right: 10,
                                      bottom: 10,
                                      child: _MuteButton(
                                        muted: playback.muted,
                                        onTap: () {
                                          playback.setMuted(!playback.muted);
                                        },
                                      ),
                                    ),
                                  if (isYt &&
                                      widget.isActive &&
                                      playback.muted)
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 48,
                                      child: Center(
                                        child: YoutubeUnmuteChip(
                                          muted: true,
                                          onTap: () =>
                                              playback.setMuted(false),
                                        ),
                                      ),
                                    ),
                                  if (!widget.isActive && isYt)
                                    const Center(
                                      child: _InactivePlayBadge(),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 13, 12, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: isYt
                                      ? () => _openUrl(
                                            widget.post.youtubeWatchUrl,
                                          )
                                      : widget.onOpenArticle,
                                  child: Text(
                                    widget.post.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: ShortsFeedTheme.titleStyle,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _ChannelAvatar(label: _channelName),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: isYt
                                            ? () => _openUrl(
                                                  widget.post
                                                      .youtubeChannelUrl,
                                                )
                                            : null,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    _channelName,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: GoogleFonts.notoSans(
                                                      color: ShortsFeedTheme
                                                          .title,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                if (isYt) ...[
                                                  const SizedBox(width: 4),
                                                  const Icon(
                                                    Icons.verified,
                                                    size: 14,
                                                    color: Color(0xFFAAAAAA),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              ShortsFeedTheme.channelMeta(
                                                views: widget.post.views,
                                                timeLabel: _timeLabel,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: ShortsFeedTheme.metaStyle,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    _MoreMenu(
                                      saved: _saved,
                                      liked: _liked,
                                      onSave: _handleSave,
                                      onLike: _handleLike,
                                      onTranslate: widget.onTranslate,
                                      onOpen: isYt
                                          ? () => _openUrl(
                                                widget.post.youtubeWatchUrl,
                                              )
                                          : widget.onOpenArticle,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: Row(
                                    children: [
                                      _ActionChip(
                                        icon: _liked
                                            ? Icons.thumb_up_alt_rounded
                                            : Icons.thumb_up_alt_outlined,
                                        label: _likeLabel,
                                        active: _liked,
                                        activeColor: p.primary,
                                        onTap: _handleLike,
                                      ),
                                      const SizedBox(width: 8),
                                      _ActionChip(
                                        icon: Icons.chat_bubble_outline_rounded,
                                        label: 'Comment',
                                        onTap: _onComment,
                                      ),
                                      const SizedBox(width: 8),
                                      _ActionChip(
                                        icon: Icons.share_outlined,
                                        label: 'Share',
                                        iconColor: const Color(0xFF25D366),
                                        onTap: widget.onShare,
                                      ),
                                      const SizedBox(width: 8),
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
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String get _likeLabel {
    final n = widget.post.likes;
    if (n <= 0) return 'Like';
    return ShortsFeedTheme.formatCountShort(n);
  }
}

class _InactivePlayBadge extends StatelessWidget {
  const _InactivePlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white30, width: 1.5),
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 36,
      ),
    );
  }
}

class _DurationViewsPill extends StatelessWidget {
  final String? duration;
  final String views;

  const _DurationViewsPill({this.duration, required this.views});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (duration != null && duration!.isNotEmpty) duration!,
      if (views.isNotEmpty) views,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            parts.join(' · '),
            style: ShortsFeedTheme.metaStyle.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (views.isNotEmpty) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.remove_red_eye_outlined,
              size: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  final bool saved;
  final bool liked;
  final VoidCallback onSave;
  final VoidCallback onLike;
  final VoidCallback onTranslate;
  final VoidCallback onOpen;

  const _MoreMenu({
    required this.saved,
    required this.liked,
    required this.onSave,
    required this.onLike,
    required this.onTranslate,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert, color: ShortsFeedTheme.meta, size: 22),
      color: const Color(0xFF1E1E1E),
      onSelected: (v) {
        switch (v) {
          case 'open':
            onOpen();
          case 'save':
            onSave();
          case 'like':
            onLike();
          case 'translate':
            onTranslate();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'open', child: Text('Open')),
        PopupMenuItem(
          value: 'save',
          child: Text(saved ? 'Unsave' : 'Save'),
        ),
        PopupMenuItem(
          value: 'like',
          child: Text(liked ? 'Unlike' : 'Like'),
        ),
        const PopupMenuItem(value: 'translate', child: Text('Translate')),
      ],
    );
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
        style: ShortsFeedTheme.titleStyle.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
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
            style: ShortsFeedTheme.actionLabelStyle.copyWith(
              color: Colors.white,
              fontSize: 11,
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
  final Color? iconColor;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? (activeColor ?? ShortsFeedTheme.accent)
        : (iconColor ?? ShortsFeedTheme.body);
    return Material(
      color: ShortsFeedTheme.surfaceMuted,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 5),
              Text(
                label,
                style: ShortsFeedTheme.actionLabelStyle.copyWith(
                  color: color,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
