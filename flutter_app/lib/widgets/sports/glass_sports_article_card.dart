import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/models.dart';
import '../../constants.dart';
import '../../widgets/premium_utils.dart';
import '../glass_card.dart';

/// A premium, state-of-the-art frosted glass article card for sports stories.
/// Built with custom specularity highlights, soft shadows, elastic touch scale,
/// and image zoom-in hover effects.
class GlassSportsArticleCard extends StatefulWidget {
  final NewsPost post;
  final bool liked;
  final bool saved;
  final VoidCallback onOpen;
  final Future<bool> Function() onLike;
  final VoidCallback onShare;
  final Future<bool> Function() onBookmark;

  const GlassSportsArticleCard({
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
  State<GlassSportsArticleCard> createState() => _GlassSportsArticleCardState();
}

class _GlassSportsArticleCardState extends State<GlassSportsArticleCard>
    with SingleTickerProviderStateMixin {
  late bool _liked;
  late bool _saved;
  late String _imageUrl;
  bool _isPressed = false;
  bool _isHovered = false;

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
  void didUpdateWidget(covariant GlassSportsArticleCard oldWidget) {
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
    return widget.post.category?.name ?? 'Sports';
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F172A).withOpacity(0.9),
      elevation: 0,
      barrierColor: Colors.black.withOpacity(0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(
                _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _liked ? Colors.redAccent : Colors.white70,
              ),
              title: Text(_liked ? 'Unlike Story' : 'Like Story',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _handleLike();
              },
            ),
            ListTile(
              leading: Icon(
                _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: _saved ? GlassColors.accentGreen : Colors.white70,
              ),
              title: Text(_saved ? 'Remove Bookmark' : 'Save Story',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _handleBookmark();
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded, color: Colors.white70),
              title: const Text('Open Source Article',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                widget.onOpen();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _imageUrl.trim().isNotEmpty;
    final snippet = premiumSnippet(widget.post, maxLength: 160);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onOpen,
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : (_isHovered ? 1.015 : 1.00),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: GlassCard(
              enableAnimation: false,
              enableBlur: false,
              radius: 18,
              padding: EdgeInsets.zero,
              color: Colors.white.withOpacity(0.05),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Article Image Frame with smooth scale/zoom
                  if (hasImage)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      child: AspectRatio(
                        aspectRatio: 1.88,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AnimatedScale(
                              scale: _isHovered ? 1.06 : 1.00,
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                              child: CachedNetworkImage(
                                imageUrl: _imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, _) => Container(
                                  color: Colors.white12,
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: GlassColors.accentGreen,
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, _, __) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) => _onImageUnavailable());
                                  return Container(color: Colors.white12);
                                },
                              ),
                            ),
                            // Ambient overlay gradient to blend image into the glass card
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: const [0.6, 1.0],
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.7),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 2. Card Content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          widget.post.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.35,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (snippet.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          // Snippet description text
                          Text(
                            snippet,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white.withOpacity(0.65),
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Meta line & actions
                        Row(
                          children: [
                            // Verified Source & Time
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _sourceName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: GlassColors.accentGreenLight,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.verified,
                                    size: 13,
                                    color: GlassColors.accentGreen,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '·  ${timeago.format(widget.post.displayTime, locale: 'en_short')}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withOpacity(0.45),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Engagement pill buttons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _GlassActionButton(
                                  icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  activeColor: Colors.redAccent,
                                  isActive: _liked,
                                  onTap: _handleLike,
                                ),
                                const SizedBox(width: 8),
                                _GlassActionButton(
                                  icon: Icons.share_outlined,
                                  activeColor: GlassColors.info,
                                  isActive: false,
                                  onTap: widget.onShare,
                                ),
                                const SizedBox(width: 8),
                                _GlassActionButton(
                                  icon: Icons.more_horiz_rounded,
                                  activeColor: Colors.white,
                                  isActive: false,
                                  onTap: _showMoreMenu,
                                ),
                              ],
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
      ),
    );
  }
}

class _GlassActionButton extends StatefulWidget {
  final IconData icon;
  final Color activeColor;
  final bool isActive;
  final VoidCallback onTap;

  const _GlassActionButton({
    required this.icon,
    required this.activeColor,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_GlassActionButton> createState() => _GlassActionButtonState();
}

class _GlassActionButtonState extends State<_GlassActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.00,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isActive
                ? widget.activeColor.withOpacity(0.18)
                : Colors.white.withOpacity(0.06),
            border: Border.all(
              color: widget.isActive
                  ? widget.activeColor.withOpacity(0.40)
                  : Colors.white.withOpacity(0.12),
              width: 0.8,
            ),
          ),
          child: Icon(
            widget.icon,
            size: 15.5,
            color: widget.isActive ? widget.activeColor : Colors.white70,
          ),
        ),
      ),
    );
  }
}
