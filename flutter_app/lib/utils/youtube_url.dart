/// Detect YouTube watch/embed URLs that [video_player] cannot stream directly.
bool isYoutubeVideoUrl(String url) {
  final u = url.trim().toLowerCase();
  if (u.isEmpty) return false;
  return u.contains('youtube.com/watch') ||
      u.contains('youtu.be/') ||
      u.contains('youtube.com/embed/') ||
      u.contains('youtube-nocookie.com/embed/') ||
      u.contains('youtube.com/shorts/');
}

/// Best-effort video id from a YouTube URL.
String? youtubeVideoIdFromUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return null;

  if (uri.host.contains('youtu.be')) {
    final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    return id != null && id.length >= 6 ? id : null;
  }

  if (uri.host.contains('youtube.com')) {
    final v = uri.queryParameters['v'];
    if (v != null && v.length >= 6) return v;

    for (final seg in uri.pathSegments) {
      if (seg == 'embed' || seg == 'shorts') {
        final idx = uri.pathSegments.indexOf(seg);
        if (idx + 1 < uri.pathSegments.length) {
          final id = uri.pathSegments[idx + 1];
          if (id.length >= 6) return id;
        }
      }
    }
  }
  return null;
}
