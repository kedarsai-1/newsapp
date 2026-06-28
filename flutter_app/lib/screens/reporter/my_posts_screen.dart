import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/models.dart';
import '../../providers/reporter_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/dailyhunt/xpresso_sliver_app_bar.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';
import '../../utils/app_utils.dart';
import '../../utils/i18n.dart';
import '../../widgets/location_label.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});
  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _statuses = [null, 'pending', 'approved', 'rejected', 'draft'];

  List<String> _labels(BuildContext context) => [
        I18n.t(context, 'posts_tab_all'),
        I18n.t(context, 'posts_tab_pending'),
        I18n.t(context, 'posts_tab_approved'),
        I18n.t(context, 'posts_tab_rejected'),
        I18n.t(context, 'posts_tab_draft'),
      ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _load(_tabs.index);
    });
    _load(0);
  }

  void _load(int i) =>
      context.read<ReporterProvider>().loadMyPosts(status: _statuses[i]);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReporterProvider>();
    final fx = FeedXpressoTheme.fx(context);
    final bottomInset = FeedXpressoTheme.feedBottomInset(context);
    final labels = _labels(context);

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        XpressoSliverAppBar(title: I18n.t(context, 'tab_my_posts')),
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarHeader(
            tabController: _tabs,
            labels: labels,
            accent: fx.accent,
            background: fx.background,
            divider: fx.divider,
            titleColor: fx.title,
            subtitleColor: fx.summary,
          ),
        ),
      ],
      body: provider.loading
          ? Center(child: CircularProgressIndicator(color: fx.accent))
          : provider.myPosts.isEmpty
              ? EmptyState(
                  icon: Icons.article_outlined,
                  title: 'No stories here',
                  subtitle: _tabs.index == 0
                      ? 'Start writing your first story.'
                      : null,
                  buttonLabel: _tabs.index == 0 ? 'Create Story' : null,
                  onButtonTap:
                      _tabs.index == 0 ? () => context.go('/reporter/new') : null,
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      provider.loadMyPosts(status: _statuses[_tabs.index]),
                  color: fx.accent,
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset),
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: provider.myPosts.length,
                    separatorBuilder: (_, __) => SizedBox(height: 10),
                    itemBuilder: (_, i) => _PostCard(
                      post: provider.myPosts[i],
                      fx: fx,
                      onEdit: () => context.go(
                        '/reporter/edit/${provider.myPosts[i].id}',
                      ),
                    ),
                  ),
                ),
    );
  }
}

class _TabBarHeader extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final List<String> labels;
  final Color accent;
  final Color background;
  final Color divider;
  final Color titleColor;
  final Color subtitleColor;

  _TabBarHeader({
    required this.tabController,
    required this.labels,
    required this.accent,
    required this.background,
    required this.divider,
    required this.titleColor,
    required this.subtitleColor,
  });

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: background,
      child: Column(
        children: [
          TabBar(
            controller: tabController,
            isScrollable: true,
            labelColor: accent,
            unselectedLabelColor: subtitleColor,
            indicatorColor: accent,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle:
                TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: labels.map((l) => Tab(text: l)).toList(),
          ),
          Divider(height: 1, thickness: 1, color: divider),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarHeader oldDelegate) => true;
}

class _PostCard extends StatelessWidget {
  final NewsPost post;
  final FeedXpressoPalette fx;
  final VoidCallback onEdit;

  const _PostCard({
    required this.post,
    required this.fx,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    final statusColor = AppUtils.statusColor(post.status, context);
    return Container(
      decoration: BoxDecoration(
        color: fx.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fx.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(AppUtils.statusIcon(post.status), size: 14, color: statusColor),
                SizedBox(width: 6),
                Text(
                  post.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const Spacer(),
                Text(
                  timeago.format(post.createdAt),
                  style: TextStyle(fontSize: 11, color: fx.summary),
                ),
              ],
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: fx.title,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  children: [
                    if (post.category != null)
                      Text(
                        '${post.category!.icon} ${post.category!.name}',
                        style: TextStyle(fontSize: 12, color: fx.summary),
                      ),
                    if (post.location != null)
                      LocationLabel(
                        location: post.location!,
                        style: TextStyle(fontSize: 12, color: fx.summary),
                        iconSize: 12,
                        expandText: false,
                        maxTextWidth: 180,
                      ),
                  ],
                ),
                if (post.status == 'rejected' && post.rejectionReason != null) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: fx.errorSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: fx.errorBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 14, color: fx.error),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            post.rejectionReason!,
                            style: TextStyle(
                              fontSize: 12,
                              color: fx.onErrorSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 8),
                Row(
                  children: [
                    if (post.status == 'approved') ...[
                      Icon(Icons.visibility_outlined, size: 13, color: fx.summary),
                      SizedBox(width: 4),
                      Text(
                        AppUtils.formatCount(post.views),
                        style: TextStyle(fontSize: 12, color: fx.summary),
                      ),
                      SizedBox(width: 12),
                      Icon(Icons.favorite_border, size: 13, color: fx.summary),
                      SizedBox(width: 4),
                      Text(
                        AppUtils.formatCount(post.likes),
                        style: TextStyle(fontSize: 12, color: fx.summary),
                      ),
                      SizedBox(width: 12),
                    ],
                    if (post.media.isNotEmpty) ...[
                      Icon(Icons.perm_media_outlined, size: 13, color: fx.summary),
                      SizedBox(width: 4),
                      Text(
                        '${post.media.length} media',
                        style: TextStyle(fontSize: 12, color: fx.summary),
                      ),
                    ],
                    const Spacer(),
                    if (['draft', 'rejected'].contains(post.status))
                      TextButton.icon(
                        onPressed: onEdit,
                        icon: Icon(Icons.edit_outlined, size: 14, color: fx.accent),
                        label: Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: fx.accent,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
