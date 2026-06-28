import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Read-aloud for article detail — respects feed language (en / hi / te).
class TtsService extends ChangeNotifier {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _speaking = false;

  bool get isSpeaking => _speaking;
  bool get isSupported => !kIsWeb;

  Future<void> _ensureReady() async {
    if (_ready) return;
    if (kIsWeb) {
      await _tts.setSpeechRate(0.92);
    } else {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.48);
    }
    _ready = true;
  }

  static String localeForLanguage(String lang) {
    switch (lang.toLowerCase()) {
      case 'hi':
        return 'hi-IN';
      case 'te':
        return 'te-IN';
      default:
        return 'en-IN';
    }
  }

  static String buildSpeakText(String title, String body) {
    final t = title.trim();
    final b = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (b.length <= 1200) return '$t. $b';
    return '$t. ${b.substring(0, 1200)}…';
  }

  Future<bool> speakArticle({
    required String title,
    required String body,
    required String languageCode,
  }) async {
    if (kIsWeb) return false;
    await _ensureReady();
    final locale = localeForLanguage(languageCode);
    try {
      await _tts.setLanguage(locale);
    } catch (_) {
      await _tts.setLanguage('en-IN');
    }
    final text = buildSpeakText(title, body);
    if (text.trim().isEmpty) return false;
    _speaking = true;
    notifyListeners();
    _tts.setCompletionHandler(() {
      _speaking = false;
      notifyListeners();
    });
    _tts.setCancelHandler(() {
      _speaking = false;
      notifyListeners();
    });
    await _tts.speak(text);
    return true;
  }

  Future<void> stop() async {
    await _tts.stop();
    _speaking = false;
    notifyListeners();
  }

  Future<bool> toggle({
    required String title,
    required String body,
    required String languageCode,
  }) async {
    if (_speaking) {
      await stop();
      return false;
    }
    return speakArticle(title: title, body: body, languageCode: languageCode);
  }
}
