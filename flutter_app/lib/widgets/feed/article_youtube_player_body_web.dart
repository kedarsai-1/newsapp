import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

import '../../models/models.dart';
import '../feed/feed_xpresso_theme.dart';
import '../shorts/youtube_shorts_player_shared.dart';
import 'article_youtube_player_body.dart';

/// Web: tap thumbnail → reveal nocookie embed with controls.
class ArticleYoutubePlayerBody extends StatefulWidget {
  final NewsPost post;
  final String videoId;

  const ArticleYoutubePlayerBody({
    super.key,
    required this.post,
    required this.videoId,
  });

  @override
  State<ArticleYoutubePlayerBody> createState() =>
      _ArticleYoutubePlayerBodyWebState();
}

class _ArticleYoutubePlayerBodyWebState extends State<ArticleYoutubePlayerBody> {
  static final Set<String> _registered = <String>{};
  bool _revealed = false;

  String get _viewType => 'article-yt-${widget.post.id}';

  void _registerView() {
    if (_registered.contains(_viewType)) return;
    final videoId = widget.videoId;
    final origin =
        Uri.base.origin.isNotEmpty ? Uri.base.origin : 'http://localhost';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final wrap = web.HTMLDivElement()
        ..style.setProperty('width', '100%')
        ..style.setProperty('height', '100%')
        ..style.setProperty('background', '#000')
        ..style.setProperty('position', 'relative');

      final iframe = web.HTMLIFrameElement()
        ..setAttribute('allowfullscreen', 'true')
        ..setAttribute(
          'allow',
          'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share',
        )
        ..style.setProperty('border', '0')
        ..style.setProperty('width', '100%')
        ..style.setProperty('height', '100%')
        ..src =
            'https://www.youtube-nocookie.com/embed/$videoId?autoplay=1&playsinline=1&controls=1&rel=0&modestbranding=1&origin=$origin';

      wrap.appendChild(iframe);
      return wrap;
    });
    _registered.add(_viewType);
  }

  void _revealPlayer() {
    if (_revealed) return;
    _registerView();
    setState(() => _revealed = true);
  }

  Future<void> _openYouTube() async {
    final url = widget.post.youtubeWatchUrl;
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    if (widget.post.youtube?.embeddable == false) {
      return ArticleYoutubeFallback(post: widget.post, onOpen: _openYouTube);
    }

    if (!_revealed) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: GestureDetector(
            onTap: _revealPlayer,
            child: YoutubeThumbnailLayer(
              post: widget.post,
              immersive: false,
              showPlay: true,
              onPlay: _revealPlayer,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: fx.mediaViewerBackground,
          child: HtmlElementView(viewType: _viewType),
        ),
      ),
    );
  }
}
