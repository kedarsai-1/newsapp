import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

import '../../models/models.dart';
import 'article_youtube_player_body.dart';

/// Web: direct iframe embed with controls — no thumbnail overlay (avoids stuck loader).
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

  late final String _viewType = 'article-yt-${widget.post.id}';

  @override
  void initState() {
    super.initState();
    if (widget.post.youtube?.embeddable == false) return;
    _registerView();
  }

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
            'https://www.youtube-nocookie.com/embed/$videoId?playsinline=1&controls=1&rel=0&modestbranding=1&origin=$origin';

      wrap.appendChild(iframe);
      return wrap;
    });

    _registered.add(_viewType);
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
    if (widget.post.youtube?.embeddable == false) {
      return ArticleYoutubeFallback(post: widget.post, onOpen: _openYouTube);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: HtmlElementView(viewType: _viewType),
        ),
      ),
    );
  }
}
