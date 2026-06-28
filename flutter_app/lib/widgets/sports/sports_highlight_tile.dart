import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/sports_models.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

/// YouTube highlight — thumbnail only until user taps play.
class SportsHighlightTile extends StatelessWidget {
  final SportsHighlight item;
  final VoidCallback onTap;

  const SportsHighlightTile({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return SizedBox(
      width: 200,
      child: Material(
        color: fx.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.thumbnail != null && item.thumbnail!.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: item.thumbnail!,
                        fit: BoxFit.cover,
                        memCacheWidth: 480,
                        placeholder: (_, __) =>
                            ColoredBox(color: fx.imagePlaceholder),
                        errorWidget: (_, __, ___) =>
                            ColoredBox(color: fx.imagePlaceholder),
                      )
                    else
                      ColoredBox(color: fx.imagePlaceholder),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: fx.overlayScrim,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: fx.onImage,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: fx.title,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
