import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../constants.dart';
import '../../users/media_widgets.dart';
import '../../widgets/location_label.dart';
import '../../widgets/shimmer_widgets.dart';

/// Media shown below the byline: videos, multi-asset posts, or extra items after the app-bar hero image.
List<MediaItem> _bodyMediaForGallery(NewsPost post) {
  final list = post.media;
  if (list.isEmpty) return const [];
  if (list.length == 1) {
    return list.first.isVideo ? list : const [];
  }
  if (!post.hasImages) return list;
  final heroImg = list.firstWhere((m) => m.isImage);
  final rest = list.where((m) => m.id != heroImg.id).toList();
  return rest.isNotEmpty ? rest : list;
}

class ArticleDetailScreen extends StatefulWidget {
  final String postId;
  const ArticleDetailScreen({super.key, required this.postId});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  NewsPost? _post;
  List<Comment> _comments = [];
  bool _loading = true;
  bool _liked = false;
  bool _bookmarked = false;
  double _readScale = 1.0;
  String? _fullText;
  bool _fullLoading = false;
  String? _fullError;
  bool _fullTriedByUser = false;
  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loggedIn = context.read<AuthProvider>().isLoggedIn;
    final postRes = await ApiService.getPost(widget.postId);
    final commentRes = await ApiService.getComments(widget.postId);
    final guestLiked = await ApiService.isGuestLiked(widget.postId);
    final guestBookmarked = await ApiService.isGuestBookmarked(widget.postId);
    final guestComments = await ApiService.getGuestComments(widget.postId);
    if (mounted) {
      setState(() {
        if (postRes['success'] == true) {
          _post = NewsPost.fromJson(postRes['post']);
        }
        if (commentRes['success'] == true) {
          _comments = (commentRes['comments'] as List)
              .map((c) => Comment.fromJson(c))
              .toList();
        }
        if (!loggedIn) {
          _liked = guestLiked;
          _bookmarked = guestBookmarked;
          _comments = [...guestComments, ..._comments];
        }
        _loading = false;
      });
    }
  }

  String _displayText(NewsPost post) {
    final short = post.summary?.trim();
    if (_fullText != null && _fullText!.trim().isNotEmpty) {
      return _fullText!.trim();
    }
    if (short != null && short.isNotEmpty) return short;
    final body = post.body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (body.length <= 420) return body;
    return '${body.substring(0, 420).trim()}...';
  }

  bool _shouldTryExtract(NewsPost post) {
    final url = post.sourceUrl?.trim();
    if (url == null || url.isEmpty) return false;
    // Heuristic: reporter stories (no sourceUrl OR has location/media) are already full.
    // For API-ingested items (sourceUrl present), try extraction.
    return true;
  }

  Future<void> _loadFullIfPossible({required bool showError}) async {
    final post = _post;
    if (post == null) return;
    if (_fullLoading || _fullText != null) return;
    if (!_shouldTryExtract(post)) return;

    setState(() {
      _fullLoading = true;
      _fullError = null;
    });
    final res = await ApiService.extractArticle(post.sourceUrl!.trim());
    if (!mounted) return;
    final text = res['text']?.toString();
    if (res['success'] == true && text != null && text.trim().isNotEmpty) {
      setState(() {
        _fullText = text.trim();
        _fullLoading = false;
        _fullError = null;
      });
      return;
    }
    if (!showError) {
      setState(() {
        _fullLoading = false;
        _fullError = null;
      });
      return;
    }
    setState(() {
      _fullLoading = false;
      _fullError =
          (res['message'] ?? 'Could not load full article.').toString();
    });
  }

  Future<void> _toggleLike() async {
    final loggedIn = context.read<AuthProvider>().isLoggedIn;
    if (!loggedIn) {
      final liked = await ApiService.toggleGuestLike(widget.postId);
      if (!mounted) return;
      setState(() {
        _liked = liked;
        if (_post != null) {
          final likes =
              liked ? _post!.likes + 1 : (_post!.likes - 1).clamp(0, 1 << 30);
          _post = NewsPost.fromJson({..._post!.toJsonMap(), 'likes': likes});
        }
      });
      return;
    }

    final res = await ApiService.toggleLike(widget.postId);
    if (res['success'] != true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(res['message'] ?? 'Please sign in to continue.')),
      );
      return;
    }
    if (res['success'] == true && mounted) {
      setState(() {
        _liked = res['liked'];
        if (_post != null) {
          _post =
              NewsPost.fromJson({..._post!.toJsonMap(), 'likes': res['likes']});
        }
      });
    }
  }

  Future<void> _toggleBookmark() async {
    final loggedIn = context.read<AuthProvider>().isLoggedIn;
    if (!loggedIn && _post != null) {
      final bookmarked = await ApiService.toggleGuestBookmark(_post!);
      if (!mounted) return;
      setState(() => _bookmarked = bookmarked);
      return;
    }

    final res = await ApiService.toggleBookmark(widget.postId);
    if (res['success'] != true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(res['message'] ?? 'Please sign in to continue.')),
      );
      return;
    }
    if (res['success'] == true && mounted) {
      setState(() => _bookmarked = res['bookmarked']);
    }
  }

  Future<void> _shareArticle() async {
    if (_post == null) return;
    final post = _post!;
    final buf = StringBuffer();
    buf.writeln(post.title);
    buf.writeln();
    final preview =
        post.summary?.trim().isNotEmpty == true ? post.summary! : post.body;
    final ex = preview.length > 600 ? '${preview.substring(0, 600)}…' : preview;
    buf.writeln(ex);
    if (post.sourceUrl?.trim().isNotEmpty == true) {
      buf.writeln();
      buf.writeln(post.sourceUrl);
    }
    final text = buf.toString();
    try {
      Rect? shareOrigin;
      final ro = context.findRenderObject();
      if (ro is RenderBox) {
        final topLeft = ro.localToGlobal(Offset.zero);
        shareOrigin = Rect.fromLTWH(
          topLeft.dx,
          topLeft.dy,
          ro.size.width,
          ro.size.height,
        );
      }
      await Share.share(
        text,
        subject: post.title,
        sharePositionOrigin: shareOrigin,
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Article copied — paste anywhere to share'),
          ),
        );
      }
    }
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final loggedIn = context.read<AuthProvider>().isLoggedIn;
    if (!loggedIn) {
      final created = await ApiService.addGuestComment(widget.postId, text);
      if (!mounted) return;
      _commentCtrl.clear();
      setState(() => _comments.insert(0, Comment.fromJson(created)));
      return;
    }

    final res = await ApiService.addComment(widget.postId, text);
    if (res['success'] != true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(res['message'] ?? 'Please sign in to continue.')),
      );
      return;
    }
    if (res['success'] == true && mounted) {
      _commentCtrl.clear();
      setState(() => _comments.insert(0, Comment.fromJson(res['comment'])));
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  bool _looksLikeLogoUrl(String url) {
    final u = url.toLowerCase();
    // URL pattern checks for logos/icons
    if (u.contains('logo') ||
        u.contains('favicon') ||
        u.contains('/s2/favicons') ||
        u.contains('clearbit.com/logo') ||
        u.contains('icon') ||
        u.contains('sprite') ||
        u.contains('placeholder') ||
        u.contains('default') ||
        u.contains('avatar') ||
        u.contains('profile') ||
        u.contains('1x1') ||
        u.contains('pixel') ||
        u.endsWith('.svg') ||
        u.endsWith('.ico')) {
      return true;
    }
    // Check for small dimension indicators in URL (e.g., 180x180, 64x64)
    final sizePattern = RegExp(r'[/_-](\d{2,3})x(\d{2,3})[/_.]');
    final match = sizePattern.firstMatch(u);
    if (match != null) {
      final w = int.tryParse(match.group(1) ?? '') ?? 0;
      final h = int.tryParse(match.group(2) ?? '') ?? 0;
      if (w > 0 && h > 0 && w <= 256 && h <= 256) {
        return true;
      }
    }
    return false;
  }

  List<Widget> _paragraphs(String text, TextStyle style) {
    final raw = text.replaceAll('\r\n', '\n');
    final parts = raw
        .split(RegExp(r'\n\s*\n+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return [Text(text, style: style)];
    }
    return [
      for (var i = 0; i < parts.length; i++) ...[
        Text(parts[i], style: style),
        if (i != parts.length - 1) const SizedBox(height: AppSpacing.s12),
      ]
    ];
  }

  Widget _glassActionShell({required Widget child}) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.50),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _glassActionIcon({
    required Widget icon,
    required VoidCallback? onPressed,
    String? tooltip,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: _glassActionShell(child: icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (_loading) {
      return Scaffold(
        backgroundColor: p.glassSurface,
        body: const ArticleDetailShimmer(),
      );
    }
    if (_post == null) {
      return const Scaffold(body: Center(child: Text('Article not found.')));
    }
    final post = _post!;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(_readScale),
      ),
      child: Scaffold(
        backgroundColor: p.scaffoldBackground,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              stretch: true,
              expandedHeight:
                  (post.hasImages && !_looksLikeLogoUrl(post.firstImage!.url))
                      ? 220
                      : 0,
              pinned: true,
              backgroundColor:
                  (post.hasImages && !_looksLikeLogoUrl(post.firstImage!.url))
                      ? p.surface.withValues(alpha: 0.62)
                      : p.surface,
              foregroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.white),
              flexibleSpace: (post.hasImages &&
                      !_looksLikeLogoUrl(post.firstImage!.url))
                  ? FlexibleSpaceBar(
                      stretchModes: const [
                        StretchMode.zoomBackground,
                        StretchMode.blurBackground,
                      ],
                      collapseMode: CollapseMode.parallax,
                      background: Hero(
                        tag: 'post-hero-${post.id}',
                        child: Material(
                          type: MaterialType.transparency,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: AppConstants.imageUrlForDisplay(
                                  post.firstImage!.url,
                                  articleReferer: post.sourceUrl,
                                ),
                                imageBuilder: (context, provider) {
                                  final isLogo =
                                      _looksLikeLogoUrl(post.firstImage!.url);
                                  return Container(
                                    color: p.scaffoldBackground,
                                    padding: isLogo
                                        ? const EdgeInsets.all(14)
                                        : EdgeInsets.zero,
                                    alignment: Alignment.center,
                                    child: Image(
                                      image: provider,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: isLogo
                                          ? BoxFit.contain
                                          : BoxFit.cover,
                                      alignment: Alignment.center,
                                      filterQuality: FilterQuality.high,
                                    ),
                                  );
                                },
                                memCacheWidth: kIsWeb ? null : 2200,
                                fadeInDuration:
                                    const Duration(milliseconds: 280),
                                placeholder: (_, __) => Container(
                                  color: p.scaffoldBackground,
                                  alignment: Alignment.center,
                                  child: const CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: p.scaffoldBackground,
                                  alignment: Alignment.center,
                                  child: Icon(
                                      Icons.image_not_supported_outlined,
                                      color: p.textHint,
                                      size: 48),
                                ),
                              ),
                              // Ensures top-right actions/back button are always readable.
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.78),
                                          Colors.black.withValues(alpha: 0.16),
                                          Colors.black.withValues(alpha: 0.56),
                                        ],
                                        stops: const [0.0, 0.50, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : null,
              actions: [
                _glassActionIcon(
                  tooltip: _fullText != null
                      ? 'Full article loaded'
                      : 'Load full article',
                  icon: Icon(
                    Icons.article_outlined,
                    color: _fullText != null ? p.primary : Colors.white,
                  ),
                  onPressed: _fullLoading
                      ? null
                      : () async {
                          setState(() => _fullTriedByUser = true);
                          await _loadFullIfPossible(showError: true);
                        },
                ),
                PopupMenuButton<double>(
                  tooltip: 'Text size',
                  icon: _glassActionShell(
                    child: const Icon(Icons.text_fields_rounded,
                        color: Colors.white),
                  ),
                  onSelected: (v) => setState(() => _readScale = v),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 0.92, child: Text('Smaller')),
                    const PopupMenuItem(value: 1.0, child: Text('Default')),
                    const PopupMenuItem(value: 1.1, child: Text('Larger')),
                    const PopupMenuItem(value: 1.22, child: Text('Largest')),
                  ],
                ),
                _glassActionIcon(
                  icon: Icon(_liked ? Icons.favorite : Icons.favorite_border,
                      color: _liked ? Colors.red : Colors.white),
                  onPressed: _toggleLike,
                ),
                _glassActionIcon(
                  icon: Icon(
                      _bookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: _bookmarked ? p.primary : Colors.white),
                  onPressed: _toggleBookmark,
                ),
                _glassActionIcon(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: _shareArticle,
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: AppSpacing.page,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category & breaking badge
                        Wrap(spacing: AppSpacing.s8, children: [
                          if (post.isBreaking)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.s8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: p.breaking,
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Text(
                                'BREAKING',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.2),
                              ),
                            ),
                          if (post.category != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.s8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: p.categoryChipBg,
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(
                                  '${post.category!.icon} ${post.category!.name}',
                                  style: TextStyle(
                                      color: p.primaryDark,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ),
                          if ((post.constituency ?? '').trim().isNotEmpty &&
                              (post.constituency ?? '').trim().toLowerCase() !=
                                  'unknown')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.s8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: p.primary.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(
                                  '📍 ${(post.constituency ?? '').trim()}',
                                  style: TextStyle(
                                      color: p.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                        ]),
                        const SizedBox(height: AppSpacing.s16),

                        // Title
                        Text(
                          post.title,
                          style: context.titleText.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.18,
                            letterSpacing: -0.3,
                            color: p.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        // Meta
                        Wrap(
                          spacing: AppSpacing.s12,
                          runSpacing: AppSpacing.s8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (post.reporter != null)
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                CircleAvatar(
                                    radius: 14,
                                    backgroundColor: p.primary,
                                    child: Text(post.reporter!.name[0],
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12))),
                                const SizedBox(width: AppSpacing.s8),
                                Text(
                                  post.reporter!.name,
                                  style: context.subtitleText.copyWith(
                                    color: p.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ]),
                            Text(
                              timeago.format(post.createdAt),
                              style:
                                  context.metaText.copyWith(color: p.textHint),
                            ),
                          ],
                        ),

                        if (post.location != null) ...[
                          const SizedBox(height: AppSpacing.s8),
                          LocationLabel(
                            location: post.location!,
                            style: TextStyle(fontSize: 12, color: p.textHint),
                            iconSize: 14,
                          ),
                        ],

                        if (_bodyMediaForGallery(post).isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.s16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child:
                                MediaGallery(media: _bodyMediaForGallery(post)),
                          ),
                        ],

                        const SizedBox(height: AppSpacing.s24),
                        Divider(height: 1, color: p.glassBorder),
                        const SizedBox(height: AppSpacing.s16),

                        // Article body
                        if (_fullLoading)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.s12),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: p.primary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s12),
                                Text(
                                  'Loading full article…',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: p.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_fullError != null && _fullTriedByUser)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.s12),
                            child: Text(
                              _fullError!,
                              style: TextStyle(
                                fontSize: 12,
                                color: p.error,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ..._paragraphs(
                          _displayText(post),
                          Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: p.textPrimary,
                                    fontSize: 15,
                                    height: 1.85,
                                  ) ??
                              TextStyle(
                                fontSize: 15,
                                height: 1.85,
                                color: p.textPrimary,
                              ),
                        ),

                        // Tags
                        if (post.tags.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.s24),
                          Wrap(
                            spacing: AppSpacing.s8,
                            runSpacing: AppSpacing.s8,
                            children: post.tags
                                .map((tag) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.s12,
                                          vertical: 4),
                                      decoration: BoxDecoration(
                                          color: p.inputFill,
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Text('#$tag',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: p.textSecondary)),
                                    ))
                                .toList(),
                          ),
                        ],

                        // Stats row
                        const SizedBox(height: AppSpacing.s24),
                        Row(children: [
                          Icon(Icons.visibility_outlined,
                              size: 16, color: p.textHint),
                          const SizedBox(width: 4),
                          Text('${post.views} views',
                              style:
                                  TextStyle(fontSize: 13, color: p.textHint)),
                          const SizedBox(width: 16),
                          Icon(_liked ? Icons.favorite : Icons.favorite_border,
                              size: 16,
                              color: _liked ? Colors.red : p.textHint),
                          const SizedBox(width: 4),
                          Text('${post.likes} likes',
                              style:
                                  TextStyle(fontSize: 13, color: p.textHint)),
                        ]),

                        const SizedBox(height: AppSpacing.s24),
                        Divider(height: 1, color: p.glassBorder),
                        const SizedBox(height: AppSpacing.s16),

                        // Comments section
                        Text('Comments (${_comments.length})',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: p.textPrimary)),
                        const SizedBox(height: AppSpacing.s12),

                        // Add comment
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _commentCtrl,
                              decoration: InputDecoration(
                                hintText: 'Write a comment...',
                                hintStyle: const TextStyle(fontSize: 14),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.s12, vertical: 10),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          IconButton(
                            icon: Icon(Icons.send, color: p.primary),
                            onPressed: _submitComment,
                          ),
                        ]),

                        const SizedBox(height: AppSpacing.s16),

                        // Comments list
                        ..._comments.map((c) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.s12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                      radius: 16,
                                      backgroundColor: p.primary,
                                      child: Text(c.user?.name[0] ?? '?',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12))),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(c.user?.name ?? 'User',
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500)),
                                          const SizedBox(height: 2),
                                          Text(c.text,
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  color: p.textPrimary)),
                                          const SizedBox(height: 3),
                                          Text(timeago.format(c.createdAt),
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: p.textHint)),
                                        ]),
                                  ),
                                ],
                              ),
                            )),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Extension to allow NewsPost to export a map (for local mutation)
