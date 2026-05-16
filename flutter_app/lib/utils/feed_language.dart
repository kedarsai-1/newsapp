import '../models/models.dart';

/// Client-side language guard — mirrors API `language` + `originalLanguage` rules.
bool postMatchesFeedLanguage(NewsPost post, String language) {
  final code = language.trim().toLowerCase();
  if (code.isEmpty || code == 'all') return true;

  final lang = post.language.trim().toLowerCase();
  final orig = post.originalLanguage?.trim().toLowerCase();

  switch (code) {
    case 'te':
      return lang == 'te' || orig == 'tel' || _looksTelugu(post);
    case 'hi':
      return lang == 'hi' || orig == 'hin' || _looksHindi(post);
    case 'en':
      return lang == 'en' || lang.isEmpty || orig == 'eng';
    default:
      return lang == code;
  }
}

bool _looksTelugu(NewsPost post) {
  final t = '${post.title} ${post.summary ?? ''}';
  return RegExp(r'[\u0C00-\u0C7F]').hasMatch(t);
}

bool _looksHindi(NewsPost post) {
  final t = '${post.title} ${post.summary ?? ''}';
  return RegExp(r'[\u0900-\u097F]').hasMatch(t);
}
