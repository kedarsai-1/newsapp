import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../constants.dart';

/// Resolves a working API base URL when the baked-in `.env` points at a stale host.
class ApiRuntimeConfig {
  ApiRuntimeConfig._();

  static const Duration _probeTimeout = Duration(seconds: 3);

  /// Production origins tried after env URLs fail (stale APK / wrong IP).
  static const List<String> _productionOrigins = [
    'http://187.127.189.109',
  ];

  static bool _resolved = false;

  static Future<void> ensureResolved() async {
    if (_resolved) return;

    for (final origin in _envOrigins()) {
      if (await _tryOrigin(origin)) return;
    }
    for (final origin in _productionOrigins) {
      if (await _tryOrigin(origin)) {
        if (kDebugMode) {
          debugPrint('[ApiRuntimeConfig] using fallback origin $origin');
        }
        return;
      }
    }

    _resolved = true;
    if (kDebugMode) {
      debugPrint('[ApiRuntimeConfig] no live origin; using baked env defaults');
    }
  }

  static List<String> _envOrigins() {
    final out = <String>[];
    void addOrigin(String? raw) {
      if (raw == null || raw.trim().isEmpty) return;
      try {
        final uri = Uri.parse(raw.trim());
        final origin = uri.hasScheme && uri.host.isNotEmpty ? uri.origin : null;
        if (origin != null && origin.isNotEmpty && !out.contains(origin)) {
          out.add(origin);
        }
      } catch (_) {}
    }

    addOrigin(dotenv.env['API_BASE_URL']);
    addOrigin(dotenv.env['SOCKET_URL']);
    addOrigin(dotenv.env['SHARE_WEB_BASE_URL']);
    return out;
  }

  static Future<bool> _tryOrigin(String origin) async {
    final fromConfig = await _fetchAppConfig(origin);
    if (fromConfig != null) {
      _apply(fromConfig);
      _resolved = true;
      return true;
    }
    if (await _probeReady('$origin/api/ready')) {
      _apply(_RuntimeEndpoints(apiBaseUrl: '$origin/api', socketUrl: origin));
      _resolved = true;
      return true;
    }
    return false;
  }

  static Future<bool> _probeReady(String url) async {
    try {
      final res = await http
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(_probeTimeout);
      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body);
      return body is Map && body['ready'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<_RuntimeEndpoints?> _fetchAppConfig(String origin) async {
    try {
      final res = await http
          .get(Uri.parse('$origin/app-config.json'))
          .timeout(_probeTimeout);
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      final api = decoded['apiBaseUrl']?.toString().trim();
      if (api == null || api.isEmpty) return null;
      final apiOrigin = Uri.parse(api).origin;
      if (!await _probeReady('$apiOrigin/api/ready')) return null;
      return _RuntimeEndpoints(
        apiBaseUrl: api.endsWith('/api') ? api : '$api/api',
        socketUrl: decoded['socketUrl']?.toString().trim(),
        shareWebBaseUrl: decoded['shareWebBaseUrl']?.toString().trim(),
      );
    } catch (_) {
      return null;
    }
  }

  static void _apply(_RuntimeEndpoints cfg) {
    AppConstants.applyRuntimeApiConfig(
      apiBaseUrl: cfg.apiBaseUrl,
      socketUrl: cfg.socketUrl,
      shareWebBaseUrl: cfg.shareWebBaseUrl,
    );
  }
}

class _RuntimeEndpoints {
  const _RuntimeEndpoints({
    required this.apiBaseUrl,
    this.socketUrl,
    this.shareWebBaseUrl,
  });

  final String apiBaseUrl;
  final String? socketUrl;
  final String? shareWebBaseUrl;
}
