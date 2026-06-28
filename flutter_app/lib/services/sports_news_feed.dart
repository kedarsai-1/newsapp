import '../models/models.dart';
import '../utils/feed_language.dart';
import 'api_service.dart';

/// Sports category feed — same API as home feed, with language + RSS sources.
abstract final class SportsNewsFeed {
  static String? _sportsCategoryId;

  static Future<String?> resolveSportsCategoryId() async {
    if (_sportsCategoryId != null) return _sportsCategoryId;
    final data = await ApiService.getCategoriesJson();
    if (data['success'] == true && data['categories'] is List) {
      for (final item in data['categories'] as List) {
        if (item is! Map) continue;
        final slug = item['slug']?.toString().toLowerCase();
        if (slug == 'sports') {
          _sportsCategoryId = item['_id']?.toString() ?? item['id']?.toString();
          return _sportsCategoryId;
        }
      }
    }
    return null;
  }

  static List<NewsPost> _parsePosts(Map<String, dynamic> res) {
    final raw = res['posts'] as List? ?? [];
    return raw
        .whereType<Map>()
        .map((e) => NewsPost.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static List<NewsPost> _filterByLanguage(List<NewsPost> posts, String? language) {
    final code = language?.trim().toLowerCase();
    if (code == null || code.isEmpty || code == 'all') return posts;
    return posts.where((p) => postMatchesFeedLanguage(p, code)).toList();
  }

  static Future<Map<String, dynamic>> fetchPostsPage({
    required int page,
    String? language,
    int? limit,
  }) async {
    final catId = await resolveSportsCategoryId();
    var res = await ApiService.getFeed(
      page: page,
      categoryId: catId,
      language: language,
      days: 30,
      sourceTypes: const ['api', 'manual', 'rss', 'html', 'youtube'],
    );
    if (res['success'] != true) return res;

    var posts = _parsePosts(res);
    posts = _filterByLanguage(posts, language);
    if (posts.isEmpty && language != null && language.isNotEmpty && language != 'all') {
      final fallback = await ApiService.getFeed(
        page: page,
        categoryId: catId,
        days: 30,
        sourceTypes: const ['api', 'manual', 'rss', 'html', 'youtube'],
      );
      if (fallback['success'] == true) {
        posts = _parsePosts(fallback);
      }
    }
    posts.sort((a, b) => b.displayTime.compareTo(a.displayTime));

    return {
      'success': true,
      'posts': posts,
      'page': int.tryParse('${res['page']}') ?? page,
      'pages': int.tryParse('${res['pages']}') ?? 1,
    };
  }
}
