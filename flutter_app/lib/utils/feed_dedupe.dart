import '../models/models.dart';

String _normalizeTitle(String title) {
  final s = title.toLowerCase().trim();
  if (s.isEmpty) return '';
  if (RegExp(r'[\u0900-\u097F]').hasMatch(s)) {
    return s
        .replaceAll(RegExp(r'[^\u0900-\u097F0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
  if (RegExp(r'[\u0C00-\u0C7F]').hasMatch(s)) {
    return s
        .replaceAll(RegExp(r'[^\u0C00-\u0C7F0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
  return s
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

Set<String> _titleWords(String title) {
  final norm = _normalizeTitle(title);
  if (norm.length < 8) return {};
  return norm.split(' ').where((w) => w.length > 2).toSet();
}

bool _titlesOverlap(String a, String b) {
  final A = _titleWords(a);
  final B = _titleWords(b);
  if (A.length < 4 || B.length < 4) return false;
  var inter = 0;
  for (final w in A) {
    if (B.contains(w)) inter++;
  }
  return inter / (A.length < B.length ? A.length : B.length) >= 0.72;
}

String _normalizeSummary(String? summary) {
  final raw = (summary ?? '').toLowerCase().trim();
  if (raw.isEmpty) return '';
  if (RegExp(r'[\u0900-\u097F]').hasMatch(raw)) {
    return raw
        .replaceAll(RegExp(r'[^\u0900-\u097F0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
  if (RegExp(r'[\u0C00-\u0C7F]').hasMatch(raw)) {
    return raw
        .replaceAll(RegExp(r'[^\u0C00-\u0C7F0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
  return raw
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'[^\w\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

Set<String> _summaryWords(String? summary) {
  final norm = _normalizeSummary(summary);
  if (norm.length < 40) return {};
  return norm.split(' ').where((w) => w.length > 2).toSet();
}

bool _summariesOverlap(String? a, String? b) {
  final A = _summaryWords(a);
  final B = _summaryWords(b);
  if (A.length < 6 || B.length < 6) return false;
  var inter = 0;
  for (final w in A) {
    if (B.contains(w)) inter++;
  }
  return inter / (A.length < B.length ? A.length : B.length) >= 0.68;
}

/// Client-side dedupe for overlapping API pages / multi-source feeds.
List<NewsPost> dedupeNewsPosts(Iterable<NewsPost> posts) {
  final seen = <String>{};
  final keptTitles = <String>[];
  final keptSummaries = <String>[];
  final out = <NewsPost>[];
  for (final p in posts) {
    final keys = <String>{
      if (_urlKey(p.sourceUrl) != null) _urlKey(p.sourceUrl)!,
      if (_normalizeTitle(p.title).length >= 8) _normalizeTitle(p.title),
      if (_normalizeSummary(p.summary).length >= 40) _normalizeSummary(p.summary),
    };
    if (keys.isNotEmpty && keys.any(seen.contains)) continue;
    if (keptTitles.any((t) => _titlesOverlap(t, p.title))) continue;
    if (keptSummaries.any((s) => _summariesOverlap(s, p.summary))) continue;
    seen.addAll(keys);
    keptTitles.add(p.title);
    final sum = p.summary?.trim();
    if (sum != null && sum.length >= 40) keptSummaries.add(sum);
    out.add(p);
  }
  return out;
}

/// Merge [incoming] into [existing] without duplicates (preserves order).
List<NewsPost> mergeDedupedPosts(List<NewsPost> existing, List<NewsPost> incoming) {
  return dedupeNewsPosts([...existing, ...incoming]);
}
