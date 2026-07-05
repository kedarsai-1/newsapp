import '../models/models.dart';

/// Body copy for article detail — cleans YouTube scrape noise, keeps useful text.
String? articleDetailBodyText(NewsPost post) {
  final summary = post.summary?.trim() ?? '';
  final body = post.body.replaceAll(RegExp(r'\s+'), ' ').trim();

  if (post.isYoutube) {
    for (final raw in [summary, body]) {
      if (raw.isEmpty) continue;
      final cleaned = _cleanYoutubeText(raw, post);
      if (cleaned != null && cleaned.isNotEmpty) return cleaned;
    }
    return _youtubeFallback(post);
  }

  // When ingest AI summary failed, storage may hold only part of the article while body has the full text.
  if (summary.isNotEmpty && body.length > summary.length + 200) {
    final sumNorm = summary.replaceAll(RegExp(r'\s+'), ' ').trim();
    final bodyNorm = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final coversSmallShareOfBody =
        sumNorm.length < bodyNorm.length * 0.55;
    final thinLedeOnly = coversSmallShareOfBody &&
        (bodyNorm.startsWith(sumNorm) ||
            bodyNorm.contains(sumNorm));
    if (thinLedeOnly) {
      return _cleanArticleBody(body, post.language);
    }
  }

  final candidate = summary.isNotEmpty ? summary : body;
  if (candidate.isEmpty) return null;

  if (!_matchesPostLanguage(candidate, post.language)) {
    final extracted = _extractPreferredScript(candidate, post.language);
    return extracted ?? candidate;
  }
  return candidate;
}

String _cleanArticleBody(String text, String lang) {
  var t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  // Drop common publisher chrome that sometimes survives extraction.
  t = t.replaceFirst(
    RegExp(
      r'^(?:Home|Bhakthi|Politics|Crime|Education|Jobs|Sports)\s+',
      caseSensitive: false,
    ),
    '',
  );
  t = t.replaceFirst(
    RegExp(r'^Published Date\s*:.*?(?=\p{Script=Telugu}|\p{Script=Devanagari})', unicode: true),
    '',
  );
  if (t.length > 2200) {
    return '${t.substring(0, 2200).trim()}…';
  }
  return t;
}

String _youtubeFallback(NewsPost post) {
  final channel = post.youtubeChannelLabel;
  switch (post.language.trim().toLowerCase()) {
    case 'te':
      return '$channel నుండి వీడియో న్యూస్. పైన ఉన్న ప్లేయర్‌లో పూర్తి వీడియో చూడండి.';
    case 'hi':
      return '$channel की वीडियो खबर। ऊपर दिए प्लेयर में पूरा वीडियो देखें।';
    case 'ta':
      return '$channel-இலிருந்து வீடியோ செய்தி. மேலே உள்ள பிளேயரில் முழு வீடியோவைப் பாருங்கள்.';
    default:
      return 'Video report from $channel. Watch the full clip in the player above.';
  }
}

String? _cleanYoutubeText(String text, NewsPost post) {
  final chunks = text
      .split(RegExp(r'[\n|•]+'))
      .map((s) => s.trim())
      .where((s) => s.length > 10)
      .toList();

  final kept = <String>[];
  for (final chunk in chunks) {
    if (_isBoilerplateChunk(chunk)) continue;
    if (_isNearDuplicate(chunk, post.title)) continue;
    kept.add(chunk);
  }

  final lang = post.language.trim().toLowerCase();
  if (lang == 'te' || lang == 'hi' || lang == 'ta') {
    final native = kept.where((c) => _hasScript(c, lang)).toList();
    if (native.isNotEmpty) {
      return _truncate(native.take(2).join(' '));
    }
    final fromScript = _extractPreferredScript(text, lang);
    if (fromScript != null && !_isBoilerplateChunk(fromScript)) {
      return _truncate(fromScript);
    }
  }

  if (kept.isNotEmpty) {
    return _truncate(kept.take(2).join(' '));
  }

  // Single block — strip trailing hashtag / CTA tails, keep the lead sentence.
  var lead = text;
  final hashIdx = lead.indexOf('#');
  if (hashIdx > 40) lead = lead.substring(0, hashIdx).trim();
  lead = lead.replaceAll(RegExp(r'👉.*$'), '').trim();
  if (lead.length > 10 &&
      !_isBoilerplateChunk(lead) &&
      !_isNearDuplicate(lead, post.title)) {
    return _truncate(lead);
  }

  return null;
}

