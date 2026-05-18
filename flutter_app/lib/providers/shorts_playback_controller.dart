import 'dart:async';

import 'package:flutter/foundation.dart';

/// Coordinates a single active Shorts embed (autoplay, mute, pause on scroll).
class ShortsPlaybackController extends ChangeNotifier {
  static const embedDelay = Duration(milliseconds: 180);

  String? _activePostId;
  bool _muted = true;
  Timer? _activateTimer;

  String? get activePostId => _activePostId;
  bool get muted => _muted;

  bool isActivePost(String postId) =>
      postId.isNotEmpty && _activePostId == postId;

  /// [immediate] mounts the embed now; default waits until scroll settles (smoother swipe).
  void setActivePost(String? postId, {bool immediate = false}) {
    final next = (postId == null || postId.isEmpty) ? null : postId;
    _activateTimer?.cancel();

    if (next == _activePostId) return;

    if (next == null) {
      _activePostId = null;
      notifyListeners();
      return;
    }

    if (immediate) {
      _activePostId = next;
      notifyListeners();
      return;
    }

    // Brief delay so PageView snap finishes before swapping embeds (smoother swipe).
    _activateTimer = Timer(embedDelay, () {
      _activePostId = next;
      notifyListeners();
    });
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
    _activateTimer?.cancel();
    if (_activePostId == null) return;
    _activePostId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _activateTimer?.cancel();
    super.dispose();
  }
}
