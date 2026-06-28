/// Avoid re-requesting Cloudinary/CDN URLs that already failed in this session.
abstract final class FeedFailedImageCache {
  FeedFailedImageCache._();

  static final Set<String> _failed = <String>{};

  static bool isFailed(String url) {
    final u = url.trim();
    return u.isNotEmpty && _failed.contains(u);
  }

  static void markFailed(String url) {
    final u = url.trim();
    if (u.isNotEmpty) _failed.add(u);
  }
}
