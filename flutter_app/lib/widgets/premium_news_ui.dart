import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../constants.dart';
import '../models/models.dart';

class PremiumScaffold extends StatelessWidget {
  final Widget child;
  final bool safeArea;

  const PremiumScaffold({
    super.key,
    required this.child,
    this.safeArea = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: GlassBackground(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _AuroraBlob(
              alignment: Alignment.topLeft,
              color: Color(0x6634D399),
              size: 230,
            ),
            const _AuroraBlob(
              alignment: Alignment(1.18, -0.45),
              color: Color(0x55C084FC),
              size: 260,
            ),
            const _AuroraBlob(
              alignment: Alignment(0.72, 1.08),
              color: Color(0x44F97316),
              size: 220,
            ),
            safeArea ? SafeArea(child: child) : child,
          ],
        ),
      ),
    );
  }
}

class _AuroraBlob extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  final double size;

  const _AuroraBlob({
    required this.alignment,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: alignment,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FrostedPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? color;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  const FrostedPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = 20,
    this.color,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: padding,
            decoration: AppCardStyles.glass(p).copyWith(
              color: color ??
                  (isDark
                      ? Colors.black.withValues(alpha: 0.46)
                      : Colors.white.withValues(alpha: 0.72)),
              borderRadius: BorderRadius.circular(radius),
              border: border ??
                  Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.black.withValues(alpha: 0.14),
                  ),
              boxShadow: boxShadow ??
                  [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.22)
                          : Colors.black.withValues(alpha: 0.10),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GradientPillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool compact;

  const GradientPillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TapScale(
      onTap: onPressed,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 18,
            vertical: compact ? 9 : 13,
          ),
          decoration: BoxDecoration(
            gradient: AppGradients.accent(p),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: p.primary.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.black, size: compact ? 16 : 18),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 12 : 14,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PremiumIconButton extends StatefulWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
  final Color? color;
  final Color? labelColor;
  final Color? panelColor;
  final bool circular;
  final Animation<double>? scale;

  const PremiumIconButton({
    super.key,
    required this.icon,
    this.label,
    this.onTap,
    this.color,
    this.labelColor,
    this.panelColor,
    this.circular = false,
    this.scale,
  });

  @override
  State<PremiumIconButton> createState() => _PremiumIconButtonState();
}

class _PremiumIconButtonState extends State<PremiumIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop;
  late final Animation<double> _popCurve;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _popCurve = CurvedAnimation(parent: _pop, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _handleTap() {
    _pop.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconOnly = FrostedPanel(
      radius: 999,
      padding: const EdgeInsets.all(12),
      color: widget.panelColor ??
          (isDark
              ? Colors.black.withValues(alpha: 0.44)
              : Colors.white.withValues(alpha: 0.74)),
      boxShadow: const [],
      child: Icon(
        widget.icon,
        color: widget.color ?? (isDark ? Colors.white : Colors.black),
        size: 22,
      ),
    );
    final content = FrostedPanel(
      radius: widget.circular ? 999 : 18,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      color: widget.panelColor ??
          (isDark
              ? Colors.black.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.68)),
      boxShadow: const [],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.icon,
            color: widget.color ?? (isDark ? Colors.white : Colors.black),
            size: 22,
          ),
          if (widget.label != null) ...[
            const SizedBox(height: 3),
            Text(
              widget.label!,
              style: TextStyle(
                color: widget.labelColor ?? p.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
    final shapedContent = widget.circular && widget.label != null
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconOnly,
              const SizedBox(height: 7),
              SizedBox(
                height: 16,
                child: Center(
                  child: Text(
                    widget.label!,
                    textScaler: TextScaler.noScaling,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.labelColor ?? p.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      shadows: const [
                        Shadow(
                            color: Color(0x66000000),
                            blurRadius: 4,
                            offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
        : (widget.circular ? iconOnly : content);
    return TapScale(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _popCurve,
        builder: (context, child) {
          final localScale = 1 + (0.12 * _popCurve.value);
          return Transform.scale(scale: localScale, child: child);
        },
        child: widget.scale == null
            ? shapedContent
            : ScaleTransition(
                scale: widget.scale!,
                child: shapedContent,
              ),
      ),
    );
  }
}

class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final Duration duration;

  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.965,
    this.duration = const Duration(milliseconds: 120),
  });

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class StoryProgressDots extends StatelessWidget {
  final int total;
  final int index;

  const StoryProgressDots({
    super.key,
    required this.total,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final visible = total.clamp(1, 12);
    return Row(
      children: List.generate(visible, (i) {
        final selected = i == index % visible;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            height: 3,
            margin: EdgeInsets.only(right: i == visible - 1 ? 0 : 5),
            decoration: BoxDecoration(
              color:
                  selected ? p.primary : Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class PremiumNewsTile extends StatelessWidget {
  final NewsPost post;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const PremiumNewsTile({
    super.key,
    required this.post,
    this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = premiumImageUrl(post);
    final source = post.category?.name ?? post.sourceName ?? 'News';
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 84,
                      height: 84,
                      child: imageUrl.isEmpty
                          ? const ColoredBox(
                              color: Color(0xFFF0F0F0),
                              child: Icon(Icons.article_outlined, size: 28),
                            )
                          : CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                              placeholder: (_, __) =>
                                  const ColoredBox(color: Color(0xFFE8E8E8)),
                              errorWidget: (_, __, ___) => const ColoredBox(
                                color: Color(0xFFF0F0F0),
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$source · ${timeago.format(post.displayTime)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF909090),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onRemove != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: onRemove,
                      icon: const Icon(Icons.close, size: 20),
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

class PremiumSkeletonCard extends StatelessWidget {
  const PremiumSkeletonCard({super.key});

  static const Color _base = Color(0xFFE0E0E0);
  static const Color _highlight = Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Shimmer.fromColors(
        baseColor: _base,
        highlightColor: _highlight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: _base,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _base,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _base,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 120,
                    decoration: BoxDecoration(
                      color: _base,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String premiumImageUrl(NewsPost post) {
  final raw = post.firstImage?.url;
  if (raw == null || raw.trim().isEmpty) return '';
  return AppConstants.imageUrlForDisplay(raw, articleReferer: post.sourceUrl);
}

String premiumSnippet(NewsPost post, {int maxLength = 360}) {
  final summary = post.summary?.replaceAll(RegExp(r'\s+'), ' ').trim();
  final base = summary?.isNotEmpty == true
      ? summary!
      : post.body.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (base.length <= maxLength) return base;
  return '${base.substring(0, maxLength).trim()}...';
}