extension NewPostMap on NewsPost {
  Map<String, dynamic> toJsonMap() => {
        '_id': id,
        'title': title,
        'body': body,
        'summary': summary,
        'reporter': reporter != null
            ? {
                '_id': reporter!.id,
                'name': reporter!.name,
                'avatar': reporter!.avatar
              }
            : null,
        'category': category != null
            ? {
                '_id': category!.id,
                'name': category!.name,
                'slug': category!.slug,
                'icon': category!.icon,
                'color': category!.color
              }
            : null,
        'media': media
            .map((m) => {
                  '_id': m.id,
                  'type': m.type,
                  'url': m.url,
                  'thumbnail': m.thumbnail,
                  'size': m.size
                })
            .toList(),
        'location': location != null
            ? {
                'latitude': location!.latitude,
                'longitude': location!.longitude,
                'address': location!.address,
                'city': location!.city,
                'state': location!.state,
                'country': location!.country
              }
            : null,
        'status': status,
        'rejectionReason': rejectionReason,
        'views': views,
        'likes': likes,
        'isBreaking': isBreaking,
        'isFeatured': isFeatured,
        'tags': tags,
        'sourceUrl': sourceUrl,
        'sourceName': sourceName,
        'language': language,
        'createdAt': createdAt.toIso8601String(),
      };
}
