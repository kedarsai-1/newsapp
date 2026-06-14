import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../constants.dart';
import '../../users/media_widgets.dart';
import '../../widgets/location_label.dart';
import '../../utils/article_detail_text.dart';
import '../../utils/text_truncation.dart';
import '../../providers/news_provider.dart';
import '../../widgets/feed/article_youtube_player.dart';
import '../../widgets/shimmer_widgets.dart';

/// Media shown below the byline — skip YouTube posts (handled by [ArticleYoutubePlayer]).
List<MediaItem> _bodyMediaForGallery(NewsPost post) {
  if (post.isYoutube) return const [];
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
  final _commentCtrl = TextEditingController();
  final _commentFocus = FocusNode();
  final _scrollCtrl = ScrollController();
  final _commentsSectionKey = GlobalKey();

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
          context.read<NewsProvider>().markPostAsSeen(widget.postId);
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

  /// Article detail shows the stored AI summary — not the raw RSS body or scraped full article.
  String? _bodyText(NewsPost post) => articleDetailBodyText(post);

  Future<void> _openSourceArticle() async {
    final url = _post?.sourceUrl?.trim();
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _toggleLike() async {
    final previous = _liked;
    setState(() {
      _liked = !previous;
      if (_post != null) {
        final likes =
            _liked ? _post!.likes + 1 : (_post!.likes - 1).clamp(0, 1 << 30);
        _post = NewsPost.fromJson({..._post!.toJsonMap(), 'likes': likes});
      }
    });
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
      setState(() {
        _liked = previous;
        if (_post != null) {
          final likes =
              _liked ? _post!.likes + 1 : (_post!.likes - 1).clamp(0, 1 << 30);
          _post = NewsPost.fromJson({..._post!.toJsonMap(), 'likes': likes});
        }
      });
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
    final previous = _bookmarked;
    setState(() => _bookmarked = !previous);
    final loggedIn = context.read<AuthProvider>().isLoggedIn;
    if (!loggedIn && _post != null) {
      final bookmarked = await ApiService.toggleGuestBookmark(_post!);
      if (!mounted) return;
      setState(() => _bookmarked = bookmarked);
      return;
    }

    final res = await ApiService.toggleBookmark(widget.postId);
    if (res['success'] != true && mounted) {
      setState(() => _bookmarked = previous);
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
    final ex = truncateAtWordBoundary(
      preview.replaceAll(RegExp(r'\s+'), ' ').trim(),
      600,
    );
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToComments());
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToComments());
    }
  }

  void _focusCommentField() {
    _commentFocus.requestFocus();
  }

  void _scrollToComments() {
    final ctx = _commentsSectionKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  Widget _commentComposer(BuildContext context, dynamic p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16), // Floating margins
        child: GlassCard(
          radius: 28,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: isDark
              ? Colors.black.withOpacity(0.40)
              : Colors.white.withOpacity(0.65),
          borderColor: isDark
              ? Colors.white.withOpacity(0.16)
              : Colors.black.withOpacity(0.08),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  focusNode: _commentFocus,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submitComment(),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Write a comment…',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white.withOpacity(0.50) : p.textHint,
                    ),
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              _GlassActionIconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: isDark ? p.primary : p.primaryDark,
                  size: 18,
                ),
                onPressed: _submitComment,
                tooltip: 'Post comment',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocus.dispose();
    _scrollCtrl.dispose();
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

  List<Widget> _paragraphs(String text, TextStyle style, BuildContext context) {
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final raw = text.replaceAll('\r\n', '\n');
    final parts = raw
        .split(RegExp(r'\n\s*\n+'))
        .map((pr) => pr.trim())
        .where((pr) => pr.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return [_renderParagraph(text, style, p, isDark)];
    }
    return [
      for (var i = 0; i < parts.length; i++) ...[
        _renderParagraph(parts[i], style, p, isDark),
        if (i != parts.length - 1) const SizedBox(height: AppSpacing.s16),
      ]
    ];
  }

  Widget _renderParagraph(String paragraphText, TextStyle style, AppPalette p, bool isDark) {
    final isQuote = paragraphText.startsWith('>') || paragraphText.startsWith('"') || paragraphText.startsWith('“');
    var cleanText = paragraphText;
    if (paragraphText.startsWith('>')) {
      cleanText = paragraphText.substring(1).trim();
    }

    if (isQuote) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: p.primary,
              width: 4,
            ),
          ),
        ),
        child: Text(
          cleanText,
          style: style.copyWith(
            color: isDark ? Colors.white.withOpacity(0.92) : p.textPrimary.withOpacity(0.85),
            fontStyle: FontStyle.italic,
            fontSize: (style.fontSize ?? 15) + 1,
            height: 1.6,
          ),
        ),
      );
    }

    return Text(
      paragraphText,
      style: style.copyWith(
        letterSpacing: 0.15,
        color: isDark ? Colors.white.withOpacity(0.88) : p.textPrimary.withOpacity(0.92),
      ),
    );
  }

  Widget _glassActionShell({
    required BuildContext context,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withOpacity(0.40)
                : Colors.white.withOpacity(0.65),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.24)
                  : Colors.black.withOpacity(0.12),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _glassActionIcon({
    required BuildContext context,
    required Widget icon,
    required VoidCallback? onPressed,
    VoidCallback? onLongPress,
    String? tooltip,
  }) {
    return _GlassActionIconButton(
      icon: icon,
      onPressed: onPressed,
      onLongPress: onLongPress,
      tooltip: tooltip,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayBase = isDark ? Colors.black : Colors.white;
    final actionIconColor = isDark ? Colors.white : Colors.black;
    if (_loading) {
      return GlassBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: const ArticleDetailShimmer(),
        ),
      );
    }
    if (_post == null) {
      return const GlassBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: Text('Article not found.')),
        ),
      );
    }
    final post = _post!;
    final showHeroImage = !post.isYoutube &&
        post.hasImages &&
        !_looksLikeLogoUrl(post.firstImage!.url);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(_readScale),
      ),
      child: GlassBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          extendBody: true,
          bottomNavigationBar: _commentComposer(context, p),
          body: CustomScrollView(
          controller: _scrollCtrl,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              stretch: true,
              expandedHeight: showHeroImage ? 220 : 0,
              pinned: true,
              backgroundColor:
                  showHeroImage ? p.surface.withValues(alpha: 0.62) : p.surface,
              foregroundColor: Colors.white,
              iconTheme: IconThemeData(color: actionIconColor),
              flexibleSpace: showHeroImage
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
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(24),
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: AppConstants.imageUrlForDisplay(
                                    post.firstImage!.url,
                                    articleReferer: post.sourceUrl,
                                  ),
                                  imageBuilder: (context, provider) {
                                    final isLogo =
                                        _looksLikeLogoUrl(post.firstImage!.url);
                                    return Container(
                                      color: Colors.transparent,
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
                                    color: Colors.transparent,
                                    alignment: Alignment.center,
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: Colors.transparent,
                                    alignment: Alignment.center,
                                    child: Icon(
                                        Icons.image_not_supported_outlined,
                                        color: p.textHint,
                                        size: 48),
                                  ),
                                ),
                              ),
                              // Ensures top-right actions/back button are always readable.
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(24),
                                  ),
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            overlayBase.withOpacity(0.70),
                                            overlayBase.withOpacity(0.12),
                                            overlayBase.withOpacity(0.50),
                                          ],
                                          stops: const [0.0, 0.50, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Frosted bottom edge border
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 1,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.15)
                                      : Colors.black.withOpacity(0.08),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : null,
              actions: [
                if (post.sourceUrl?.trim().isNotEmpty == true)
                  _glassActionIcon(
                    context: context,
                    tooltip: 'Read original article',
                    icon: Icon(Icons.open_in_new_rounded, color: actionIconColor),
                    onPressed: _openSourceArticle,
                  ),
                PopupMenuButton<double>(
                  tooltip: 'Text size',
                  icon: _glassActionShell(
                    context: context,
                    child: Icon(Icons.text_fields_rounded, color: actionIconColor),
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
                  context: context,
                  icon: Icon(_liked ? Icons.favorite : Icons.favorite_border,
                      color: _liked ? Colors.red : actionIconColor),
                  onPressed: _toggleLike,
                ),
                _glassActionIcon(
                  context: context,
                  icon: Icon(
                      _bookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: _bookmarked ? p.primary : actionIconColor),
                  onPressed: _toggleBookmark,
                ),
                _glassActionIcon(
                  context: context,
                  icon: Icon(Icons.share_outlined, color: actionIconColor),
                  onPressed: _shareArticle,
                ),
                _glassActionIcon(
                  context: context,
                  tooltip: _comments.isEmpty
                      ? 'Comment'
                      : '${_comments.length} comments',
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(Icons.chat_bubble_outline, color: actionIconColor),
                      if (_comments.isNotEmpty)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            constraints: const BoxConstraints(minWidth: 14),
                            decoration: BoxDecoration(
                              color: p.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _comments.length > 99
                                  ? '99+'
                                  : '${_comments.length}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  onPressed: _focusCommentField,
                  onLongPress: _scrollToComments,
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
                        if (post.isYoutube && (post.youtube?.videoId ?? '').isNotEmpty) ...[
                          ArticleYoutubePlayer(post: post),
                          const SizedBox(height: 16),
                        ],
                        // Title Editorial Card
                        GlassCard(
                          margin: const EdgeInsets.only(bottom: 24),
                          radius: 24,
                          padding: const EdgeInsets.all(20),
                          borderColor: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.08),
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.50),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category & breaking badge
                              Wrap(
                                spacing: AppSpacing.s8,
                                runSpacing: 6,
                                children: [
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
                                            fontSize: 10,
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
                                              color: isDark ? p.primary : p.primaryDark,
                                              fontSize: 10,
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
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.s16),

                              // Title
                              Text(
                                post.title,
                                style: context.titleText.copyWith(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  height: 1.25,
                                  letterSpacing: -0.3,
                                  color: p.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s16),

                              // Meta (Reporter, time, location)
                              Row(
                                children: [
                                  if (post.reporter != null) ...[
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: p.primary,
                                      child: Text(
                                        post.reporter!.name[0].toUpperCase(),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.s8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            post.reporter!.name,
                                            style: context.subtitleText.copyWith(
                                              color: p.textPrimary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            timeago.format(post.displayTime),
                                            style: context.metaText.copyWith(
                                              color: p.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    Expanded(
                                      child: Text(
                                        timeago.format(post.displayTime),
                                        style: context.metaText.copyWith(
                                          color: p.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (post.location != null) ...[
                                    const SizedBox(width: AppSpacing.s8),
                                    LocationLabel(
                                      location: post.location!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: p.textSecondary,
                                      ),
                                      iconSize: 14,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

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

                        if (_bodyText(post) != null) ...[
                          ..._paragraphs(
                            _bodyText(post)!,
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
                            context,
                          ),
                        ],

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
                        Wrap(
                          spacing: AppSpacing.s12,
                          runSpacing: AppSpacing.s8,
                          children: [
                            // Views Chip
                            GlassCard(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              radius: 12,
                              color: isDark
                                  ? Colors.white.withOpacity(0.04)
                                  : Colors.black.withOpacity(0.03),
                              borderColor: isDark
                                  ? Colors.white.withOpacity(0.10)
                                  : Colors.black.withOpacity(0.06),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.visibility_outlined,
                                    size: 15,
                                    color: isDark ? Colors.white.withOpacity(0.70) : p.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${post.views} views',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white.withOpacity(0.80) : p.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Likes Chip
                            GestureDetector(
                              onTap: _toggleLike,
                              child: GlassCard(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                radius: 12,
                                color: isDark
                                    ? Colors.white.withOpacity(0.04)
                                    : Colors.black.withOpacity(0.03),
                                borderColor: isDark
                                    ? Colors.white.withOpacity(0.10)
                                    : Colors.black.withOpacity(0.06),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _liked ? Icons.favorite : Icons.favorite_border,
                                      size: 15,
                                      color: _liked
                                          ? Colors.redAccent
                                          : (isDark ? Colors.white.withOpacity(0.70) : p.textSecondary),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${post.likes} likes',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white.withOpacity(0.80) : p.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.s16),
                        GestureDetector(
                          onTap: _comments.isEmpty
                              ? _focusCommentField
                              : _scrollToComments,
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s16,
                              vertical: AppSpacing.s12,
                            ),
                            radius: 16,
                            color: isDark
                                ? Colors.white.withOpacity(0.04)
                                : Colors.black.withOpacity(0.03),
                            borderColor: isDark
                                ? Colors.white.withOpacity(0.10)
                                : Colors.black.withOpacity(0.06),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.forum_outlined,
                                  size: 20,
                                  color: p.primary,
                                ),
                                const SizedBox(width: AppSpacing.s12),
                                Expanded(
                                  child: Text(
                                    _comments.isEmpty
                                        ? 'Be the first to comment'
                                        : '${_comments.length} comment${_comments.length == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white.withOpacity(0.90) : p.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  _comments.isEmpty ? 'Comment' : 'View all',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: p.primary,
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  size: 20,
                                  color: p.primary,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.s24),
                        Divider(height: 1, color: p.glassBorder),
                        const SizedBox(height: AppSpacing.s16),

                        // Comments section
                        KeyedSubtree(
                          key: _commentsSectionKey,
                          child: Text(
                            'Comments (${_comments.length})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: p.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        if (_comments.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.s24,
                            ),
                            child: Text(
                              'No comments yet. Use the bar below to share your thoughts.',
                              style: TextStyle(
                                fontSize: 13,
                                color: p.textHint,
                                height: 1.4,
                              ),
                            ),
                          ),

                        // Comments list
                        ..._comments.map((c) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                            child: GlassCard(
                              padding: const EdgeInsets.all(12),
                              radius: 16,
                              color: isDark
                                  ? Colors.white.withOpacity(0.03)
                                  : Colors.black.withOpacity(0.02),
                              borderColor: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.black.withOpacity(0.04),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: p.primary,
                                    child: Text(
                                      (c.user?.name ?? '?')[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              c.user?.name ?? 'User',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white : p.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              timeago.format(c.createdAt),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? Colors.white.withOpacity(0.50) : p.textHint,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          c.text,
                                          style: TextStyle(
                                            fontSize: 14,
                                            height: 1.4,
                                            color: isDark ? Colors.white.withOpacity(0.90) : p.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
        if (sourcePublishedAt != null)
          'sourcePublishedAt': sourcePublishedAt!.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };
}

class _GlassActionIconButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final String? tooltip;

  const _GlassActionIconButton({
    required this.icon,
    required this.onPressed,
    this.onLongPress,
    this.tooltip,
  });

  @override
  State<_GlassActionIconButton> createState() => _GlassActionIconButtonState();
}

class _GlassActionIconButtonState extends State<_GlassActionIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _isPressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Tooltip(
          message: widget.tooltip ?? '',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withOpacity(0.40)
                        : Colors.white.withOpacity(0.65),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.24)
                          : Colors.black.withOpacity(0.12),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: widget.icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
