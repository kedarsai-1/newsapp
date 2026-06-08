/// Word/sentence-aware truncation for feed card snippets (server: utils/summaryText.js).
String truncateAtWordBoundary(String text, int maxLength) {
  final x = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (x.isEmpty) return '';
  if (x.length <= maxLength) return x;

  final cut = x.substring(0, maxLength);
  final minSentence = (maxLength * 0.35).floor();

  for (final end in ['. ', '। ', '? ', '! ']) {
    final idx = cut.lastIndexOf(end);
    if (idx >= minSentence) {
      return cut.substring(0, idx + 1).trim();
    }
  }

  final minWord = (maxLength * 0.5).floor();
  final sp = cut.lastIndexOf(' ');
  if (sp >= minWord) {
    return '${cut.substring(0, sp).trim()}…';
  }

  final comma = cut.lastIndexOf(', ');
  if (comma >= minWord) {
    return '${cut.substring(0, comma).trim()}…';
  }

  return '${cut.substring(0, maxLength - 1).trim()}…';
}
