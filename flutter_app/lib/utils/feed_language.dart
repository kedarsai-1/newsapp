import '../models/models.dart';

/// Central client-side language guard — mirrors API `language` + `originalLanguage` rules.
bool postMatchesFeedLanguage(NewsPost post, String language) {
  final code = language.trim().toLowerCase();
  if (code.isEmpty || code == 'all') return true;

  final lang = post.language.trim().toLowerCase();
  final orig = post.originalLanguage?.trim().toLowerCase();

  // 1. Explicit match of language code or 3-letter ISO code
  if (lang == code) return true;
  if (orig == _threeLetterCode(code)) return true;

  // 2. Strict cross-exclusion: if post belongs to another known language, exclude it
  final knownLanguages = {'en', 'te', 'hi', 'ta', 'kn', 'ml'};
  if (lang.isNotEmpty && lang != code && knownLanguages.contains(lang)) {
    return false;
  }
  if (orig != null && orig.isNotEmpty && orig != _threeLetterCode(code) && knownLanguages.contains(_twoLetterCode(orig))) {
    return false;
  }

  // 3. Fallback script detection based on character ranges (Title, Summary, and Body)
  switch (code) {
    case 'te':
      return _looksTelugu(post);
    case 'hi':
      return _looksHindi(post);
    case 'ta':
      return _looksTamil(post);
    case 'kn':
      return _looksKannada(post);
    case 'ml':
      return _looksMalayalam(post);
    case 'en':
      // English matches if lang is explicitly 'en', or if lang is empty/unknown AND it has no regional scripts.
      if (lang.isNotEmpty && lang != 'en') return false;
      if (orig != null && orig.isNotEmpty && orig != 'eng') return false;
      // If it contains any regional script, exclude from English feed
      if (_looksTelugu(post) || _looksHindi(post) || _looksTamil(post) || _looksKannada(post) || _looksMalayalam(post)) {
        return false;
      }
      return true;
    default:
      return lang == code;
  }
}

String _threeLetterCode(String twoLetter) {
  switch (twoLetter) {
    case 'en': return 'eng';
    case 'te': return 'tel';
    case 'hi': return 'hin';
    case 'ta': return 'tam';
    case 'kn': return 'kan';
    case 'ml': return 'mal';
    default: return '';
  }
}

String _twoLetterCode(String threeLetter) {
  switch (threeLetter) {
    case 'eng': return 'en';
    case 'tel': return 'te';
    case 'hin': return 'hi';
    case 'tam': return 'ta';
    case 'kan': return 'kn';
    case 'mal': return 'ml';
    default: return '';
  }
}

bool _looksTelugu(NewsPost post) {
  final t = '${post.title} ${post.summary ?? ''} ${post.body}';
  return RegExp(r'[\u0C00-\u0C7F]').hasMatch(t);
}

bool _looksHindi(NewsPost post) {
  final t = '${post.title} ${post.summary ?? ''} ${post.body}';
  return RegExp(r'[\u0900-\u097F]').hasMatch(t);
}

bool _looksTamil(NewsPost post) {
  final t = '${post.title} ${post.summary ?? ''} ${post.body}';
  return RegExp(r'[\u0B80-\u0BFF]').hasMatch(t);
}

bool _looksKannada(NewsPost post) {
  final t = '${post.title} ${post.summary ?? ''} ${post.body}';
  return RegExp(r'[\u0C80-\u0CFF]').hasMatch(t);
}

bool _looksMalayalam(NewsPost post) {
  final t = '${post.title} ${post.summary ?? ''} ${post.body}';
  return RegExp(r'[\u0D00-\u0D7F]').hasMatch(t);
}
