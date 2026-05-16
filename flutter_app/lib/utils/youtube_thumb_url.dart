/// YouTube still image URLs — prefer HD, fall back when unavailable.
abstract final class YoutubeThumbUrl {
  static const _host = 'https://i.ytimg.com/vi';

  static String maxRes(String videoId) => '$_host/$videoId/maxresdefault.jpg';

  static String high(String videoId) => '$_host/$videoId/hqdefault.jpg';

  static String standard(String videoId) => '$_host/$videoId/sddefault.jpg';

  /// Best-effort primary URL (maxres); UI should fall back via [fallbacks].
  static String primary(String videoId) => maxRes(videoId);

  static List<String> fallbacks(String videoId) => [
        maxRes(videoId),
        high(videoId),
        standard(videoId),
      ];

  static String? fromPost({
    String? videoId,
    String? mediaThumbnail,
  }) {
    final stored = mediaThumbnail?.trim();
    if (stored != null && stored.isNotEmpty) {
      if (stored.contains('maxresdefault') || stored.contains('hqdefault')) {
        return stored;
      }
    }
    if (videoId == null || videoId.isEmpty) return null;
    return primary(videoId);
  }
}
