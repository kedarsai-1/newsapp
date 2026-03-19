import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../models/models.dart';
import '../constants.dart';

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
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
            errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 60),
          ),
        ),
      ),
    );
  }
}

// Inline video player
class InlineVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const InlineVideoPlayer({super.key, required this.videoUrl});

  @override
  State<InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<InlineVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      });
    _controller.addListener(() {
      if (mounted) setState(() => _playing = _controller.value.isPlaying);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(
        height: 220,
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller),
          GestureDetector(
            onTap: () {
              _controller.value.isPlaying ? _controller.pause() : _controller.play();
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
            child: VideoProgressIndicator(_controller, allowScrubbing: true, colors: const VideoProgressColors(playedColor: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

// Media gallery — horizontal scrollable thumbnails for an article
class MediaGallery extends StatelessWidget {
  final List<MediaItem> media;
  const MediaGallery({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    // Single image — full width
    if (media.length == 1 && media.first.isImage) {
      return GestureDetector(
        onTap: () => PhotoViewer.show(context, media.first.url),
        child: CachedNetworkImage(
          imageUrl: media.first.url,
          width: double.infinity,
          height: 220,
          fit: BoxFit.cover,
        ),
      );
    }

    // Single video
    if (media.length == 1 && media.first.isVideo) {
      return InlineVideoPlayer(videoUrl: media.first.url);
    }

    // Multiple — horizontal scroll
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: media.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final item = media[i];
          return GestureDetector(
            onTap: () {
              if (item.isImage) PhotoViewer.show(context, item.url);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: item.isVideo ? (item.thumbnail ?? item.url) : item.url,
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(width: 200, height: 200, color: const Color(0xFFF0F0F0)),
                    errorWidget: (_, __, ___) => Container(width: 200, height: 200, color: const Color(0xFFF0F0F0), child: const Icon(Icons.broken_image, color: AppColors.textHint)),
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