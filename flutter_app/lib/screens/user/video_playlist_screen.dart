import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../services/video_playlist.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

/// Video playlist screen showing saved watch-later videos.
class VideoPlaylistScreen extends StatefulWidget {
  const VideoPlaylistScreen({super.key});

  @override
  State<VideoPlaylistScreen> createState() => _VideoPlaylistScreenState();
}

class _VideoPlaylistScreenState extends State<VideoPlaylistScreen> {
  List<NewsPost> _videos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    setState(() => _loading = true);
    try {
      final videos = await VideoPlaylistService.getAll();
      if (mounted) {
        setState(() {
          _videos = videos;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear playlist?'),
        content: const Text('Remove all videos from your playlist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await VideoPlaylistService.clear();
      await _loadPlaylist();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final isDark = FeedXpressoTheme.isDark(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch Later'),
        actions: [
          if (_videos.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear all',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _videos.isEmpty
              ? EmptyState(
                  icon: Icons.video_library_outlined,
                  title: 'No videos saved yet',
                  subtitle: 'Videos you save for later will appear here.',
                  buttonLabel: 'Browse videos',
                  onButtonTap: () => context.go('/shorts'),
                  dark: isDark,
                )
              : RefreshIndicator(
                  onRefresh: _loadPlaylist,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _videos.length,
                    itemBuilder: (context, index) {
                      final post = _videos[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => context.go('/article/${post.id}'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Container(
                                  color: fx.surfaceElevated,
                                  child: Center(
                                    child: Icon(
                                      Icons.play_circle_outline,
                                      size: 48,
                                      color: fx.textSecondary.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post.title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: fx.textPrimary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (post.sourceName != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          post.sourceName!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: fx.textSecondary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
