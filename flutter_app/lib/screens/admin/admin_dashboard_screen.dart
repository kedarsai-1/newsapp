import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../providers/admin_provider.dart';
import '../../widgets/shimmer_widgets.dart';
import '../../utils/app_utils.dart';
import '../../models/models.dart';
import '../../constants.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _State();
}

class _State extends State<AdminDashboardScreen> {
  @override
  void initState() { super.initState(); context.read<AdminProvider>().loadDashboard(); }

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    final p = context.watch<AdminProvider>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        showBack: false,
        title: Text('Admin Panel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: fx.title)),
        actions: [GlassBadge(label: 'Admin', accentColor: fx.accentSecondary, icon: Icons.admin_panel_settings), SizedBox(width: 12)],
      ),
      body: p.loading && p.dashboardStats == null
          ? ListView(padding: const EdgeInsets.all(16), children: [const StatsShimmer()])
          : RefreshIndicator(
              onRefresh: () => p.loadDashboard(),
              color: fx.accentLight,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (p.dashboardStats != null) ...[
                  Text('Overview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fx.title)),
                  SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
                    childAspectRatio: 1.5, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    children: [
                      GlassStatCard(label: 'Total Users', value: '${p.dashboardStats!['totalUsers']}', icon: Icons.people_outline, accentColor: fx.info),
                      GlassStatCard(label: 'Reporters', value: '${p.dashboardStats!['totalReporters']}', icon: Icons.mic_outlined, accentColor: fx.accentLight),
                      GlassStatCard(label: 'Pending Review', value: '${p.dashboardStats!['pendingPosts']}', icon: Icons.pending_outlined, accentColor: fx.warning),
                      GlassStatCard(label: 'Published Today', value: '${p.dashboardStats!['approvedToday']}', icon: Icons.check_circle_outline, accentColor: fx.success),
                    ],
                  ),
                  SizedBox(height: 24),
                ],

                Text('Management', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fx.title)),
                SizedBox(height: 12),
                _ActionTile(icon: Icons.pending_actions, label: 'Review Pending Posts',
                    badge: p.dashboardStats?['pendingPosts']?.toString(), color: fx.warning, onTap: () => context.go('/admin/pending')),
                SizedBox(height: 10),
                _ActionTile(icon: Icons.people, label: 'Manage Users', color: fx.info, onTap: () => context.go('/admin/users')),
                SizedBox(height: 10),
                _ActionTile(
                  icon: Icons.play_circle_outline,
                  label: 'Run YouTube ingest',
                  color: fx.accentLight,
                  onTap: () async {
                    final res = await p.runYoutubeIngestion();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          res['message']?.toString() ??
                              (res['success'] == true
                                  ? 'YouTube ingest started'
                                  : 'YouTube ingest failed'),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 10),
                _ActionTile(
                  icon: Icons.account_balance_outlined,
                  label: 'Run political video ingest',
                  color: fx.info,
                  onTap: () async {
                    final res = await p.runPoliticalVideoIngestion();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          res['message']?.toString() ??
                              (res['success'] == true
                                  ? 'Political ingest started'
                                  : 'Political ingest failed'),
                        ),
                      ),
                    );
                  },
                ),

                if (p.recentActivity.isNotEmpty) ...[
                  SizedBox(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Needs Review', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fx.title)),
                    TextButton(onPressed: () => context.go('/admin/pending'),
                        child: Text('View All', style: TextStyle(color: fx.accentLight))),
                  ]),
                  ...p.recentActivity.map((post) => _PendingRow(post: post, provider: p)),
                ],
              ]),
            ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, this.badge, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
          SizedBox(width: 14),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fx.title))),
          if (badge != null && badge != '0')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: fx.warning.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: fx.warning.withOpacity(0.4))),
              child: Text(badge!, style: TextStyle(color: fx.warning, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          SizedBox(width: 8),
          Icon(Icons.chevron_right, color: fx.textHint, size: 18),
        ]),
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  final NewsPost post;
  final AdminProvider provider;
  const _PendingRow({required this.post, required this.provider});

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: fx.glassSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: fx.glassBorder, width: 0.8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 14, backgroundColor: fx.accentTertiarySurface, child: Text(AppUtils.initials(post.reporter?.name ?? '?'), style: TextStyle(color: fx.accentTertiaryLight, fontSize: 10, fontWeight: FontWeight.bold))),
          SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(post.reporter?.name ?? 'Reporter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fx.title)),
            Text(timeago.format(post.createdAt), style: TextStyle(fontSize: 10, color: fx.textHint)),
          ])),
          if (post.category != null)
            GlassBadge(label: post.category!.name, accentColor: fx.accent),
        ]),
        SizedBox(height: 8),
        Text(post.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fx.title), maxLines: 2, overflow: TextOverflow.ellipsis),
        SizedBox(height: 10),
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () async {
              final ctrl = TextEditingController();
              final reason = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
                title: Text('Rejection Reason'),
                content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Why is this being rejected?'), maxLines: 3, style: TextStyle(color: fx.title)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text('Reject')),
                ],
              ));
              if (reason != null && reason.isNotEmpty) {
                final ok = await provider.rejectPost(post.id, reason);
                if (ok && context.mounted) AppUtils.showInfo(context, 'Post rejected.');
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: fx.accentSecondarySurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: fx.accentSecondaryBorder)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.close, size: 14, color: fx.accentSecondaryLight),
                SizedBox(width: 4),
                Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fx.accentSecondaryLight)),
              ]),
            ),
          )),
          SizedBox(width: 8),
          Expanded(flex: 2, child: GestureDetector(
            onTap: () async {
              final ok = await provider.approvePost(post.id);
              if (ok && context.mounted) AppUtils.showSuccess(context, 'Story published!');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [fx.accent.withOpacity(0.5), fx.accent.withOpacity(0.3)]),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: fx.accentBorder),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.check, size: 14, color: fx.accentLight),
                SizedBox(width: 4),
                Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fx.accentLight)),
              ]),
            ),
          )),
        ]),
      ]),
    );
  }
}
