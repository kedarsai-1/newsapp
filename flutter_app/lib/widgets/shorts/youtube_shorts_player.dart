import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../models/models.dart';

/// Thumbnail-first YouTube shorts player — one iframe controller at a time.
class YoutubeShortsPlayer extends StatefulWidget {
  final NewsPost post;
  final bool isActive;

  const YoutubeShortsPlayer({
    super.key,
    required this.post,
    required this.isActive,
  });

  @override
  State<YoutubeShortsPlayer> createState() => _YoutubeShortsPlayerState();
}

class _YoutubeShortsPlayerState extends State<YoutubeShortsPlayer> {
  YoutubePlayerController? _controller;
  bool _playRequested = false;
  bool _embedFailed = false;

  @override
  void initState() {
    super.initState();
    _maybeAutoPlay();
  }

  @override
  void didUpdateWidget(YoutubeShortsPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _disposeController();
      _playRequested = false;
      _embedFailed = false;
      _maybeAutoPlay();
      return;
    }
    if (oldWidget.isActive != widget.isActive) {
      if (!widget.isActive) {
        _disposeController();
        _playRequested = false;
      } else {
        _maybeAutoPlay();
      }
    }
  }

  void _maybeAutoPlay() {
    if (!widget.isActive || _playRequested || _embedFailed) return;
    if (widget.post.youtube?.embeddable == false) return;
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (!mounted || !widget.isActive || _playRequested) return;
      _startEmbed();
    });
  }

  void _startEmbed() {
    final videoId = widget.post.youtube?.videoId;
    if (videoId == null || videoId.isEmpty) return;
    if (widget.post.youtube?.embeddable == false) {
      setState(() => _embedFailed = true);
      return;
    }
    setState(() => _playRequested = true);
    _disposeController();
    final controller = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        strictRelatedVideos: true,
        playsInline: true,
        enableCaption: false,
        showFullscreenButton: false,
      ),
    );
    controller.listen((value) {
      if (!mounted) return;
      if (value.hasError) {
        setState(() {
          _embedFailed = true;
          _playRequested = false;
        });
        _disposeController();
      }
    });
    _controller = controller;
    setState(() {});
  }

  void _disposeController() {
    _controller?.close();
    _controller = null;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  Future<void> _openExternal(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _thumbnailLayer() {
    final thumb = widget.post.youtubeThumbnailUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumb.isNotEmpty)
          CachedNetworkImage(
            imageUrl: thumb,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (_, __) => const ColoredBox(color: Color(0xFF141414)),
            errorWidget: (_, __, ___) =>
                const ColoredBox(color: Color(0xFF141414)),
          )
        else
          const ColoredBox(color: Color(0xFF141414)),
        if (!_playRequested || _embedFailed)
          Center(
            child: GestureDetector(
              onTap: _embedFailed
                  ? () => _openExternal(widget.post.youtubeWatchUrl)
                  : _startEmbed,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: Icon(
                  _embedFailed ? Icons.open_in_new_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: _embedFailed ? 28 : 40,
                ),
              ),
            ),
          ),
        Positioned(
          top: 12,
          left: 12,
          child: _YoutubeBadge(channel: widget.post.youtubeChannelLabel),
        ),
      ],
    );
  }

  Widget _fallbackCard() {
    return ColoredBox(
      color: const Color(0xFF141414),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_disabled_outlined, color: Colors.white38, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Video unavailable in app',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _openExternal(widget.post.youtubeWatchUrl),
                icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
                label: const Text('Open on YouTube'),
              ),
              if (widget.post.youtubeChannelUrl != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _openExternal(widget.post.youtubeChannelUrl),
                  child: Text('View ${widget.post.youtubeChannelLabel}'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.post.youtube?.embeddable == false || _embedFailed) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _thumbnailLayer(),
          _fallbackCard(),
        ],
      );
    }

    if (_playRequested && _controller != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.black,
            child: Center(
              child: YoutubePlayer(
                controller: _controller!,
                aspectRatio: 9 / 16,
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: _YoutubeBadge(channel: widget.post.youtubeChannelLabel),
          ),
        ],
      );
    }

    return _thumbnailLayer();
  }
}

class _YoutubeBadge extends StatelessWidget {
  final String channel;

  const _YoutubeBadge({required this.channel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_circle_filled, color: Color(0xFFFF0000), size: 16),
          const SizedBox(width: 6),
          Text(
            'YouTube · $channel',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
