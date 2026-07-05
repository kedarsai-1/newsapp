import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/models.dart';
import '../../utils/feed_image_url.dart';

/// One full-screen story card with subtle 3D page-turn during vertical scroll.
///
/// Hero image applies a gentle rotateX / scale transform driven by [pageDelta]:
///  delta 0.0 → identity, +/-1.0 → max tilt (0.14 rad rotateX, 0.97 scale).
/// The parent PageView feeds per-card offsets so motion tracks finger drag.
///
/// Layout (top to bottom):
///  1. Full-bleed hero image with scrim gradient.
///  2. Bottom dark content panel:
///      Source · Time
///      Headline (2 lines)
///      Summary (6 lines)
///      Read full story →
///      Like · Share · Bookmark · More
class StoryPageCard extends StatelessWidget {
  const StoryPageCard({
    super.key,
    required this.post,
    required this.onTap,
    required this.onLike,
    required this.onBookmark,
    required this.onShare,
    required this.onMore,
    required this.liked,
    required this.bookmarked,
    required this.pageDelta,
  });

  final NewsPost post;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onBookmark;
  final VoidCallback onShare;
  final VoidCallback onMore;
  final bool liked;
  final bool bookmarked;
  final double pageDelta;

  @override
  Widget build(BuildContext context) {
    final summary = _extractSummary(post);

    // 3D transform: rotateX + scale + slight vertical shift.
    final p = pageDelta.clamp(-1.0, 1.0);
    final progress = p.abs();
    final angle = p * 0.14;
    final sc = 1.0 - (progress * 0.03);
    final shiftY = p * 16.0;

    final rotMatrix = Matrix4.identity()
      ..setEntry(3, 2, 0.001) // perspective depth
      ..rotateX(angle)
      ..setTranslationRaw(0.0, shiftY, 0.0);
    final scaleMatrix = Matrix4.diagonal3Values(sc, sc, sc);
    final matrix = rotMatrix.multiplied(scaleMatrix);

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Hero image ──────────────────────────────────────────────────
          Opacity(
            opacity: (1.0 - progress * 0.14).clamp(0.82, 1.0),
            child: Transform(
              transform: matrix,
              alignment: Alignment.center,
              child: _buildHeroImage(post),
            ),
          ),
          // ── Scrim overlay — keeps text readable on any image ────────────
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                    Color(0x0D000000), // top 0.05
                    Color(0x33000000), // +0.20
                    Color(0x77000000), // +0.47
                    Color(0xCC000000), // bottom 0.80
                    ],
                    stops: [0.00, 0.28, 0.65, 1.00],
                  ),
                ),
              ),
            ),
          ),
          // ── Play icon for video stories ──────────────────────────────────
          if (post.isYoutube)
            const Align(
              alignment: Alignment.center,
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white70,
                size: 84,
              ),
            ),
          // ── SafeArea wrapper ─────────────────────────────────────────────
          SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Bottom content panel anchored to the screen bottom.
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildContentPanel(context, summary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // CONTENT PANEL
  // ════════════════════════════════════════════════════════════════════════

  /// Bottom dark panel: source/time → headline → summary → cta → actions.
  Widget _buildContentPanel(BuildContext context, String summary) {
    final h = MediaQuery.sizeOf(context).height;
    final panelHeight = (h * 0.42).clamp(290.0, 430.0);
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 260, maxHeight: panelHeight),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: const Border(
          top: BorderSide(color: Colors.white10, width: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          // ── 1. Source + time ──────────────────────────────────────────────
          _buildSourceMeta(),
          const SizedBox(height: 12),
          // ── 2. Headline ──────────────────────────────────────────────────
          Text(
            post.title,
            style: const _HeadlineStyle(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          // ── 3. Summary ────────────────────────────────────────────────────
          const SizedBox(height: 10),
          Expanded(
            child: ScrollConfiguration(
              behavior: const _NoGlowScrollBehavior(),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Text(
                  summary.isNotEmpty ? summary : post.body.trim(),
                  style: const _SummaryStyle(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ── 4. Read full story ────────────────────────────────────────────
          const Text(
            'Full story in feed',
            style: _CtaStyle(),
          ),
          const SizedBox(height: 12),
          // ── 5. Action row ────────────────────────────────────────────────
          _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildSourceMeta() {
    return Row(
      children: [
        // Source — 13px / w600 / white 85%
        Expanded(
          child: Text(
            post.displaySourceName,
            style: const TextStyle(
              color: Color(0xFFD9D9D9),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.05,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        // Time — 12.5px / w500 / white 65%
        Text(
          _relativeTime(post.displayTime),
          style: const TextStyle(
            color: Color(0xFFA6A6A6),
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // ACTION ROW
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildActionBar() {
    return Row(
      children: [
        _ActionBtn(
          icon: liked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
          color: liked ? const Color(0xFFEF4444) : Colors.white70,
          onTap: onLike,
        ),
        const SizedBox(width: 16),
        _ActionBtn(
          icon: Icons.share_rounded,
          color: Colors.white70,
          onTap: onShare,
        ),
        const SizedBox(width: 16),
        _ActionBtn(
          icon: bookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
          color: bookmarked ? const Color(0xFFD4AF37) : Colors.white70,
          onTap: onBookmark,
        ),
        const Spacer(),
        _ActionBtn(
          icon: Icons.more_horiz_rounded,
          color: Colors.white70,
          onTap: onMore,
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // HERO IMAGE
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildHeroImage(NewsPost post) {
    final url = feedImageUrlForPost(post);
    if (url.isEmpty) {
      return Container(color: const Color(0xFF0E0E0E));
    }

    return RepaintBoundary(
      child: Container(
        color: const Color(0xFF0E0E0E),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          alignment: Alignment.topCenter,
          memCacheHeight: 1200,
          placeholder: (_, __) => const SizedBox.shrink(),
          errorWidget: (_, __, ___) => Container(color: const Color(0xFF0E0E0E)),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════════════════

  String _extractSummary(NewsPost post) {
    // Prefer post.summary if it has real content.
    final raw = (post.summary ?? '').trim();
    String text;
    if (raw.length >= 40) {
      text = raw;
    } else {
      final body = post.body.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (body.isEmpty) return '';
      text = body;
    }
    return text;
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

// ════════════════════════════════════════════════════════════════════════════
// TYPOGRAPHY CONSTANTS — single source of truth for the card
// ════════════════════════════════════════════════════════════════════════════

class _HeadlineStyle extends TextStyle {
  const _HeadlineStyle()
      : super(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          height: 1.24,
        );
}

class _SummaryStyle extends TextStyle {
  const _SummaryStyle()
      : super(
          color: const Color(0xFFD1D1D1),
          fontSize: 14.5,
          fontWeight: FontWeight.w400,
          height: 1.48,
        );
}

class _CtaStyle extends TextStyle {
  const _CtaStyle()
      : super(
          color: const Color(0xFFD4AF37),
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        );
}

// ════════════════════════════════════════════════════════════════════════════
// ACTION BUTTON — 44×44 hit target
// ════════════════════════════════════════════════════════════════════════════

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
