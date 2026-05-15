import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/models.dart';
import 'compact_news_row.dart';
import '../premium_news_ui.dart';

/// Throttled precache — runs at most once per scroll index window.
class FeedImagePrecache {
  FeedImagePrecache._();

  static int? _lastStartIndex;
  static int _postsLength = 0;

  static void reset() {
    _lastStartIndex = null;
    _postsLength = 0;
  }

  /// Call from [ScrollController] listener (not [ListView.builder]).
  static void onScroll(
    BuildContext context,
    List<NewsPost> posts,
    ScrollPosition position, {
    int ahead = 4,
  }) {
    if (posts.isEmpty || !position.hasPixels) return;
    if (posts.length != _postsLength) {
      _postsLength = posts.length;
      _lastStartIndex = null;
    }

    final extent = position.viewportDimension;
    if (extent <= 0) return;

    const rowExtent = kFeedRowExtent;
    final first = (position.pixels / rowExtent).floor().clamp(0, posts.length - 1);
    if (_lastStartIndex == first) return;
    _lastStartIndex = first;

    precacheUpcomingFeedImages(context, posts, first, ahead: ahead);
  }
}

void precacheUpcomingFeedImages(
  BuildContext context,
  List<NewsPost> posts,
  int currentIndex, {
  int ahead = 4,
}) {
  if (posts.isEmpty) return;
  final end = (currentIndex + ahead + 1).clamp(0, posts.length);
  for (var i = currentIndex + 1; i < end; i++) {
    final url = premiumImageUrl(posts[i]);
    if (url.isEmpty) continue;
    precacheImage(
      CachedNetworkImageProvider(url),
      context,
    );
  }
}
