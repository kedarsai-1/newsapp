import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/models.dart';
import '../../theme/app_palette.dart';
import '../../theme/design_tokens.dart';
import '../../utils/feed_image_url.dart';

/// Premium news card with AI summary expansion
///
/// Features:
/// - 20dp rounded corners
/// - 16:9 aspect ratio hero image
/// - Category badge on image
/// - Gradient overlay for readability
/// - Bold headline (max 2 lines)
/// - Summary (max 4 lines)
/// - AI summary expansion panel
/// - Reading time estimate
/// - Bookmark, share, listen, more actions
/// - Smooth micro-interactions
/// - Haptic feedback
/// - Light/dark theme support
class NewsCard extends StatefulWidget {
  final NewsPost post;
  final bool isExpanded;
  final VoidCallback onBookmark;
  final VoidCallback onShare;
  final VoidCallback onAIExpand;
  final VoidCallback onTap;
  final VoidCallback? onListen;
  final AppPalette? palette;

  const NewsCard({
    super.key,
    required this.post,
    required this.isExpanded,
    required this.onBookmark,
    required this.onShare,
    required this.onAIExpand,
    required this.onTap,
    this.onListen,
    this.palette,
  });

  @override
  State<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<NewsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;

  bool _isPressed = false;
  bool _isBookmarked = false;
  bool _isLiked = false; // TODO wire to actual like state via provider

