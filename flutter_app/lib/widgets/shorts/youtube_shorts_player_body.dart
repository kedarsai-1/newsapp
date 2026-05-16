import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/models.dart';
import '../../providers/shorts_playback_controller.dart';
import '../../utils/youtube_iframe_html.dart';
import 'youtube_shorts_player_shared.dart';

/// Mobile: lazy YouTube Iframe API in WebView — one active player at a time.
class YoutubeShortsPlayerBody extends StatefulWidget {
  final NewsPost post;
  final bool isActive;
  final bool immersive;

  const YoutubeShortsPlayerBody({
    super.key,
    required this.post,
    required this.isActive,
    this.immersive = true,
  });

  @override
  State<YoutubeShortsPlayerBody> createState() => _YoutubeShortsPlayerBodyState();
}

class _YoutubeShortsPlayerBodyState extends State<YoutubeShortsPlayerBody> {
  WebViewController? _controller;
  bool _embedMounted = false;
  bool _embedFailed = false;
  bool _playerReady = false;

  String? get _videoId => widget.post.youtube?.videoId;

  @override
  void initState() {
    super.initState();
    context.read<ShortsPlaybackController>().addListener(_onPlaybackChanged);
    _syncWithPlayback();
  }

  @override
  void didUpdateWidget(YoutubeShortsPlayerBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive ||
        oldWidget.post.id != widget.post.id) {
      _syncWithPlayback();
    }
  }

  @override
  void dispose() {
    context.read<ShortsPlaybackController>().removeListener(_onPlaybackChanged);
    _teardownPlayer();
    super.dispose();
  }

  void _onPlaybackChanged() {
    if (!mounted) return;
    _syncWithPlayback();
    _applyMute();
  }

  bool get _shouldPlay {
    final playback = context.read<ShortsPlaybackController>();
    return widget.isActive &&
        playback.isActivePost(widget.post.id) &&
        widget.post.youtube?.embeddable != false;
  }

  void _syncWithPlayback() {
    if (_shouldPlay) {
      _mountPlayerIfNeeded();
      if (_playerReady) _runJs('window.playCmd()');
    } else {
      if (_playerReady) _runJs('window.pauseCmd()');
      if (!widget.isActive) _teardownPlayer();
    }
    setState(() {});
  }

  void _mountPlayerIfNeeded() {
    if (_embedMounted || _embedFailed) return;
    final videoId = _videoId;
    if (videoId == null || videoId.isEmpty) return;
    if (widget.post.youtube?.embeddable == false) return;

    final playback = context.read<ShortsPlaybackController>();
    final elementId = 'yt-${widget.post.id}';
    final html = YoutubeIframeHtml.playerPage(
      videoId: videoId,
      elementId: elementId,
      autoplay: true,
      mute: playback.muted,
      enableIntersectionObserver: false,
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (msg) {
          final m = msg.message;
          if (m == 'ready') {
            _playerReady = true;
            _applyMute();
            if (_shouldPlay) _runJs('window.playCmd()');
          } else if (m == 'error') {
            if (mounted) setState(() => _embedFailed = true);
            _teardownPlayer();
          }
        },
      )
      ..loadHtmlString(html, baseUrl: 'https://www.youtube-nocookie.com');

    _embedMounted = true;
  }

  void _teardownPlayer() {
    if (_playerReady) _runJs('window.pauseCmd()');
    _playerReady = false;
    _embedMounted = false;
    _controller = null;
  }

  void _runJs(String script) {
    _controller?.runJavaScript(script);
  }

  void _applyMute() {
    if (!_playerReady) return;
    final muted = context.read<ShortsPlaybackController>().muted;
    _runJs('window.muteCmd(${muted ? 'true' : 'false'})');
  }

  void _onTapVideo() {
    final playback = context.read<ShortsPlaybackController>();
    if (playback.muted) {
      playback.setMuted(false);
    } else if (_playerReady) {
      _runJs('window.playCmd()');
    } else {
      _mountPlayerIfNeeded();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.post.youtube?.embeddable == false || _embedFailed) {
      return _wrap(
        Stack(
          fit: StackFit.expand,
          children: [
            YoutubeThumbnailLayer(
              post: widget.post,
              immersive: widget.immersive,
            ),
            YoutubeFallbackCard(post: widget.post),
          ],
        ),
      );
    }

    if (_embedMounted && _controller != null && _shouldPlay) {
      return _wrap(
        GestureDetector(
          onTap: _onTapVideo,
          behavior: HitTestBehavior.opaque,
          child: ColoredBox(
            color: Colors.black,
            child: WebViewWidget(controller: _controller!),
          ),
        ),
      );
    }

    return _wrap(
      GestureDetector(
        onTap: _onTapVideo,
        behavior: HitTestBehavior.opaque,
        child: YoutubeThumbnailLayer(
          post: widget.post,
          immersive: widget.immersive,
        ),
      ),
    );
  }

  Widget _wrap(Widget child) {
    if (!widget.immersive) {
      return ColoredBox(
        color: Colors.black,
        child: SizedBox.expand(child: child),
      );
    }
    return ShortsVideoFrame(child: child);
  }
}
