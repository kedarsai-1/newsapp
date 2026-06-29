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
    case 'ta':
      return lang == 'ta' || orig == 'tam' || _looksTamil(post);
    case 'kn':
      return lang == 'kn' || orig == 'kan' || _looksKannada(post);
    case 'bn':
      return lang == 'bn' || orig == 'ben' || _looksBengali(post);
    case 'ml':
      return lang == 'ml' || orig == 'mal' || _looksMalayalam(post);
    case 'en':
      return lang == 'en' || lang.isEmpty || orig == 'eng';
    default:
      return lang == code;
  }
}

bool _looksTelugu(NewsPost post) {
  final t = '${post.title} ${post.summary ?? ''}';
  return RegExp(r'[ఀ-౿]').hasMatch(t);
}

bool _looksHindi(NewsPost post) {
  final t = '${post.title} ${post.summary ?? ''}';
  return RegExp(r'[ऀ-ॿ]').hasMatch(t);
}

bool _looksTamil(NewsPost post) {
  final t = '${post.title} ${post.summary ?? ''}';
  return RegExp(r'[஀-௿]').hasMatch(t);
}

bool _looksKannada(NewsPost post) {
  final t = '${post.title} ${post.summary ?? ''}';
  return RegExp(r'[ಀ-೿]').hasMatch(t);
}

bool _looksBengali(NewsPost post) {
  final t = '${post.title} ${post.summary ?? ''}';
  return RegExp(r'[ঀ-৿]').hasMatch(t);
}

bool _looksMalayalam(NewsPost post) {
  final t = '${post.title} ${post.summary ?? ''}';
  return RegExp(r'[ഀ-ൿ]').hasMatch(t);
}
