import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

/// Sports / cricket API — all calls go through our backend (CricAPI key hidden).
abstract final class SportsApiService {
  static const _timeout = Duration(seconds: 25);

  /// Server deployed without `/api/sports/*` routes (needs Railway redeploy).
  static const String codeSportsApiMissing = 'SPORTS_API_MISSING';

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    return {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> _get(String path,
      [Map<String, String>? query]) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$path').replace(
      queryParameters: query,
    );
    try {
      final res = await http.get(uri, headers: await _headers()).timeout(_timeout);
      final body = res.body.trim();

      if (res.statusCode == 404) {
        return {
          'success': false,
          'code': codeSportsApiMissing,
          'statusCode': 404,
          'message':
              'Sports API is not on the server yet. Redeploy your Railway service with the latest backend code (includes /api/sports routes).',
        };
      }

      if (body.isEmpty) {
        return {
          'success': false,
          'message': 'Empty response from server (${res.statusCode}).',
        };
      }

      if (body.startsWith('<!') || body.startsWith('<html')) {
        return {
          'success': false,
          'code': res.statusCode == 404 ? codeSportsApiMissing : null,
          'statusCode': res.statusCode,
          'message': res.statusCode == 404
              ? 'Sports API not found. Redeploy Railway with the latest server code.'
              : 'Server returned an error page instead of JSON.',
        };
      }

      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        if (res.statusCode >= 400) {
          return {
            'success': false,
            'statusCode': res.statusCode,
            'message': decoded['message']?.toString() ?? 'Request failed',
          };
        }
        return decoded;
      }
      return {'success': false, 'message': 'Unexpected response format.'};
    } on FormatException {
      return {
        'success': false,
        'message':
            'Invalid response from ${AppConstants.apiConnectionHint}. Redeploy the backend if you only see this on Cricket.',
      };
    } catch (e) {
      return {
        'success': false,
        'message':
            'Cannot reach ${AppConstants.apiConnectionHint}. Check Railway is running and assets/.env has API_BASE_URL=https://your-app.up.railway.app/api',
      };
    }
  }

  static Future<Map<String, dynamic>> getLive() => _get('/sports/live');

  static Future<Map<String, dynamic>> getMatch(String id) =>
      _get('/sports/match/$id');

  static Future<Map<String, dynamic>> getNews({
    int page = 1,
    int limit = 15,
    String? language,
  }) =>
      _get('/sports/news', {
        'page': '$page',
        'limit': '$limit',
        if (language != null && language.isNotEmpty && language != 'all')
          'language': language,
      });

  static Future<Map<String, dynamic>> getLeaderboard() =>
      _get('/sports/leaderboard');

  static Future<Map<String, dynamic>> votePoll(
    String matchId,
    String option,
  ) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/sports/match/$matchId/poll/vote');
    try {
      final res = await http
          .post(
            uri,
            headers: {
              ...(await _headers()),
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'option': option}),
          )
          .timeout(_timeout);
      final body = res.body.trim();
      if (body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server.'};
      }
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return {'statusCode': res.statusCode, ...decoded};
      }
      return {'success': false, 'message': 'Unexpected response format.'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
