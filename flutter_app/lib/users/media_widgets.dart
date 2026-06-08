import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/models.dart';
import '../constants.dart';
import '../theme/app_palette.dart';
import '../utils/youtube_iframe_html.dart';
import '../utils/youtube_thumb_url.dart';
import '../utils/youtube_url.dart';

// Full-screen photo viewer
class PhotoViewer extends StatelessWidget {
  final String imageUrl;
  const PhotoViewer({super.key, required this.imageUrl});

  static void show(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhotoViewer(imageUrl: imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: AppConstants.resolveMediaUrl(imageUrl),
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
            errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 60),
          ),
        ),
      ),
    );
  }
}

// Inline video player — direct MP4/HLS only (not YouTube watch URLs).
class InlineVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const InlineVideoPlayer({super.key, required this.videoUrl});

  @override
  State<InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<InlineVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _playing = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (isYoutubeVideoUrl(widget.videoUrl)) {
      _failed = true;
      return;
    }
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(AppConstants.resolveMediaUrl(widget.videoUrl)),
    )
      ..initialize().timeout(const Duration(seconds: 12)).then((_) {
        if (mounted) setState(() => _initialized = true);
      }).catchError((_) {
        if (mounted) setState(() => _failed = true);
      });
    _controller!.addListener(() {
      if (mounted) setState(() => _playing = _controller!.value.isPlaying);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (_failed) {
      return Container(
        height: 220,
        color: Colors.black,
        alignment: Alignment.center,
        child: const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 40),
      );
    }
    if (!_initialized) {
      return Container(
        height: 220,
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller!),
          GestureDetector(
            onTap: () {
              _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
            },
            child: AnimatedOpacity(
              opacity: _playing ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
              ),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: VideoProgressIndicator(_controller!, allowScrubbing: true, colors: VideoProgressColors(playedColor: p.primary)),
          ),
        ],
      ),
    );
  }
}

/// YouTube embed for article detail — thumbnail first, WebView on tap.
class ArticleYoutubePlayer extends StatefulWidget {
  final NewsPost post;

  const ArticleYoutubePlayer({super.key, required this.post});

  @override
  State<ArticleYoutubePlayer> createState() => _ArticleYoutubePlayerState();
}

class _ArticleYoutubePlayerState extends State<ArticleYoutubePlayer> {
  WebViewController? _controller;
  bool _embedMounted = false;
  bool _embedFailed = false;

  String? get _videoId {
    final fromMeta = widget.post.youtube?.videoId;
    if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;
    final fromMedia = widget.post.firstVideo?.url;
    if (fromMedia != null) return youtubeVideoIdFromUrl(fromMedia);
    return youtubeVideoIdFromUrl(widget.post.sourceUrl ?? '');
  }

  String get _thumbUrl {
    final vid = _videoId;
    if (vid != null && vid.isNotEmpty) {
      return YoutubeThumbUrl.high(vid);
    }
    final stored = widget.post.youtubeThumbnailUrl;
    if (stored.isNotEmpty) return stored;
    final mediaThumb = widget.post.firstVideo?.thumbnail;
    if (mediaThumb != null && mediaThumb.trim().isNotEmpty) {
      return AppConstants.resolveMediaUrl(mediaThumb);
    }
    return '';
  }

  Future<void> _openExternal() async {
    final url = widget.post.youtubeWatchUrl;
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _mountEmbed() {
    if (_embedMounted || _embedFailed) return;
    final videoId = _videoId;
    if (videoId == null || videoId.isEmpty) {
      _openExternal();
      return;
    }
    if (widget.post.youtube?.embeddable == false) {
      _openExternal();
      return;
    }

    final html = YoutubeIframeHtml.playerPage(
      videoId: videoId,
      elementId: 'yt-article-${widget.post.id}',
      autoplay: true,
      mute: false,
      enableIntersectionObserver: false,
      showControls: true,
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (msg) {
          if (msg.message == 'error' && mounted) {
            setState(() => _embedFailed = true);
          }
        },
      )
      ..loadHtmlString(html, baseUrl: 'https://www.youtube-nocookie.com');

    setState(() => _embedMounted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_embedFailed) {
      return _YoutubeThumbnailTap(
        thumbUrl: _thumbUrl,
        onTap: _openExternal,
        label: 'Watch on YouTube',
      );
    }

    if (_embedMounted && _controller != null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: WebViewWidget(controller: _controller!),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: _YoutubeThumbnailTap(
        thumbUrl: _thumbUrl,
        onTap: _mountEmbed,
        label: null,
      ),
    );
  }
}

class _YoutubeThumbnailTap extends StatelessWidget {
  final String thumbUrl;
  final VoidCallback onTap;
  final String? label;

  const _YoutubeThumbnailTap({
    required this.thumbUrl,
    required this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: thumbUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => const ColoredBox(color: Color(0xFF141414)),
                errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF141414)),
              )
            else
              const ColoredBox(color: Color(0xFF141414)),
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
              ),
            ),
            if (label != null)
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(label!, style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Media gallery — horizontal scrollable thumbnails for an article
class MediaGallery extends StatelessWidget {
  final List<MediaItem> media;
  final NewsPost? post;

  const MediaGallery({super.key, required this.media, this.post});

  bool _isYoutubeVideo(MediaItem item) {
    if (post?.isYoutube == true) return item.isVideo;
    return item.isVideo && isYoutubeVideoUrl(item.url);
  }

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    // Single image — full width
    if (media.length == 1 && media.first.isImage) {
      return GestureDetector(
        onTap: () => PhotoViewer.show(context, AppConstants.resolveMediaUrl(media.first.url)),
        child: CachedNetworkImage(
          imageUrl: AppConstants.resolveMediaUrl(media.first.url),
          width: double.infinity,
          height: 220,
          fit: BoxFit.cover,
        ),
      );
    }

    // Single video — YouTube uses embed/thumbnail, not raw network player
    if (media.length == 1 && media.first.isVideo) {
      if (_isYoutubeVideo(media.first) && post != null) {
        return ArticleYoutubePlayer(post: post!);
      }
      if (isYoutubeVideoUrl(media.first.url)) {
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: _YoutubeThumbnailTap(
            thumbUrl: AppConstants.resolveMediaUrl(media.first.thumbnail ?? ''),
            onTap: () async {
              final uri = Uri.tryParse(AppConstants.resolveMediaUrl(media.first.url));
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            label: 'Watch on YouTube',
          ),
        );
      }
      return InlineVideoPlayer(videoUrl: AppConstants.resolveMediaUrl(media.first.url));
    }

    // Multiple — horizontal scroll
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: media.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = media[i];
          final p = context.palette;
          return GestureDetector(
            onTap: () {
              if (item.isImage) PhotoViewer.show(context, AppConstants.resolveMediaUrl(item.url));
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: AppConstants.resolveMediaUrl(item.isVideo ? (item.thumbnail ?? item.url) : item.url),
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(width: 200, height: 200, color: const Color(0xFFF0F0F0)),
                    errorWidget: (_, __, ___) => Container(width: 200, height: 200, color: const Color(0xFFF0F0F0), child: Icon(Icons.broken_image, color: p.textHint)),
                  ),
                  if (item.isVideo)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black26,
                        child: const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 44)),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}