import 'package:flutter/material.dart';

import '../news_shimmer_loader.dart';
import 'shorts_feed_theme.dart';

/// Shorts loading skeleton — theme-aware card frame.
class ShortsCardShimmer extends StatelessWidget {
  final double topInset;

  const ShortsCardShimmer({super.key, this.topInset = 0});

  @override
  Widget build(BuildContext context) {
    final st = ShortsFeedTheme.fx(context);
    return ColoredBox(
      color: st.background,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          ShortsFeedTheme.pageHPad,
          topInset,
          ShortsFeedTheme.pageHPad,
          16,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ShortsFeedTheme.maxCardWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: st.card,
                borderRadius: BorderRadius.circular(ShortsFeedTheme.cardRadius),
                border: Border.all(color: st.cardBorder),
              ),
              child: const ClipRRect(
                borderRadius: BorderRadius.all(
                  Radius.circular(ShortsFeedTheme.cardRadius),
                ),
                child: NewsShimmerLoader(
                  count: 1,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
