import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'feed_xpresso_theme.dart';
import '../../utils/feed_failed_image_cache.dart';

export 'feed_xpresso_theme.dart' show FeedXpressoTheme, kFeedRowExtent;

/// Dailyhunt-style feed row — redesigned with modern glass morphism effects.
class CompactNewsRow extends StatefulWidget {
  final String title;
  final String? summary;
  final String? imageUrl;
  final String metaLine;
  final String? sourceName;
  final String? timeLabel;
  final bool showVerified;
  final VoidCallback? onTap;
  final Widget? trailing;
  final List<CompactFeedAction>? footerActions;
  final int titleMaxLines;
  final int summaryMaxLines;
  final bool showDivider;
  final bool showSummary;
  final bool showPlayOverlay;
  final VoidCallback? onImageUnavailable;

  const CompactNewsRow({
    super.key,
    required this.title,
    this.summary,
    this.imageUrl,
    this.metaLine = '',
    this.sourceName,
    this.timeLabel,
    this.showVerified = true,
    this.onTap,
    this.trailing,
    this.footerActions,
    this.titleMaxLines = FeedXpressoTheme.titleMaxLines,
    this.summaryMaxLines = FeedXpressoTheme.summaryMaxLines,
    this.showDivider = true,
    this.showSummary = false,
    this.showPlayOverlay = false,
    this.onImageUnavailable,
  });

  @override
  State<CompactNewsRow> createState() => _CompactNewsRowState();
}

class _CompactNewsRowState extends State<CompactNewsRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memW = (MediaQuery.sizeOf(context).width * dpr).round().clamp(480, 1400);
    final url = widget.imageUrl?.trim() ?? '';
    final hasSummary =
        widget.showSummary && widget.summary != null && widget.summary!.trim().isNotEmpty;
    final actions = widget.footerActions;
    final hasActions = actions != null && actions.isNotEmpty;

    return Semantics(
      button: true,
      label: widget.title,
      hint: 'Double tap to read the full article',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 100),
            scale: _pressed ? 0.98 : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              decoration: BoxDecoration(
                color: _pressed
                    ? fx.glassSurface.withValues(alpha: 0.8)
                    : fx.glassSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _pressed
                      ? fx.accent.withValues(alpha: 0.3)
                      : fx.glassBorder,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: fx.accent.withValues(alpha: _pressed ? 0.08 : 0.04),
                    blurRadius: _pressed ? 12 : 8,
                    offset: Offset(0, _pressed ? 6 : 4),
                  ),
                ],
              ),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (url.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    child: _HeroImage(
                      fx: fx,
                      url: url,
                      memCacheWidth: memW,
                      showPlayOverlay: widget.showPlayOverlay,
                      onUnavailable: widget.onImageUnavailable,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.title,
                        maxLines: widget.titleMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                          letterSpacing: -0.3,
                          color: fx.title,
                        ),
                      ),
                      if (hasSummary) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.summary!.trim(),
                          maxLines: widget.summaryMaxLines.clamp(1, 2),
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                            color: fx.summary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _MetaRow(
                              fx: fx,
                              metaLine: widget.metaLine,
                              sourceName: widget.sourceName,
                              timeLabel: widget.timeLabel,
                              showVerified: widget.showVerified,
                            ),
                          ),
                          if (hasActions)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: actions,
                            )
                          else if (widget.trailing != null)
                            widget.trailing!,
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

class _MetaRow extends StatelessWidget {
  final FeedXpressoPalette fx;
  final String metaLine;
  final String? sourceName;
  final String? timeLabel;
  final bool showVerified;

  const _MetaRow({
    required this.fx,
    required this.metaLine,
    this.sourceName,
    this.timeLabel,
    required this.showVerified,
  });

  @override
  Widget build(BuildContext context) {
    final src = sourceName?.trim();
    final time = timeLabel?.trim();
    if (src != null && src.isNotEmpty) {
      return Row(
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    fx.accent.withValues(alpha: 0.15),
                    fx.accentTertiary.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: fx.accent.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      src,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: fx.accent,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  if (showVerified) ...[
                    const SizedBox(width: 3),
                    Icon(
                      Icons.verified,
                      size: 12,
                      color: fx.verifiedBadge,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (time != null && time.isNotEmpty) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.access_time_rounded,
              size: 12,
              color: fx.meta,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                time,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: fx.meta,
                ),
              ),
            ),
          ],
        ],
      );
    }
    return Text(
      metaLine,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.notoSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: fx.meta,
      ),
    );
  }
}

class _HeroImage extends StatefulWidget {
  final FeedXpressoPalette fx;
  final String url;
  final int memCacheWidth;
  final bool showPlayOverlay;
  final VoidCallback? onUnavailable;

