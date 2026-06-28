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
import '../../widgets/feed/feed_xpresso_theme.dart';

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

  String get _channelName => widget.post.displaySourceName;

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
    final fx = context.fx;
    final p = context.palette;
    final st = ShortsFeedTheme.fx(context);
    final isYt = widget.post.isYoutube;
    final topSafe = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: st.background,
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
                final cardW = constraints.maxWidth.clamp(0.0, ShortsFeedTheme.maxCardWidth);

                return SizedBox(
                  width: cardW,
                  height: constraints.maxHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: st.card,
                      borderRadius:
                          BorderRadius.circular(ShortsFeedTheme.cardRadius),
                      border: Border.all(color: st.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: st.scrim.withValues(alpha: 0.55),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(ShortsFeedTheme.cardRadius),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: RepaintBoundary(
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
                                    IgnorePointer(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            stops: [0.0, 0.4, 1.0],
                                            colors: [
                                              fx.overlayScrim,
                                              Colors.transparent,
                                              fx.overlayScrim,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isYt)
                                      Positioned(
                                        top: 10,
                                        left: 10,
                                        child: _SourcePill(
                                          label: 'YouTube',
                                          icon: Icons.play_circle_filled,
                                          iconColor: fx.liked,
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
                                      Selector<ShortsPlaybackController, bool>(
                                        selector: (_, p) => p.muted,
                                        builder: (context, muted, _) {
                                          return Positioned(
                                            right: 10,
                                            bottom: 10,
                                            child: _MuteButton(
                                              muted: muted,
                                              onTap: () {
                                                final playback = context
                                                    .read<ShortsPlaybackController>();
                                                playback.setMuted(!muted);
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    if (!widget.isActive && isYt)
                                      Center(
                                        child: _InactivePlayBadge(),
                                      ),
                                  ],
                                ),
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
                                    style: st.titleStyle(),
                                  ),
                                ),
                                SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _ChannelAvatar(label: _channelName),
                                    SizedBox(width: 10),
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
                                                      color: st.title,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                if (isYt) ...[
                                                  SizedBox(width: 4),
                                                  Icon(
                                                    Icons.verified,
                                                    size: 14,
                                                    color: fx.meta,
                                                  ),
                                                ],
                                              ],
                                            ),
                                            SizedBox(height: 3),
                                            Text(
                                              ShortsFeedTheme.channelMeta(
                                                views: widget.post.views,
                                                timeLabel: _timeLabel,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: st.metaStyle(),
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
                                SizedBox(height: 12),
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
                                      SizedBox(width: 8),
                                      _ActionChip(
                                        icon: Icons.chat_bubble_outline_rounded,
                                        label: 'Comment',
                                        onTap: _onComment,
                                      ),
                                      SizedBox(width: 8),
                                      _ActionChip(
                                        icon: Icons.share_outlined,
                                        label: 'Share',
                                        iconColor: fx.shareAccent,
                                        onTap: widget.onShare,
                                      ),
                                      SizedBox(width: 8),
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
    final fx = context.fx;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: fx.overlayScrim,
        shape: BoxShape.circle,
        border: Border.all(color: fx.onVideoMuted, width: 1.5),
      ),
      child: Icon(
        Icons.play_arrow_rounded,
        color: fx.onImage,
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
    final fx = context.fx;
    final parts = <String>[
      if (duration != null && duration!.isNotEmpty) duration!,
      if (views.isNotEmpty) views,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fx.overlayScrim,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            parts.join(' · '),
            style: ShortsFeedTheme.metaStyle.copyWith(
              color: fx.onImage,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (views.isNotEmpty) ...[
            SizedBox(width: 6),
            Icon(
              Icons.remove_red_eye_outlined,
              size: 14,
              color: fx.onImage.withValues(alpha: 0.9),
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
    final st = ShortsFeedTheme.fx(context);
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_vert, color: st.meta, size: 22),
      color: st.card,
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
    final st = ShortsFeedTheme.fx(context);
    final initial = label.isNotEmpty ? label[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 18,
      backgroundColor: st.surfaceMuted,
      child: Text(
        initial,
        style: st.titleStyle().copyWith(
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
    final fx = context.fx;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fx.overlayScrim,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          SizedBox(width: 5),
          Text(
            label,
            style: ShortsFeedTheme.actionLabelStyle.copyWith(
              color: fx.onImage,
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
    final fx = context.fx;
    return Listener(
      onPointerDown: (_) => onTap(),
      child: Material(
        color: fx.overlayScrim,
        elevation: 4,
        shape: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color: fx.onImage,
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
    final st = ShortsFeedTheme.fx(context);
    final color = active
        ? (activeColor ?? st.accent)
        : (iconColor ?? st.body);
    return Material(
      color: st.surfaceMuted,
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
              SizedBox(width: 5),
              Text(
                label,
                style: st.actionLabelStyle().copyWith(
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
