import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/reporter_provider.dart';
import '../../services/auth_provider.dart';
import '../../widgets/shimmer_widgets.dart';
import '../../widgets/dailyhunt/xpresso_sliver_app_bar.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';
import '../../utils/app_utils.dart';
import '../../utils/i18n.dart';

class ReporterDashboardScreen extends StatefulWidget {
  const ReporterDashboardScreen({super.key});
  @override
  State<ReporterDashboardScreen> createState() => _State();
}

class _State extends State<ReporterDashboardScreen> {
  @override
  void initState() {
    super.initState();
    final p = context.read<ReporterProvider>();
    p.loadStats();
    p.loadMyPosts();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ReporterProvider>();
    final user = context.watch<AuthProvider>().user;
    final fx = FeedXpressoTheme.fx(context);
    final bottomInset = FeedXpressoTheme.feedBottomInset(context);

    return RefreshIndicator(
      onRefresh: () async {
        await p.loadStats();
        await p.loadMyPosts();
      },
      color: fx.accent,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          XpressoSliverAppBar(
            title: I18n.t(context, 'reporter_hub_title'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Hello, ${user?.name ?? ''}',
                style: TextStyle(fontSize: 13, color: fx.summary),
              ),
            ),
          ),
          if (p.loading && p.stats == null)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: StatsShimmer(),
              ),
            )
          else ...[
            if (p.stats != null)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Stats',
                        style: fx.screenTitleStyle.copyWith(fontSize: 15),
                      ),
                      SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.6,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _StatCard(
                            label: 'Total Posts',
                            value: '${p.stats!['totalPosts']}',
                            icon: Icons.article_outlined,
                            color: fx.accent,
                          ),
                          _StatCard(
                            label: 'Approved',
                            value: '${p.stats!['approved']}',
                            icon: Icons.check_circle_outline,
                            color: fx.success,
                          ),
                          _StatCard(
                            label: 'Pending',
                            value: '${p.stats!['pending']}',
                            icon: Icons.pending_outlined,
                            color: fx.onWarningSurface,
                          ),
                          _StatCard(
                            label: 'Total Views',
                            value: AppUtils.formatCount(p.stats!['totalViews'] ?? 0),
                            icon: Icons.visibility_outlined,
                            color: fx.info,
                          ),
                          _StatCard(
                            label: 'Rejected',
                            value: '${p.stats!['rejected']}',
                            icon: Icons.cancel_outlined,
                            color: fx.error,
                          ),
                          _StatCard(
                            label: 'Total Likes',
                            value: AppUtils.formatCount(p.stats!['totalLikes'] ?? 0),
                            icon: Icons.favorite_outline,
                            color: fx.accentSecondary,
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      Text(
                        'Quick Actions',
                        style: fx.screenTitleStyle.copyWith(fontSize: 15),
                      ),
                      SizedBox(height: 12),
                      _ActionTile(
                        icon: Icons.add_circle_outline,
                        title: 'Create New Story',
                        subtitle: 'Write, add media, and submit',
                        color: fx.accent,
                        onTap: () => context.go('/reporter/new'),
                      ),
                      SizedBox(height: 10),
                      _ActionTile(
                        icon: Icons.article_outlined,
                        title: 'All My Stories',
                        subtitle: 'Track status of your posts',
                        color: fx.info,
                        onTap: () => context.go('/reporter/posts'),
                      ),
                      if ((p.stats?['pending'] ?? 0) > 0) ...[
                        SizedBox(height: 10),
                        _ActionTile(
                          icon: Icons.pending_outlined,
                          title: 'Pending Review (${p.stats!['pending']})',
                          subtitle: 'Awaiting admin approval',
                          color: fx.onWarningSurface,
                          onTap: () => context.go('/reporter/posts'),
                        ),
                      ],
                      if ((p.stats?['rejected'] ?? 0) > 0) ...[
                        SizedBox(height: 10),
                        _ActionTile(
                          icon: Icons.edit_note,
                          title: 'Needs Revision (${p.stats!['rejected']})',
                          subtitle: 'Rejected stories to fix',
                          color: fx.error,
                          onTap: () => context.go('/reporter/posts'),
                        ),
                      ],
                      SizedBox(height: bottomInset),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fx.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fx.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: fx.title,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fx.summary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fx.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fx.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: fx.title,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: fx.summary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: fx.summary, size: 18),
          ],
        ),
      ),
    );
  }
}
