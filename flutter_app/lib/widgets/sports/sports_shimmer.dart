import 'package:flutter/material.dart';

import '../feed/feed_xpresso_palette.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';
import '../news_shimmer_loader.dart';

class SportsHomeShimmer extends StatelessWidget {
  const SportsHomeShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      children: [
        _bar(fx, width: 120),
        SizedBox(height: 10),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            separatorBuilder: (_, __) => SizedBox(width: 10),
            itemBuilder: (_, __) => _liveCard(fx),
          ),
        ),
        SizedBox(height: 20),
        _bar(fx, width: 100),
        SizedBox(height: 10),
        const NewsShimmerLoader(count: 4, shrinkWrap: true, physics: NeverScrollableScrollPhysics()),
      ],
    );
  }

  Widget _bar(FeedXpressoPalette fx, {required double width}) {
    return Container(
      width: width,
      height: 14,
      decoration: BoxDecoration(
        color: fx.shimmerBase,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _liveCard(FeedXpressoPalette fx) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: fx.shimmerBase,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
