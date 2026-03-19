import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../providers/admin_provider.dart';
import '../../widgets/shimmer_widgets.dart';
import '../../utils/app_utils.dart';
import '../../models/models.dart';
import '../../constants.dart';

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
    final p = context.watch<AdminProvider>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        showBack: false,
        title: const Text('Admin Panel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: GlassColors.textPrimary)),
        actions: [GlassBadge(label: 'Admin', accentColor: GlassColors.accentOrange, icon: Icons.admin_panel_settings), const SizedBox(width: 12)],
      ),
      body: p.loading && p.dashboardStats == null
          ? ListView(padding: const EdgeInsets.all(16), children: [const StatsShimmer()])
          : RefreshIndicator(
              onRefresh: () => p.loadDashboard(),
              color: GlassColors.accentGreenLight,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (p.dashboardStats != null) ...[
                  const Text('Overview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: GlassColors.textPrimary)),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
                    childAspectRatio: 1.5, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    children: [
                      GlassStatCard(label: 'Total Users', value: '${p.dashboardStats!['totalUsers']}', icon: Icons.people_outline, accentColor: GlassColors.info),
                      GlassStatCard(label: 'Reporters', value: '${p.dashboardStats!['totalReporters']}', icon: Icons.mic_outlined, accentColor: GlassColors.accentGreenLight),
                      GlassStatCard(label: 'Pending Review', value: '${p.dashboardStats!['pendingPosts']}', icon: Icons.pending_outlined, accentColor: GlassColors.warning),
                      GlassStatCard(label: 'Published Today', value: '${p.dashboardStats!['approvedToday']}', icon: Icons.check_circle_outline, accentColor: GlassColors.success),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                const Text('Management', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: GlassColors.textPrimary)),
                const SizedBox(height: 12),
                _ActionTile(icon: Icons.pending_actions, label: 'Review Pending Posts',
                    badge: p.dashboardStats?['pendingPosts']?.toString(), color: GlassColors.warning, onTap: () => context.go('/admin/pending')),
                const SizedBox(height: 10),
                _ActionTile(icon: Icons.people, label: 'Manage Users', color: GlassColors.info, onTap: () => context.go('/admin/users')),

                if (p.recentActivity.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Needs Review', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: GlassColors.textPrimary)),
                    TextButton(onPressed: () => context.go('/admin/pending'),
                        child: const Text('View All', style: TextStyle(color: GlassColors.accentGreenLight))),
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
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: GlassColors.textPrimary))),
          if (badge != null && badge != '0')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: GlassColors.warning.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: GlassColors.warning.withOpacity(0.4))),
              child: Text(badge!, style: TextStyle(color: GlassColors.warning, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: GlassColors.textHint, size: 18),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: GlassColors.surfaceWhite, borderRadius: BorderRadius.circular(14), border: Border.all(color: GlassColors.borderWhite, width: 0.8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 14, backgroundColor: GlassColors.accentPurpleSurface, child: Text(AppUtils.initials(post.reporter?.name ?? '?'), style: const TextStyle(color: GlassColors.accentPurpleLight, fontSize: 10, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(post.reporter?.name ?? 'Reporter', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GlassColors.textPrimary)),
            Text(timeago.format(post.createdAt), style: const TextStyle(fontSize: 10, color: GlassColors.textHint)),
          ])),
          if (post.category != null)
            GlassBadge(label: post.category!.name, accentColor: GlassColors.accentGreen),
        ]),
        const SizedBox(height: 8),
        Text(post.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GlassColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () async {
              final ctrl = TextEditingController();
              final reason = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
                title: const Text('Rejection Reason'),
                content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Why is this being rejected?'), maxLines: 3, style: const TextStyle(color: GlassColors.textPrimary)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Reject')),
                ],
              ));
              if (reason != null && reason.isNotEmpty) {
                final ok = await provider.rejectPost(post.id, reason);
                if (ok && context.mounted) AppUtils.showInfo(context, 'Post rejected.');
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: GlassColors.accentOrangeSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: GlassColors.accentOrangeBorder)),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.close, size: 14, color: GlassColors.accentOrangeLight),
                SizedBox(width: 4),
                Text('Reject', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlassColors.accentOrangeLight)),
              ]),
            ),
          )),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: GestureDetector(
            onTap: () async {
              final ok = await provider.approvePost(post.id);
              if (ok && context.mounted) AppUtils.showSuccess(context, 'Story published!');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [GlassColors.accentGreen.withOpacity(0.5), GlassColors.accentGreen.withOpacity(0.3)]),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: GlassColors.accentGreenBorder),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.check, size: 14, color: GlassColors.accentGreenLight),
                SizedBox(width: 4),
                Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlassColors.accentGreenLight)),
              ]),
            ),
          )),
        ]),
      ]),
    );
  }
}