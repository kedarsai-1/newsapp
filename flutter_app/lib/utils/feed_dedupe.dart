import '../models/models.dart';

String _normalizeTitle(String title) {
  return title
      .toLowerCase()
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r"[''`]"), "'")
      .replaceAll(RegExp(r'[^\w\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String? _urlKey(String? url) {
  if (url == null) return null;
  final raw = url.trim();
  if (raw.isEmpty) return null;
  try {
    final u = Uri.parse(raw);
    if (!u.hasScheme) return null;
    var host = u.host.toLowerCase();
    if (host.startsWith('www.')) host = host.substring(4);
    final path = u.path.replaceAll(RegExp(r'/+$'), '');
    final drop = {'utm_source', 'utm_medium', 'utm_campaign', 'fbclid', 'gclid'};
    final qp = Map<String, String>.from(u.queryParameters)
      ..removeWhere((k, _) => drop.contains(k.toLowerCase()) || k.toLowerCase().startsWith('utm_'));
    final qs = qp.entries.map((e) => '${e.key}=${e.value}').join('&');
    return '${u.scheme}://$host$path${qs.isEmpty ? '' : '?$qs'}';
  } catch (_) {
    return raw;
  }
}

/// Client-side dedupe for overlapping API pages / multi-source feeds.
List<NewsPost> dedupeNewsPosts(Iterable<NewsPost> posts) {
  final seen = <String>{};
  final out = <NewsPost>[];
  for (final p in posts) {
    final keys = <String>{
      if (_urlKey(p.sourceUrl) != null) _urlKey(p.sourceUrl)!,
      if (_normalizeTitle(p.title).length >= 12) _normalizeTitle(p.title),
    };
    if (keys.isNotEmpty && keys.any(seen.contains)) continue;
    seen.addAll(keys);
    out.add(p);
  }
  return out;
}

/// Merge [incoming] into [existing] without duplicates (preserves order).
List<NewsPost> mergeDedupedPosts(List<NewsPost> existing, List<NewsPost> incoming) {
  return dedupeNewsPosts([...existing, ...incoming]);
}
