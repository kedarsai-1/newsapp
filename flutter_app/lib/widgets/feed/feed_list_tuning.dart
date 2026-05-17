import 'package:flutter/material.dart';

import 'feed_xpresso_theme.dart';

/// Shared list scroll + cache settings for feed surfaces.
abstract final class FeedListTuning {
  static const scrollPhysics = AlwaysScrollableScrollPhysics(
    parent: ClampingScrollPhysics(),
  );

  static const double cacheExtent = 280;

  static const EdgeInsets listPadding = EdgeInsets.only(top: 6);

  /// Applies [ClampingScrollPhysics] to descendant scrollables.
  static Widget clampingScroll({required Widget child}) {
    return ScrollConfiguration(
      behavior: const _FeedScrollBehavior(),
      child: child,
    );
  }
}

class _FeedScrollBehavior extends MaterialScrollBehavior {
  const _FeedScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}

/// Const footer spinner for paginated feed lists.
class FeedListLoadingFooter extends StatelessWidget {
  const FeedListLoadingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: fx.iconFg,
          ),
        ),
      ),
    );
  }
}
