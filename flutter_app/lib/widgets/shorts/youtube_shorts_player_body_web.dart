import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

import '../../models/models.dart';
import '../../providers/shorts_playback_controller.dart';
import 'youtube_shorts_player_shared.dart';

/// Web: YouTube nocookie embed via platform view; Flutter controls play/pause/mute.
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
  State<YoutubeShortsPlayerBody> createState() => _YoutubeShortsPlayerBodyWebState();
}

class _YoutubeShortsPlayerBodyWebState extends State<YoutubeShortsPlayerBody> {
  static final Set<String> _registeredViews = <String>{};

  String? get _videoId => widget.post.youtube?.videoId;
  String get _viewType => 'yt-short-${widget.post.id}';

  @override
  void initState() {
    super.initState();
    context.read<ShortsPlaybackController>().addListener(_onPlaybackChanged);
    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_shouldEmbed) return;
        _ensureViewRegistered();
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(YoutubeShortsPlayerBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive && _shouldEmbed) {
        _ensureViewRegistered();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
      _applyPlaybackCommands();
    }
  }

  @override
  void dispose() {
    context.read<ShortsPlaybackController>().removeListener(_onPlaybackChanged);
    if (_registeredViews.contains(_viewType)) {
      _runJs(_pauseScript());
    }
    super.dispose();
  }

  void _onPlaybackChanged() {
    if (!mounted) return;
    _applyPlaybackCommands();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  bool get _shouldEmbed {
    final playback = context.read<ShortsPlaybackController>();
    return widget.isActive &&
        playback.isActivePost(widget.post.id) &&
        widget.post.youtube?.embeddable != false;
  }

  String _escape(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll("'", "\\'");

  String _playScript() {
    final vid = _escape(_videoId ?? '');
    return "window.__shortsCmd && window.__shortsCmd('$vid','play');";
  }

  String _pauseScript() {
    final vid = _escape(_videoId ?? '');
    return "window.__shortsCmd && window.__shortsCmd('$vid','pause');";
  }

  String _muteScript(bool muted) {
    final vid = _escape(_videoId ?? '');
    return "window.__shortsCmd && window.__shortsCmd('$vid','mute',$muted);";
  }

  void _runJs(String code) {
    final script = web.HTMLScriptElement()..text = code;
    web.document.body?.appendChild(script);
    script.remove();
  }

  void _applyPlaybackCommands() {
    if (_videoId == null) return;
    if (!_registeredViews.contains(_viewType)) return;
    if (_shouldEmbed) {
      _runJs(_playScript());
      _runJs(_muteScript(context.read<ShortsPlaybackController>().muted));
    } else {
      _runJs(_pauseScript());
    }
  }

  void _ensureViewRegistered() {
    if (_registeredViews.contains(_viewType)) return;
    final videoId = _videoId;
    if (videoId == null || videoId.isEmpty) return;

    final elementId = 'player-${widget.post.id}';
    final safeId = _escape(videoId);

    final origin = _escape(Uri.base.origin.isNotEmpty ? Uri.base.origin : 'http://localhost');

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final wrap = web.HTMLDivElement()
        ..id = 'wrap-${widget.post.id}'
        ..style.setProperty('width', '100%')
        ..style.setProperty('height', '100%')
        ..style.setProperty('background', '#000')
        ..style.setProperty('position', 'relative')
        ..style.setProperty('overflow', 'hidden');

      final playerDiv = web.HTMLDivElement()
        ..id = elementId
        ..style.setProperty('position', 'absolute')
        ..style.setProperty('inset', '0')
        ..style.setProperty('width', '100%')
        ..style.setProperty('height', '100%');

      wrap.appendChild(playerDiv);

      // Direct nocookie embed — more reliable in Flutter web HtmlElementView than Iframe API.
      final initScript = web.HTMLScriptElement()
        ..text = '''
(function() {
  window.__shortsYT = window.__shortsYT || {};
  window.__shortsCmd = window.__shortsCmd || function(videoId, cmd, arg) {
    var p = window.__shortsYT[videoId];
    if (!p) return;
    if (cmd === 'play' && p.playVideo) p.playVideo();
    if (cmd === 'pause' && p.pauseVideo) p.pauseVideo();
    if (cmd === 'mute') { arg ? p.mute() : p.unMute(); }
  };
  var host = document.getElementById('$elementId');
  if (!host) return;
  var iframe = document.createElement('iframe');
  iframe.setAttribute('allowfullscreen', 'true');
  iframe.setAttribute('allow', 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share');
  iframe.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;border:0;pointer-events:none;';
  iframe.src = 'https://www.youtube-nocookie.com/embed/$safeId'
    + '?enablejsapi=1&autoplay=1&mute=1&playsinline=1&controls=0&rel=0&modestbranding=1&fs=0&iv_load_policy=3'
    + '&origin=$origin';
  host.appendChild(iframe);
  var ready = false;
  iframe.addEventListener('load', function() { ready = true; });
  function ytCmd(func) {
    try {
      if (!ready || !iframe.contentWindow) return;
      iframe.contentWindow.postMessage(JSON.stringify({
        event: 'command', func: func, args: ''
      }), '*');
    } catch (e) {}
  }
  window.__shortsYT['$safeId'] = {
    playVideo: function() { ytCmd('playVideo'); },
    pauseVideo: function() { ytCmd('pauseVideo'); },
    mute: function() { ytCmd('mute'); },
    unMute: function() { ytCmd('unMute'); }
  };
})();
''';
      wrap.appendChild(initScript);
      return wrap;
    });
    _registeredViews.add(_viewType);
  }

  Future<void> _openExternal(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _onTapVideo() {
    final playback = context.read<ShortsPlaybackController>();
    if (playback.muted) {
      playback.setMuted(false);
      _runJs(_muteScript(false));
    }
    _runJs(_playScript());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.post.youtube?.embeddable == false) {
      return _wrap(
        Stack(
          fit: StackFit.expand,
          children: [
            YoutubeThumbnailLayer(
              post: widget.post,
              immersive: widget.immersive,
              showPlay: true,
              onPlay: () => _openExternal(widget.post.youtubeWatchUrl),
            ),
            YoutubeFallbackCard(post: widget.post),
          ],
        ),
      );
    }

    if (_shouldEmbed) {
      if (!_registeredViews.contains(_viewType)) {
        return _wrap(
          GestureDetector(
            onTap: _onTapVideo,
            child: YoutubeThumbnailLayer(
              post: widget.post,
              immersive: widget.immersive,
              showPlay: true,
            ),
          ),
        );
      }
      return _wrap(_embeddedPlayerStack());
    }

    return _wrap(
      GestureDetector(
        onTap: _onTapVideo,
        child: YoutubeThumbnailLayer(
          post: widget.post,
          immersive: widget.immersive,
        ),
      ),
    );
  }

  /// Iframe uses pointer-events:none so Flutter overlays (mute, etc.) receive taps on web.
  Widget _embeddedPlayerStack() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        HtmlElementView(viewType: _viewType),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _onTapVideo,
            child: const SizedBox.expand(),
          ),
        ),
      ],
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
