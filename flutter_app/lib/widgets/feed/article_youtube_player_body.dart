import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/models.dart';
import '../../utils/youtube_iframe_html.dart';
import '../feed/feed_xpresso_palette.dart';
import '../feed/feed_xpresso_theme.dart';
import '../shorts/youtube_shorts_player_shared.dart';

/// Mobile: WebView embed with visible controls for article reading.
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
      _ArticleYoutubePlayerBodyState();
}

class _ArticleYoutubePlayerBodyState extends State<ArticleYoutubePlayerBody> {
  WebViewController? _controller;
  bool _failed = false;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
  }

  void _mountPlayer() {
    final elementId = 'article-yt-${widget.post.id}';
    final html = YoutubeIframeHtml.playerPage(
      videoId: widget.videoId,
      elementId: elementId,
      autoplay: true,
      mute: false,
      showControls: true,
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(FeedXpressoPalette.dark.mediaViewerBackground)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (msg) {
          if (!mounted) return;
          if (msg.message == 'error') {
            setState(() => _failed = true);
          }
        },
      )
      ..loadHtmlString(html, baseUrl: 'https://www.youtube-nocookie.com');
  }

  Future<void> _openYouTube() async {
    final url = widget.post.youtubeWatchUrl;
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _revealPlayer() {
    if (_revealed || widget.post.youtube?.embeddable == false) return;
    _mountPlayer();
    setState(() => _revealed = true);
  }

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    if (widget.post.youtube?.embeddable == false || _failed) {
      return _Fallback(post: widget.post, onOpen: _openYouTube);
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
        child: _controller != null
            ? ColoredBox(
                color: fx.mediaViewerBackground,
                child: WebViewWidget(controller: _controller!),
              )
            : ColoredBox(color: fx.mediaViewerBackground),
      ),
    );
  }
}

class ArticleYoutubeFallback extends StatelessWidget {
  final NewsPost post;
  final VoidCallback onOpen;

  const ArticleYoutubeFallback({
    super.key,
    required this.post,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) => _Fallback(post: post, onOpen: onOpen);
}

class _Fallback extends StatelessWidget {
  final NewsPost post;
  final VoidCallback onOpen;

  const _Fallback({required this.post, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: YoutubeThumbnailLayer(
          post: post,
          immersive: false,
          showPlay: true,
          onPlay: onOpen,
        ),
      ),
    );
  }
}
