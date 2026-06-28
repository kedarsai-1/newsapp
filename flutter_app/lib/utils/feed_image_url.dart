import '../constants.dart';
import '../models/models.dart';
import 'feed_failed_image_cache.dart';

/// Logos, favicons, and site placeholders — not valid feed hero images.
bool isUnusableFeedImageUrl(String? url) {
  if (url == null) return true;
  final u = url.trim().toLowerCase();
  if (u.isEmpty) return true;
  if (u.contains('clearbit.com')) return true;
  if (u.contains('/s2/favicons')) return true;
  if (u.contains('favicon') ||
      u.contains('/logo') ||
      u.contains('/logos/') ||
      u.contains('sprite') ||
      RegExp(r'[/_.-]icon\.(jpg|jpeg|png|webp|gif)').hasMatch(u) ||
      u.contains('/icons/') ||
      u.contains('placeholder') ||
      u.contains('/theme/images/') ||
      RegExp(r'/default[_-]?og[_-]?image').hasMatch(u) ||
      RegExp(r'/default[/-]').hasMatch(u) ||
      u.contains('avatar') ||
      u.contains('/profile/') ||
      u.contains('1x1') ||
      u.contains('pixel') ||
      u.contains('scorecardresearch.com') ||
      u.contains('doubleclick.net') ||
      u.contains('googletagmanager.com') ||
      u.contains('google-analytics.com') ||
      u.endsWith('.svg') ||
      u.endsWith('.ico')) {
    return true;
  }
  if (!RegExp(r'\.(jpg|jpeg|png|webp|gif|avif)(\?|$)').hasMatch(u) &&
      RegExp(r'[?&]cj=1(&|$)').hasMatch(u)) {
    return true;
  }
  if (u.contains('news.google.com') ||
      u.contains('gstatic.com') ||
      u.contains('googleusercontent.com')) {
    return true;
  }
  final sizePattern = RegExp(r'[/_-](\d{2,3})x(\d{2,3})[/_.]');
  final match = sizePattern.firstMatch(u);
  if (match != null) {
    final w = int.tryParse(match.group(1) ?? '') ?? 0;
    final h = int.tryParse(match.group(2) ?? '') ?? 0;
    if (w > 0 && h > 0 && w <= 256 && h <= 256) return true;
  }
  return false;
}

void _collectFeedImageCandidate(
  NewsPost post,
  String? raw,
  Set<String> seen,
  List<String> out,
) {
  final trimmed = (raw ?? '').trim();
  if (trimmed.isEmpty || isUnusableFeedImageUrl(trimmed)) return;
  final display = AppConstants.imageUrlForDisplay(
    trimmed,
    articleReferer: post.sourceUrl,
  );
  if (display.isEmpty || FeedFailedImageCache.isFailed(display)) return;
  if (seen.add(display)) out.add(display);
}

/// All article photos suitable for the feed hero, in priority order.
List<String> feedImageUrlCandidatesForPost(NewsPost post) {
  final out = <String>[];
  final seen = <String>{};
  for (final m in post.media) {
    if (!m.isImage) continue;
    _collectFeedImageCandidate(post, m.url, seen, out);
  }
  for (final m in post.media) {
    if (!m.isVideo) continue;
    _collectFeedImageCandidate(post, m.thumbnail, seen, out);
  }
  _collectFeedImageCandidate(post, post.youtubeThumbnailUrl, seen, out);
  return out;
}

/// First article photo suitable for the feed, or empty when only logos exist.
String feedImageUrlForPost(NewsPost post) {
  final candidates = feedImageUrlCandidatesForPost(post);
  return candidates.isNotEmpty ? candidates.first : '';
}
