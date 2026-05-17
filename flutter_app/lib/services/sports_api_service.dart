import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants.dart';

/// Sports / cricket API — all calls go through our backend (CricAPI key hidden).
abstract final class SportsApiService {
  static const _timeout = Duration(seconds: 25);

  static Future<Map<String, dynamic>> _get(String path,
      [Map<String, String>? query]) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$path').replace(
      queryParameters: query,
    );
    try {
      final res = await http.get(uri).timeout(_timeout);
      final body = res.body.trim();
      if (body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server.'};
      }
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        if (res.statusCode >= 400) {
          return {
            'success': false,
            'message': decoded['message']?.toString() ?? 'Request failed',
          };
        }
        return decoded;
      }
      return {'success': false, 'message': 'Unexpected response format.'};
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error. Check server is running on port ${AppConstants.defaultApiPort}.',
      };
    }
  }

  static Future<Map<String, dynamic>> getLive() => _get('/sports/live');

  static Future<Map<String, dynamic>> getMatch(String id) =>
      _get('/sports/match/$id');

  static Future<Map<String, dynamic>> getNews({
    int page = 1,
    int limit = 15,
  }) =>
      _get('/sports/news', {
        'page': '$page',
        'limit': '$limit',
      });

  static Future<Map<String, dynamic>> getHighlights({int limit = 8}) =>
      _get('/sports/highlights', {'limit': '$limit'});
}
