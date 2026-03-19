import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/reporter_provider.dart';
import '../../services/auth_provider.dart';
import '../../widgets/shimmer_widgets.dart';
import '../../utils/app_utils.dart';
import '../../constants.dart';

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
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        showBack: false,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Reporter Hub', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: GlassColors.textPrimary)),
          Text('Hello, ${user?.name ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: GlassColors.textTertiary)),
        ]),
        actions: [GlassBadge(label: 'Reporter', accentColor: GlassColors.accentGreen, icon: Icons.mic), const SizedBox(width: 12)],
      ),
      body: p.loading && p.stats == null
          ? ListView(padding: const EdgeInsets.all(16), children: [const StatsShimmer()])
          : RefreshIndicator(
              onRefresh: () async { await p.loadStats(); await p.loadMyPosts(); },
              color: GlassColors.accentGreenLight,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (p.stats != null) ...[
                  const Text('Your Stats', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: GlassColors.textPrimary)),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
                    childAspectRatio: 1.6, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    children: [
                      GlassStatCard(label: 'Total Posts', value: '${p.stats!['totalPosts']}', icon: Icons.article_outlined, accentColor: GlassColors.accentGreen),
                      GlassStatCard(label: 'Approved', value: '${p.stats!['approved']}', icon: Icons.check_circle_outline, accentColor: GlassColors.success),
                      GlassStatCard(label: 'Pending', value: '${p.stats!['pending']}', icon: Icons.pending_outlined, accentColor: GlassColors.warning),
                      GlassStatCard(label: 'Total Views', value: AppUtils.formatCount(p.stats!['totalViews'] ?? 0), icon: Icons.visibility_outlined, accentColor: GlassColors.info),
                      GlassStatCard(label: 'Rejected', value: '${p.stats!['rejected']}', icon: Icons.cancel_outlined, accentColor: GlassColors.error),
                      GlassStatCard(label: 'Total Likes', value: AppUtils.formatCount(p.stats!['totalLikes'] ?? 0), icon: Icons.favorite_outline, accentColor: GlassColors.accentOrangeLight),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                const Text('Quick Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: GlassColors.textPrimary)),
                const SizedBox(height: 12),
                _ActionTile(icon: Icons.add_circle_outline, title: 'Create New Story', subtitle: 'Write, add media, and submit', color: GlassColors.accentGreen, onTap: () => context.go('/reporter/new')),
                const SizedBox(height: 10),
                _ActionTile(icon: Icons.article_outlined, title: 'All My Stories', subtitle: 'Track status of your posts', color: GlassColors.info, onTap: () => context.go('/reporter/posts')),
                if ((p.stats?['pending'] ?? 0) > 0) ...[
                  const SizedBox(height: 10),
                  _ActionTile(icon: Icons.pending_outlined, title: 'Pending Review (${p.stats!['pending']})', subtitle: 'Awaiting admin approval', color: GlassColors.warning, onTap: () => context.go('/reporter/posts')),
                ],
                if ((p.stats?['rejected'] ?? 0) > 0) ...[
                  const SizedBox(height: 10),
                  _ActionTile(icon: Icons.edit_note, title: 'Needs Revision (${p.stats!['rejected']})', subtitle: 'Rejected stories to fix', color: GlassColors.error, onTap: () => context.go('/reporter/posts')),
                ],
              ]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/reporter/new'),
        backgroundColor: GlassColors.accentGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Story', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: GlassColors.textPrimary)),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: GlassColors.textTertiary)),
          ])),
          Icon(Icons.chevron_right, color: GlassColors.textHint, size: 18),
        ]),
      ),
    );
  }
}