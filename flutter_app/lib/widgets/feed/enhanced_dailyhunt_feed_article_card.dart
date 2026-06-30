import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/models.dart';
import '../../widgets/feed/feed_xpresso_palette_enhanced.dart';
import '../../widgets/feed/feed_image_cache.dart';
import 'feed_xpresso_theme.dart';

/// Enhanced Dailyhunt-style feed row with modern design, improved typography, and better visual hierarchy.
class EnhancedDailyhuntFeedArticleCard extends StatefulWidget {
  final NewsPost post;
  final bool liked;
  final bool saved;
  final bool isRead;
  final VoidCallback onOpen;
  final Future<bool> Function() onLike;
  final VoidCallback onShare;
  final Future<bool> Function() onBookmark;

  const EnhancedDailyhuntFeedArticleCard({
    super.key,
    required this.post,
    required this.liked,
    required this.saved,
    this.isRead = false,
    required this.onOpen,
    required this.onLike,
    required this.onShare,
    required this.onBookmark,
  });

  @override
  State<EnhancedDailyhuntFeedArticleCard> createState() => _EnhancedDailyhuntFeedArticleCardState();
}

class _EnhancedDailyhuntFeedArticleCardState extends State<EnhancedDailyhuntFeedArticleCard> {
  late bool _liked;
  late bool _saved;
  late List<String> _imageCandidates;
  late int _imageCandidateIndex;
  late String _imageUrl;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _syncFromPost();
  }

  void _syncFromPost() {
    _liked = widget.liked;
    _saved = widget.saved;
    _imageCandidates = [widget.post.firstImage?.url].whereType<String>().where((url) => url.trim().isNotEmpty).toList();
    _imageCandidateIndex = 0;
    _imageUrl = _imageCandidates.isNotEmpty ? _imageCandidates.first : '';
  }

  @override
  void didUpdateWidget(covariant EnhancedDailyhuntFeedArticleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _syncFromPost();
    } else {
      if (oldWidget.liked != widget.liked) _liked = widget.liked;
      if (oldWidget.saved != widget.saved) _saved = widget.saved;
    }
  }

  String get _sourceName => widget.post.displaySourceName;

  static String? _countLabel(int n) {
    if (n <= 0) return null;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) {
      final k = n / 1000;
      // Show "1k" not "1.0k"
      return k == k.roundToDouble() ? '${k.round()}k' : '${k.toStringAsFixed(1)}k';
    }
    return '$n';
  }

  void _onImageUnavailable() {
    if (!mounted) return;
    final next = _imageCandidateIndex + 1;
    if (next < _imageCandidates.length) {
      setState(() {
        _imageCandidateIndex = next;
        _imageUrl = _imageCandidates[next];
      });
      return;
    }
    if (_imageUrl.trim().isEmpty) return;
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
    final palette = FeedXpressoPaletteEnhanced.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.sheet,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: palette.glassBorder, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: palette.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Actions',
                style: GoogleFonts.notoSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Action items
            _ActionTile(
              icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              iconColor: _liked ? palette.liked : palette.actionMuted,
              label: _liked ? 'Unlike' : 'Like this article',
              onTap: () {
                Navigator.pop(ctx);
                _handleLike();
              },
              palette: palette,
            ),
            _ActionTile(
              icon: _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              iconColor: _saved ? palette.accent : palette.actionMuted,
              label: _saved ? 'Remove from saved' : 'Save for later',
              onTap: () {
                Navigator.pop(ctx);
                _handleBookmark();
              },
              palette: palette,
            ),
            _ActionTile(
              icon: Icons.open_in_new_rounded,
              iconColor: palette.actionMuted,
              label: 'Read full article',
              onTap: () {
                Navigator.pop(ctx);
                widget.onOpen();
              },
              palette: palette,
            ),
            _ActionTile(
              icon: Icons.share_rounded,
              iconColor: palette.shareAccent,
              label: 'Share article',
              onTap: () {
                Navigator.pop(ctx);
                widget.onShare();
              },
              palette: palette,
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = FeedXpressoPaletteEnhanced.dark;
    final shareCount = _countLabel(widget.post.views > 0 ? widget.post.views : widget.post.likes);
    final fx = FeedXpressoTheme.fx(context);

    return Opacity(
      opacity: widget.isRead ? 0.65 : 1.0,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onOpen,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 100),
          scale: _isPressed ? 0.98 : 1.0,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: palette.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: palette.glassBorder.withValues(alpha: 0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: palette.heroShadow,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero image with enhanced design
                if (_imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: Stack(
                      children: [
                        _EnhancedHeroImage(
                          url: _imageUrl,
                          fx: fx,
                          onUnavailable: _onImageUnavailable,
                          showPlayOverlay: widget.post.isYoutube,
                        ),
                        // Gradient overlay for better text contrast
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.4),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // YouTube play button
                        if (widget.post.isYoutube)
                          Center(
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: palette.accent,
                                size: 36,
                              ),
                            ),
                          ),
                        // Category badge
                        Positioned(
                          top: 12,
                          left: 12,
                          child: _CategoryBadge(
                            post: widget.post,
                            palette: palette,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Content area
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Headline with enhanced typography
                      Text(
                        widget.post.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                          letterSpacing: -0.3,
                          color: palette.title,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Meta info with enhanced design
                      Row(
                        children: [
                          // Source info
                          Expanded(
                            child: Row(
                              children: [
                                // Source avatar
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        palette.brandGradientStart,
                                        palette.brandGradientEnd,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _sourceName.isNotEmpty
                                          ? _sourceName[0].toUpperCase()
                                          : 'N',
                                      style: GoogleFonts.notoSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              _sourceName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.notoSans(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: palette.textSecondary,
                                              ),
                                            ),
                                          ),
                                          if ((widget.post as dynamic).sourceVerified == true) ...[
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.verified,
                                              size: 14,
                                              color: palette.verifiedBadge,
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        timeago.format(widget.post.displayTime),
                                        style: GoogleFonts.notoSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: palette.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Action buttons
                          _EnhancedFeedAction(
                            icon: Icons.chat_bubble_outline_rounded,
                            color: palette.actionMuted,
                            onTap: widget.onOpen,
                            palette: palette,
                          ),
                          _EnhancedFeedAction(
                            icon: Icons.share_outlined,
                            color: palette.shareAccent,
                            count: shareCount,
                            onTap: widget.onShare,
                            palette: palette,
                          ),
                          _EnhancedFeedAction(
                            icon: Icons.more_vert_rounded,
                            color: palette.actionMuted,
                            onTap: _showMoreMenu,
                            palette: palette,
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
}

class _EnhancedHeroImage extends StatefulWidget {
  final String url;
  final FeedXpressoPalette fx;
  final VoidCallback? onUnavailable;
  final bool showPlayOverlay;

  const _EnhancedHeroImage({
    required this.url,
    required this.fx,
    this.onUnavailable,
    this.showPlayOverlay = false,
  });

  @override
  State<_EnhancedHeroImage> createState() => _EnhancedHeroImageState();
}

class _EnhancedHeroImageState extends State<_EnhancedHeroImage> {
  bool _failed = false;

  void _reportUnavailable() {
    if (_failed) return;
    _failed = true;
    widget.onUnavailable?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.trim().isEmpty || _failed) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: widget.fx.imagePlaceholder,
          child: Center(
            child: Icon(
              Icons.image_outlined,
              size: 48,
              color: widget.fx.meta,
            ),
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: widget.url.trim(),
      fit: BoxFit.cover,
      alignment: Alignment.center,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: widget.fx.imagePlaceholder,
          child: Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(widget.fx.accent),
              ),
            ),
          ),
        ),
      ),
      errorWidget: (_, __, ___) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _reportUnavailable());
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: widget.fx.imagePlaceholder,
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                size: 48,
                color: widget.fx.meta,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final NewsPost post;
  final FeedXpressoPaletteEnhanced palette;

  const _CategoryBadge({
    required this.post,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final category = post.category?.name ?? '';
    final gradient = FeedXpressoPaletteEnhanced.categoryGradientEnhanced(category);

    if (category.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient.$2,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.$2[0].withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        category,
        style: GoogleFonts.notoSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _EnhancedFeedAction extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? count;
  final FeedXpressoPaletteEnhanced palette;

  const _EnhancedFeedAction({
    required this.icon,
    required this.color,
    this.onTap,
    this.count,
    required this.palette,
  });

  @override
  State<_EnhancedFeedAction> createState() => _EnhancedFeedActionState();
}

class _EnhancedFeedActionState extends State<_EnhancedFeedAction> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        scale: _isPressed ? 0.85 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.palette.glassSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.palette.glassBorder,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.color,
              ),
              if (widget.count != null) ...[
                const SizedBox(width: 5),
                Text(
                  widget.count!,
                  style: GoogleFonts.notoSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: widget.color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final FeedXpressoPaletteEnhanced palette;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.notoSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: palette.textTertiary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}