  @override
  void initState() {
    super.initState();

    _expandController = AnimationController(
      duration: DesignTokens.durationMedium,
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );

    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 0.125, // 45 degrees
    ).animate(CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutBack,
    ));

    if (widget.isExpanded) {
      _expandController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(NewsCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = palette.scaffoldBackground.computeLuminance() < 0.5;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: DesignTokens.durationFast,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: DesignTokens.durationNormal,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(DesignTokens.cardBorderRadius),
            border: Border.all(
              color: palette.cardBorder.withValues(alpha: isDark ? 0.3 : 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                blurRadius: _isPressed ? 4 : DesignTokens.elevationMD,
                offset: Offset(0, _isPressed ? 2 : 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hero Image
              _buildHeroImage(palette),

              // Content Section
              Padding(
                padding: const EdgeInsets.all(DesignTokens.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category badge
                    _buildCategoryBadge(palette),

                    const SizedBox(height: DesignTokens.space12),

                    // Headline
                    _buildHeadline(palette),

                    const SizedBox(height: DesignTokens.space10),

                    // Summary
                    _buildSummary(palette),

                    const SizedBox(height: DesignTokens.space16),

                    // AI Summary Chip
                    _buildAISummaryChip(palette),

                    // AI Expansion Panel
                    if (widget.isExpanded)
                      _buildAIExpansionPanel(palette),

                    const SizedBox(height: DesignTokens.space12),

                    // Metadata
                    _buildMetadata(palette),

                    const SizedBox(height: DesignTokens.space12),

                    // Action Bar
                    _buildActionBar(palette),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroImage(AppPalette palette) {
    final url = feedImageUrlForPost(widget.post);

    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(DesignTokens.cardBorderRadius),
        topRight: Radius.circular(DesignTokens.cardBorderRadius),
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Image
          AspectRatio(
            aspectRatio: DesignTokens.cardImageAspectRatio,
            child: url.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    memCacheHeight: 720,
                    placeholder: (_, __) => Container(
                      color: palette.surface,
                      child: Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.primary,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => _buildImagePlaceholder(palette),
                  )
                : _buildImagePlaceholder(palette),
          ),

          // Gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.4),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // Play icon for video
          if (widget.post.isYoutube)
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 40,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder(AppPalette palette) {
    return Container(
      color: palette.surface,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: palette.textTertiary,
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(AppPalette palette) {
    final categoryName = widget.post.category?.name ?? 'News';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space8,
        vertical: DesignTokens.space4,
      ),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXS),
      ),
      child: Text(
        categoryName.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: palette.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildHeadline(AppPalette palette) {
    return Text(
      widget.post.title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        height: 1.3,
        color: palette.textPrimary,
        letterSpacing: -0.2,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSummary(AppPalette palette) {
    final summary = _extractSummary(widget.post);

    return Text(
      summary,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: palette.textSecondary,
        letterSpacing: 0.1,
      ),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _extractSummary(NewsPost post) {
    final raw = (post.summary ?? '').trim();
    if (raw.length >= 40) return raw;
    final body = post.body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (body.isEmpty) return '';
    return body.length > 280 ? '${body.substring(0, 277)}...' : body;
  }

  Widget _buildAISummaryChip(AppPalette palette) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onAIExpand();
          HapticFeedback.lightImpact();
        },
        borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space12,
            vertical: DesignTokens.space8,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                palette.primary.withValues(alpha: 0.1),
                palette.accentPurple.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
            border: Border.all(
              color: palette.primary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '✨',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(width: DesignTokens.space6),
              Text(
                'AI Summary',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.primary,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(width: DesignTokens.space6),
              RotationTransition(
                turns: _rotateAnimation,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: palette.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIExpansionPanel(AppPalette palette) {
    return SizeTransition(
      sizeFactor: _expandAnimation,
      child: Container(
        margin: const EdgeInsets.only(top: DesignTokens.space12),
        padding: const EdgeInsets.all(DesignTokens.space16),
        decoration: BoxDecoration(
          color: palette.scaffoldBackground.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          border: Border.all(
            color: palette.divider.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Why this matters',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: DesignTokens.space8),
            Text(
              _extractSummary(widget.post),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: DesignTokens.space16),
            Text(
              'Key facts',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: DesignTokens.space8),
            ...List.generate(3, (i) => _buildBulletPoint(palette)),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.space6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: palette.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: DesignTokens.space8),
          Expanded(
            child: Text(
              'Key fact about this news story that matters',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.4,
                color: palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata(AppPalette palette) {
    final readingTime = _calculateReadingTime(widget.post);

    return Row(
      children: [
        // Source
        Icon(
          Icons.source_outlined,
          size: 14,
          color: palette.textTertiary,
        ),
        const SizedBox(width: DesignTokens.space4),
        Text(
          widget.post.displaySourceName,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: palette.textSecondary,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(width: DesignTokens.space12),

        // Time
        Icon(
          Icons.access_time,
          size: 14,
          color: palette.textTertiary,
        ),
        const SizedBox(width: DesignTokens.space4),
        Text(
          _relativeTime(widget.post.displayTime),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: palette.textTertiary,
          ),
        ),

        const SizedBox(width: DesignTokens.space12),

        // Reading time
        Icon(
          Icons.menu_book_outlined,
          size: 14,
          color: palette.textTertiary,
        ),
        const SizedBox(width: DesignTokens.space4),
        Text(
          '$readingTime min read',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: palette.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar(AppPalette palette) {
    return Row(
      children: [
        // Bookmark
        _ActionButton(
          icon: _isBookmarked
            ? Icons.bookmark_rounded
            : Icons.bookmark_outline_rounded,
          isActive: _isBookmarked,
          activeColor: palette.primary,
          onTap: () {
            setState(() => _isBookmarked = !_isBookmarked);
            widget.onBookmark();
            HapticFeedback.lightImpact();
          },
          palette: palette,
        ),

        const SizedBox(width: DesignTokens.space4),

        // Share
        _ActionButton(
          icon: Icons.share_outlined,
          onTap: () {
            widget.onShare();
            HapticFeedback.lightImpact();
          },
          palette: palette,
        ),

        const SizedBox(width: DesignTokens.space4),

        // Listen
        _ActionButton(
          icon: Icons.headphones_outlined,
          onTap: widget.onListen,
          palette: palette,
        ),

        const Spacer(),

        // More options
        _ActionButton(
          icon: Icons.more_horiz,
          onTap: () {
            _showMoreOptions(context, palette);
            HapticFeedback.lightImpact();
          },
          palette: palette,
        ),
      ],
    );
  }

  void _showMoreOptions(BuildContext context, AppPalette palette) {
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: palette.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _buildOptionTile(
              Icons.link,
              'Copy link',
              () => Navigator.pop(context),
              palette,
            ),
            _buildOptionTile(
              Icons.open_in_new,
              'Open in browser',
              () => Navigator.pop(context),
              palette,
            ),
            _buildOptionTile(
              Icons.report_outlined,
              'Report story',
              () => Navigator.pop(context),
              palette,
            ),
            const SizedBox(height: DesignTokens.space16),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    IconData icon,
    String label,
    VoidCallback onTap,
    AppPalette palette,
  ) {
    return ListTile(
      leading: Icon(icon, color: palette.textSecondary),
      title: Text(
        label,
        style: TextStyle(color: palette.textPrimary),
      ),
      onTap: onTap,
    );
  }

  int _calculateReadingTime(NewsPost post) {
    final wordCount = (post.summary ?? post.body).split(' ').length;
    return (wordCount / 200).ceil().clamp(1, 15);
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }
}

/// Individual action button with haptic feedback
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback? onTap;
  final AppPalette palette;

  const _ActionButton({
    required this.icon,
    this.isActive = false,
    this.activeColor,
    required this.onTap,
    required this.palette,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: DesignTokens.durationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive
        ? (widget.activeColor ?? widget.palette.primary)
        : widget.palette.textSecondary;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: DesignTokens.minTouchTarget,
          height: DesignTokens.minTouchTarget,
          decoration: BoxDecoration(
            color: widget.isActive
                ? color.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
          ),
          child: Icon(
            widget.icon,
            size: DesignTokens.iconSizeMD,
            color: color,
          ),
        ),
      ),
    );
  }
}