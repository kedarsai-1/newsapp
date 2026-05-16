import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../models/models.dart';
import '../premium_news_ui.dart';
import 'youtube_shorts_player.dart';

/// Full-bleed media for shorts — YouTube iframe or direct video/image fallback.
class ShortsMediaLayer extends StatefulWidget {
  final NewsPost post;
  final bool isActive;

  /// Full-bleed immersive vs filling a fixed aspect-ratio card slot.
  final bool immersive;

  const ShortsMediaLayer({
    super.key,
    required this.post,
    required this.isActive,
    this.immersive = true,
  });

  @override
  State<ShortsMediaLayer> createState() => _ShortsMediaLayerState();
}

class _ShortsMediaLayerState extends State<ShortsMediaLayer> {
  VideoPlayerController? _controller;
  bool _videoFailed = false;

  @override
  void initState() {
    super.initState();
    _maybeInitVideo();
  }

  @override
  void didUpdateWidget(ShortsMediaLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _disposeVideo();
      _videoFailed = false;
      _maybeInitVideo();
      return;
    }
    if (oldWidget.isActive != widget.isActive && _controller?.value.isInitialized == true) {
      if (widget.isActive) {
        _controller!.play();
      } else {
        _controller!.pause();
      }
    }
  }

  void _maybeInitVideo() {
    final vid = widget.post.firstVideo;
    if (vid == null || vid.url.trim().isEmpty) return;
    final uri = Uri.tryParse(vid.url.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      _videoFailed = true;
      return;
    }
    _controller = VideoPlayerController.networkUrl(uri)
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        if (widget.isActive) {
          _controller!.play();
        }
      }).catchError((_) {
        if (!mounted) return;
        setState(() {
          _videoFailed = true;
          _disposeVideo();
        });
      });
  }

  void _disposeVideo() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  Widget _imageBackdrop(String url, {int? memCacheWidth}) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: memCacheWidth,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => const ColoredBox(
        color: Color(0xFF141414),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => const ColoredBox(
        color: Color(0xFF141414),
        child: Center(
          child: Icon(Icons.article_outlined, color: Colors.white24, size: 56),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.post.isYoutube) {
      return YoutubeShortsPlayer(
        post: widget.post,
        isActive: widget.isActive,
        immersive: widget.immersive,
      );
    }

    final dpr = MediaQuery.of(context).devicePixelRatio;
    final memW = (MediaQuery.sizeOf(context).width * dpr).clamp(720, 1600).round();

    final vid = widget.post.firstVideo;
    if (vid != null &&
        vid.url.trim().isNotEmpty &&
        !_videoFailed &&
        _controller?.value.isInitialized == true) {
      final sz = _controller!.value.size;
      if (sz.width > 0 && sz.height > 0) {
        return ColoredBox(
          color: Colors.black,
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: sz.width,
              height: sz.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        );
      }
    }

    final imageUrl = premiumImageUrl(widget.post);
    if (imageUrl.isNotEmpty) {
      return _imageBackdrop(imageUrl, memCacheWidth: kIsWeb ? null : memW);
    }

    return const ColoredBox(
      color: Color(0xFF141414),
      child: Center(
        child: Icon(Icons.article_outlined, color: Colors.white24, size: 56),
      ),
    );
  }
}
