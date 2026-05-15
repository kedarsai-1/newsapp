import 'package:flutter/material.dart';

/// Shared list scroll + cache settings for feed surfaces.
abstract final class FeedListTuning {
  static const scrollPhysics = AlwaysScrollableScrollPhysics(
    parent: ClampingScrollPhysics(),
  );

  /// Pixels of off-screen layout cache (balance memory vs jank).
  static const double cacheExtent = 240;

  static const EdgeInsets listPadding = EdgeInsets.zero;
}