bool _isBoilerplateChunk(String text) {
  final lower = text.toLowerCase();
  if (lower.contains('👉')) return true;
  if (RegExp(r'watch .+ live', caseSensitive: false).hasMatch(lower)) {
    return true;
  }
  if (lower.contains('subscribe') &&
      (lower.contains('channel') || lower.contains('bell'))) {
    return true;
  }
  if (RegExp(r'^#(\w+\s*)+$').hasMatch(text.trim())) return true;
  final tags = RegExp(r'#\w+').allMatches(text).length;
  if (tags >= 3 && text.length < tags * 18) return true;
  return false;
}

String? _extractPreferredScript(String text, String lang) {
  final code = lang.trim().toLowerCase();
  final pattern = switch (code) {
    'te' => RegExp(
        r'[\u0C00-\u0C7F][\u0C00-\u0C7F\s.,!?\-:;"\u2019\u2018]*',
      ),
    'hi' => RegExp(
        r'[\u0900-\u097F][\u0900-\u097F\s.,!?\-:;"\u2019\u2018]*',
      ),
    'ta' => RegExp(
        r'[\u0B80-\u0BFF][\u0B80-\u0BFF\s.,!?\-:;"\u2019\u2018]*',
      ),
    _ => null,
  };
  if (pattern == null) return null;
  final matches = pattern
      .allMatches(text)
      .map((m) => m.group(0)?.trim() ?? '')
      .where((s) => s.length > 16)
      .toList();
  if (matches.isEmpty) return null;
  return matches.take(2).join(' ');
}

bool _hasScript(String text, String lang) {
  final code = lang.trim().toLowerCase();
  switch (code) {
    case 'te':
      return RegExp(r'[\u0C00-\u0C7F]').hasMatch(text);
    case 'hi':
      return RegExp(r'[\u0900-\u097F]').hasMatch(text);
    case 'ta':
      return RegExp(r'[\u0B80-\u0BFF]').hasMatch(text);
    default:
      return true;
  }
}

String _truncate(String text, [int max = 480]) {
  final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.length <= max) return t;
  return '${t.substring(0, max).trim()}…';
}

bool _isNearDuplicate(String a, String b) {
  final na = _normalize(a);
  final nb = _normalize(b);
  if (na.isEmpty || nb.isEmpty) return false;
  if (na == nb) return true;
  if (na.length > 24 && nb.contains(na)) return true;
  if (nb.length > 24 && na.contains(nb)) return true;
  return false;
}

String _normalize(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^\w\u0900-\u0C7F\u0B80-\u0BFF]+'), '');

bool _matchesPostLanguage(String text, String lang) {
  final code = lang.trim().toLowerCase();
  if (code.isEmpty || code == 'all' || code == 'en') return true;

  final latin = RegExp(r'[A-Za-z]').allMatches(text).length;
  if (latin < 24) return true;

  if (code == 'te') {
    final telugu = RegExp(r'[\u0C00-\u0C7F]').allMatches(text).length;
    return telugu >= latin * 0.25;
  }
  if (code == 'hi') {
    final hindi = RegExp(r'[\u0900-\u097F]').allMatches(text).length;
    return hindi >= latin * 0.25;
  }
  if (code == 'ta') {
    final tamil = RegExp(r'[\u0B80-\u0BFF]').allMatches(text).length;
    return tamil >= latin * 0.25;
  }
  return true;
}
