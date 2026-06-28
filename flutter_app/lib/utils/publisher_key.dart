import '../models/models.dart';

/// Stable publisher key — keep in sync with server `publisherKey.js`.
String publisherKeyFromName(String raw) {
  final cleaned = cleanIngestSourceLabel(raw) ?? raw.trim();
  if (cleaned.isEmpty) return '';
  var key = cleaned
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u0900-\u097F\u0C00-\u0C7F]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (key.length > 120) key = key.substring(0, 120);
  return key;
}

String publisherKeyForPost(NewsPost post) =>
    publisherKeyFromName(post.displaySourceName);
