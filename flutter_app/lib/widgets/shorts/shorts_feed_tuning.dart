import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../utils/youtube_thumb_url.dart';

/// Scroll / snap tuning for the vertical Shorts [PageView].
abstract final class ShortsFeedTuning {
  /// Only mount the active page's YouTube iframe (no hidden neighbor embeds).
  static const allowImplicitScrolling = false;

  /// Prefetch thumbnails this many pages ahead/behind the current index.
  static const precacheNeighborRadius = 2;

  static const scrollPhysics = _ShortsSnapScrollPhysics();

  /// Prefetch thumbnails for the first cards (instant paint on tab open).
  static void precacheInitialBatch(BuildContext context, List<NewsPost> posts) {
    if (posts.isEmpty) return;
    final count = posts.length.clamp(0, 5);
    for (var i = 0; i < count; i++) {
      precacheThumbnails(context, posts, i);
    }
  }

  static void precacheThumbnails(
    BuildContext context,
    List<NewsPost> posts,
    int centerIndex,
  ) {
    if (posts.isEmpty) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memW = (MediaQuery.sizeOf(context).width * dpr).round().clamp(480, 1280);

    for (var d = -precacheNeighborRadius; d <= precacheNeighborRadius; d++) {
      if (d == 0) continue;
      final i = centerIndex + d;
      if (i < 0 || i >= posts.length) continue;
      final post = posts[i];
      if (!post.isYoutube) continue;
      final vid = post.youtube?.videoId;
      if (vid == null || vid.isEmpty) continue;
      final url = YoutubeThumbUrl.high(vid);
      precacheImage(
        CachedNetworkImageProvider(url, maxWidth: memW),
        context,
      );
    }
  }
}

/// Snappy full-viewport vertical snap between Shorts pages.
class _ShortsSnapScrollPhysics extends ScrollPhysics {
  const _ShortsSnapScrollPhysics({super.parent});

  @override
  _ShortsSnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _ShortsSnapScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.32,
        stiffness: 420,
        damping: 32,
      );

  @override
  double get minFlingVelocity => 180;

  @override
  double get maxFlingVelocity => 5000;

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final page = position.pixels / position.viewportDimension;
    final target = velocity.abs() < 280
        ? page.round()
        : (velocity > 0 ? page.ceil() : page.floor());
    final maxPage =
        (position.maxScrollExtent / position.viewportDimension).round();
    final clamped = target.clamp(0, maxPage);
    final to = clamped * position.viewportDimension;
    if ((to - position.pixels).abs() < 0.5) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      to,
      velocity,
      tolerance: toleranceFor(position),
    );
  }
}
