import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/models.dart';
import '../../services/video_playlist.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

/// Video playlist screen showing saved watch-later videos - Modern glass design.
class VideoPlaylistScreen extends StatefulWidget {
  const VideoPlaylistScreen({super.key});

  @override
  State<VideoPlaylistScreen> createState() => _VideoPlaylistScreenState();
}

class _VideoPlaylistScreenState extends State<VideoPlaylistScreen> {
  List<NewsPost> _videos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    setState(() => _loading = true);
    try {
      final videos = await VideoPlaylistService.getAll();
      if (mounted) {
        setState(() {
          _videos = videos;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) {
        final fx = FeedXpressoTheme.fx(ctx);
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: fx.glassSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: fx.glassBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: fx.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: fx.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_sweep_rounded, color: fx.error, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'Clear playlist?',
                style: GoogleFonts.notoSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: fx.title,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Remove all videos from your watch later list?',
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  color: fx.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _GlassButton(
                      label: 'Cancel',
                      onTap: () => Navigator.pop(ctx, false),
                      fx: fx,
                      secondary: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GradientButton(
                      label: 'Clear',
                      onTap: () => Navigator.pop(ctx, true),
                      fx: fx,
                      color: fx.error,
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom),
            ],
          ),
        );
      },
    );
    if (confirmed == true) {
      await VideoPlaylistService.clear();
      await _loadPlaylist();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final isDark = FeedXpressoTheme.isDark(context);

    return Scaffold(
      backgroundColor: fx.background,
      appBar: AppBar(
        backgroundColor: fx.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: fx.iconFg),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/feed');
            }
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [fx.accent, fx.accentTertiary],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.play_circle_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Watch Later',
              style: GoogleFonts.notoSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: fx.title,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          if (_videos.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep_outlined, color: fx.iconFg),
              tooltip: 'Clear all',
              onPressed: _clearAll,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: fx.accent, strokeWidth: 2),
            )
          : _videos.isEmpty
              ? EmptyState(
                  icon: Icons.video_library_outlined,
                  title: 'No videos saved yet',
                  subtitle: 'Videos you save for later will appear here.',
                  buttonLabel: 'Browse videos',
                  onButtonTap: () => context.go('/shorts'),
                  dark: isDark,
                )
              : RefreshIndicator(
                  color: fx.accent,
                  onRefresh: _loadPlaylist,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _videos.length,
                    itemBuilder: (context, index) {
                      final post = _videos[index];
                      return _VideoCard(
                        post: post,
                        onTap: () => context.go('/article/${post.id}'),
                      );
                    },
                  ),
                ),
    );
  }
}

class _VideoCard extends StatefulWidget {
  final NewsPost post;
  final VoidCallback onTap;

  const _VideoCard({required this.post, required this.onTap});

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final durationSec = widget.post.youtube?.durationSeconds;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: fx.glassSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: fx.glassBorder),
            boxShadow: [
              BoxShadow(
                color: fx.heroShadow,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Video thumbnail
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (widget.post.hasImages && widget.post.firstImage != null)
                        CachedNetworkImage(
                          imageUrl: widget.post.firstImage!.url,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: fx.iconSurface),
                          errorWidget: (_, __, ___) => Container(
                            color: fx.iconSurface,
                            child: Icon(Icons.video_library_rounded, size: 48, color: fx.textSecondary),
                          ),
                        )
                      else
                        Container(
                          color: fx.accent.withValues(alpha: 0.1),
                          child: Icon(Icons.play_circle_outline, size: 56, color: fx.accent),
                        ),
                      // Play button overlay
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [fx.accent, fx.accentTertiary],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: fx.accent.withValues(alpha: 0.4),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                        ),
                      ),
                      // Duration badge
                      if (durationSec != null && durationSec > 0)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              durationSec >= 60
                                  ? '${(durationSec / 60).ceil()} min'
                                  : '${durationSec}s',
                              style: GoogleFonts.notoSans(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.post.title,
                      style: GoogleFonts.notoSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: fx.title,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.post.sourceName != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: fx.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.post.sourceName!,
                              style: GoogleFonts.notoSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: fx.accent,
                              ),
                            ),
                          ),
                          if (widget.post.language != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              widget.post.language!.toUpperCase(),
                              style: GoogleFonts.notoSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: fx.textHint,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final dynamic fx;
  final bool secondary;

  const _GlassButton({
    required this.label,
    required this.onTap,
    required this.fx,
    this.secondary = false,
  });

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: widget.fx.iconSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.fx.divider),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: GoogleFonts.notoSans(
                color: widget.fx.iconFg,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final dynamic fx;
  final Color? color;

  const _GradientButton({
    required this.label,
    required this.onTap,
    required this.fx,
    this.color,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? widget.fx.accent;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withValues(alpha: 0.75)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: GoogleFonts.notoSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