  const _HeroImage({
    required this.fx,
    required this.url,
    required this.memCacheWidth,
    this.showPlayOverlay = false,
    this.onUnavailable,
  });

  @override
  State<_HeroImage> createState() => _HeroImageState();
}

class _HeroImageState extends State<_HeroImage> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.url.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onUnavailable?.call();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _HeroImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _failed = false;
      if (widget.url.trim().isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onUnavailable?.call();
        });
      }
    }
  }

  void _reportUnavailable() {
    if (_failed) return;
    _failed = true;
    FeedFailedImageCache.markFailed(widget.url);
    widget.onUnavailable?.call();
  }

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final url = widget.url.trim();
    if (url.isEmpty || _failed) {
      return _imageFrame(
        fx: widget.fx,
        child: AspectRatio(
          aspectRatio: FeedXpressoTheme.imageAspectRatio,
          child: ColoredBox(
            color: fx.imagePlaceholder,
            child: const Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 32,
                color: Colors.white38,
              ),
            ),
          ),
        ),
      );
    }

    return _imageFrame(
      fx: widget.fx,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: FeedXpressoTheme.imageFit,
        alignment: FeedXpressoTheme.imageAlignment,
        memCacheWidth: widget.memCacheWidth,
        fadeInDuration: const Duration(milliseconds: 160),
        fadeOutDuration: Duration.zero,
        placeholder: (_, __) => AspectRatio(
          aspectRatio: FeedXpressoTheme.imageAspectRatio,
          child: ColoredBox(color: fx.imagePlaceholder),
        ),
        errorWidget: (_, __, ___) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _reportUnavailable());
          return AspectRatio(
            aspectRatio: FeedXpressoTheme.imageAspectRatio,
            child: ColoredBox(color: fx.imagePlaceholder),
          );
        },
        imageBuilder: (context, imageProvider) {
          return AspectRatio(
            aspectRatio: FeedXpressoTheme.imageAspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image(
                  image: imageProvider,
                  fit: FeedXpressoTheme.imageFit,
                  alignment: FeedXpressoTheme.imageAlignment,
                  width: double.infinity,
                  height: double.infinity,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.55, 1.0],
                      colors: [
                        Colors.transparent,
                        fx.overlayScrim,
                      ],
                    ),
                  ),
                ),
                if (widget.showPlayOverlay)
                  Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      size: 56,
                      color: fx.onImage.withValues(alpha: 0.92),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Widget _imageFrame({required FeedXpressoPalette fx, required Widget child}) {
  final isDark = fx.background.computeLuminance() < 0.2;
  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: FeedXpressoTheme.imageBorderRadius,
      border: Border.all(
        color: fx.glassBorder.withValues(alpha: 0.8),
        width: 0.5,
      ),
      boxShadow: [
        BoxShadow(
          color: fx.accent.withValues(alpha: isDark ? 0.15 : 0.08),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: FeedXpressoTheme.imageBorderRadius,
      child: child,
    ),
  );
}

/// Engagement action — icon with optional count, modern glass morphism style.
class CompactFeedAction extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? count;
  /// Accessibility label describing what this action does.
  final String? semanticLabel;

  const CompactFeedAction({
    super.key,
    required this.icon,
    required this.color,
    this.onTap,
    this.count,
    this.semanticLabel,
  });

  static Color muted(BuildContext context) =>
      FeedXpressoTheme.fx(context).actionMuted;
  static Color active(BuildContext context) =>
      FeedXpressoTheme.fx(context).actionActive;
  static Color shareAccent(BuildContext context) =>
      FeedXpressoTheme.fx(context).shareAccent;

  @override
  State<CompactFeedAction> createState() => _CompactFeedActionState();
}

class _CompactFeedActionState extends State<CompactFeedAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final label = widget.count?.trim();
    final showCount = label != null && label.isNotEmpty;

    return Semantics(
      button: true,
      label: widget.semanticLabel ?? 'Action button',
      hint: widget.onTap != null ? 'Double tap to activate' : null,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        scale: _pressed ? 0.92 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _pressed
                ? widget.color.withValues(alpha: 0.15)
                : fx.glassSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _pressed
                  ? widget.color.withValues(alpha: 0.3)
                  : fx.glassBorder,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _pressed ? 0.12 : 0.05),
                blurRadius: _pressed ? 6 : 4,
                offset: Offset(0, _pressed ? 3 : 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: _pressed ? widget.color : widget.color.withValues(alpha: 0.85),
              ),
              if (showCount) ...[
                const SizedBox(width: 5),
                Text(
                  label,
                  style: GoogleFonts.notoSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _pressed ? widget.color : widget.color.withValues(alpha: 0.85),
                    height: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }
}
