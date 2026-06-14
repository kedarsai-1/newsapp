import 'package:flutter/material.dart';

import '../../models/models.dart';
import 'article_youtube_player_body.dart'
    if (dart.library.html) 'article_youtube_player_body_web.dart';

/// Standalone 16:9 YouTube embed for article detail — no Shorts playback controller.
class ArticleYoutubePlayer extends StatelessWidget {
  final NewsPost post;

  const ArticleYoutubePlayer({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final videoId = post.youtube?.videoId.trim() ?? '';
    if (videoId.isEmpty) return const SizedBox.shrink();
    return ArticleYoutubePlayerBody(post: post, videoId: videoId);
  }
}
