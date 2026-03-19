import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/models.dart';

class ApiService {
  static String? _token;

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

  static Future<Map<String, dynamic>> _get(String path) async {
    final res = await http.get(Uri.parse('${AppConstants.baseUrl}$path'), headers: _headers);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('${AppConstants.baseUrl}$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return jsonDecode(res.body);
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

  static Future<Map<String, dynamic>> login(String email, String password) async {
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
    String? city,
    String? search,
    bool breaking = false,
  }) async {
    final params = {
      'page': page.toString(),
      'limit': AppConstants.pageSize.toString(),
      if (categoryId != null) 'category': categoryId,
      if (city != null) 'city': city,
      if (search != null) 'search': search,
      if (breaking) 'breaking': 'true',
    };
    final uri = Uri.parse('${AppConstants.baseUrl}/news/feed').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getPost(String id) async => _get('/news/$id');

  static Future<Map<String, dynamic>> toggleLike(String postId) async =>
      _post('/news/$postId/like', {});

  static Future<Map<String, dynamic>> toggleBookmark(String postId) async =>
      _post('/news/$postId/bookmark', {});

  static Future<Map<String, dynamic>> getBookmarks() async => _get('/news/bookmarks');

  static Future<Map<String, dynamic>> getComments(String postId) async =>
      _get('/news/$postId/comments');

  static Future<Map<String, dynamic>> addComment(String postId, String text) async =>
      _post('/news/$postId/comments', {'text': text});

  // ─── CATEGORIES ──────────────────────────────────────────────────────────

  static Future<List<Category>> getCategories() async {
    final data = await _get('/categories');
    if (data['success'] == true) {
      return (data['categories'] as List).map((c) => Category.fromJson(c)).toList();
    }
    return [];
  }

  // ─── REPORTER ────────────────────────────────────────────────────────────

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
    final uri = Uri.parse('${AppConstants.baseUrl}/reporter/posts');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $_token'
      ..fields['title'] = title
      ..fields['body'] = body
      ..fields['categoryId'] = categoryId
      ..fields['isDraft'] = isDraft.toString()
      ..fields['tags'] = jsonEncode(tags);

    if (summary != null) request.fields['summary'] = summary;
    if (latitude != null) request.fields['latitude'] = latitude.toString();
    if (longitude != null) request.fields['longitude'] = longitude.toString();

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

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getMyPosts({String? status, int page = 1}) async {
    final params = {
      'page': page.toString(),
      if (status != null) 'status': status,
    };
    final uri = Uri.parse('${AppConstants.baseUrl}/reporter/posts')
        .replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getReporterStats() async => _get('/reporter/stats');

  // ─── ADMIN ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getDashboard() async => _get('/admin/dashboard');

  static Future<Map<String, dynamic>> getPendingPosts({int page = 1}) async =>
      _get('/admin/posts/pending?page=$page');

  static Future<Map<String, dynamic>> approvePost(String id, {
    bool isBreaking = false,
    bool isFeatured = false,
  }) async {
    return _put('/admin/posts/$id/approve', {
      'isBreaking': isBreaking,
      'isFeatured': isFeatured,
    });
  }

  static Future<Map<String, dynamic>> rejectPost(String id, String reason) async =>
      _put('/admin/posts/$id/reject', {'reason': reason});

  static Future<Map<String, dynamic>> getUsers({String? role, int page = 1}) async {
    final params = {'page': page.toString(), if (role != null) 'role': role};
    final uri = Uri.parse('${AppConstants.baseUrl}/admin/users')
        .replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateUserRole(String userId, String role) async =>
      _put('/admin/users/$userId/role', {'role': role});

  static Future<Map<String, dynamic>> toggleUserActive(String userId) async =>
      _put('/admin/users/$userId/toggle-active', {});
}