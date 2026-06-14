import '../constants.dart';
import '../models/models.dart';

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

/// First article photo suitable for the feed, or empty when only logos exist.
String feedImageUrlForPost(NewsPost post) {
  for (final m in post.media) {
    if (!m.isImage) continue;
    final raw = m.url.trim();
    if (raw.isEmpty || isUnusableFeedImageUrl(raw)) continue;
    return AppConstants.imageUrlForDisplay(raw, articleReferer: post.sourceUrl);
  }
  for (final m in post.media) {
    if (!m.isVideo) continue;
    final thumb = (m.thumbnail ?? '').trim();
    if (thumb.isNotEmpty && !isUnusableFeedImageUrl(thumb)) {
      return AppConstants.imageUrlForDisplay(thumb, articleReferer: post.sourceUrl);
    }
  }
  final ytThumb = post.youtubeThumbnailUrl.trim();
  if (ytThumb.isNotEmpty && !isUnusableFeedImageUrl(ytThumb)) {
    return AppConstants.imageUrlForDisplay(ytThumb, articleReferer: post.sourceUrl);
  }
  return '';
}
