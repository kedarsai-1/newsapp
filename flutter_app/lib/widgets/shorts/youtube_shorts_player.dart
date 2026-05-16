import 'package:flutter/material.dart';

import '../../models/models.dart';
import 'youtube_shorts_player_body.dart'
    if (dart.library.html) 'youtube_shorts_player_body_web.dart';

/// Thumbnail-first YouTube shorts player (iframe on mobile, external open on web).
class YoutubeShortsPlayer extends StatelessWidget {
  final NewsPost post;
  final bool isActive;
  final bool immersive;

  const YoutubeShortsPlayer({
    super.key,
    required this.post,
    required this.isActive,
    this.immersive = true,
  });

  @override
  Widget build(BuildContext context) {
    return YoutubeShortsPlayerBody(
      post: post,
      isActive: isActive,
      immersive: immersive,
    );
  }
}
