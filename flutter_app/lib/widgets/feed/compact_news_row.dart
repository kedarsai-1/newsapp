import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'feed_xpresso_theme.dart';
import '../glass_card.dart';
import '../../constants.dart';

export 'feed_xpresso_theme.dart' show FeedXpressoTheme, kFeedRowExtent;

/// Dailyhunt-style feed row — premium glassmorphic floating capsule card.
class CompactNewsRow extends StatelessWidget {
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
    this.onImageUnavailable,
  });

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memW = (MediaQuery.sizeOf(context).width * dpr).round().clamp(480, 1400);
    final url = imageUrl?.trim() ?? '';
    final hasSummary =
        showSummary && summary != null && summary!.trim().isNotEmpty;
    final actions = footerActions;
    final hasActions = actions != null && actions.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          padding: const EdgeInsets.all(12),
          radius: 14,
          enableBlur: false,
          borderColor: GlassColors.borderWhite,
          color: GlassColors.surfaceWhite,
          enableAnimation: true,
          boxShadow: [
            BoxShadow(
              color: GlassColors.isLightMode
                  ? Colors.black.withOpacity(0.04)
                  : Colors.black.withOpacity(0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (url.isNotEmpty)
                _HeroImage(
                  fx: fx,
                  url: url,
                  memCacheWidth: memW,
                  onUnavailable: onImageUnavailable,
                ),
              if (url.isNotEmpty)
                const SizedBox(height: FeedXpressoTheme.imageToTitleGap),
              Text(
                title,
                maxLines: titleMaxLines,
                overflow: TextOverflow.ellipsis,
                style: fx.titleStyle,
              ),
              if (hasSummary) ...[
                const SizedBox(height: 5),
                Text(
                  summary!.trim(),
                  maxLines: summaryMaxLines.clamp(1, 2),
                  overflow: TextOverflow.ellipsis,
                  style: fx.summaryStyle,
                ),
              ],
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _MetaRow(
                      fx: fx,
                      metaLine: metaLine,
                      sourceName: sourceName,
                      timeLabel: timeLabel,
                      showVerified: showVerified,
                    ),
                  ),
                  if (hasActions)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions,
                    )
                  else if (trailing != null)
                    trailing!,
                ],
              ),
            ],
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
            child: Text(
              src,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: fx.sourceStyle,
            ),
          ),
          if (showVerified) ...[
            const SizedBox(width: 3),
            Icon(
              Icons.verified,
              size: 14,
              color: fx.verifiedBadge,
            ),
          ],
          if (time != null && time.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                '·',
                style: fx.metaStyle.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            Flexible(
              child: Text(
                time,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: fx.metaStyle,
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
      style: fx.metaStyle,
    );
  }
}

class _HeroImage extends StatefulWidget {
  final FeedXpressoPalette fx;
  final String url;
  final int memCacheWidth;
  final VoidCallback? onUnavailable;

  const _HeroImage({
    required this.fx,
    required this.url,
    required this.memCacheWidth,
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
          child: ColoredBox(color: fx.imagePlaceholder),
        ),
      );
    }

    return _imageFrame(
      fx: widget.fx,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: FeedXpressoTheme.imageFit,
        alignment: FeedXpressoTheme.imageAlignment,
        memCacheWidth: kIsWeb ? null : widget.memCacheWidth,
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
                        widget.fx.background.computeLuminance() < 0.2
                            ? const Color(0x40000000)
                            : const Color(0x26000000),
                      ],
                    ),
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
      border: isDark
          ? null
          : Border.all(
              color: fx.divider.withValues(alpha: 0.9),
              width: 0.5,
            ),
      boxShadow: isDark
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: fx.accent.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
    ),
    child: ClipRRect(
      borderRadius: FeedXpressoTheme.imageBorderRadius,
      child: child,
    ),
  );
}

/// Engagement action — icon with optional count (Dailyhunt comment / share style).
class CompactFeedAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? count;

  const CompactFeedAction({
    super.key,
    required this.icon,
    required this.color,
    this.onTap,
    this.count,
  });

  static Color muted(BuildContext context) =>
      FeedXpressoTheme.fx(context).actionMuted;
  static Color active(BuildContext context) =>
      FeedXpressoTheme.fx(context).actionActive;
  static Color shareAccent(BuildContext context) =>
      FeedXpressoTheme.fx(context).shareAccent;

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final label = count?.trim();
    final showCount = label != null && label.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: fx.background.computeLuminance() < 0.2
                  ? fx.iconSurface.withValues(alpha: 0.85)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: fx.divider.withValues(alpha: 0.85),
                width: 0.5,
              ),
              boxShadow: fx.background.computeLuminance() < 0.2
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: color),
                if (showCount) ...[
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
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
