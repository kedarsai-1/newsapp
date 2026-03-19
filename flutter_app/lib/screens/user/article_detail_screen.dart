import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../constants.dart';

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
  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final postRes = await ApiService.getPost(widget.postId);
    final commentRes = await ApiService.getComments(widget.postId);
    if (mounted) {
      setState(() {
        if (postRes['success'] == true) _post = NewsPost.fromJson(postRes['post']);
        if (commentRes['success'] == true) {
          _comments = (commentRes['comments'] as List).map((c) => Comment.fromJson(c)).toList();
        }
        _loading = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    final res = await ApiService.toggleLike(widget.postId);
    if (res['success'] == true && mounted) {
      setState(() {
        _liked = res['liked'];
        if (_post != null) {
          _post = NewsPost.fromJson({..._post!.toJsonMap(), 'likes': res['likes']});
        }
      });
    }
  }

  Future<void> _toggleBookmark() async {
    final res = await ApiService.toggleBookmark(widget.postId);
    if (res['success'] == true && mounted) setState(() => _bookmarked = res['bookmarked']);
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final res = await ApiService.addComment(widget.postId, text);
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

  @override
  Widget build(BuildContext context) {
    final imageFit = kIsWeb ? BoxFit.contain : BoxFit.cover;
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_post == null) return const Scaffold(body: Center(child: Text('Article not found.')));
    final post = _post!;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: post.hasImages ? 240 : 0,
            pinned: true,
            flexibleSpace: post.hasImages
                ? FlexibleSpaceBar(
                    background: CachedNetworkImage(
                      imageUrl: post.firstImage!.url,
                      fit: imageFit,
                    ),
                  )
                : null,
            actions: [
              IconButton(
                icon: Icon(_liked ? Icons.favorite : Icons.favorite_border, color: _liked ? Colors.red : null),
                onPressed: _toggleLike,
              ),
              IconButton(
                icon: Icon(_bookmarked ? Icons.bookmark : Icons.bookmark_border, color: _bookmarked ? AppColors.primary : null),
                onPressed: _toggleBookmark,
              ),
              IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category & breaking badge
                  Wrap(spacing: 8, children: [
                    if (post.isBreaking)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.breaking, borderRadius: BorderRadius.circular(6)),
                        child: const Text('BREAKING', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    if (post.category != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFE1F5EE), borderRadius: BorderRadius.circular(6)),
                        child: Text('${post.category!.icon} ${post.category!.name}', style: const TextStyle(color: AppColors.primaryDark, fontSize: 11, fontWeight: FontWeight.w500)),
                      ),
                  ]),
                  const SizedBox(height: 12),

                  // Title
                  Text(post.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary, height: 1.3)),
                  const SizedBox(height: 12),

                  // Meta
                  Row(children: [
                    if (post.reporter != null) ...[
                      CircleAvatar(radius: 14, backgroundColor: AppColors.primary, child: Text(post.reporter!.name[0], style: const TextStyle(color: Colors.white, fontSize: 12))),
                      const SizedBox(width: 8),
                      Text(post.reporter!.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                    ],
                    Text(timeago.format(post.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                  ]),

                  if (post.location != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(post.location!.displayLocation, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                    ]),
                  ],

                  const Divider(height: 28),

                  // Article body
                  Text(post.body, style: const TextStyle(fontSize: 16, color: AppColors.textPrimary, height: 1.7)),

                  // Tags
                  if (post.tags.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8, runSpacing: 6,
                      children: post.tags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(20)),
                        child: Text('#$tag', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      )).toList(),
                    ),
                  ],

                  // Stats row
                  const SizedBox(height: 20),
                  Row(children: [
                    Icon(Icons.visibility_outlined, size: 16, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text('${post.views} views', style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
                    const SizedBox(width: 16),
                    Icon(_liked ? Icons.favorite : Icons.favorite_border, size: 16, color: _liked ? Colors.red : AppColors.textHint),
                    const SizedBox(width: 4),
                    Text('${post.likes} likes', style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
                  ]),

                  const Divider(height: 32),

                  // Comments section
                  Text('Comments (${_comments.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),

                  // Add comment
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        decoration: InputDecoration(
                          hintText: 'Write a comment...',
                          hintStyle: const TextStyle(fontSize: 14),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: AppColors.primary),
                      onPressed: _submitComment,
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // Comments list
                  ..._comments.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(radius: 16, backgroundColor: AppColors.primary, child: Text(c.user?.name[0] ?? '?', style: const TextStyle(color: Colors.white, fontSize: 12))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.user?.name ?? 'User', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text(c.text, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                            const SizedBox(height: 3),
                            Text(timeago.format(c.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
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
        ],
      ),
    );
  }
}

// Extension to allow NewsPost to export a map (for local mutation)
extension NewPostMap on NewsPost {
  Map<String, dynamic> toJsonMap() => {
    '_id': id, 'title': title, 'body': body, 'summary': summary,
    'reporter': reporter != null ? {'_id': reporter!.id, 'name': reporter!.name, 'avatar': reporter!.avatar} : null,
    'category': category != null ? {'_id': category!.id, 'name': category!.name, 'slug': category!.slug, 'icon': category!.icon, 'color': category!.color} : null,
    'media': media.map((m) => {'_id': m.id, 'type': m.type, 'url': m.url, 'thumbnail': m.thumbnail, 'size': m.size}).toList(),
    'location': location != null ? {'latitude': location!.latitude, 'longitude': location!.longitude, 'address': location!.address, 'city': location!.city, 'state': location!.state, 'country': location!.country} : null,
    'status': status, 'rejectionReason': rejectionReason,
    'views': views, 'likes': likes, 'isBreaking': isBreaking, 'isFeatured': isFeatured,
    'tags': tags, 'createdAt': createdAt.toIso8601String(),
  };
}