import '../constants.dart';
import '../models/models.dart';
import 'feed_failed_image_cache.dart';

/// Logos, favicons, and site placeholders — not valid feed hero images.
/// This conservative check only blocks clear non-content images so that
/// legitimate publisher images whose CDN paths contain words like "logo"
/// or "default" are not silently dropped. Domain-aware checks (Google hosts,
/// placeholder paths) are applied separately in _collectFeedImageCandidate.
bool isUnusableFeedImageUrl(String? url) {
  if (url == null) return true;
  final u = url.trim().toLowerCase();
  if (u.isEmpty) return true;

  // Must look like an actual image file — SVG/ICO are never feed images.
  if (u.endsWith('.svg') || u.endsWith('.ico')) return true;

  // Tracking pixels, ad slots, and third-party asset hosts.
  if (u.contains('clearbit.com')) return true;
  if (u.contains('/s2/favicons')) return true;
  if (u.contains('scorecardresearch.com')) return true;
  if (u.contains('doubleclick.net')) return true;
  if (u.contains('googletagmanager.com')) return true;
  if (u.contains('google-analytics.com')) return true;
  if (u.contains('1x1') || u.contains('pixel')) return true;

  // Favicon / icon file patterns — but avoid catching legitimate paths.
  if (u.contains('/favicon') && !u.contains('/favicon')) return true;
  if (RegExp(r'[/_.-]icon[_-]?\d+\.(jpg|jpeg|png|webp|gif)').hasMatch(u)) return true;

  return false;
}

/// Block Google-hosted assets and placeholder paths unless the image originates
/// from the same domain as the article itself (some publishers use Google CDN).
bool _isBlockedByDomain(String url, String? articleSourceUrl) {
  final u = url.toLowerCase();
  final blocked = [
    'news.google.com',
    'gstatic.com',
    'googleusercontent.com',
    '/theme/images/',
    'placeholder',
    '/default_og_image',
    '/default_og-image',
  ];
  if (blocked.any((p) => u.contains(p))) {
    if (articleSourceUrl != null) {
      try {
        final imgHost = Uri.tryParse(url)?.host ?? '';
        final srcHost = Uri.tryParse(articleSourceUrl)?.host ?? '';
        if (imgHost.isNotEmpty && srcHost.isNotEmpty && imgHost == srcHost) return false;
      } catch (_) {}
    }
    return true;
  }
  // Block tiny dimension images only when we can't fall back to another URL.
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

  // Second pass: block Google/placeholder domains unless the image is from the
  // article's own origin (a publisher hosting on Google infrastructure).
  if (_isBlockedByDomain(trimmed, post.sourceUrl)) return;

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
