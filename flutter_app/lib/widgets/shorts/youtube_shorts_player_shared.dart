import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../utils/youtube_thumb_url.dart';

/// Full-screen 9:16 frame for Shorts video/thumbnail.
class ShortsVideoFrame extends StatelessWidget {
  final Widget child;

  const ShortsVideoFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: ClipRect(child: child),
            ),
          ),
        ],
      ),
    );
  }
}

/// HD YouTube thumbnail with maxres → hq → sd fallback.
class HdYoutubeThumbnail extends StatefulWidget {
  final NewsPost post;

  const HdYoutubeThumbnail({super.key, required this.post});

  @override
  State<HdYoutubeThumbnail> createState() => _HdYoutubeThumbnailState();
}

class _HdYoutubeThumbnailState extends State<HdYoutubeThumbnail> {
  int _urlIndex = 0;

  List<String> get _urls {
    final vid = widget.post.youtube?.videoId;
    if (vid == null || vid.isEmpty) {
      final stored = widget.post.youtubeThumbnailUrl;
      return stored.isEmpty ? const [] : [stored];
    }
    // Web: load hq first (smaller/faster); mobile: maxres then fallbacks.
    if (kIsWeb) {
      return [
        YoutubeThumbUrl.high(vid),
        YoutubeThumbUrl.maxRes(vid),
        YoutubeThumbUrl.standard(vid),
      ];
    }
    return YoutubeThumbUrl.fallbacks(vid);
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    if (urls.isEmpty) {
      return const ColoredBox(color: Color(0xFF141414));
    }
    final idx = _urlIndex.clamp(0, urls.length - 1);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memW = (MediaQuery.sizeOf(context).width * dpr).round().clamp(720, 1920);

    return CachedNetworkImage(
      imageUrl: urls[idx],
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: memW,
      fadeInDuration: const Duration(milliseconds: 120),
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => const ColoredBox(color: Color(0xFF141414)),
      errorWidget: (_, __, ___) {
        if (idx + 1 < urls.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _urlIndex != idx) return;
            setState(() => _urlIndex = idx + 1);
          });
        }
        return const ColoredBox(color: Color(0xFF141414));
      },
    );
  }
}

class YoutubeThumbnailLayer extends StatelessWidget {
  final NewsPost post;
  final bool showPlay;
  final VoidCallback? onPlay;
  final bool immersive;

  const YoutubeThumbnailLayer({
    super.key,
    required this.post,
    this.showPlay = false,
    this.onPlay,
    this.immersive = true,
  });

  @override
  Widget build(BuildContext context) {
    final stack = Stack(
      fit: StackFit.expand,
      children: [
        HdYoutubeThumbnail(post: post),
        if (showPlay && onPlay != null)
          Center(
            child: GestureDetector(
              onTap: onPlay,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
        if (immersive)
          Positioned(
            top: 12,
            left: 12,
            child: YoutubeBadge(channel: post.youtubeChannelLabel),
          ),
      ],
    );
    if (!immersive) {
      return ColoredBox(
        color: Colors.black,
        child: SizedBox.expand(child: stack),
      );
    }
    return ShortsVideoFrame(child: stack);
  }
}

class YoutubeUnmuteChip extends StatelessWidget {
  final bool muted;
  final VoidCallback onTap;

  const YoutubeUnmuteChip({
    super.key,
    required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!muted) return const SizedBox.shrink();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.volume_off_rounded, color: Colors.white, size: 18),
            SizedBox(width: 6),
            Text(
              'Tap to unmute',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class YoutubeFallbackCard extends StatelessWidget {
  final NewsPost post;

  const YoutubeFallbackCard({super.key, required this.post});

  Future<void> _openExternal(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xCC000000),
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
                onPressed: () => _openExternal(post.youtubeWatchUrl),
                icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
                label: const Text('Open on YouTube'),
              ),
              if (post.youtubeChannelUrl != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _openExternal(post.youtubeChannelUrl),
                  child: Text('View ${post.youtubeChannelLabel}'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class YoutubeBadge extends StatelessWidget {
  final String channel;

  const YoutubeBadge({super.key, required this.channel});

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
