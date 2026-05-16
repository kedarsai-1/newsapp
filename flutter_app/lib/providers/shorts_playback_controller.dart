import 'package:flutter/foundation.dart';

/// Coordinates a single active Shorts embed (autoplay, mute, pause on scroll).
class ShortsPlaybackController extends ChangeNotifier {
  String? _activePostId;
  bool _muted = true;

  String? get activePostId => _activePostId;
  bool get muted => _muted;

  bool isActivePost(String postId) =>
      postId.isNotEmpty && _activePostId == postId;

  void setActivePost(String? postId) {
    final next = (postId == null || postId.isEmpty) ? null : postId;
    if (_activePostId == next) return;
    _activePostId = next;
    notifyListeners();
  }

  void toggleMute() {
    _muted = !_muted;
    notifyListeners();
  }

  void setMuted(bool value) {
    if (_muted == value) return;
    _muted = value;
    notifyListeners();
  }

  void pauseAll() {
    if (_activePostId == null) return;
    _activePostId = null;
    notifyListeners();
  }
}
