import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/models.dart';
import '../utils/api_memory_cache.dart';

class ApiService {
  /// Render / free tiers can cold-start; keep this generous.
  static const Duration _httpTimeout = Duration(seconds: 90);

  static String? _token;
  static bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConstants.tokenKey);
  }

  static Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// GET requests: no `Content-Type` so unauthenticated calls are browser "simple"
  /// requests (fewer CORS preflight failures on Flutter web).
  static Map<String, String> get _getHeaders => {
        'Accept': 'application/json',
        if (_token != null && _token!.isNotEmpty)
          'Authorization': 'Bearer $_token',
      };

  static String _friendlyNetworkMessage(Object e) {
    final raw = e.toString();
    if (raw.contains('Failed to fetch')) {
      return kIsWeb
          ? 'Could not reach the news server from the browser. Check your connection and tap Try again.'
          : 'Could not reach the news server. Check your connection and try again.';
    }
    if (raw.contains('SocketException') ||
        raw.contains('Network is unreachable')) {
      return 'No internet connection. Try again when you are online.';
    }
    return 'Something went wrong. Please try again.';
  }

  static Future<Map<String, dynamic>> _decodeGetResponse(http.Response res) async {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return {
        'success': false,
        'statusCode': res.statusCode,
        'message': res.statusCode == 404
            ? 'Endpoint not found on server (deploy latest API or use local API_BASE_URL).'
            : 'Server error ${res.statusCode}. Check API is running.',
      };
    }
    final body = res.body.trim();
    if (body.isEmpty) {
      return {
        'success': false,
        'statusCode': res.statusCode,
        'message': 'Empty response from server.',
      };
    }
    if (body.startsWith('<')) {
      return {
        'success': false,
        'statusCode': res.statusCode,
        'message': res.statusCode == 404
            ? 'Political videos API is not on this server yet. Deploy the latest backend or use http://127.0.0.1:5001/api locally.'
            : 'Server returned HTML instead of JSON.',
      };
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return {'statusCode': res.statusCode, ...decoded};
    }
    return {'success': false, 'message': 'Unexpected response format.'};
  }

  static Future<Map<String, dynamic>> _get(String path) async {
    try {
      final res = await http
          .get(Uri.parse('${AppConstants.baseUrl}$path'), headers: _getHeaders)
          .timeout(_httpTimeout);
      return _decodeGetResponse(res);
    } on TimeoutException {
      return {
        'success': false,
        'message':
            'Request timed out. The API may be waking up — pull to refresh in a moment.',
      };
    } on FormatException {
      return {
        'success': false,
        'message': 'Could not read data from the server (invalid JSON).',
      };
    } catch (e) {
      return {
        'success': false,
        'message': _friendlyNetworkMessage(e),
      };
    }
  }

  static String _queryCacheKey(String path, Map<String, String> queryParams) {
    final entries = queryParams.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final qs = entries.map((e) => '${e.key}=${e.value}').join('&');
    return qs.isEmpty ? path : '$path?$qs';
  }

  static Future<Map<String, dynamic>> _getQuery(
    String path,
    Map<String, String> queryParams, {
    Duration? memoryCacheTtl,
  }) async {
    String? cacheKey;
    if (memoryCacheTtl != null) {
      cacheKey = _queryCacheKey(path, queryParams);
      final cached = ApiMemoryCache.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) return Map<String, dynamic>.from(cached);
    }
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}$path')
          .replace(queryParameters: queryParams);
      final res =
          await http.get(uri, headers: _getHeaders).timeout(_httpTimeout);
      final decoded = await _decodeGetResponse(res);
      if (cacheKey != null &&
          memoryCacheTtl != null &&
          decoded['success'] == true) {
        ApiMemoryCache.set(cacheKey, decoded, memoryCacheTtl);
      }
      return decoded;
    } on TimeoutException {
      return {
        'success': false,
        'message':
            'Request timed out. The API may be waking up — pull to refresh in a moment.',
      };
    } on FormatException {
      return {
        'success': false,
        'message': 'Could not read data from the server (invalid JSON).',
      };
    } catch (e) {
      return {
        'success': false,
        'message': _friendlyNetworkMessage(e),
      };
    }
  }

  static Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    try {
      final res = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(_httpTimeout);
      return jsonDecode(res.body);
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Request timed out. Try again in a few seconds.',
      };
    }
  }

  static Future<Map<String, dynamic>> _put(
      String path, Map<String, dynamic> body) async {
    try {
      final res = await http
          .put(
            Uri.parse('${AppConstants.baseUrl}$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(_httpTimeout);
      return jsonDecode(res.body);
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Request timed out. Try again in a few seconds.',
      };
    }
  }

  static Future<Map<String, dynamic>> _delete(String path) async {
    try {
      final res = await http
          .delete(
            Uri.parse('${AppConstants.baseUrl}$path'),
            headers: _getHeaders,
          )
          .timeout(_httpTimeout);
      return jsonDecode(res.body);
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Request timed out. Try again in a few seconds.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': _friendlyNetworkMessage(e),
      };
    }
  }

  // ─── AUTH ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String role = 'user',
    String? phone,
  }) async {
    return _post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
      if (phone != null) 'phone': phone,
    });
  }

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    return _post('/auth/login', {'email': email, 'password': password});
  }

  static Future<Map<String, dynamic>> getMe() async => _get('/auth/me');

  static Future<void> updateFcmToken(String fcmToken) async {
    await _put('/auth/fcm-token', {'fcmToken': fcmToken});
  }

  // ─── OTP ─────────────────────────────────────────────────────────────────

  /// Send OTP to email or phone.
  /// [target] = email address or phone number.
  /// [purpose] = 'login' or 'register'.
  static Future<Map<String, dynamic>> sendOtp({
    required String target,
    required String purpose, // 'login' | 'register'
  }) async {
    return _post('/auth/otp/send', {'target': target, 'purpose': purpose});
  }

  /// Verify OTP for login — returns JWT + user on success.
  static Future<Map<String, dynamic>> verifyLoginOtp({
    required String target,
    required String code,
  }) async {
    return _post('/auth/otp/verify-login', {'target': target, 'code': code});
  }

  /// Verify OTP for registration — creates account and returns JWT + user.
  static Future<Map<String, dynamic>> verifyRegisterOtp({
    required String name,
    String? email,
    String? phone,
    required String password,
    required String role,
    required String code,
  }) async {
    return _post('/auth/otp/verify-register', {
      'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      'password': password,
      'role': role,
      'code': code,
    });
  }

  // ─── NEWS FEED ───────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getFeed({
    int page = 1,
    String? categoryId,
    String? language,
    String? constituency,
    String? politicsScope,
    String? city,
    String? search,
    bool breaking = false,
    int? days,
    List<String>? sourceTypes,
    bool hasVideo = false,
    bool politicalOnly = false,
    bool excludePolitics = false,
  }) async {
    final params = {
      'page': page.toString(),
      'limit': AppConstants.pageSize.toString(),
      if (categoryId != null) 'category': categoryId,
      if (language != null && language != 'all') 'language': language,
      if (constituency != null &&
          constituency != 'all' &&
          constituency.trim().isNotEmpty)
        'constituency': constituency.trim(),
      if (politicsScope != null &&
          politicsScope != 'all' &&
          politicsScope.trim().isNotEmpty)
        'politicsScope': politicsScope.trim().toLowerCase(),
      if (city != null) 'city': city,
      if (search != null) 'search': search,
      if (breaking) 'breaking': 'true',
      if (days != null) 'days': days.toString(),
      if (sourceTypes != null && sourceTypes.isNotEmpty)
        'sourceTypes': sourceTypes
            .map((s) => s.trim().toLowerCase())
            .where((s) => s.isNotEmpty)
            .join(','),
      if (hasVideo) 'hasVideo': 'true',
      if (politicalOnly) 'politicalOnly': 'true',
      if (excludePolitics) 'excludePolitics': 'true',
    };
    final useClientCache =
        (search == null || search.trim().isEmpty) && page <= 1;
    return _getQuery(
      '/news/feed',
      params,
      memoryCacheTtl: useClientCache ? const Duration(seconds: 30) : null,
    );
  }

  static Future<Map<String, dynamic>> getPost(String id) async =>
      _get('/news/$id');

  /// Extract full article text from the publisher URL (best-effort).
  static Future<Map<String, dynamic>> extractArticle(String url) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/news/extract')
        .replace(queryParameters: {'url': url});
    try {
      final res =
          await http.get(uri, headers: _getHeaders).timeout(_httpTimeout);
      return jsonDecode(res.body);
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Extraction timed out. Try opening the source link instead.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Extraction failed: $e'};
    }
  }

  static Future<Map<String, dynamic>> toggleLike(String postId) async =>
      _post('/news/$postId/like', {});

  static Future<Map<String, dynamic>> toggleBookmark(String postId) async =>
      _post('/news/$postId/bookmark', {});

  static Future<Map<String, dynamic>> getBookmarks() async =>
      _get('/news/bookmarks');

  static Future<Map<String, dynamic>> getComments(String postId) async =>
      _get('/news/$postId/comments');

  static Future<Map<String, dynamic>> addComment(
          String postId, String text) async =>
      _post('/news/$postId/comments', {'text': text});

  static Future<Map<String, dynamic>> translateText({
    required String text,
    required String targetLanguage,
  }) async {
    return _post('/news/translate', {
      'text': text,
      'targetLanguage': targetLanguage,
    });
  }

  // ─── GUEST INTERACTIONS (LOCAL STORAGE) ────────────────────────────────────

  static Future<Set<String>> _guestStringSet(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(key) ?? const []).toSet();
  }

  static Future<void> _saveGuestStringSet(
      String key, Set<String> values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, values.toList());
  }

  static Future<bool> toggleGuestLike(String postId) async {
    final likes = await _guestStringSet(AppConstants.guestLikesKey);
    final liked = !likes.contains(postId);
    if (liked) {
      likes.add(postId);
    } else {
      likes.remove(postId);
    }
    await _saveGuestStringSet(AppConstants.guestLikesKey, likes);
    return liked;
  }

  static Future<bool> isGuestLiked(String postId) async {
    final likes = await _guestStringSet(AppConstants.guestLikesKey);
    return likes.contains(postId);
  }

  static Future<bool> toggleGuestBookmark(NewsPost post) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.guestBookmarksKey);
    final map = raw == null
        ? <String, dynamic>{}
        : (jsonDecode(raw) as Map<String, dynamic>);
    final bookmarked = !map.containsKey(post.id);
    if (bookmarked) {
      map[post.id] = {
        '_id': post.id,
        'title': post.title,
        'body': post.body,
        'summary': post.summary,
        'reporter': post.reporter == null
            ? null
            : {
                '_id': post.reporter!.id,
                'name': post.reporter!.name,
                'email': post.reporter!.email,
                'role': post.reporter!.role,
                'avatar': post.reporter!.avatar,
              },
        'category': post.category == null
            ? null
            : {
                '_id': post.category!.id,
                'name': post.category!.name,
                'slug': post.category!.slug,
                'icon': post.category!.icon,
                'color': post.category!.color,
              },
        'media': post.media
            .map((m) => {
                  '_id': m.id,
                  'type': m.type,
                  'url': m.url,
                  'thumbnail': m.thumbnail,
                  'size': m.size,
                })
            .toList(),
        'location': post.location == null
            ? null
            : {
                'latitude': post.location!.latitude,
                'longitude': post.location!.longitude,
                'address': post.location!.address,
                'city': post.location!.city,
                'state': post.location!.state,
                'country': post.location!.country,
              },
        'status': post.status,
        'rejectionReason': post.rejectionReason,
        'views': post.views,
        'likes': post.likes,
        'isBreaking': post.isBreaking,
        'isFeatured': post.isFeatured,
        'tags': post.tags,
        'createdAt': post.createdAt.toIso8601String(),
      };
    } else {
      map.remove(post.id);
    }
    await prefs.setString(AppConstants.guestBookmarksKey, jsonEncode(map));
    return bookmarked;
  }

  static Future<bool> isGuestBookmarked(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.guestBookmarksKey);
    if (raw == null) return false;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.containsKey(postId);
  }

  static Future<List<NewsPost>> getGuestBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.guestBookmarksKey);
    if (raw == null) return [];
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.values
        .whereType<Map<String, dynamic>>()
        .map(NewsPost.fromJson)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<Map<String, dynamic>> addGuestComment(
      String postId, String text) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.guestCommentsKey);
    final byPost = raw == null
        ? <String, dynamic>{}
        : (jsonDecode(raw) as Map<String, dynamic>);
    final list = (byPost[postId] as List<dynamic>? ?? <dynamic>[]);

    final comment = {
      '_id': 'guest_${DateTime.now().millisecondsSinceEpoch}',
      'user': {
        '_id': 'guest',
        'name': 'Guest User',
        'email': 'guest@local',
        'role': 'user',
      },
      'text': text,
      'createdAt': DateTime.now().toIso8601String(),
    };
    list.insert(0, comment);
    byPost[postId] = list;
    await prefs.setString(AppConstants.guestCommentsKey, jsonEncode(byPost));
    return comment;
  }

  static Future<List<Comment>> getGuestComments(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.guestCommentsKey);
    if (raw == null) return [];
    final byPost = jsonDecode(raw) as Map<String, dynamic>;
    final list = (byPost[postId] as List<dynamic>? ?? <dynamic>[]);
    return list
        .whereType<Map<String, dynamic>>()
        .map(Comment.fromJson)
        .toList();
  }

  // ─── CATEGORIES ──────────────────────────────────────────────────────────

  /// Full JSON from GET /categories (for error messages).
  static Future<Map<String, dynamic>> getCategoriesJson() async {
    const cacheKey = '/categories';
    final cached = ApiMemoryCache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) return Map<String, dynamic>.from(cached);
    final data = await _get('/categories');
    if (data['success'] == true) {
      ApiMemoryCache.set(cacheKey, data, const Duration(minutes: 5));
    }
    return data;
  }

  /// GET /categories/by-slug/:slug — single category when list cache misses.
  static Future<Map<String, dynamic>> getCategoryBySlug(String slug) async {
    final encoded = Uri.encodeComponent(slug.trim());
    return _get('/categories/by-slug/$encoded');
  }

  static Future<List<Category>> getCategories() async {
    final data = await _get('/categories');
    if (data['success'] == true && data['categories'] is List) {
      return (data['categories'] as List)
          .map((c) => Category.fromJson(c as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  // ─── REPORTER ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _sendReporterMultipart({
    required String method,
    required Uri uri,
    required Map<String, String> fields,
    List<XFile> mediaFiles = const [],
    String? operationLabel,
  }) async {
    final label = operationLabel ?? '$method ${uri.path}';
    try {
      final request = http.MultipartRequest(method, uri)
        ..headers['Authorization'] = 'Bearer $_token'
        ..fields.addAll(fields);

      for (final file in mediaFiles) {
        final name = file.name.toLowerCase();
        final ext = name.contains('.') ? name.split('.').last : '';
        final isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(ext);
        final bytes = await file.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'media',
            bytes,
            filename: file.name.isEmpty ? 'media.$ext' : file.name,
            contentType: MediaType(isVideo ? 'video' : 'image', ext),
          ),
        );
      }

      final streamed = await request.send().timeout(_httpTimeout);
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        Map<String, dynamic> decoded = {};
        try {
          final parsed = jsonDecode(res.body);
          if (parsed is Map<String, dynamic>) decoded = parsed;
        } catch (_) {}
        return {
          'success': false,
          'statusCode': res.statusCode,
          'message': decoded['message'] ??
              'Server error ${res.statusCode} during $label.',
        };
      }

      final body = res.body.trim();
      if (body.isEmpty) {
        return {
          'success': false,
          'statusCode': res.statusCode,
          'message': 'Empty response from server.',
        };
      }
      if (body.startsWith('<')) {
        return {
          'success': false,
          'statusCode': res.statusCode,
          'message': 'Server returned HTML instead of JSON.',
        };
      }
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return {'statusCode': res.statusCode, ...decoded};
      }
      return {'success': false, 'message': 'Unexpected response format.'};
    } on TimeoutException {
      return {
        'success': false,
        'message':
            'Request timed out. The API may be waking up — try again in a moment.',
      };
    } on FormatException {
      return {
        'success': false,
        'message': 'Could not read data from the server (invalid JSON).',
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ApiService] $label failed: $e');
      }
      return {
        'success': false,
        'message': _friendlyNetworkMessage(e),
      };
    }
  }

  static Future<Map<String, dynamic>> createPost({
    required String title,
    required String body,
    String? summary,
    required String categoryId,
    double? latitude,
    double? longitude,
    List<String> tags = const [],
    List<XFile> mediaFiles = const [],
    bool isDraft = false,
  }) async {
    final fields = <String, String>{
      'title': title,
      'body': body,
      'categoryId': categoryId,
      'isDraft': isDraft.toString(),
      'tags': jsonEncode(tags),
    };
    if (summary != null) fields['summary'] = summary;
    if (latitude != null) fields['latitude'] = latitude.toString();
    if (longitude != null) fields['longitude'] = longitude.toString();

    return _sendReporterMultipart(
      method: 'POST',
      uri: Uri.parse('${AppConstants.baseUrl}/reporter/posts'),
      fields: fields,
      mediaFiles: mediaFiles,
      operationLabel: 'createPost title="${title.trim()}"',
    );
  }

  static Future<Map<String, dynamic>> getMyPosts(
      {String? status, int page = 1}) async {
    final params = {
      'page': page.toString(),
      if (status != null) 'status': status,
    };
    final uri = Uri.parse('${AppConstants.baseUrl}/reporter/posts')
        .replace(queryParameters: params);
    final res = await http.get(uri, headers: _getHeaders);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getReporterStats() async =>
      _get('/reporter/stats');

  static Future<Map<String, dynamic>> updatePost({
    required String postId,
    required String title,
    required String body,
    String? summary,
    required String categoryId,
    List<String> tags = const [],
    List<XFile> mediaFiles = const [],
  }) async {
    final fields = <String, String>{
      'title': title,
      'body': body,
      'categoryId': categoryId,
      'tags': jsonEncode(tags),
    };
    if (summary != null) fields['summary'] = summary;

    return _sendReporterMultipart(
      method: 'PUT',
      uri: Uri.parse('${AppConstants.baseUrl}/reporter/posts/$postId'),
      fields: fields,
      mediaFiles: mediaFiles,
      operationLabel: 'updatePost postId=$postId title="${title.trim()}"',
    );
  }

  static Future<Map<String, dynamic>> deletePostMedia({
    required String postId,
    required String mediaId,
  }) async =>
      _delete('/reporter/posts/$postId/media/$mediaId');

  // ─── ADMIN ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getDashboard() async =>
      _get('/admin/dashboard');

  static Future<Map<String, dynamic>> getPendingPosts({int page = 1}) async =>
      _get('/admin/posts/pending?page=$page');

  static Future<Map<String, dynamic>> approvePost(
    String id, {
    bool isBreaking = false,
    bool isFeatured = false,
  }) async {
    return _put('/admin/posts/$id/approve', {
      'isBreaking': isBreaking,
      'isFeatured': isFeatured,
    });
  }

  static Future<Map<String, dynamic>> rejectPost(
          String id, String reason) async =>
      _put('/admin/posts/$id/reject', {'reason': reason});

  static Future<Map<String, dynamic>> getUsers(
      {String? role, int page = 1}) async {
    final params = {'page': page.toString(), if (role != null) 'role': role};
    final uri = Uri.parse('${AppConstants.baseUrl}/admin/users')
        .replace(queryParameters: params);
    final res = await http.get(uri, headers: _getHeaders);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateUserRole(
          String userId, String role) async =>
      _put('/admin/users/$userId/role', {'role': role});

  static Future<Map<String, dynamic>> toggleUserActive(String userId) async =>
      _put('/admin/users/$userId/toggle-active', {});

  static Future<Map<String, dynamic>> runIngestionNow() async =>
      _post('/admin/ingestion/run', {});

  static Future<Map<String, dynamic>> getIngestionStatus() async =>
      _get('/admin/ingestion/status');

  // ─── Political video reels (classified YouTube) ───────────────────────────

  static Future<Map<String, dynamic>> getPoliticalVideoFeed({
    int page = 1,
    String? language,
    String? category,
  }) async {
    final params = {
      'page': page.toString(),
      'limit': AppConstants.pageSize.toString(),
      if (language != null && language != 'all') 'language': language,
      if (category != null && category.trim().isNotEmpty) 'category': category,
    };

    return _getQuery('/political-videos/feed', params);
  }
}
