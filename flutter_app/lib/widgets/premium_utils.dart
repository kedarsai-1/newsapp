// Premium utility functions extracted from the legacy premium_news_ui.dart

import '../models/models.dart';
import '../utils/feed_image_url.dart';
import '../utils/app_utils.dart';
import '../utils/text_truncation.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Returns the image URL for a news post (same as the original premiumImageUrl).
String premiumImageUrl(NewsPost post) => feedImageUrlForPost(post);

String _normalizeSnippetWhitespace(String text) {
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Generates a concise snippet of the post's body/summary, mirroring the original premiumSnippet.
String premiumSnippet(NewsPost post, {int maxLength = 360}) {
  final summary = _normalizeSnippetWhitespace(
    AppUtils.decodeHtmlEntities(post.summary ?? ''),
  );
  final base = summary.isNotEmpty
      ? summary
      : _normalizeSnippetWhitespace(
          AppUtils.decodeHtmlEntities(post.body),
        );
  return truncateAtWordBoundary(base, maxLength);
}
